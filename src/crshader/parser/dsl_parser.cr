require "compiler/crystal/syntax"
require "../ast/shader_ast"
require "../ast/types"
require "../macros/macro_engine"
require "./error_formatter"

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

      begin
        parser = Crystal::Parser.new(normalized_source)
        parser.filename = @filename
        ast = parser.parse
      rescue ex : Crystal::SyntaxException
        raise ShaderError.new(
          ex.message || "Syntax error",
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
          end
        end

      when "shader"
        process_shader_block(node)

      when "render_mode"
        node.args.each do |arg|
          @program.render_modes << node_to_string_or_sym(arg)
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
          @current_group = node_to_string_or_sym(arg)
          @current_subgroup = nil
        end

      when "subgroup", "uniform_subgroup"
        if arg = node.args.first?
          @current_subgroup = node_to_string_or_sym(arg)
        end

      when "uniform"
        process_uniform_call(node, qualifier: UniformQualifier::Default)

      when "instance_uniform"
        process_uniform_call(node, qualifier: UniformQualifier::Instance)

      when "global_uniform"
        process_uniform_call(node, qualifier: UniformQualifier::Global)

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
      name = ""
      type_name = "Float32"
      default_val : Crystal::ASTNode? = nil
      hints = [] of String
      array_size : String? = nil
      is_var_array = false

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
          else
            type_name = type_ast.to_s
          end
          default_val = first_arg.value
          if default_val.is_a?(Crystal::ArrayLiteral)
            is_var_array = true
            array_size ||= (default_val.elements.empty? ? "16" : default_val.elements.size.to_s)
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
          end
        elsif first_arg.is_a?(Crystal::SymbolLiteral) || first_arg.is_a?(Crystal::Var) || first_arg.is_a?(Crystal::Call)
          name = node_to_string_or_sym(first_arg)
          if node.args.size >= 2
            type_name = node.args[1].to_s
          end
        end
      end

      # Named args: hint, default, filter, repeat, size, type
      node.named_args.try &.each do |narg|
        case narg.name
        when "default"
          default_val = narg.value
          if default_val.is_a?(Crystal::ArrayLiteral)
            is_var_array = true
            array_size ||= (default_val.elements.empty? ? "16" : default_val.elements.size.to_s)
          end
        when "hint"
          if narg.value.is_a?(Crystal::ArrayLiteral)
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
          type_name = narg.value.to_s
        else
          hints << normalize_hint(node_to_hint_string(narg.value))
        end
      end

      return if name.empty?

      @program.uniforms << UniformDecl.new(
        name: name,
        type_name: type_name,
        default_value: default_val,
        hints: hints,
        group: @current_group,
        subgroup: @current_subgroup,
        qualifier: qualifier,
        array_size: array_size,
        is_var_array: is_var_array
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
      name = node.args.first?.try(&.to_s) || "Buffer"
      instance_name = name.underscore
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
      name = node.args.first?.try(&.to_s) || "PushConstants"
      instance_name = name.underscore

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
        # e.g. hint_range(0.0, 1.0)
        args_str = node.args.map { |a| node_to_string_or_sym(a) }.join(", ")
        "#{node.name}(#{args_str})"
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
      when /^hint_/
        raw_hint
      else
        raw_hint
      end
    end
  end
end
