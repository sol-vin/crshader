require "../ast/types"
require "../ast/shader_ast"
require "../runtime/variant_cache"
require "../language/gradients_and_curves"

module CrShader
  # =============================================================================
  # ShaderBuilder - Programmatic Crystal Shader Constructor & Procedural Mutator
  # =============================================================================
  class ShaderBuilder
    getter shader_type_kind : String
    property render_modes : Array(String) = [] of String
    property requires : Array(String) = [] of String
    property declaration_lines : Array(String) = [] of String
    property traits : Array(TraitUse) = [] of TraitUse
    property feature_overrides : Hash(String, FeatureValue) = {} of String => FeatureValue
    property helper_defs : Array(String) = [] of String
    property vertex_chunks : Array(String) = [] of String
    property fragment_chunks : Array(String) = [] of String
    property light_chunks : Array(String) = [] of String
    property pixel_chunks : Array(String) = [] of String
    property compositor_stage : String = "post_transparent"
    property compositor_access : Array(String) = ["color"]
    property strip_debug_inspects : Bool = false

    def initialize(shader_type : Symbol | String = :spatial)
      @shader_type_kind = shader_type.to_s.downcase
    end

    def render_mode(*modes : Symbol | String) : self
      modes.each do |m|
        ms = m.to_s
        @render_modes << ms unless @render_modes.includes?(ms)
      end
      self
    end

    def require_lib(*libs : String) : self
      libs.each do |l|
        @requires << l unless @requires.includes?(l)
      end
      self
    end

    def feature(
      name : Symbol | String,
      default : FeatureValue = true,
      options : Array(Symbol | String)? = nil,
    ) : self
      fname = name.to_s
      if options && !options.empty?
        opts_str = options.map { |o| ":#{o}" }.join(", ")
        @declaration_lines << "feature :#{fname}, options: [#{opts_str}], default: :#{default}"
      else
        val_lit = case default
                  when Bool   then default.to_s
                  when Int32  then default.to_s
                  when Symbol then ":#{default}"
                  else             "\"#{default}\""
                  end
        @declaration_lines << "feature :#{fname}, default: #{val_lit}"
      end
      @feature_overrides[fname] = default unless @feature_overrides.has_key?(fname)
      self
    end

    def set_feature(name : Symbol | String, value : FeatureValue) : self
      @feature_overrides[name.to_s] = value
      self
    end

    def uniform(
      name : Symbol | String,
      type_name : Symbol | String,
      default : String? = nil,
      hint : Symbol | String? = nil,
      range : ::Range(Float64, Float64) | ::Range(Float32, Float32)? = nil,
      group : String? = nil,
    ) : self
      line = String.build do |io|
        io << "group \"#{group}\" do\n  " if group
        io << "property " << name.to_s << " : " << type_name.to_s
        io << " = " << default if default
        if r = range
          io << ", range: " << r.begin << ".." << r.end
        end
        if h = hint
          hs = h.to_s
          io << ", hint: " << (hs.includes?("(") ? hs : ":#{hs}")
        end
        io << "\nend" if group
      end
      @declaration_lines << line
      self
    end

    def property(
      name : Symbol | String,
      type_name : Symbol | String,
      default : String? = nil,
      hint : Symbol | String? = nil,
      range : ::Range(Float64, Float64) | ::Range(Float32, Float32)? = nil,
      group : String? = nil,
    ) : self
      uniform(name, type_name, default: default, hint: hint, range: range, group: group)
    end

    def sampler(
      name : Symbol | String,
      filter : Symbol | String? = nil,
      repeat : Symbol | String? = nil,
      hint : Symbol | String? = nil,
    ) : self
      parts = ["sampler :#{name}"]
      parts << "filter: :#{filter}" if filter
      parts << "repeat: :#{repeat}" if repeat
      if h = hint
        hs = h.to_s
        parts << "hint: #{hs.includes?("(") ? hs : ":#{hs}"}"
      end
      @declaration_lines << parts.join(", ")
      self
    end

    def varying(name : Symbol | String, type_name : Symbol | String, qualifier : Symbol | String? = nil) : self
      if q = qualifier
        @declaration_lines << "varying #{name} : #{type_name}, qualifier: :#{q}"
      else
        @declaration_lines << "varying #{name} : #{type_name}"
      end
      self
    end

    def gradient(
      name : Symbol | String,
      stops,
      space : Symbol | String = :oklab,
      interp : Symbol | String = :linear,
    ) : self
      norm = ProceduralLUT.normalize_stops(stops)
      entries = norm.map do |s|
        sprintf("%.4f => Color.new(%.4f, %.4f, %.4f, %.4f)", s.pos, s.r, s.g, s.b, s.a)
      end
      @declaration_lines << "gradient :#{name}, {#{entries.join(", ")}}, space: :#{space}, interp: :#{interp}"
      self
    end

    def curve(
      name : Symbol | String,
      points,
      interp : Symbol | String = :smooth,
    ) : self
      norm = ProceduralLUT.normalize_points(points)
      entries = norm.map { |p| sprintf("%.4f => %.4f", p.pos, p.value) }
      @declaration_lines << "curve :#{name}, {#{entries.join(", ")}}, interp: :#{interp}"
      self
    end

    def use_trait(path_or_name : Symbol | String, prefix : Symbol | String? = nil) : self
      raw = path_or_name.to_s
      normalized = raw.includes?("/") || raw.ends_with?(".crshader") ? raw : "std/traits/#{raw}"
      @traits << TraitUse.new(normalized, prefix.try(&.to_s))
      self
    end

    def function(name : Symbol | String, params : String, return_type : Symbol | String, body : String) : self
      @helper_defs << "def #{name}(#{params}) : #{return_type}\n#{indent_lines(body, 2)}\nend"
      self
    end

    def vertex(code : String) : self
      @vertex_chunks = [code]
      self
    end

    def append_vertex(code : String) : self
      @vertex_chunks << code
      self
    end

    def fragment(code : String) : self
      @fragment_chunks = [code]
      self
    end

    def append_fragment(code : String) : self
      @fragment_chunks << code
      self
    end

    def light(code : String) : self
      @light_chunks = [code]
      self
    end

    def append_light(code : String) : self
      @light_chunks << code
      self
    end

    def process_pixel(code : String) : self
      @pixel_chunks = [code]
      self
    end

    def append_pixel(code : String) : self
      @pixel_chunks << code
      self
    end

    def access(*buffers : Symbol | String) : self
      buffers.each do |b|
        bs = b.to_s
        @compositor_access << bs unless @compositor_access.includes?(bs)
      end
      self
    end

    def inspect_var(label : Symbol | String, expr : String? = nil) : self
      stmt = expr ? "inspect :#{label}, #{expr}" : "inspect #{label}"
      if @shader_type_kind == "compositor" || @shader_type_kind == "compositor_effect"
        @pixel_chunks << stmt
      else
        @fragment_chunks << stmt
      end
      self
    end

    # Procedural Mutators
    def add_color_tint(name : Symbol | String = :tint_color, hex : String = "#ffffff") : self
      uname = name.to_s
      uniform(uname, :Color, default: "Color.hex(\"#{hex}\")", hint: :source_color)
      if @shader_type_kind == "canvas_item"
        append_fragment("COLOR = COLOR * #{uname}")
      elsif @shader_type_kind == "compositor" || @shader_type_kind == "compositor_effect"
        append_pixel("color = color * #{uname}")
      else
        append_fragment("ALBEDO = ALBEDO * #{uname}.rgb")
      end
      self
    end

    def add_uv_warp(freq : Float32 = 8.0_f32, amp : Float32 = 0.02_f32) : self
      uniform(:warp_freq, :Float32, default: sprintf("%.3f", freq), range: 0.5_f32..32.0_f32)
      uniform(:warp_amp, :Float32, default: sprintf("%.4f", amp), range: 0.0_f32..0.25_f32)
      append_vertex("UV = UV + vec2(sin(UV.y * warp_freq + TIME) * warp_amp, cos(UV.x * warp_freq + TIME) * warp_amp)")
      self
    end

    def add_rim_glow(prefix : Symbol | String? = nil) : self
      use_trait("std/traits/rim_fresnel", prefix: prefix)
    end

    def add_dissolve(prefix : Symbol | String? = nil) : self
      use_trait("std/traits/dissolve", prefix: prefix)
    end

    def release(enabled : Bool = true) : self
      @strip_debug_inspects = enabled
      self
    end

    # Deep-clones this builder for zero-mutation branching / specialization
    def fork : ShaderBuilder
      copy = clone_state
      copy
    end

    def fork(&block : ShaderBuilder ->) : ShaderBuilder
      copy = clone_state
      yield copy
      copy
    end

    def to_crshader : String
      String.build do |io|
        if @shader_type_kind == "compositor" || @shader_type_kind == "compositor_effect"
          io << "compositor_effect :" << @compositor_stage << " do\n"
          io << "  access " << @compositor_access.map { |a| ":#{a}" }.join(", ") << "\n"
          @requires.each { |r| io << "  require \"#{r}\"\n" }
          @declaration_lines.each { |dl| io << indent_lines(dl, 2) << "\n" }
          @traits.each do |tu|
            if p = tu.prefix
              io << "  use_trait \"" << tu.path_or_name << "\", prefix: :" << p << "\n"
            else
              io << "  use_trait \"" << tu.path_or_name << "\"\n"
            end
          end
          @helper_defs.each { |hd| io << indent_lines(hd, 2) << "\n" }
          unless @pixel_chunks.empty?
            io << "  process_pixel do |coord, uv, color|\n"
            @pixel_chunks.each { |c| io << indent_lines(c, 4) << "\n" }
            io << "  end\n"
          end
          io << "end\n"
        else
          st = @shader_type_kind == "canvas" ? "canvas_item" : @shader_type_kind
          io << "shader_type :" << st << "\n"
          unless @render_modes.empty?
            io << "render_mode " << @render_modes.map { |m| ":#{m}" }.join(", ") << "\n"
          end
          @requires.each { |r| io << "require \"#{r}\"\n" }
          @declaration_lines.each { |dl| io << dl << "\n" }
          @traits.each do |tu|
            if p = tu.prefix
              io << "use_trait \"" << tu.path_or_name << "\", prefix: :" << p << "\n"
            else
              io << "use_trait \"" << tu.path_or_name << "\"\n"
            end
          end
          @helper_defs.each { |hd| io << hd << "\n" }

          unless @vertex_chunks.empty?
            io << "def vertex\n"
            @vertex_chunks.each { |c| io << indent_lines(c, 2) << "\n" }
            io << "end\n"
          end

          unless @fragment_chunks.empty?
            io << "def fragment\n"
            @fragment_chunks.each { |c| io << indent_lines(c, 2) << "\n" }
            io << "end\n"
          end

          unless @light_chunks.empty?
            io << "def light\n"
            @light_chunks.each { |c| io << indent_lines(c, 2) << "\n" }
            io << "end\n"
          end
        end
      end
    end

    def compile(target : ShaderTarget? = nil, cache : VariantCache = VariantCache.global) : String
      is_comp = (@shader_type_kind == "compositor" || @shader_type_kind == "compositor_effect" || @shader_type_kind == "compute")
      resolved_target = target || (is_comp ? ShaderTarget::GLSL : nil)
      variant = cache.get_or_compile(
        source: to_crshader,
        target: resolved_target,
        features: @feature_overrides,
        strip_debug_inspects: @strip_debug_inspects
      )
      variant.code
    end

    private def clone_state : ShaderBuilder
      copy = ShaderBuilder.new(@shader_type_kind)
      copy.render_modes = @render_modes.dup
      copy.requires = @requires.dup
      copy.declaration_lines = @declaration_lines.dup
      copy.traits = @traits.dup
      copy.feature_overrides = @feature_overrides.dup
      copy.helper_defs = @helper_defs.dup
      copy.vertex_chunks = @vertex_chunks.dup
      copy.fragment_chunks = @fragment_chunks.dup
      copy.light_chunks = @light_chunks.dup
      copy.pixel_chunks = @pixel_chunks.dup
      copy.compositor_stage = @compositor_stage
      copy.compositor_access = @compositor_access.dup
      copy.strip_debug_inspects = @strip_debug_inspects
      copy
    end

    private def indent_lines(text : String, spaces : Int32) : String
      pad = " " * spaces
      text.lines.map { |l| l.strip.empty? ? "" : "#{pad}#{l}" }.join("\n")
    end
  end

  def self.build(shader_type : Symbol | String = :spatial) : ShaderBuilder
    ShaderBuilder.new(shader_type)
  end

  def self.build(shader_type : Symbol | String = :spatial, &block : ShaderBuilder ->) : ShaderBuilder
    builder = ShaderBuilder.new(shader_type)
    yield builder
    builder
  end
end
