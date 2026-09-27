require "../base"
require "../symbol_table"
require "../../ast/shader_ast"

module CrShader
  class GDShaderEmitter < BaseVisitor
    getter program : ShaderProgram

    def initialize(io : IO, @program : ShaderProgram, symbol_table : SymbolTable = SymbolTable.new(ShaderTarget::GDShader))
      super(io, ShaderTarget::GDShader, symbol_table)
      register_known_functions
    end

    private def register_known_functions
      @program.functions.each do |name, def_node|
        if rt = def_node.return_type
          @symbol_table.register_function(name, TypeInfo.resolve(rt.to_s, ShaderTarget::GDShader))
        end
      end
    end

    def emit(helper_functions : Array(Crystal::Def) = [] of Crystal::Def)
      helper_functions.each do |h|
        if rt = h.return_type
          @symbol_table.register_function(h.name, TypeInfo.resolve(rt.to_s, ShaderTarget::GDShader))
        end
      end
      emit_header
      emit_preprocessor
      emit_render_modes
      emit_default_precisions
      emit_constants
      emit_structs
      emit_uniforms
      emit_varyings
      emit_helpers(helper_functions)
      emit_shader_stages
    end

    private def emit_header
      st = @program.shader_type.to_gdshader_keyword
      @io << "shader_type #{st};\n\n"
    end

    private def emit_preprocessor
      has_content = false
      unless @program.preprocessor_lines.empty?
        @program.preprocessor_lines.each do |line|
          @io << line << "\n"
        end
        has_content = true
      end

      unless @program.includes.empty?
        @program.includes.each do |inc|
          @io << "#include \"#{inc}\"\n"
        end
        has_content = true
      end

      @io << "\n" if has_content
    end

    private def emit_default_precisions
      return if @program.default_precisions.empty?
      @program.default_precisions.each do |typ, prec|
        resolved_type = TypeInfo.resolve(typ, ShaderTarget::GDShader)
        @io << "precision #{prec} #{resolved_type};\n"
      end
      @io << "\n"
    end

    private def emit_render_modes
      return if @program.render_modes.empty?
      @io << "render_mode " << @program.render_modes.join(", ") << ";\n\n"
    end

    private def emit_constants
      return if @program.constants.empty?
      @program.constants.each do |c|
        if c.value.is_a?(Crystal::ArrayLiteral)
          arr = c.value.as(Crystal::ArrayLiteral)
          elem_type = if (arr_of = arr.of)
                        TypeInfo.resolve(arr_of.to_s, ShaderTarget::GDShader)
                      elsif c.type_name
                        TypeInfo.resolve(c.type_name.not_nil!, ShaderTarget::GDShader)
                      elsif (first = arr.elements.first?)
                        TypeInfo.resolve(@symbol_table.infer_type(first), ShaderTarget::GDShader)
                      else
                        "float"
                      end
          arr_size = arr.elements.size
          @symbol_table.register_global(c.name, "#{elem_type}[#{arr_size}]")
          @io << "const #{elem_type} #{c.name}[#{arr_size}] = "
          c.value.accept(self)
          @io << ";\n"
        else
          val_type = c.type_name || @symbol_table.infer_type(c.value)
          resolved_type = TypeInfo.resolve(val_type, ShaderTarget::GDShader)
          @symbol_table.register_global(c.name, resolved_type)
          @io << "const #{resolved_type} #{c.name} = "
          c.value.accept(self)
          @io << ";\n"
        end
      end
      @io << "\n"
    end

    private def emit_structs
      return if @program.structs.empty?
      @program.structs.each_value do |st|
        @io << "struct #{st.name} {\n"
        st.fields.each do |f|
          ftype = TypeInfo.resolve(f.type_name, ShaderTarget::GDShader)
          @io << "\t#{ftype} #{f.name};\n"
        end
        @io << "};\n\n"
      end
    end

    private def emit_uniforms
      return if @program.uniforms.empty?

      current_grp : String? = nil
      current_subgrp : String? = nil

      @program.uniforms.each do |u|
        # Emit group header if changed
        if u.group && u.group != current_grp
          current_grp = u.group
          @io << "group_uniforms #{current_grp};\n"
        end

        if u.subgroup && u.subgroup != current_subgrp
          current_subgrp = u.subgroup
          @io << "group_uniforms.#{current_subgrp};\n"
        end

        qual_prefix = case u.qualifier
                      when UniformQualifier::Instance then "instance uniform"
                      when UniformQualifier::Global   then "global uniform"
                      else                                "uniform"
                      end

        if u.is_var_array
          array_len = u.array_size || "16"
          @io << "const int #{u.name}_size = #{array_len};\n"
          @symbol_table.register_global("#{u.name}_size", "int")
        end

        utype = TypeInfo.resolve(u.type_name, ShaderTarget::GDShader)
        array_str = u.array_size ? "[#{u.array_size}]" : ""
        @symbol_table.register_global(u.name, "#{utype}#{array_str}")

        prec_str = u.precision ? "#{u.precision} " : ""
        @io << "#{qual_prefix} #{prec_str}#{utype} #{u.name}#{array_str}"
        if !u.hints.empty?
          @io << " : " << u.hints.join(", ")
        end
        if (default_val = u.default_value) && !u.is_var_array && u.array_size.nil?
          @io << " = "
          default_val.accept(self)
        end
        @io << ";\n"
      end
      @io << "\n"
    end

    private def emit_varyings
      return if @program.varyings.empty?
      @program.varyings.each do |v|
        vtype = TypeInfo.resolve(v.type_name, ShaderTarget::GDShader)
        @symbol_table.register_global(v.name, vtype)
        if qual = v.qualifier
          @io << "#{qual} "
        end
        @io << "varying "
        if prec = v.precision
          @io << "#{prec} "
        end
        @io << "#{vtype} #{v.name};\n"
      end
      @io << "\n"
    end

    property emitted_functions : Set(String) = Set(String).new

    private def emit_helpers(helpers : Array(Crystal::Def))
      helpers.each do |h|
        next if @emitted_functions.includes?(h.name)
        emit_function(h)
        @emitted_functions.add(h.name)
      end
    end

    ALL_STAGES = ["vertex", "fragment", "light", "start", "process", "collide", "sky", "fog"]

    private def emit_shader_stages
      # Emit any user-defined non-stage functions that were not in helpers
      @program.functions.each do |name, def_node|
        next if ALL_STAGES.includes?(name)
        next if @emitted_functions.includes?(name)
        emit_function(def_node)
        @emitted_functions.add(name)
      end

      ALL_STAGES.each do |stage_name|
        if def_node = @program.functions[stage_name]?
          emit_function(def_node, is_stage: true)
          @emitted_functions.add(stage_name)
        end
      end
    end

    private def emit_function(def_node : Crystal::Def, is_stage : Bool = false)
      @symbol_table.enter_function
      self.in_processor_function = is_stage
      self.current_function_name = def_node.name

      ret_type = if is_stage
                   "void"
                 elsif ret_type_node = def_node.return_type
                   TypeInfo.resolve(ret_type_node.to_s, ShaderTarget::GDShader)
                 else
                   "void"
                 end

      @io << "#{ret_type} #{def_node.name}("
      def_node.args.each_with_index do |arg, idx|
        @io << ", " if idx > 0
        arg_type = arg.restriction ? TypeInfo.resolve(arg.restriction.to_s, ShaderTarget::GDShader) : "float"
        clean_type = arg_type.sub(/^(inout|out)\s+/, "")
        @symbol_table.register_param(arg.name, clean_type)
        @io << "#{arg_type} #{arg.name}"
      end
      @io << ") {\n"

      @current_return_type = ret_type
      indent do
        emit_block_body(def_node.body, is_function_body: true)
      end
      @current_return_type = nil

      @io << "}\n\n"
      @symbol_table.exit_function
      self.in_processor_function = false
      self.current_function_name = nil
    end
  end
end
