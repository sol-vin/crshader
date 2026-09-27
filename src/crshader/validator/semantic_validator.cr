require "compiler/crystal/syntax"
require "../ast/types"
require "../ast/shader_ast"
require "../parser/error_formatter"
require "./rules"

module CrShader::Validator
  class ValidationContext
    property errors : Array(ShaderError) = [] of ShaderError
    property warnings : Array(String) = [] of String
    property filename : String?
    property source_lines : Array(String)

    def initialize(@filename : String? = nil, @source_lines : Array(String) = [] of String)
    end

    def error(message : String, line_number : Int32? = nil, column_number : Int32? = nil, tip : String? = nil)
      err = ShaderError.new(message, filename: @filename, line_number: line_number, column_number: column_number, tip: tip)
      @errors << err
    end

    def warn(message : String)
      @warnings << message
    end

    def has_errors? : Bool
      !@errors.empty?
    end

    def check!
      if first = @errors.first?
        raise first
      end
    end
  end

  class SemanticValidator
    getter program : ShaderProgram
    getter context : ValidationContext

    ALL_KNOWN_STAGES = Set{"vertex", "fragment", "light", "start", "process", "sky", "fog", "main"}

    def initialize(@program : ShaderProgram, filename : String? = nil, source_lines : Array(String) = [] of String)
      @context = ValidationContext.new(filename, source_lines)
    end

    def validate! : ShaderProgram
      validate_render_modes
      validate_stages
      validate_stage_builtins
      validate_uniforms
      validate_compute_layout
      @context.check!
      @program
    end

    def validate_render_modes : Void
      allowed = Rules::VALID_RENDER_MODES[@program.shader_type]? || Set(String).new
      st_name = @program.shader_type.to_gdshader_keyword

      @program.render_modes.each do |mode|
        clean_mode = mode.to_s
        next if allowed.includes?(clean_mode)

        # Check if mode belongs to another shader type
        other_type : ShaderType? = nil
        Rules::VALID_RENDER_MODES.each do |st, set|
          if set.includes?(clean_mode)
            other_type = st
            break
          end
        end

        if ot = other_type
          @context.error(
            "Render mode '#{clean_mode}' is not valid for '#{st_name}' shaders. It is only supported in '#{ot.to_gdshader_keyword}' shaders.",
            tip: "Remove '#{clean_mode}' or verify your shader_type."
          )
        else
          suggestion = Rules.find_closest_match(clean_mode, allowed) || Rules.find_closest_match(clean_mode, Rules::ALL_RENDER_MODES)
          tip_msg = suggestion ? "Did you mean '#{suggestion}'?" : "Check Godot render_mode documentation for '#{st_name}' shaders."
          @context.error(
            "Unknown render mode '#{clean_mode}' for '#{st_name}' shader.",
            tip: tip_msg
          )
        end
      end
    end

    def validate_stages : Void
      valid_stages = @program.shader_type.valid_stages
      st_name = @program.shader_type.to_gdshader_keyword

      @program.functions.each do |name, def_node|
        next unless ALL_KNOWN_STAGES.includes?(name)
        unless valid_stages.includes?(name)
          suggestion = Rules.find_closest_match(name, valid_stages)
          tip_msg = "Valid stages for '#{st_name}' are: #{valid_stages.join(", ")}."
          tip_msg += " (Did you mean '#{suggestion}'?)" if suggestion

          loc = def_node.location
          @context.error(
            "Stage '#{name}' cannot be used in a '#{st_name}' shader.",
            line_number: loc.try(&.line_number),
            column_number: loc.try(&.column_number),
            tip: tip_msg
          )
        end
      end
    end

    def validate_stage_builtins : Void
      @program.functions.each do |stage_name, def_node|
        next unless ALL_KNOWN_STAGES.includes?(stage_name)
        scanner = BuiltinScanner.new(stage_name, @context)
        def_node.body.accept(scanner)
      end
    end

    def validate_uniforms : Void
      @program.uniforms.each do |u|
        # 1. Type validation
        type_str = u.type_name
        is_known = TypeInfo::PRIMITIVES.has_key?(type_str) ||
                   @program.structs.has_key?(type_str) ||
                   type_str.starts_with?("Array(") ||
                   type_str == "PackedColorArray" ||
                   type_str == "ColorPalette" ||
                   u.is_var_array

        unless is_known
          closest = Rules.find_closest_match(type_str, TypeInfo::PRIMITIVES.keys)
          tip_msg = closest ? "Did you mean '#{closest}'?" : "Declare a struct or use standard shader types (Float32, Vec2, Vec3, Vec4, Color, Sampler2D)."
          @context.error(
            "Unknown uniform type '#{type_str}' on uniform '#{u.name}'.",
            tip: tip_msg
          )
        end

        # 2. Instance uniform constraints (Godot forbids samplers / textures as instance uniforms)
        if u.qualifier == UniformQualifier::Instance
          if type_str.downcase.includes?("sampler") || type_str.downcase.includes?("image")
            @context.error(
              "Instance uniforms cannot be texture samplers ('#{u.name}' has type '#{type_str}').",
              tip: "Use standard 'uniform' for textures or pass indices to a texture array."
            )
          end
        end

        # 3. Hint validation
        u.hints.each do |hint|
          # source_color only on Color, Vec4, or Array(Color)
          if hint == "source_color" || hint == "hint_color"
            valid_color_type = type_str == "Color" || type_str == "Vec4" ||
                               (u.is_array? && type_str == "Color") ||
                               type_str == "PackedColorArray"
            unless valid_color_type
              @context.error(
                "Hint 'source_color' is only valid for Color or Vec4 uniforms, but uniform '#{u.name}' has type '#{type_str}'.",
                tip: "Change uniform type to 'Color' or remove 'hint: :source_color'."
              )
            end
          end

          # hint_range(min, max[, step]) validation
          if m = hint.match(/hint_range\(\s*([-\d.]+)\s*,\s*([-\d.]+)(?:\s*,\s*([-\d.]+))?\s*\)/)
            min_v = m[1].to_f32? || 0.0_f32
            max_v = m[2].to_f32? || 1.0_f32
            step_v = m[3]?.try(&.to_f32?)

            if min_v >= max_v
              @context.error(
                "hint_range minimum (#{min_v}) must be strictly less than maximum (#{max_v}) on uniform '#{u.name}'.",
                tip: "Swap bounds so range is min..max."
              )
            end

            if step = step_v
              if step <= 0.0_f32
                @context.error(
                  "hint_range step (#{step}) must be greater than zero on uniform '#{u.name}'.",
                  tip: "Specify a positive step value (e.g. 0.05 or 0.1)."
                )
              elsif step > (max_v - min_v)
                @context.error(
                  "hint_range step (#{step}) exceeds total range (#{max_v - min_v}) on uniform '#{u.name}'.",
                  tip: "Reduce step value to fit within the range bounds."
                )
              end
            end
          end

          # Texture hints on non-sampler uniforms
          if ["filter_linear", "filter_nearest", "repeat_enable", "repeat_disable", "hint_screen_texture", "hint_depth_texture"].includes?(hint)
            unless type_str.downcase.includes?("sampler") || type_str.downcase.includes?("image")
              @context.error(
                "Hint '#{hint}' is only valid for Sampler2D uniforms, but uniform '#{u.name}' has type '#{type_str}'.",
                tip: "Change type to 'Sampler2D' or remove '#{hint}'."
              )
            end
          end
        end
      end
    end

    def validate_compute_layout : Void
      return unless @program.shader_type == ShaderType::Compute
      layout = @program.compute_layout
      if layout.x <= 0 || layout.y <= 0 || layout.z <= 0
        @context.error(
          "Compute local_size dimensions must all be greater than zero (got #{layout.x}, #{layout.y}, #{layout.z}).",
          tip: "Specify positive dimensions such as: local_size 8, 8, 1"
        )
      end
    end

    # AST Visitor checking built-in variable reads and writes inside stage bodies
    private class BuiltinScanner < Crystal::Visitor
      getter stage_name : String
      getter context : ValidationContext

      def initialize(@stage_name : String, @context : ValidationContext)
      end

      # Inspect assignments: e.g. ALBEDO = ..., builtin_ALBEDO = ...
      def visit(node : Crystal::Assign)
        target = node.target
        var_name = case target
                   when Crystal::Var
                     target.name.sub(/^builtin_/, "")
                   when Crystal::Path
                     target.names.first.sub(/^builtin_/, "")
                   when Crystal::Call
                     # e.g. ALBEDO.rgb = ...
                     obj = target.obj
                     if obj.is_a?(Crystal::Var)
                       obj.name.sub(/^builtin_/, "")
                     elsif obj.is_a?(Crystal::Path)
                       obj.names.first.sub(/^builtin_/, "")
                     else
                       ""
                     end
                   else
                     ""
                   end

        if allowed_stages = Rules::STAGE_WRITABLE_BUILTINS[var_name]?
          unless allowed_stages.includes?(@stage_name)
            loc = node.location
            @context.error(
              "Cannot assign to built-in '#{var_name}' in #{@stage_name} stage.",
              line_number: loc.try(&.line_number),
              column_number: loc.try(&.column_number),
              tip: "'#{var_name}' is only writable in: #{allowed_stages.join(", ")} stage."
            )
          end
        end
        true
      end

      # Inspect calls to check read-only / stage-restricted reads
      def visit(node : Crystal::Var)
        clean_name = node.name.sub(/^builtin_/, "")
        if allowed_stages = Rules::STAGE_READABLE_ONLY[clean_name]?
          unless allowed_stages.includes?(@stage_name)
            loc = node.location
            @context.error(
              "Variable '#{clean_name}' cannot be read in #{@stage_name} stage.",
              line_number: loc.try(&.line_number),
              column_number: loc.try(&.column_number),
              tip: "'#{clean_name}' is only available in: #{allowed_stages.join(", ")} stage."
            )
          end
        end
        true
      end

      def visit(node : Crystal::ASTNode)
        true
      end
    end
  end
end
