require "lapis"
require "./crshader/compiler"

module CrShader
  include Godot

  class VariantCache
    @godot_shaders : Hash(UInt64, Godot::Shader) = {} of UInt64 => Godot::Shader

    def get_or_create_godot_shader(
      source : String,
      features : Hash(String, FeatureValue)? = nil,
      strip_debug_inspects : Bool = false,
      optimize_names : Bool = false,
      filename : String? = nil,
    ) : Godot::Shader?
      variant = get_or_compile(
        source: source,
        target: ShaderTarget::GDShader,
        features: features,
        strip_debug_inspects: strip_debug_inspects,
        optimize_names: optimize_names,
        filename: filename
      )

      @mutex.synchronize do
        if existing = @godot_shaders[variant.key]?
          if !existing.pointer.null? && existing.alive?
            return existing
          else
            @godot_shaders.delete(variant.key)
          end
        end
      end

      shader = Godot.create(Godot::Shader)
      return nil if shader.nil? || shader.pointer.null?
      shader.set_code(variant.code)

      @mutex.synchronize do
        @godot_shaders[variant.key] = shader
      end
      shader
    rescue
      nil
    end

    protected def evict_godot_entry(key : UInt64) : Void
      @godot_shaders.delete(key)
    end

    protected def clear_godot_entries : Void
      @godot_shaders.clear
    end
  end

  class Composer
    def compile_godot_shader(cache : VariantCache = VariantCache.global) : Godot::Shader?
      cache.get_or_create_godot_shader(
        source: to_crshader,
        features: @feature_overrides,
        strip_debug_inspects: @strip_debug_inspects
      )
    end
  end

  class ShaderBuilder
    def to_godot_shader(cache : VariantCache = VariantCache.global) : Godot::Shader?
      cache.get_or_create_godot_shader(
        source: to_crshader,
        features: @feature_overrides,
        strip_debug_inspects: @strip_debug_inspects
      )
    end
  end

  module ProceduralLUT
    def bake_gradient(
      stops,
      width : Int32 = 256,
      space : Symbol | String = :oklab,
      interp : Symbol | String = :linear,
    ) : Godot::Texture2D?
      w = Math.max(width, 2)
      bytes = sample_gradient_bytes(stops, width: w, space: space, interp: interp)
      bytes_to_1d_texture(bytes, w)
    end

    def bake_curve(
      points,
      width : Int32 = 256,
      interp : Symbol | String = :smooth,
    ) : Godot::Texture2D?
      w = Math.max(width, 2)
      bytes = sample_curve_bytes(points, width: w, interp: interp)
      bytes_to_1d_texture(bytes, w)
    end

    private def bytes_to_1d_texture(bytes : Bytes, width : Int32) : Godot::Texture2D?
      img = Godot.create(Godot::Image)
      return nil if img.nil? || img.pointer.null?
      pba = Godot::PackedByteArray.new(bytes.size)
      pba.to_unsafe.copy_from(bytes.to_unsafe, bytes.size)
      # Godot 4 Image::FORMAT_RGBA8 == 5
      img.call("set_data", width.to_i64, 1_i64, false, 5_i64, pba)
      Godot::ImageTexture.create_from_image(img)
    rescue
      nil
    end
  end

  # =============================================================================
  # CRShader - First-Class Shading Language Resource for Godot
  # =============================================================================
  # Inherits natively from Godot::Shader. Holds Crystal-based .crshader source
  # and compiles transparently in-memory into Godot's native shader bytecode.
  @[Tool]
  node CRShader < Godot::Shader do
    @[Export]
    property crshader_source : String = ""

    @[Export]
    property shader_target : String = "auto"

    property file_path : String = ""
    property last_compiled_code : String = ""
    property last_resolved_target : ShaderTarget = ShaderTarget::GDShader
    property last_error_message : String = ""
    property last_error_line : Int32 = 0
    property active_features : Hash(String, FeatureValue) = {} of String => FeatureValue
    property strip_debug_inspects : Bool = false

    def self.new(pointer : Void* = Pointer(Void).null) : self
      inst = allocate
      inst.initialize(pointer)
      inst
    end

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def set_crshader_source(source : String) : Void
      @crshader_source = source
      recompile
    end

    def set_feature(name : Symbol | String, value : FeatureValue) : Bool
      @active_features[name.to_s] = value
      recompile
    end

    def specialize(features : Hash(String, FeatureValue), cache : VariantCache = VariantCache.global) : Godot::Shader?
      merged = @active_features.merge(features)
      cache.get_or_create_godot_shader(
        source: @crshader_source,
        features: merged,
        strip_debug_inspects: @strip_debug_inspects,
        filename: @file_path.empty? ? nil : @file_path
      )
    end

    def specialize(**features) : Godot::Shader?
      map = @active_features.dup
      features.each do |k, v|
        map[k.to_s] = v.as(FeatureValue)
      end
      VariantCache.global.get_or_create_godot_shader(
        source: @crshader_source,
        features: map,
        strip_debug_inspects: @strip_debug_inspects,
        filename: @file_path.empty? ? nil : @file_path
      )
    end

    def recompile : Bool
      return false if @crshader_source.strip.empty?
      begin
        explicit_t = (@shader_target.strip.empty? || @shader_target.downcase == "auto") ? nil : ShaderTarget.from_string?(@shader_target)
        fs_file = resolve_disk_path(@file_path)
        eff_filename = fs_file.empty? ? (@file_path.empty? ? nil : @file_path) : fs_file
        variant = VariantCache.global.get_or_compile(
          source: @crshader_source,
          target: explicit_t,
          features: @active_features,
          strip_debug_inspects: @strip_debug_inspects,
          filename: eff_filename
        )
        @last_compiled_code = variant.code
        @last_resolved_target = variant.target
        @last_error_message = ""
        @last_error_line = 0
        if variant.target == ShaderTarget::GDShader
          set_code(variant.code) unless @pointer.null?
        end
        true
      rescue ex : ShaderError
        @last_error_message = ex.message || "Shader compilation error"
        @last_error_line = ex.line_number || 1
        Godot.printerr("[CRShader] Compilation error in #{@file_path}: #{@last_error_message}")
        false
      rescue ex
        @last_error_message = ex.message || "Shader compilation error"
        @last_error_line = 1
        Godot.printerr("[CRShader] Compilation error in #{@file_path}: #{@last_error_message}")
        false
      end
    end

    # Compiles all `emit_target` outputs (or default sibling output), optionally writes them to disk,
    # and hot-reloads any cached `Godot::Shader` resources in `ResourceLoader` so open scenes update live.
    def compile_and_sync_targets!(write_disk : Bool = true) : Array(Tuple(String, ShaderTarget, String))
      return [] of Tuple(String, ShaderTarget, String) if @crshader_source.strip.empty?
      explicit_t = (@shader_target.strip.empty? || @shader_target.downcase == "auto") ? nil : ShaderTarget.from_string?(@shader_target)
      fs_file = resolve_disk_path(@file_path)
      eff_filename = fs_file.empty? ? (@file_path.empty? ? nil : @file_path) : fs_file

      compiler = CrShader::Compiler.new(
        target_override: explicit_t,
        feature_overrides: @active_features,
        strip_debug_inspects: @strip_debug_inspects
      )
      outputs = compiler.compile_emit_targets(@crshader_source, filename: eff_filename, write_disk: write_disk)
      if first = outputs.first?
        @last_compiled_code = first[2]
        @last_resolved_target = first[1]
        @last_error_message = ""
        @last_error_line = 0
        if first[1] == ShaderTarget::GDShader && !@pointer.null?
          set_code(first[2])
        end
      end

      # Hot-update any loaded Godot::Shader resources in ResourceLoader cache (e.g. outline.gdshader & pattern_replace.gdshader)
      if !Godot::ProjectSettings.singleton_ptr.null? && !Godot::ResourceLoader.singleton_ptr.null?
        ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
        rl = Godot::ResourceLoader.new(Godot::ResourceLoader.singleton_ptr)
        outputs.each do |out_fs_path, tgt, code|
          next unless tgt == ShaderTarget::GDShader && !out_fs_path.empty?
          res_path = ps.call_str("localize_path", out_fs_path.gsub('\\', '/'))
          next unless res_path.starts_with?("res://")
          has_cached = (rl.call_bool("has_cached", res_path) rescue false)
          if has_cached
            if cached_obj = (rl.call_obj("load", res_path, "Shader", 1_i64) rescue nil)
              if !cached_obj.pointer.null? && cached_obj.pointer != @pointer
                cached_obj.call("set_code", code) rescue nil
              end
            end
          end
        end
      end

      outputs
    end

    def resolve_disk_path(path : String) : String
      return "" if path.empty?
      if path.starts_with?("res://") || path.starts_with?("user://")
        if !Godot::ProjectSettings.singleton_ptr.null?
          ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
          gp = ps.call_str("globalize_path", path).gsub('\\', '/')
          return gp if !gp.empty?
        end
        stripped = path.sub(/^(res|user):\/\//, "")
        return File.expand_path(stripped) if File.exists?(stripped)
        return stripped
      end
      path
    end

    # Tool button: Exports compiled GDShader to disk on-demand
    @[ExportToolButton("Export to .gdshader")]
    def export_gdshader : Void
      export_to_format("gdshader")
    end

    # Tool button: Exports compiled GDShader include header (.gdshaderinc) to disk on-demand
    @[ExportToolButton("Export to .gdshaderinc")]
    def export_gdshaderinc : Void
      export_to_format("gdshaderinc")
    end

    # Tool button: Exports compiled GLSL compute shader to disk on-demand
    @[ExportToolButton("Export to .glsl")]
    def export_glsl : Void
      export_to_format("glsl")
    end

    # Tool button: Recompiles shader in-memory
    @[ExportToolButton("Recompile Shader")]
    def trigger_recompile : Void
      if recompile
        Godot.print("[CRShader] Successfully recompiled shader in-memory.")
      end
    end

    private def export_to_format(format : String) : Void
      target = ShaderTarget.from_string?(format) || ShaderTarget::GDShader
      compiler = CrShader::Compiler.new(
        target_override: target,
        feature_overrides: @active_features,
        strip_debug_inspects: @strip_debug_inspects
      )
      transpiled = compiler.compile_source(@crshader_source, filename: @file_path.empty? ? nil : @file_path)

      base_path = @file_path.empty? ? "res://exported_shader" : @file_path.sub(/\.crshader$/, "")
      out_ext = case target
                when ShaderTarget::GLSL        then ".glsl"
                when ShaderTarget::GDShaderInc then ".gdshaderinc"
                else                                ".gdshader"
                end
      out_path = "#{base_path}#{out_ext}"

      global_path = out_path
      if !Godot::ProjectSettings.singleton_ptr.null?
        ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
        gp = ps.call_str("globalize_path", out_path).gsub('\\', '/')
        global_path = gp unless gp.empty?
      end

      File.write(global_path, transpiled)
      Godot.print("[CRShader] Exported #{format.upcase} to #{out_path}")
    rescue ex
      Godot.printerr("[CRShader] Export #{format} failed: #{ex.message}")
    end
  end
end
