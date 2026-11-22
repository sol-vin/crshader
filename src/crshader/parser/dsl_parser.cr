require "compiler/crystal/syntax"
require "../ast/shader_ast"
require "../ast/types"
require "../macros/macro_engine"
require "./error_formatter"
require "./tres_reader"
require "./gdshaderinc_reader"
require "../std/registry"
require "../validator/rules"
require "../extensions/registry"
require "../language/gradients_and_curves"
require "./archetypes"
require "../composer/trait_fuser"

module CrShader
  class DslParser
    getter program : ShaderProgram
    getter macro_engine : MacroEngine
    property current_group : String? = nil
    property current_subgroup : String? = nil
    getter filename : String?
    getter source_lines : Array(String)
    getter loaded_modules : Set(String)
    getter force_target : Bool
    property feature_overrides : Hash(String, FeatureValue)

    def initialize(
      @filename : String? = nil,
      default_target : ShaderTarget = ShaderTarget::GDShader,
      @loaded_modules : Set(String) = Set(String).new,
      @force_target : Bool = false,
      @feature_overrides : Hash(String, FeatureValue) = {} of String => FeatureValue,
    )
      @program = ShaderProgram.new(default_target)
      @macro_engine = MacroEngine.new(default_target, @program.shader_type)
      @source_lines = [] of String
      if fn = @filename
        if File.exists?(fn)
          @loaded_modules.add(File.expand_path(fn).gsub('\\', '/'))
        end
      end
    end

    def parse(source : String) : ShaderProgram
      @source_lines = source.lines

      # Early scan for shader_type / compute / compositor so MacroEngine TARGET & SHADER_TYPE are accurate
      detect_early_target_and_type(source)

      # Extract raw preprocessor directives: #include, #define, #undef, #ifdef, #ifndef, #if, #elif, #else, #endif, #pragma
      source.each_line do |line|
        trimmed = line.strip
        if trimmed =~ /^#(include|define|undef|ifdef|ifndef|if|elif|else|endif|pragma)\b/
          @program.preprocessor_lines << trimmed
          if m = trimmed.match(/^#include\s+"([^"]+)"/)
            GdshaderincReader.import_signatures(m[1], @program, @filename)
          end
        end
      end

      # Normalize `const NAME : Type =` and `const NAME =` (supports single-line & multiline RHS arrays/expressions!)
      normalized_source = source.gsub(/(^|\n)([ \t]*)const[ \t]+([a-zA-Z_][a-zA-Z0-9_]*)[ \t]*:[ \t]*([a-zA-Z_][a-zA-Z0-9_]*)[ \t]*=(?!=)/) do |_, m|
        "#{m[1]}#{m[2]}__const_typed__#{m[4]}__#{m[3]} ="
      end
      normalized_source = normalized_source.gsub(/(^|\n)([ \t]*)const[ \t]+([a-zA-Z_][a-zA-Z0-9_]*)[ \t]*=(?!=)/) do |_, m|
        "#{m[1]}#{m[2]}__const_untyped__#{m[3]} ="
      end

      # Normalize uppercase built-in variable assignments to avoid dynamic constant assignment errors
      # and handle compound assignments without requiring prior local definition
      normalized_source = normalized_source.gsub(/\b([A-Z][A-Z0-9_]*)\s*(\+|-|\*|\/|%|&|\||\^|<<|>>)?=(?!=)/) do |match, regex_match|
        name = regex_match[1]
        if op = regex_match[2]?
          "builtin_#{name} = #{name} #{op} "
        else
          "builtin_#{name} = "
        end
      end

      # Normalize include with string literal to gd_include to bypass Crystal's module include keyword
      normalized_source = normalized_source.gsub(/\binclude\s+("res:\/\/[^"]+"|\"[^\"]+\")/) do |_, regex_match|
        "gd_include #{regex_match[1]}"
      end

      # Normalize empty untyped array literal [] to ([] of Void) to allow Crystal's parser to accept it
      normalized_source = normalized_source.gsub(/=\s*\[\s*\]/, "= ([] of Void)")

      # Normalize property keyword to uniform call to bypass Crystal's built-in property macro limitation with named arguments
      normalized_source = normalized_source.gsub(/\bproperty\s+([a-zA-Z_][a-zA-Z0-9_]*\s*:)/) do |_, regex_match|
        "uniform #{regex_match[1]}"
      end

      # Normalize lowercase primitive types in genuine type annotations (uniform/export/varying/field x : float, record x : float, func(x : float), etc.)
      type_pattern = "(float|int|uint|bool|vec2|vec3|vec4|color|mat2|mat3|mat4|sampler2d|sampler_2d|sampler_cube|ivec2|ivec3|ivec4|uvec2|uvec3|uvec4)"
      normalized_source = normalized_source.gsub(/\b(uniform|export|varying|flat_varying|smooth_varying|field)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*#{type_pattern}\b/i) do |_, m|
        "#{m[1]} #{m[2]} : #{TypeInfo.normalize(m[3])}"
      end
      normalized_source = normalized_source.gsub(/(^|\n|\brecord\b[^\n]*?,\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*#{type_pattern}\b/i) do |_, m|
        "#{m[1]}#{m[2]} : #{TypeInfo.normalize(m[3])}"
      end
      normalized_source = normalized_source.gsub(/(\([^\)]*?\b[a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*#{type_pattern}\b/i) do |_, m|
        "#{m[1]} : #{TypeInfo.normalize(m[2])}"
      end

      begin
        parser = Crystal::Parser.new(normalized_source)
        parser.filename = @filename
        ast = parser.parse
      rescue ex : Crystal::SyntaxException
        line_content = normalized_source.lines[ex.line_number - 1]? || ""
        raise ShaderError.new(
          "#{ex.message} (at line #{ex.line_number}:#{ex.column_number}: `#{line_content}`)",
          filename: @filename,
          line_number: ex.line_number,
          column_number: ex.column_number
        )
      end

      # Pre-load required modules & macros BEFORE macro expansion so imported macros/constants expand!
      preload_requires(ast)
      @macro_engine.configure_target(@program.target, @program.shader_type)

      # Pre-scan feature declarations & overrides BEFORE macro / when_feature expansion!
      prescan_features(ast)
      apply_orphan_feature_overrides

      # Macro & feature guard expansion pass
      expanded_ast = @macro_engine.expand(ast)

      # Process top-level AST nodes
      if expanded_ast.is_a?(Crystal::Expressions)
        expanded_ast.expressions.each do |node|
          process_top_level_node(node)
        end
      else
        process_top_level_node(expanded_ast)
      end

      # Fuse all `use_trait` blocks into stages, uniforms, and varyings
      TraitFuser.fuse!(@program, @filename, @feature_overrides)

      @program
    end

    def process_hoisted_node(node : Crystal::ASTNode) : Void
      process_top_level_node(node)
    end

    private def process_top_level_node(node : Crystal::ASTNode)
      case node
      when Crystal::Call
        process_call(node)
      when Crystal::Def
        process_def(node)
      when Crystal::Assign
        process_assign(node)
      when Crystal::ClassDef
        process_struct(node)
      when Crystal::Require
        process_require(node)
      when Crystal::Nop
        # Skip empty nodes
      else
        @program.raw_top_level_nodes << node
      end
    end

    private def process_call(node : Crystal::Call)
      case node.name
      when "shader_type"
        if arg = node.args.first?
          val = node_to_string_or_sym(arg)
          if st = ShaderType.from_string?(val)
            @program.shader_type = st
            if st == ShaderType::Compute && !@force_target
              @program.target = ShaderTarget::GLSL
            end
          else
            valid_types = ["spatial", "canvas_item", "particles", "sky", "fog", "compute"]
            closest = Validator::Rules.find_closest_match(val, valid_types)
            tip_msg = closest ? "Did you mean ':#{closest}'?" : "Valid types are: :spatial, :canvas_item, :particles, :sky, :fog, :compute."
            loc = node.location
            raise ShaderError.new(
              "Unknown shader_type ':#{val}'.",
              filename: @filename,
              line_number: loc.try(&.line_number),
              column_number: loc.try(&.column_number),
              tip: tip_msg
            )
          end
        end
      when "shader"
        process_shader_block(node)
      when "render_mode"
        node.args.each do |arg|
          if arg.is_a?(Crystal::ArrayLiteral)
            arg.elements.each do |el|
              @program.render_modes << node_to_string_or_sym(el)
            end
          else
            @program.render_modes << node_to_string_or_sym(arg)
          end
        end
      when "setup_gdshader"
        @program.setup_gdshader = true
      when "require"
        if arg = node.args.first?
          req_str = node_to_string_or_sym(arg)
          handle_require_path(req_str)
        end
      when "group", "uniform_group"
        if arg = node.args.first?
          name = node_to_string_or_sym(arg)
          if block = node.block
            prev_group = @current_group
            prev_subgroup = @current_subgroup
            @current_group = name
            @current_subgroup = nil
            if block.body.is_a?(Crystal::Expressions)
              block.body.as(Crystal::Expressions).expressions.each { |child| process_top_level_node(child) }
            else
              process_top_level_node(block.body)
            end
            @current_group = prev_group
            @current_subgroup = prev_subgroup
          else
            @current_group = name
            @current_subgroup = nil
          end
        end
      when "subgroup", "uniform_subgroup"
        if arg = node.args.first?
          name = node_to_string_or_sym(arg)
          if block = node.block
            prev_subgroup = @current_subgroup
            @current_subgroup = name
            if block.body.is_a?(Crystal::Expressions)
              block.body.as(Crystal::Expressions).expressions.each { |child| process_top_level_node(child) }
            else
              process_top_level_node(block.body)
            end
            @current_subgroup = prev_subgroup
          else
            @current_subgroup = name
          end
        end
      when "generate_node", "node_generator", "export_node"
        type_str = node.args[0]?.try { |a| node_to_string_or_sym(a) } || "mesh3d"
        name_str = node.args[1]?.try { |a| node_to_string_or_sym(a) } || "GeneratedNode"
        out_path = node.args[2]?.try { |a| node_to_string_or_sym(a) }
        @program.node_generations << NodeGenerationTarget.new(type_str, name_str, out_path)
      when "uniform", "property", "export"
        process_uniform_call(node, qualifier: UniformQualifier::Default)
      when "instance_uniform"
        process_uniform_call(node, qualifier: UniformQualifier::Instance)
      when "global_uniform"
        process_uniform_call(node, qualifier: UniformQualifier::Global)
      when "sampler"
        process_sampler_call(node)
      when "record"
        process_record_call(node)
      when "constant_decl"
        if node.args.size >= 3
          cname = node_to_string_or_sym(node.args[0])
          ctype_node = node.args[1]
          ctype = ctype_node.is_a?(Crystal::NilLiteral) ? nil : node_to_string_or_sym(ctype_node)
          cval = node.args[2]
          if cval.is_a?(Crystal::Expressions) && cval.expressions.size == 1
            cval = cval.expressions.first
          end
          @program.imported_constants.delete(cname)
          @program.constants.reject! { |c| c.name == cname }
          @program.constants << ConstantDecl.new(name: cname, value: cval, type_name: ctype)
          @macro_engine.register_constant(cname, cval)
        end
      when "stage"
        process_stage_call(node)
      when "compositor_effect", "compositor_pass"
        process_compositor_effect_call(node)
      when "compute_kernel"
        process_compute_kernel_call(node)
      when "storage_buffer"
        process_buffer_call(node)
      when "storage_image"
        process_image_call(node)
      when "push_constants"
        process_push_constant_call(node)
      when "kernel_1d"
        process_kernel_1d_call(node)
      when "kernel_2d"
        process_kernel_2d_call(node)
      when "particle_simulation", "compute_particles"
        process_particle_simulation_call(node)
      when "step_particles"
        process_step_particles_call(node)
      when "varying"
        process_varying_call(node)
      when "flat_varying"
        process_varying_call(node, forced_qualifier: "flat")
      when "smooth_varying"
        process_varying_call(node, forced_qualifier: "smooth")
      when "include", "gd_include"
        if arg = node.args.first?
          inc_path = node_to_string_or_sym(arg)
          @program.includes << inc_path unless @program.includes.includes?(inc_path)
          GdshaderincReader.import_signatures(inc_path, @program, @filename)
        end
      when "define"
        if arg = node.args.first?
          def_name = node_to_string_or_sym(arg)
          val_str = node.args[1]?.try { |a| node_to_string_or_sym(a) }
          directive = val_str ? "#define #{def_name} #{val_str}" : "#define #{def_name}"
          @program.preprocessor_lines << directive
        end
      when "undefine", "undef"
        if arg = node.args.first?
          def_name = node_to_string_or_sym(arg)
          @program.preprocessor_lines << "#undef #{def_name}"
        end
      when "pragma"
        if arg = node.args.first?
          pname = node_to_string_or_sym(arg)
          pval = node.args[1]?.try { |a| node_to_string_or_sym(a) }
          directive = pval ? "#pragma #{pname} #{pval}" : "#pragma #{pname}"
          @program.preprocessor_lines << directive
        end
      when "default_precision", "precision"
        if node.args.size >= 2
          prec = node_to_string_or_sym(node.args[0])
          typ = node_to_string_or_sym(node.args[1])
          @program.default_precisions[typ] = prec
        end
      when "const"
        process_const_call(node)
      when "local_size"
        process_local_size_call(node)
      when "buffer"
        process_buffer_call(node)
      when "push_constant"
        process_push_constant_call(node)
      when "shared"
        process_shared_call(node)
      when "image2d"
        process_image_call(node)
      when "feature"
        process_feature_call(node)
      when "gradient"
        if gdecl = GradientsAndCurves.parse_gradient_call(node)
          @program.gradients.reject! { |g| g.name == gdecl.name }
          @program.gradients << gdecl
          @program.imported_functions.delete(gdecl.name)
          @program.functions[gdecl.name] = GradientsAndCurves.synthesize_gradient_def(gdecl)
        end
      when "curve"
        if cdecl = GradientsAndCurves.parse_curve_call(node)
          @program.curves.reject! { |c| c.name == cdecl.name }
          @program.curves << cdecl
          @program.imported_functions.delete(cdecl.name)
          @program.functions[cdecl.name] = GradientsAndCurves.synthesize_curve_def(cdecl)
        end
      when "shader_trait"
        if tdecl = TraitFuser.parse_trait_decl(node, self)
          @program.traits[tdecl.name] = tdecl
        end
      when "use_trait"
        process_use_trait_call(node)
      when "sprite_effect", "screen_effect", "ui_effect", "surface_material"
        Archetypes.process(node, self)
      when "vertex", "fragment", "light", "start", "process", "collide", "sky", "fog"
        if node.block
          synthesize_stage_def(node)
        else
          @program.raw_top_level_nodes << node
        end
      else
        if CrShader::Extensions.handle_directive(node.name, node, self)
          return
        end
        # Could be a top-level helper call or raw statement
        @program.raw_top_level_nodes << node
      end
    end

    private def process_shader_block(node : Crystal::Call)
      if arg = node.args.first?
        val = node_to_string_or_sym(arg)
        if st = ShaderType.from_string?(val)
          @program.shader_type = st
          if st == ShaderType::Compute
            @program.target = ShaderTarget::GLSL
          end
        end
      end

      if block = node.block
        if block.body.is_a?(Crystal::Expressions)
          block.body.as(Crystal::Expressions).expressions.each do |child|
            process_top_level_node(child)
          end
        else
          process_top_level_node(block.body)
        end
      end
    end

    private def synthesize_stage_def(node : Crystal::Call)
      if block = node.block
        def_node = Crystal::Def.new(node.name, body: block.body)
        @program.functions[node.name] = def_node
      end
    end

    private def process_shared_call(node : Crystal::Call)
      name = ""
      type_name = "UInt32"
      size = "256"

      if first_arg = node.args.first?
        if first_arg.is_a?(Crystal::TypeDeclaration)
          name = first_arg.var.to_s
          type_ast = first_arg.declared_type
          if type_ast.is_a?(Crystal::Generic) && type_ast.name.to_s == "Array"
            type_name = type_ast.type_vars.first?.try(&.to_s) || "UInt32"
            size = type_ast.type_vars.size > 1 ? type_ast.type_vars[1].to_s : "256"
          else
            type_name = type_ast.to_s
          end
        else
          name = node_to_string_or_sym(first_arg)
          if node.args.size >= 2
            type_name = node.args[1].to_s
          end
        end
      end

      node.named_args.try &.each do |narg|
        case narg.name
        when "size" then size = narg.value.to_s
        when "type" then type_name = narg.value.to_s
        end
      end

      return if name.empty?
      @program.shared_memories << SharedMemoryDecl.new(name: name, type_name: type_name, size: size)
    end

    private def process_image_call(node : Crystal::Call)
      name = ""
      image_type = "image2D"
      format = "rgba32f"
      set = 0
      binding = 0
      is_writeonly = false
      is_readonly = false
      is_restrict = false

      if first_arg = node.args.first?
        name = node_to_string_or_sym(first_arg)
      end

      node.named_args.try &.each do |narg|
        case narg.name
        when "type", "image_type" then image_type = node_to_string_or_sym(narg.value)
        when "format"             then format = node_to_string_or_sym(narg.value)
        when "set"                then set = narg.value.to_s.to_i? || 0
        when "binding"            then binding = narg.value.to_s.to_i? || 0
        when "writeonly"          then is_writeonly = narg.value.to_s == "true"
        when "readonly"           then is_readonly = narg.value.to_s == "true"
        when "restrict"           then is_restrict = narg.value.to_s == "true"
        end
      end

      return if name.empty?
      @program.images << ImageUniformDecl.new(
        name: name,
        image_type: image_type,
        format: format,
        set: set,
        binding: binding,
        writeonly: is_writeonly,
        readonly: is_readonly,
        restrict: is_restrict
      )
    end

    private def process_uniform_call(node : Crystal::Call, qualifier : UniformQualifier = UniformQualifier::Default)
      # Syntax A: uniform albedo : Color = Color.new(...), hint: :source_color
      #   node.args[0] is TypeDeclaration(var, declared_type, value)
      # Syntax B: uniform :albedo, Color, default: ..., hint: ...
      # Syntax C: uniform my_var_array = [] or uniform my_palette = [vec4(...)]
      # Syntax D: uniform palette = resource("res://default_palettes/cottonville.tres")
      # Syntax E: uniform palette = PackedColorArray[Color.new(...), ...]
      name = ""
      type_name = "Float32"
      default_val : Crystal::ASTNode? = nil
      hints = [] of String
      array_size : String? = nil
      is_var_array = false
      resource_path : String? = nil
      is_packed_array = false
      embedded_elements : Array(Crystal::ASTNode)? = nil
      precision : String? = nil
      explicit_set : Int32? = nil
      explicit_binding : Int32? = nil

      base_dir = @filename ? File.dirname(@filename.not_nil!) : nil

      if node.args.size >= 1
        first_arg = node.args[0]
        if first_arg.is_a?(Crystal::TypeDeclaration)
          name = first_arg.var.to_s
          type_ast = first_arg.declared_type
          if type_ast.is_a?(Crystal::Generic) && type_ast.name.to_s == "Array"
            type_name = type_ast.type_vars.first?.try(&.to_s) || "Float32"
            if type_ast.type_vars.size > 1
              array_size = type_ast.type_vars[1].to_s
              is_var_array = false
            else
              is_var_array = true
              array_size = nil
            end
          elsif type_ast.to_s == "PackedColorArray" || type_ast.to_s == "ColorPalette"
            type_name = "Color"
            is_packed_array = true
            is_var_array = true
          else
            type_name = type_ast.to_s
          end
          default_val = first_arg.value
          if default_val.is_a?(Crystal::ArrayLiteral)
            is_var_array = true
            array_size ||= (default_val.elements.empty? ? "16" : default_val.elements.size.to_s)
          elsif default_val.is_a?(Crystal::Call) && (default_val.name == "resource" || default_val.name == "tres")
            res_arg = default_val.args.first?.try { |a| node_to_string_or_sym(a) } || ""
            resource_path = res_arg
            is_var_array = true
            if data = TresReader.read(res_arg, base_dir: base_dir)
              array_size = (data.size.zero? ? "16" : data.size.to_s)
              type_name = data.elem_type
              nodes = data.to_ast_nodes
              embedded_elements = nodes
              default_val = Crystal::ArrayLiteral.new(nodes)
            else
              array_size ||= "16"
              type_name = "Color"
            end
          end
        elsif first_arg.is_a?(Crystal::Assign)
          name = first_arg.target.to_s
          val_node = first_arg.value
          if val_node.is_a?(Crystal::Expressions) && val_node.expressions.size == 1
            val_node = val_node.expressions.first
          end
          default_val = val_node
          if default_val.is_a?(Crystal::ArrayLiteral)
            is_var_array = true
            array_size = default_val.elements.empty? ? "16" : default_val.elements.size.to_s
            if !default_val.elements.empty?
              if inferred = infer_array_elem_type(default_val.elements.first)
                type_name = inferred
              end
            else
              type_name = "Color"
            end
          elsif default_val.is_a?(Crystal::Call) && (default_val.name == "resource" || default_val.name == "tres")
            res_arg = default_val.args.first?.try { |a| node_to_string_or_sym(a) } || ""
            resource_path = res_arg
            is_var_array = true
            if data = TresReader.read(res_arg, base_dir: base_dir)
              array_size = (data.size.zero? ? "16" : data.size.to_s)
              type_name = data.elem_type
              nodes = data.to_ast_nodes
              embedded_elements = nodes
              default_val = Crystal::ArrayLiteral.new(nodes)
            else
              array_size = "16"
              type_name = "Color"
            end
          elsif default_val.is_a?(Crystal::Call) && default_val.name == "[]" && default_val.obj.is_a?(Crystal::Path)
            obj_name = default_val.obj.as(Crystal::Path).names.first
            if obj_name == "PackedColorArray"
              is_packed_array = true
              is_var_array = true
              type_name = "Color"
              array_size = default_val.args.empty? ? "16" : default_val.args.size.to_s
              embedded_elements = default_val.args
              default_val = Crystal::ArrayLiteral.new(default_val.args)
            end
          end
        elsif first_arg.is_a?(Crystal::SymbolLiteral) || first_arg.is_a?(Crystal::Var) || first_arg.is_a?(Crystal::Call)
          name = node_to_string_or_sym(first_arg)
          if node.args.size >= 2
            type_name = node.args[1].to_s
          end
        end
      end

      # Named args: hint, default, filter, repeat, size, type, resource
      node.named_args.try &.each do |narg|
        case narg.name
        when "default"
          default_val = narg.value
          if default_val.is_a?(Crystal::ArrayLiteral)
            is_var_array = true
            array_size ||= (default_val.elements.empty? ? "16" : default_val.elements.size.to_s)
          elsif default_val.is_a?(Crystal::Call) && (default_val.name == "resource" || default_val.name == "tres")
            res_arg = default_val.args.first?.try { |a| node_to_string_or_sym(a) } || ""
            resource_path = res_arg
            is_var_array = true
            if data = TresReader.read(res_arg, base_dir: base_dir)
              array_size = (data.size.zero? ? "16" : data.size.to_s)
              type_name = data.elem_type
              nodes = data.to_ast_nodes
              embedded_elements = nodes
              default_val = Crystal::ArrayLiteral.new(nodes)
            else
              array_size ||= "16"
              type_name = "Color"
            end
          end
        when "resource", "tres", "palette"
          res_arg = node_to_string_or_sym(narg.value)
          resource_path = res_arg
          is_var_array = true
          if data = TresReader.read(res_arg, base_dir: base_dir)
            array_size ||= (data.size.zero? ? "16" : data.size.to_s)
            type_name = data.elem_type if type_name == "Float32" || type_name.empty?
            nodes = data.to_ast_nodes
            embedded_elements = nodes
            default_val ||= Crystal::ArrayLiteral.new(nodes)
          else
            array_size ||= "16"
            type_name = "Color" if type_name == "Float32" || type_name.empty?
          end
        when "range"
          if narg.value.is_a?(Crystal::RangeLiteral)
            range_lit = narg.value.as(Crystal::RangeLiteral)
            min_v = range_lit.from.to_s
            max_v = range_lit.to.to_s
            step_v = node.named_args.try(&.find { |a| a.name == "step" }).try(&.value.to_s)
            if step_v
              hints << "hint_range(#{min_v}, #{max_v}, #{step_v})"
            else
              hints << "hint_range(#{min_v}, #{max_v})"
            end
          end
        when "step"
          # Handled with range
        when "hint"
          if narg.value.is_a?(Crystal::RangeLiteral)
            range_lit = narg.value.as(Crystal::RangeLiteral)
            min_v = range_lit.from.to_s
            max_v = range_lit.to.to_s
            step_v = node.named_args.try(&.find { |a| a.name == "step" }).try(&.value.to_s)
            if step_v
              hints << "hint_range(#{min_v}, #{max_v}, #{step_v})"
            else
              hints << "hint_range(#{min_v}, #{max_v})"
            end
          elsif narg.value.is_a?(Crystal::ArrayLiteral)
            narg.value.as(Crystal::ArrayLiteral).elements.each do |el|
              hints << normalize_hint(node_to_hint_string(el))
            end
          else
            hints << normalize_hint(node_to_hint_string(narg.value))
          end
        when "filter", "repeat"
          hints << "#{narg.name}_#{node_to_string_or_sym(narg.value)}"
        when "size"
          array_size = narg.value.to_s
          is_var_array = true
        when "precision"
          precision = node_to_string_or_sym(narg.value)
        when "type"
          type_name = TypeInfo.normalize(narg.value.to_s)
        when "set"
          explicit_set = narg.value.to_s.to_i?
        when "binding"
          explicit_binding = narg.value.to_s.to_i?
        else
          hints << normalize_hint(node_to_hint_string(narg.value))
        end
      end

      return if name.empty?

      if default_val.is_a?(Crystal::Call) && (hex_ast = parse_hex_color_to_ast(default_val.as(Crystal::Call)))
        default_val = hex_ast
      end

      type_name = TypeInfo.normalize(type_name)
      doc_comment = extract_doc_comment(node.location.try(&.line_number))

      @program.uniforms.reject! { |u| u.name == name }
      @program.uniforms << UniformDecl.new(
        name: name,
        type_name: type_name,
        default_value: default_val,
        hints: hints,
        group: @current_group,
        subgroup: @current_subgroup,
        qualifier: qualifier,
        array_size: array_size,
        is_var_array: is_var_array,
        resource_path: resource_path,
        is_packed_array: is_packed_array,
        embedded_elements: embedded_elements,
        precision: precision,
        doc_comment: doc_comment,
        set: explicit_set,
        binding: explicit_binding
      )
    end

    private def infer_array_elem_type(elem : Crystal::ASTNode) : String?
      case elem
      when Crystal::Call
        case elem.name
        when "vec4"  then "Vec4"
        when "vec3"  then "Vec3"
        when "vec2"  then "Vec2"
        when "ivec2" then "IVec2"
        when "ivec3" then "IVec3"
        when "ivec4" then "IVec4"
        when "Color", "new"
          obj_name = elem.obj.try(&.to_s) || ""
          if obj_name == "Color" || elem.name == "Color"
            "Color"
          elsif obj_name == "Vec4"
            "Vec4"
          elsif obj_name == "Vec3"
            "Vec3"
          elsif obj_name == "Vec2"
            "Vec2"
          else
            nil
          end
        else
          nil
        end
      when Crystal::NumberLiteral
        elem.kind.to_s.includes?("f") ? "Float32" : "Int32"
      when Crystal::BoolLiteral
        "Bool"
      else
        nil
      end
    end

    private def process_varying_call(node : Crystal::Call, forced_qualifier : String? = nil)
      # varying v_normal : Vec3, qualifier: :flat, precision: :highp
      name = ""
      type_name = "Vec3"
      qualifier : String? = forced_qualifier
      precision : String? = nil

      if first_arg = node.args.first?
        if first_arg.is_a?(Crystal::TypeDeclaration)
          name = first_arg.var.to_s
          type_name = first_arg.declared_type.to_s
        else
          name = node_to_string_or_sym(first_arg)
          if node.args.size >= 2
            type_name = node.args[1].to_s
          end
        end
      end

      node.named_args.try &.each do |narg|
        case narg.name
        when "qualifier", "interpolation"
          qualifier ||= node_to_string_or_sym(narg.value)
        when "precision"
          precision = node_to_string_or_sym(narg.value)
        end
      end

      return if name.empty?

      @program.varyings << VaryingDecl.new(
        name: name,
        type_name: type_name,
        qualifier: qualifier,
        precision: precision
      )
    end

    private def process_const_call(node : Crystal::Call)
      if first_arg = node.args.first?
        if first_arg.is_a?(Crystal::Assign)
          name = first_arg.target.to_s
          val = first_arg.value
          @program.constants << ConstantDecl.new(name: name, value: val)
        end
      end
    end

    private def process_local_size_call(node : Crystal::Call)
      # local_size 8, 8, 1 OR local_size x: 8, y: 8, z: 1
      x = 8
      y = 8
      z = 1

      if node.args.size >= 1
        x = node.args[0].to_s.to_i? || 8
      end
      if node.args.size >= 2
        y = node.args[1].to_s.to_i? || 8
      end
      if node.args.size >= 3
        z = node.args[2].to_s.to_i? || 1
      end

      node.named_args.try &.each do |narg|
        case narg.name
        when "x" then x = narg.value.to_s.to_i? || x
        when "y" then y = narg.value.to_s.to_i? || y
        when "z" then z = narg.value.to_s.to_i? || z
        end
      end

      @program.compute_layout = ComputeLayout.new(x, y, z)
    end

    private def process_buffer_call(node : Crystal::Call)
      # buffer MyBuffer, set: 0, binding: 0, std: :std430, restrict: true do ... end
      raw_name = node.args.first?.try { |a| node_to_string_or_sym(a) } || "Buffer"
      name = raw_name.camelcase
      instance_name = raw_name.underscore
      set = 0
      binding = 0
      std = "std430"
      is_restrict = false
      is_readonly = false

      node.named_args.try &.each do |narg|
        case narg.name
        when "as", "instance" then instance_name = node_to_string_or_sym(narg.value)
        when "set"            then set = narg.value.to_s.to_i? || 0
        when "binding"        then binding = narg.value.to_s.to_i? || 0
        when "std"            then std = node_to_string_or_sym(narg.value)
        when "restrict"       then is_restrict = narg.value.to_s == "true"
        when "readonly"       then is_readonly = narg.value.to_s == "true"
        end
      end

      fields = [] of BufferField
      if block = node.block
        extract_buffer_fields(block.body, fields)
      end

      @program.buffers << BufferDecl.new(
        name: name,
        instance_name: instance_name,
        set: set,
        binding: binding,
        std: std,
        restrict: is_restrict,
        readonly: is_readonly,
        fields: fields
      )
    end

    private def process_push_constant_call(node : Crystal::Call)
      raw_name = node.args.first?.try { |a| node_to_string_or_sym(a) } || "PushConstants"
      name = raw_name.camelcase
      instance_name = raw_name.underscore

      node.named_args.try &.each do |narg|
        case narg.name
        when "as", "instance" then instance_name = node_to_string_or_sym(narg.value)
        end
      end

      fields = [] of BufferField
      if block = node.block
        extract_buffer_fields(block.body, fields)
      end

      @program.push_constants << PushConstantDecl.new(
        name: name,
        instance_name: instance_name,
        fields: fields
      )
    end

    private def extract_buffer_fields(node : Crystal::ASTNode, fields : Array(BufferField))
      if node.is_a?(Crystal::Expressions)
        node.expressions.each { |child| extract_buffer_fields(child, fields) }
      elsif node.is_a?(Crystal::Call)
        # field data : Array(Float32) OR field count : Int32
        if node.name == "field" && (first_arg = node.args.first?)
          if first_arg.is_a?(Crystal::TypeDeclaration)
            f_name = first_arg.var.to_s
            type_ast = first_arg.declared_type
            if type_ast.is_a?(Crystal::Generic) && type_ast.name.to_s == "Array"
              inner_type = type_ast.type_vars.first?.try(&.to_s) || "Float32"
              array_size = type_ast.type_vars.size > 1 ? type_ast.type_vars[1].to_s : nil
              fields << BufferField.new(f_name, inner_type, is_array: true, array_size: array_size)
            else
              fields << BufferField.new(f_name, type_ast.to_s, is_array: false)
            end
          end
        end
      elsif node.is_a?(Crystal::TypeDeclaration)
        f_name = node.var.to_s
        type_ast = node.declared_type
        fields << BufferField.new(f_name, type_ast.to_s, is_array: false)
      end
    end

    private def process_def(node : Crystal::Def)
      @program.imported_functions.delete(node.name)
      @program.functions[node.name] = node
    end

    private def process_assign(node : Crystal::Assign)
      # e.g. PI = 3.14159265 or `const NAME : Type = expr` / `const NAME = expr`
      if node.target.is_a?(Crystal::Path) || node.target.is_a?(Crystal::Var)
        raw_name = node.target.to_s
        ctype : String? = nil
        name = if m = raw_name.match(/^__const_typed__([a-zA-Z_][a-zA-Z0-9_]*)__(.+)$/)
                 ctype = m[1]
                 m[2]
               elsif raw_name.starts_with?("__const_untyped__")
                 raw_name.sub(/^__const_untyped__/, "")
               else
                 raw_name.sub(/^builtin_/, "")
               end
        @program.imported_constants.delete(name)
        @program.constants.reject! { |c| c.name == name }
        @program.constants << ConstantDecl.new(name: name, value: node.value, type_name: ctype)
        @macro_engine.register_constant(name, node.value)
      else
        @program.raw_top_level_nodes << node
      end
    end

    private def process_struct(node : Crystal::ClassDef)
      fields = [] of StructField
      if body = node.body
        if body.is_a?(Crystal::Expressions)
          body.expressions.each do |child|
            if child.is_a?(Crystal::TypeDeclaration)
              fields << StructField.new(child.var.to_s, child.declared_type.to_s)
            end
          end
        elsif body.is_a?(Crystal::TypeDeclaration)
          fields << StructField.new(body.var.to_s, body.declared_type.to_s)
        end
      end
      sname = node.name.to_s
      @program.imported_structs.delete(sname)
      @program.structs[sname] = StructDecl.new(sname, fields)
    end

    private def process_require(node : Crystal::Require)
      handle_require_path(node.string)
    end

    private def detect_early_target_and_type(source : String) : Void
      unconditional = source.gsub(/\{%\s*if\b.*?\{%\s*end\s*%\}/m, "")
      if m = unconditional.match(/\bshader(?:_type)?\s*\(?\s*:?([a-z_0-9]+)/i)
        if st = ShaderType.from_string?(m[1])
          @program.shader_type = st
          if st == ShaderType::Compute && !@force_target
            @program.target = ShaderTarget::GLSL
          end
        end
      elsif unconditional =~ /\b(compositor_effect|compositor_pass|compute_kernel|particle_simulation|compute_particles)\b/
        @program.shader_type = ShaderType::Compute
        @program.target = ShaderTarget::GLSL unless @force_target
      elsif unconditional =~ /\b(sprite_effect|ui_effect)\b/
        @program.shader_type = ShaderType::CanvasItem
      elsif unconditional =~ /\bsurface_material\b/
        @program.shader_type = ShaderType::Spatial
      elsif unconditional =~ /\bscreen_effect\b/
        if unconditional =~ /\bscreen_effect[^\n]*?(?:mode\s*:\s*:?spatial|depth\s*:\s*true)/
          @program.shader_type = ShaderType::Spatial
        else
          @program.shader_type = ShaderType::CanvasItem
        end
      end
      @macro_engine.configure_target(@program.target, @program.shader_type)
    end

    private def preload_requires(node : Crystal::ASTNode) : Void
      case node
      when Crystal::Expressions
        node.expressions.each { |child| preload_requires(child) }
      when Crystal::Require
        handle_require_path(node.string)
      when Crystal::Call
        if node.name == "require" && (arg = node.args.first?)
          handle_require_path(node_to_string_or_sym(arg))
        elsif (blk = node.block) && ["shader", "group", "uniform_group", "compositor_effect", "compositor_pass", "sprite_effect", "screen_effect", "ui_effect", "surface_material"].includes?(node.name)
          preload_requires(blk.body)
        end
      end
    end

    private def prescan_features(node : Crystal::ASTNode) : Void
      case node
      when Crystal::Expressions
        node.expressions.each { |child| prescan_features(child) }
      when Crystal::Call
        if node.name == "feature" && node.obj.nil?
          register_feature_from_call(node)
        elsif (blk = node.block)
          prescan_features(blk.body)
        end
      end
    end

    private def apply_orphan_feature_overrides : Void
      @feature_overrides.each do |fname, fval|
        next if @program.features.any? { |f| f.name == fname }
        ast_val = feature_value_to_ast(fval)
        @macro_engine.register_feature(fname, ast_val)
      end
    end

    private def process_feature_call(node : Crystal::Call) : Void
      register_feature_from_call(node)
    end

    private def register_feature_from_call(node : Crystal::Call) : Void
      return if node.args.empty?
      fname = node_to_string_or_sym(node.args[0]).strip
      return if fname.empty?

      options = [] of String
      default_node : Crystal::ASTNode? = node.args[1]?

      node.named_args.try &.each do |narg|
        case narg.name
        when "default"
          default_node = narg.value
        when "options", "values"
          if narg.value.is_a?(Crystal::ArrayLiteral)
            narg.value.as(Crystal::ArrayLiteral).elements.each do |el|
              options << node_to_string_or_sym(el)
            end
          end
        end
      end

      kind, def_str = if !options.empty?
                        d = default_node ? node_to_string_or_sym(default_node) : options.first
                        {FeatureKind::Enum, d}
                      elsif default_node.is_a?(Crystal::NumberLiteral)
                        {FeatureKind::Int, default_node.as(Crystal::NumberLiteral).value}
                      elsif default_node.is_a?(Crystal::BoolLiteral)
                        {FeatureKind::Bool, default_node.as(Crystal::BoolLiteral).value ? "true" : "false"}
                      elsif default_node
                        s = node_to_string_or_sym(default_node)
                        if s == "true" || s == "false"
                          {FeatureKind::Bool, s}
                        elsif s.to_i?
                          {FeatureKind::Int, s}
                        else
                          {FeatureKind::Enum, s}
                        end
                      else
                        {FeatureKind::Bool, "true"}
                      end

      active_str = if @feature_overrides.has_key?(fname)
                     VariantCache.normalize_feature_val(@feature_overrides[fname])
                   else
                     def_str
                   end

      doc = extract_doc_comment(node.location.try(&.line_number))
      fdecl = FeatureDecl.new(
        name: fname,
        kind: kind,
        default_value: def_str,
        active_value: active_str,
        options: options,
        doc_comment: doc
      )

      @program.features.reject! { |f| f.name == fname }
      @program.features << fdecl

      ast_node = case kind
                 when FeatureKind::Bool
                   Crystal::BoolLiteral.new(active_str == "true" || active_str == "1")
                 when FeatureKind::Int
                   Crystal::NumberLiteral.new(active_str.to_i? || 0)
                 else
                   Crystal::StringLiteral.new(active_str)
                 end

      @macro_engine.register_feature(fname, ast_node)

      # Also expose Bool / Int features as imported compile-time constants so runtime expressions can read `FEATURE_<NAME>`
      case kind
      when FeatureKind::Bool
        @program.constants.reject! { |c| c.name == fdecl.macro_name }
        @program.constants << ConstantDecl.new(fdecl.macro_name, ast_node, "Bool")
        @program.imported_constants.add(fdecl.macro_name)
      when FeatureKind::Int
        @program.constants.reject! { |c| c.name == fdecl.macro_name }
        @program.constants << ConstantDecl.new(fdecl.macro_name, ast_node, "Int32")
        @program.imported_constants.add(fdecl.macro_name)
      end
    end

    private def feature_value_to_ast(val : FeatureValue) : Crystal::ASTNode
      case val
      when Bool   then Crystal::BoolLiteral.new(val)
      when Int32  then Crystal::NumberLiteral.new(val)
      when Symbol then Crystal::StringLiteral.new(val.to_s)
      when String
        if val == "true" || val == "false"
          Crystal::BoolLiteral.new(val == "true")
        elsif iv = val.to_i?
          Crystal::NumberLiteral.new(iv)
        else
          Crystal::StringLiteral.new(val)
        end
      else
        Crystal::StringLiteral.new(val.to_s)
      end
    end

    private def process_use_trait_call(node : Crystal::Call) : Void
      return if node.args.empty?
      target_str = node_to_string_or_sym(node.args[0])
      prefix : String? = nil
      node.named_args.try &.each do |narg|
        if narg.name == "prefix" || narg.name == "as"
          prefix = node_to_string_or_sym(narg.value)
        end
      end
      @program.trait_uses << TraitUse.new(target_str, prefix)
    end

    def self.resolve_crshader_file(req_str : String, filename : String?) : String?
      base_dir = filename ? File.dirname(filename) : "."
      candidates = [] of String

      if req_str.starts_with?("res://")
        clean = req_str.sub(%r{^res://}, "").gsub('\\', '/')
        curr = File.expand_path(base_dir)
        5.times do
          if File.exists?(File.join(curr, "project.godot"))
            candidates << File.join(curr, clean)
            candidates << "#{File.join(curr, clean)}.crshader"
            break
          end
          parent = File.dirname(curr)
          break if parent == curr
          curr = parent
        end
        candidates << clean
        candidates << "#{clean}.crshader"
      elsif req_str.starts_with?("./") || req_str.starts_with?("../") || req_str.ends_with?(".crshader")
        resolved = File.expand_path(req_str, base_dir)
        candidates << resolved
        candidates << "#{resolved}.crshader" unless resolved.ends_with?(".crshader")
      end

      candidates.find { |c| File.exists?(c) && File.file?(c) }
    end

    private def resolve_crshader_path(req_str : String) : String?
      self.class.resolve_crshader_file(req_str, @filename)
    end

    private def merge_imported_program(sub_parser : DslParser, include_uniforms : Bool = true) : Void
      sub_program = sub_parser.program

      # Merge macros, features & compile-time constants into MacroEngine
      sub_parser.macro_engine.macros.each { |k, m| @macro_engine.macros[k] = m }
      sub_parser.macro_engine.features.each { |k, fv| @macro_engine.register_feature(k, fv) }
      sub_program.constants.each { |c| @macro_engine.register_constant(c.name, c.value) }
      sub_program.features.each do |f|
        unless @program.features.any? { |ef| ef.name == f.name }
          @program.features << f
        end
      end
      sub_program.traits.each do |tname, tdecl|
        @program.traits[tname] ||= tdecl
      end
      sub_program.gradients.each do |g|
        unless @program.gradients.any? { |eg| eg.name == g.name }
          @program.gradients << g
        end
      end
      sub_program.curves.each do |cv|
        unless @program.curves.any? { |ec| ec.name == cv.name }
          @program.curves << cv
        end
      end

      # Merge structs, constants, and functions (marked as imported for TreeShaker)
      sub_program.structs.each do |k, v|
        unless @program.structs.has_key?(k)
          @program.structs[k] = v
          @program.imported_structs.add(k)
        end
      end

      sub_program.constants.each do |c|
        unless @program.constants.any? { |existing| existing.name == c.name }
          @program.constants << c
          @program.imported_constants.add(c.name)
        end
      end

      sub_program.functions.each do |k, v|
        unless @program.functions.has_key?(k)
          @program.functions[k] = v
          @program.imported_functions.add(k)
        end
      end

      if include_uniforms
        sub_program.uniforms.each do |u|
          unless @program.uniforms.any? { |existing| existing.name == u.name }
            @program.uniforms << u
          end
        end
        sub_program.varyings.each do |v|
          unless @program.varyings.any? { |existing| existing.name == v.name }
            @program.varyings << v
          end
        end
        sub_program.buffers.each do |b|
          unless @program.buffers.any? { |existing| existing.name == b.name }
            @program.buffers << b
          end
        end
        sub_program.push_constants.each do |pc|
          unless @program.push_constants.any? { |existing| existing.name == pc.name }
            @program.push_constants << pc
          end
        end
        sub_program.includes.each do |inc|
          @program.includes << inc unless @program.includes.includes?(inc)
        end
      end

      sub_program.external_structs.each { |k, v| @program.external_structs[k] = v }
      sub_program.external_functions.each { |k, v| @program.external_functions[k] = v }
      sub_program.external_constants.each { |k, v| @program.external_constants[k] = v }
      sub_program.requires.each { |r| @program.requires.add(r) }
    end

    private def handle_require_path(req_str : String)
      if Std.has_module?(req_str)
        clean_std = req_str.sub(/^std\//, "")
        mod_key = "std:#{clean_std}"
        @program.requires.add(req_str)
        if @loaded_modules.add?(mod_key)
          if std_src = Std.module_source(clean_std)
            sub_parser = DslParser.new(
              filename: "<std/#{clean_std}>",
              default_target: @program.target,
              loaded_modules: @loaded_modules,
              force_target: true,
              feature_overrides: @feature_overrides
            )
            sub_parser.parse(std_src)
            merge_imported_program(sub_parser, include_uniforms: true)
          end
        end
        return
      end

      if candidate = resolve_crshader_path(req_str)
        canon = File.expand_path(candidate).gsub('\\', '/')
        if @loaded_modules.add?(canon)
          sub_parser = DslParser.new(
            filename: candidate,
            default_target: @program.target,
            loaded_modules: @loaded_modules,
            force_target: true,
            feature_overrides: @feature_overrides
          )
          sub_parser.parse(File.read(candidate))
          merge_imported_program(sub_parser, include_uniforms: true)
        end
        return
      end

      @program.requires.add(req_str)
    end

    private def extract_doc_comment(line_number : Int32?) : String?
      return nil unless line_number && line_number > 1
      idx = line_number - 2
      collected = [] of String
      while idx >= 0
        line = @source_lines[idx]?.try(&.strip) || ""
        if line.starts_with?("#")
          break if line =~ /^#(include|define|undef|ifdef|ifndef|if|elif|else|endif|pragma)\b/
          clean_comment = line.sub(/^#+\s?/, "").strip
          # Skip pure decorative divider bars like # ==== or # ----
          if clean_comment !~ /^[=\-*_]{4,}$/ && !clean_comment.empty?
            collected.unshift(clean_comment)
          end
          idx -= 1
        else
          break
        end
      end
      collected.empty? ? nil : collected.join(" ")
    end

    private def node_to_string_or_sym(node : Crystal::ASTNode) : String
      case node
      when Crystal::SymbolLiteral, Crystal::StringLiteral
        node.value
      when Crystal::Var
        node.name
      when Crystal::Path
        node.names.join("::")
      when Crystal::Call
        node.name
      else
        node.to_s
      end
    end

    private def node_to_hint_string(node : Crystal::ASTNode) : String
      case node
      when Crystal::SymbolLiteral, Crystal::StringLiteral
        node.value
      when Crystal::Call
        hname = node.name
        hname = "hint_range" if hname == "range"
        hname = "hint_enum" if hname == "enum"
        args_str = if hname == "hint_enum"
                     node.args.map { |a| "\"#{node_to_string_or_sym(a)}\"" }.join(", ")
                   else
                     node.args.map { |a| node_to_string_or_sym(a) }.join(", ")
                   end
        "#{hname}(#{args_str})"
      else
        node.to_s
      end
    end

    private def normalize_hint(raw_hint : String) : String
      case raw_hint
      when "screen_texture", "depth_texture", "normal_roughness_texture",
           "default_white", "default_black", "default_transparent",
           "roughness_r", "roughness_g", "roughness_b", "roughness_a",
           "roughness_normal", "anisotropy", "normal"
        "hint_#{raw_hint}"
      when "color", "source_color"
        "source_color"
      when /^hint_/
        raw_hint
      else
        raw_hint
      end
    end

    private def parse_hex_color_to_ast(call : Crystal::Call) : Crystal::ASTNode?
      return nil unless (call.name == "hex" || call.name == "from_hex")
      arg = call.args.first?
      return nil unless arg

      hex_str = case arg
                when Crystal::StringLiteral then arg.value.strip
                when Crystal::NumberLiteral then arg.value.sub(/^0x/i, "")
                else                             return nil
                end

      clean_hex = hex_str.sub(/^#/, "")
      if clean_hex.size == 6
        r = (clean_hex[0..1].to_i(16) / 255.0_f32).round(4)
        g = (clean_hex[2..3].to_i(16) / 255.0_f32).round(4)
        b = (clean_hex[4..5].to_i(16) / 255.0_f32).round(4)
        Crystal::Parser.new("Color.new(#{r}, #{g}, #{b}, 1.0)").parse
      elsif clean_hex.size == 8
        r = (clean_hex[0..1].to_i(16) / 255.0_f32).round(4)
        g = (clean_hex[2..3].to_i(16) / 255.0_f32).round(4)
        b = (clean_hex[4..5].to_i(16) / 255.0_f32).round(4)
        a = (clean_hex[6..7].to_i(16) / 255.0_f32).round(4)
        Crystal::Parser.new("Color.new(#{r}, #{g}, #{b}, #{a})").parse
      else
        nil
      end
    rescue
      nil
    end

    private def process_sampler_call(node : Crystal::Call)
      return unless (first_arg = node.args.first?)
      name = node_to_string_or_sym(first_arg)
      hints = [] of String
      explicit_set : Int32? = nil
      explicit_binding : Int32? = nil

      node.named_args.try &.each do |narg|
        case narg.name
        when "filter", "repeat"
          hints << "#{narg.name}_#{node_to_string_or_sym(narg.value)}"
        when "hint"
          hints << normalize_hint(node_to_hint_string(narg.value))
        when "set"
          explicit_set = narg.value.to_s.to_i?
        when "binding"
          explicit_binding = narg.value.to_s.to_i?
        end
      end

      doc_comment = extract_doc_comment(node.location.try(&.line_number))
      @program.uniforms.reject! { |u| u.name == name }
      @program.uniforms << UniformDecl.new(
        name: name,
        type_name: "Sampler2D",
        hints: hints,
        group: @current_group,
        subgroup: @current_subgroup,
        doc_comment: doc_comment,
        set: explicit_set,
        binding: explicit_binding
      )
    end

    private def process_record_call(node : Crystal::Call)
      return if node.args.empty?
      struct_name = node_to_string_or_sym(node.args[0])
      fields = [] of StructField
      node.args[1..-1].each do |arg|
        if arg.is_a?(Crystal::TypeDeclaration)
          f_name = arg.var.to_s
          f_type = TypeInfo.normalize(arg.declared_type.to_s)
          fields << StructField.new(f_name, f_type)
        end
      end
      node.named_args.try &.each do |narg|
        f_name = narg.name
        f_type = TypeInfo.normalize(narg.value.to_s)
        fields << StructField.new(f_name, f_type)
      end
      @program.imported_structs.delete(struct_name)
      @program.structs[struct_name] = StructDecl.new(struct_name, fields)
    end

    private def process_stage_call(node : Crystal::Call)
      return unless (first_arg = node.args.first?) && (block = node.block)
      stage_name = node_to_string_or_sym(first_arg)
      @program.functions[stage_name] = Crystal::Def.new(stage_name, body: block.body)
    end

    private def process_compositor_effect_call(node : Crystal::Call)
      @program.shader_type = ShaderType::Compute
      @program.target = ShaderTarget::GLSL
      @program.is_compositor = true
      @program.compute_layout = ComputeLayout.new(8, 8, 1)

      stage_name = node.args.first?.try { |a| node_to_string_or_sym(a) } || "post_transparent"
      @program.compositor_stage = case stage_name.downcase
                                  when "post_transparent" then "PostTransparent"
                                  when "post_opaque"      then "PostOpaque"
                                  when "pre_opaque"       then "PreOpaque"
                                  when "post_sky"         then "PostSky"
                                  else                         "PostTransparent"
                                  end

      if block = node.block
        process_compositor_block(block.body)
      end
    end

    private def process_compositor_block(node : Crystal::ASTNode)
      if node.is_a?(Crystal::Expressions)
        node.expressions.each { |child| process_compositor_block(child) }
        return
      end

      case node
      when Crystal::Call
        case node.name
        when "access"
          node.args.each do |arg|
            sym = node_to_string_or_sym(arg).downcase
            case sym
            when "color"
              @program.compositor_access_color = true
            when "depth", "depth_texture"
              @program.compositor_access_depth = true
            when "normal_roughness", "normal", "normals"
              @program.compositor_access_normal_roughness = true
            when "scene_data", "matrices", "camera"
              @program.compositor_access_scene_data = true
            end
          end
        when "process_pixel"
          process_pixel_block(node)
        else
          process_top_level_node(node)
        end
      else
        process_top_level_node(node)
      end
    end

    private def process_pixel_block(node : Crystal::Call)
      return unless (block = node.block)

      has_color = @program.images.any? { |img| img.name == "color_image" }
      unless has_color
        @program.images << ImageUniformDecl.new("color_image", "image2D", "rgba16f", set: 0, binding: 0)
      end

      if @program.compositor_access_depth
        has_depth = @program.uniforms.any? { |u| u.name == "depth_texture" } || @program.images.any? { |img| img.name == "depth_image" }
        unless has_depth
          @program.uniforms << UniformDecl.new(
            name: "depth_texture",
            type_name: "Sampler2D",
            set: 0,
            binding: 1
          )
        end
      end

      if @program.compositor_access_normal_roughness
        has_nr = @program.uniforms.any? { |u| u.name == "normal_roughness_texture" }
        unless has_nr
          @program.uniforms << UniformDecl.new(
            name: "normal_roughness_texture",
            type_name: "Sampler2D",
            set: 0,
            binding: 2
          )
        end
      end

      coord_var = block.args[0]?.try(&.name) || "coord"
      has_uv_arg = block.args.size >= 3
      uv_var = has_uv_arg ? block.args[1].name : "__uv"
      color_var = has_uv_arg ? block.args[2].name : (block.args[1]?.try(&.name) || "color")

      @program.coord_stage_var = coord_var
      @program.pixel_stage_vars = {uv_var, color_var}
      needs_uv = has_uv_arg || !@program.trait_uses.empty?
      uv_line = needs_uv ? "#{uv_var} = (vec2(float(#{coord_var}.x), float(#{coord_var}.y)) + vec2(0.5, 0.5)) / vec2(float(size.x), float(size.y))" : ""

      main_code = <<-CR
        def main
          #{coord_var} = ivec2(gl_GlobalInvocationID.xy)
          size = imageSize(color_image)
          if #{coord_var}.x >= size.x || #{coord_var}.y >= size.y
            return
          end
          #{uv_line}
          #{color_var} = imageLoad(color_image, #{coord_var})
        end
      CR

      parsed_def = Crystal::Parser.new(main_code).parse.as(Crystal::Def)
      main_body_exprs = parsed_def.body.as(Crystal::Expressions).expressions

      if block.body.is_a?(Crystal::Expressions)
        main_body_exprs.concat(block.body.as(Crystal::Expressions).expressions)
      else
        main_body_exprs << block.body
      end

      store_call = Crystal::Call.new(
        nil,
        "imageStore",
        [
          Crystal::Var.new("color_image").as(Crystal::ASTNode),
          Crystal::Var.new(coord_var).as(Crystal::ASTNode),
          Crystal::Var.new(color_var).as(Crystal::ASTNode),
        ]
      )
      main_body_exprs << store_call

      parsed_def.body = Crystal::Expressions.new(main_body_exprs)
      @program.functions["main"] = parsed_def
    end

    private def process_compute_kernel_call(node : Crystal::Call)
      @program.shader_type = ShaderType::Compute
      @program.target = ShaderTarget::GLSL

      x = node.args[0]?.try(&.to_s.to_i?) || 8
      y = node.args[1]?.try(&.to_s.to_i?) || 8
      z = node.args[2]?.try(&.to_s.to_i?) || 1
      @program.compute_layout = ComputeLayout.new(x, y, z)

      if block = node.block
        if block.body.is_a?(Crystal::Expressions)
          block.body.as(Crystal::Expressions).expressions.each { |child| process_top_level_node(child) }
        else
          process_top_level_node(block.body)
        end
      end
    end

    private def process_kernel_1d_call(node : Crystal::Call)
      return unless (block = node.block)
      bound_var = node.args.first?.try { |a| node_to_string_or_sym(a) } || "count"
      idx_var = block.args.first?.try(&.name) || "idx"

      kernel_code = <<-CR
        def main
          #{idx_var} = gl_GlobalInvocationID.x
          if #{idx_var} >= #{bound_var}
            return
          end
        end
      CR

      parsed_def = Crystal::Parser.new(kernel_code).parse.as(Crystal::Def)
      main_body_exprs = parsed_def.body.as(Crystal::Expressions).expressions
      if block.body.is_a?(Crystal::Expressions)
        main_body_exprs.concat(block.body.as(Crystal::Expressions).expressions)
      else
        main_body_exprs << block.body
      end
      parsed_def.body = Crystal::Expressions.new(main_body_exprs)
      @program.functions["main"] = parsed_def
    end

    private def process_kernel_2d_call(node : Crystal::Call)
      return unless (block = node.block)
      bound_target = node.args.first?.try { |a| node_to_string_or_sym(a) } || "image"
      coord_var = block.args.first?.try(&.name) || "coord"

      size_calc = if @program.images.any? { |img| img.name == bound_target }
                    "imageSize(#{bound_target})"
                  else
                    bound_target
                  end

      kernel_code = <<-CR
        def main
          #{coord_var} = ivec2(gl_GlobalInvocationID.xy)
          __size = #{size_calc}
          if #{coord_var}.x >= __size.x || #{coord_var}.y >= __size.y
            return
          end
        end
      CR

      parsed_def = Crystal::Parser.new(kernel_code).parse.as(Crystal::Def)
      main_body_exprs = parsed_def.body.as(Crystal::Expressions).expressions
      if block.body.is_a?(Crystal::Expressions)
        main_body_exprs.concat(block.body.as(Crystal::Expressions).expressions)
      else
        main_body_exprs << block.body
      end
      parsed_def.body = Crystal::Expressions.new(main_body_exprs)
      @program.functions["main"] = parsed_def
    end

    private def process_particle_simulation_call(node : Crystal::Call)
      @program.shader_type = ShaderType::Compute
      @program.target = ShaderTarget::GLSL
      @program.requires.add("particles")

      x = node.args[0]?.try(&.to_s.to_i?) || 64
      y = node.args[1]?.try(&.to_s.to_i?) || 1
      z = node.args[2]?.try(&.to_s.to_i?) || 1
      @program.compute_layout = ComputeLayout.new(x, y, z)

      buf_name = "ParticleBuffer"
      buf_instance = "particle_buffer"
      set_idx = 0
      bind_idx = 0
      auto_buffers = true

      node.named_args.try &.each do |narg|
        case narg.name
        when "local_size", "workgroup_size"
          @program.compute_layout = ComputeLayout.new(narg.value.to_s.to_i? || 64, 1, 1)
        when "buffer"
          raw = node_to_string_or_sym(narg.value)
          buf_name = raw.camelcase
          buf_instance = raw.underscore
        when "set"
          set_idx = narg.value.to_s.to_i? || 0
        when "binding"
          bind_idx = narg.value.to_s.to_i? || 0
        when "auto_buffers"
          auto_buffers = narg.value.to_s != "false"
        end
      end

      if block = node.block
        if block.body.is_a?(Crystal::Expressions)
          block.body.as(Crystal::Expressions).expressions.each { |child| process_top_level_node(child) }
        else
          process_top_level_node(block.body)
        end
      end

      if auto_buffers && @program.buffers.empty?
        @program.buffers << BufferDecl.new(
          name: buf_name,
          instance_name: buf_instance,
          set: set_idx,
          binding: bind_idx,
          std: "std430",
          restrict: true,
          readonly: false,
          fields: [
            BufferField.new("positions", "Vec4", is_array: true),
            BufferField.new("velocities", "Vec4", is_array: true),
            BufferField.new("colors", "Vec4", is_array: true),
          ]
        )
      end

      if auto_buffers && @program.push_constants.empty?
        @program.push_constants << PushConstantDecl.new(
          name: "SimParams",
          instance_name: "sim_params",
          fields: [
            BufferField.new("delta_time", "Float32", is_array: false),
            BufferField.new("particle_count", "UInt32", is_array: false),
            BufferField.new("gravity", "Vec3", is_array: false),
            BufferField.new("drag", "Float32", is_array: false),
            BufferField.new("turbulence", "Float32", is_array: false),
            BufferField.new("time", "Float32", is_array: false),
          ]
        )
      end
    end

    private def process_step_particles_call(node : Crystal::Call)
      return unless (block = node.block)

      buf_inst = @program.buffers.first?.try(&.instance_name) || "particle_buffer"
      pc_inst = @program.push_constants.first?.try(&.instance_name) || "sim_params"
      bound_expr = if first_arg = node.args.first?
                     node_to_string_or_sym(first_arg)
                   else
                     "#{pc_inst}.particle_count"
                   end

      idx_var = block.args[0]?.try(&.name) || "idx"
      pos_var = block.args[1]?.try(&.name) || "pos"
      vel_var = block.args[2]?.try(&.name) || "vel"
      life_var = block.args[3]?.try(&.name) || "life"

      preamble = <<-CR
        def main
          #{idx_var} = gl_GlobalInvocationID.x
          if #{idx_var} >= #{bound_expr}
            return
          end
          __pos_life = #{buf_inst}.positions[#{idx_var}]
          __vel_max = #{buf_inst}.velocities[#{idx_var}]
          #{pos_var} = __pos_life.xyz
          #{life_var} = __pos_life.w
          #{vel_var} = __vel_max.xyz
        end
      CR

      parsed_def = Crystal::Parser.new(preamble).parse.as(Crystal::Def)
      main_body_exprs = parsed_def.body.as(Crystal::Expressions).expressions

      if block.body.is_a?(Crystal::Expressions)
        main_body_exprs.concat(block.body.as(Crystal::Expressions).expressions)
      else
        main_body_exprs << block.body
      end

      pos_store = Crystal::Call.new(
        Crystal::Call.new(Crystal::Var.new(buf_inst), "positions"),
        "[]=",
        [
          Crystal::Var.new(idx_var).as(Crystal::ASTNode),
          Crystal::Call.new(nil, "vec4", [
            Crystal::Var.new(pos_var).as(Crystal::ASTNode),
            Crystal::Var.new(life_var).as(Crystal::ASTNode),
          ] of Crystal::ASTNode).as(Crystal::ASTNode),
        ] of Crystal::ASTNode
      )

      vel_store = Crystal::Call.new(
        Crystal::Call.new(Crystal::Var.new(buf_inst), "velocities"),
        "[]=",
        [
          Crystal::Var.new(idx_var).as(Crystal::ASTNode),
          Crystal::Call.new(nil, "vec4", [
            Crystal::Var.new(vel_var).as(Crystal::ASTNode),
            Crystal::Call.new(Crystal::Var.new("__vel_max"), "w").as(Crystal::ASTNode),
          ] of Crystal::ASTNode).as(Crystal::ASTNode),
        ] of Crystal::ASTNode
      )

      main_body_exprs << pos_store
      main_body_exprs << vel_store

      parsed_def.body = Crystal::Expressions.new(main_body_exprs)
      @program.functions["main"] = parsed_def
    end
  end
end
