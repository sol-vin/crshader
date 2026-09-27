require "compiler/crystal/syntax"
require "../ast/shader_ast"
require "../ast/types"
require "../macros/macro_engine"
require "./error_formatter"
require "./tres_reader"
require "../validator/rules"
require "../extensions/registry"

module CrShader
  class DslParser
    getter program : ShaderProgram
    getter macro_engine : MacroEngine
    property current_group : String? = nil
    property current_subgroup : String? = nil
    getter filename : String?
    getter source_lines : Array(String)

    def initialize(@filename : String? = nil, default_target : ShaderTarget = ShaderTarget::GDShader)
      @program = ShaderProgram.new(default_target)
      @macro_engine = MacroEngine.new
      @source_lines = [] of String
    end

    def parse(source : String) : ShaderProgram
      @source_lines = source.lines

      # Normalize uppercase built-in variable assignments to avoid dynamic constant assignment errors
      normalized_source = source.gsub(/\b([A-Z][A-Z0-9_]*)\s*(\+|-|\*|\/|%|&|\||\^|<<|>>)?=(?!=)/) do |match, regex_match|
        op = regex_match[2]? || ""
        "builtin_#{regex_match[1]} #{op}= "
      end

      # Normalize empty untyped array literal [] to ([] of Void) to allow Crystal's parser to accept it
      normalized_source = normalized_source.gsub(/=\s*\[\s*\]/, "= ([] of Void)")

      # Normalize property keyword to uniform call to bypass Crystal's built-in property macro limitation with named arguments
      normalized_source = normalized_source.gsub(/\bproperty\s+([a-zA-Z_][a-zA-Z0-9_]*\s*:)/) do |_, regex_match|
        "uniform #{regex_match[1]}"
      end

      # Normalize lowercase primitive types in genuine type annotations (uniform/export/field x : float, record x : float, func(x : float), etc.)
      type_pattern = "(float|int|uint|bool|vec2|vec3|vec4|color|mat2|mat3|mat4|sampler2d|sampler_2d|sampler_cube|ivec2|ivec3|ivec4|uvec2|uvec3|uvec4)"
      normalized_source = normalized_source.gsub(/\b(uniform|export|varying|field)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*#{type_pattern}\b/i) do |_, m|
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

      # Macro expansion pass
      expanded_ast = @macro_engine.expand(ast)

      # Process top-level AST nodes
      if expanded_ast.is_a?(Crystal::Expressions)
        expanded_ast.expressions.each do |node|
          process_top_level_node(node)
        end
      else
        process_top_level_node(expanded_ast)
      end

      @program
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
            if st == ShaderType::Compute
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

      when "varying"
        process_varying_call(node)

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

      when "vertex", "fragment", "light", "start", "process", "sky", "fog"
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
      format = "rgba32f"
      set = 0
      binding = 0

      if first_arg = node.args.first?
        name = node_to_string_or_sym(first_arg)
      end

      node.named_args.try &.each do |narg|
        case narg.name
        when "format" then format = node_to_string_or_sym(narg.value)
        when "set" then set = narg.value.to_s.to_i? || 0
        when "binding" then binding = narg.value.to_s.to_i? || 0
        end
      end

      return if name.empty?
      @program.images << ImageUniformDecl.new(name: name, format: format, set: set, binding: binding)
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
        when "type"
          type_name = TypeInfo.normalize(narg.value.to_s)
        else
          hints << normalize_hint(node_to_hint_string(narg.value))
        end
      end

      return if name.empty?

      if default_val.is_a?(Crystal::Call) && (hex_ast = parse_hex_color_to_ast(default_val.as(Crystal::Call)))
        default_val = hex_ast
      end

      type_name = TypeInfo.normalize(type_name)

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
        embedded_elements: embedded_elements
      )
    end

    private def infer_array_elem_type(elem : Crystal::ASTNode) : String?
      case elem
      when Crystal::Call
        case elem.name
        when "vec4" then "Vec4"
        when "vec3" then "Vec3"
        when "vec2" then "Vec2"
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

    private def process_varying_call(node : Crystal::Call)
      # varying v_normal : Vec3, qualifier: :flat
      name = ""
      type_name = "Vec3"
      qualifier : String? = nil

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
        if narg.name == "qualifier" || narg.name == "interpolation"
          qualifier = node_to_string_or_sym(narg.value)
        end
      end

      return if name.empty?

      @program.varyings << VaryingDecl.new(
        name: name,
        type_name: type_name,
        qualifier: qualifier
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
        when "set"           then set = narg.value.to_s.to_i? || 0
        when "binding"       then binding = narg.value.to_s.to_i? || 0
        when "std"           then std = node_to_string_or_sym(narg.value)
        when "restrict"      then is_restrict = narg.value.to_s == "true"
        when "readonly"      then is_readonly = narg.value.to_s == "true"
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
      @program.functions[node.name] = node
    end

    private def process_assign(node : Crystal::Assign)
      # e.g. PI = 3.14159265
      if node.target.is_a?(Crystal::Path) || node.target.is_a?(Crystal::Var)
        name = node.target.to_s.sub(/^builtin_/, "")
        @program.constants << ConstantDecl.new(name: name, value: node.value)
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
      @program.structs[node.name.to_s] = StructDecl.new(node.name.to_s, fields)
    end

    private def process_require(node : Crystal::Require)
      handle_require_path(node.string)
    end

    private def handle_require_path(req_str : String)
      if req_str.starts_with?("./") || req_str.starts_with?("../")
        base_dir = @filename ? File.dirname(@filename.not_nil!) : "."
        resolved_path = File.expand_path(req_str, base_dir)
        candidate = File.exists?(resolved_path) ? resolved_path : "#{resolved_path}.crshader"
        if File.exists?(candidate)
          sub_parser = DslParser.new(filename: candidate, default_target: @program.target)
          sub_program = sub_parser.parse(File.read(candidate))
          sub_program.functions.each { |k, v| @program.functions[k] = v }
          sub_program.structs.each { |k, v| @program.structs[k] = v }
          @program.constants.concat(sub_program.constants)
          @program.buffers.concat(sub_program.buffers)
          @program.push_constants.concat(sub_program.push_constants)
          sub_program.requires.each { |r| @program.requires.add(r) }
          return
        end
      end
      @program.requires.add(req_str)
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
        args_str = node.args.map { |a| node_to_string_or_sym(a) }.join(", ")
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
                else return nil
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

      node.named_args.try &.each do |narg|
        case narg.name
        when "filter", "repeat"
          hints << "#{narg.name}_#{node_to_string_or_sym(narg.value)}"
        when "hint"
          hints << normalize_hint(node_to_hint_string(narg.value))
        end
      end

      @program.uniforms << UniformDecl.new(
        name: name,
        type_name: "Sampler2D",
        hints: hints,
        group: @current_group,
        subgroup: @current_subgroup
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
                                  when "post_opaque" then "PostOpaque"
                                  when "pre_opaque" then "PreOpaque"
                                  when "post_sky" then "PostSky"
                                  else "PostTransparent"
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
            @program.compositor_access_color = true if sym == "color"
            @program.compositor_access_depth = true if sym == "depth"
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
        @program.images << ImageUniformDecl.new("color_image", "image2D", "rgba32f", set: 0, binding: 0)
      end

      if @program.compositor_access_depth
        has_depth = @program.images.any? { |img| img.name == "depth_image" }
        unless has_depth
          @program.images << ImageUniformDecl.new("depth_image", "image2D", "r32f", set: 0, binding: 1)
        end
      end

      coord_var = block.args[0]?.try(&.name) || "coord"
      color_var = block.args[1]?.try(&.name) || "color"

      main_code = <<-CR
        def main
          #{coord_var} = ivec2(gl_GlobalInvocationID.xy)
          size = imageSize(color_image)
          if #{coord_var}.x >= size.x || #{coord_var}.y >= size.y
            return
          end
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
          Crystal::Var.new(color_var).as(Crystal::ASTNode)
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
  end
end
