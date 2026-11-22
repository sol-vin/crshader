require "../ast/types"
require "../ast/shader_ast"
require "../runtime/variant_cache"

module CrShader
  # =============================================================================
  # Composer - Runtime Multi-Trait Shader Assembler & Variant Compiler
  # =============================================================================
  class Composer
    enum Mode
      Spatial
      CanvasItem
      ScreenEffect
      CompositorEffect
    end

    getter mode : Mode
    property preset : String? = nil
    property screen_mode : String = "canvas"
    property needs_depth : Bool = false
    property needs_normal_roughness : Bool = false
    property compositor_stage : String = "post_transparent"
    property render_mode_list : Array(String) = [] of String
    property traits : Array(TraitUse) = [] of TraitUse
    property declared_features : Array(Tuple(String, FeatureValue, Array(String))) = [] of Tuple(String, FeatureValue, Array(String))
    property feature_overrides : Hash(String, FeatureValue) = {} of String => FeatureValue
    property uniform_lines : Array(String) = [] of String
    property vertex_body : String? = nil
    property fragment_body : String? = nil
    property light_body : String? = nil
    property pixel_body : String? = nil
    property strip_debug_inspects : Bool = false

    def self.spatial(preset : Symbol | String? = nil) : self
      inst = new(Mode::Spatial)
      inst.preset = preset.try(&.to_s)
      inst
    end

    def self.canvas_item : self
      new(Mode::CanvasItem)
    end

    def self.screen_effect(mode : Symbol | String = :canvas, depth : Bool = false) : self
      inst = new(Mode::ScreenEffect)
      inst.screen_mode = mode.to_s
      inst.needs_depth = depth
      inst
    end

    def self.compositor_effect(
      stage : Symbol | String = :post_transparent,
      depth : Bool = false,
      normal_roughness : Bool = false,
    ) : self
      inst = new(Mode::CompositorEffect)
      inst.compositor_stage = stage.to_s
      inst.needs_depth = depth
      inst.needs_normal_roughness = normal_roughness
      inst
    end

    def initialize(@mode : Mode = Mode::Spatial)
    end

    def render_modes(*modes : Symbol | String) : self
      modes.each do |m|
        ms = m.to_s
        @render_mode_list << ms unless @render_mode_list.includes?(ms)
      end
      self
    end

    def with_trait(path_or_name : Symbol | String, prefix : Symbol | String? = nil) : self
      raw = path_or_name.to_s
      normalized = raw.includes?("/") || raw.ends_with?(".crshader") ? raw : "std/traits/#{raw}"
      @traits << TraitUse.new(normalized, prefix.try(&.to_s))
      self
    end

    def with_feature(
      name : Symbol | String,
      value : FeatureValue,
      options : Array(Symbol | String)? = nil,
    ) : self
      fname = name.to_s
      opts = options ? options.map(&.to_s) : ([] of String)
      unless @declared_features.any? { |df| df[0] == fname }
        @declared_features << {fname, value, opts}
      end
      @feature_overrides[fname] = value
      self
    end

    def with_uniform(
      name : Symbol | String,
      type_name : Symbol | String,
      default : String? = nil,
      hint : Symbol | String? = nil,
      range : ::Range(Float64, Float64) | ::Range(Float32, Float32)? = nil,
    ) : self
      line = String.build do |io|
        io << "property " << name.to_s << " : " << type_name.to_s
        io << " = " << default if default
        if r = range
          io << ", range: " << r.begin << ".." << r.end
        end
        if h = hint
          hs = h.to_s
          io << ", hint: " << (hs.includes?("(") ? hs : ":#{hs}")
        end
      end
      @uniform_lines << line
      self
    end

    def vertex(code : String) : self
      @vertex_body = code
      self
    end

    def fragment(code : String) : self
      @fragment_body = code
      self
    end

    def light(code : String) : self
      @light_body = code
      self
    end

    def pixel(code : String) : self
      @pixel_body = code
      self
    end

    def release(enabled : Bool = true) : self
      @strip_debug_inspects = enabled
      self
    end

    def to_crshader : String
      String.build do |io|
        case @mode
        when Mode::CompositorEffect
          io << "compositor_effect :" << @compositor_stage << " do\n"
          access_syms = [":color"]
          access_syms << ":depth" if @needs_depth
          access_syms << ":normal_roughness" if @needs_normal_roughness
          io << "  access " << access_syms.join(", ") << "\n"
          emit_declarations(io, "  ")
          if pb = @pixel_body
            io << "  process_pixel do |coord, uv, color|\n"
            pb.each_line { |l| io << "    " << l.rstrip << "\n" }
            io << "  end\n"
          end
          io << "end\n"
        when Mode::ScreenEffect
          emit_declarations(io, "")
          io << "screen_effect mode: :" << @screen_mode << ", depth: " << @needs_depth << " do |uv, color|\n"
          if pb = (@pixel_body || @fragment_body)
            pb.each_line { |l| io << "  " << l.rstrip << "\n" }
          else
            io << "  color\n"
          end
          io << "end\n"
        when Mode::Spatial
          if pr = @preset
            io << "surface_material :" << pr << " do\n"
            io << "  render_mode " << @render_mode_list.map { |m| ":#{m}" }.join(", ") << "\n" unless @render_mode_list.empty?
            emit_declarations(io, "  ")
            emit_stages(io, "  ", default_spatial_albedo: @fragment_body.nil?)
            io << "end\n"
          else
            io << "shader_type :spatial\n"
            io << "render_mode " << @render_mode_list.map { |m| ":#{m}" }.join(", ") << "\n" unless @render_mode_list.empty?
            emit_declarations(io, "")
            emit_stages(io, "", default_spatial_albedo: @fragment_body.nil?)
          end
        when Mode::CanvasItem
          io << "shader_type :canvas_item\n"
          io << "render_mode " << @render_mode_list.map { |m| ":#{m}" }.join(", ") << "\n" unless @render_mode_list.empty?
          emit_declarations(io, "")
          emit_stages(io, "", default_spatial_albedo: false)
        end
      end
    end

    def compile(target : ShaderTarget? = nil, cache : VariantCache = VariantCache.global) : String
      resolved_target = target || (@mode == Mode::CompositorEffect ? ShaderTarget::GLSL : nil)
      variant = cache.get_or_compile(
        source: to_crshader,
        target: resolved_target,
        features: @feature_overrides,
        strip_debug_inspects: @strip_debug_inspects
      )
      variant.code
    end

    private def emit_declarations(io : IO, pad : String) : Void
      @declared_features.each do |fname, def_val, opts|
        if !opts.empty?
          opts_str = opts.map { |o| ":#{o}" }.join(", ")
          io << pad << "feature :" << fname << ", options: [" << opts_str << "], default: :" << def_val.to_s << "\n"
        else
          val_lit = case def_val
                    when Bool   then def_val.to_s
                    when Int32  then def_val.to_s
                    when Symbol then ":#{def_val}"
                    else             "\"#{def_val}\""
                    end
          io << pad << "feature :" << fname << ", default: " << val_lit << "\n"
        end
      end

      @uniform_lines.each do |ul|
        io << pad << ul << "\n"
      end

      @traits.each do |tu|
        if p = tu.prefix
          io << pad << "use_trait \"" << tu.path_or_name << "\", prefix: :" << p << "\n"
        else
          io << pad << "use_trait \"" << tu.path_or_name << "\"\n"
        end
      end
    end

    private def emit_stages(io : IO, pad : String, default_spatial_albedo : Bool) : Void
      if vb = @vertex_body
        io << pad << "def vertex\n"
        vb.each_line { |l| io << pad << "  " << l.rstrip << "\n" }
        io << pad << "end\n"
      end

      if fb = @fragment_body
        io << pad << "def fragment\n"
        fb.each_line { |l| io << pad << "  " << l.rstrip << "\n" }
        io << pad << "end\n"
      elsif default_spatial_albedo
        io << pad << "def fragment\n"
        io << pad << "  ALBEDO = vec3(0.85, 0.85, 0.85)\n"
        io << pad << "end\n"
      end

      if lb = @light_body
        io << pad << "def light\n"
        lb.each_line { |l| io << pad << "  " << l.rstrip << "\n" }
        io << pad << "end\n"
      end
    end
  end
end
