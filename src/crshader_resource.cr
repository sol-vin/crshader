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
    property shader_target : String = "gdshader"

    property file_path : String = ""
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
        target = ShaderTarget.from_string?(@shader_target)
        variant = VariantCache.global.get_or_compile(
          source: @crshader_source,
          target: target,
          features: @active_features,
          strip_debug_inspects: @strip_debug_inspects,
          filename: @file_path.empty? ? nil : @file_path
        )
        if variant.target == ShaderTarget::GDShader
          set_code(variant.code) unless @pointer.null?
        end
        true
      rescue ex
        Godot.printerr("[CRShader] Compilation error in #{@file_path}: #{ex.message}")
        false
      end
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
