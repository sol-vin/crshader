require "../base"
require "../symbol_table"
require "../../ast/shader_ast"

module CrShader
  class GDShaderEmitter < BaseVisitor
    getter program : ShaderProgram

    def initialize(
      io : IO,
      @program : ShaderProgram,
      symbol_table : SymbolTable = SymbolTable.new(ShaderTarget::GDShader),
      target : ShaderTarget = ShaderTarget::GDShader,
    )
      super(io, target, symbol_table)
      register_known_symbols
    end

    private def register_known_symbols
      @program.external_structs.each_value do |st|
        @symbol_table.register_struct(st.name, st.fields.map { |f| {f.name, f.type_name} })
      end
      @program.structs.each_value do |st|
        @symbol_table.register_struct(st.name, st.fields.map { |f| {f.name, f.type_name} })
      end
      @program.external_constants.each do |cname, ctype|
        @symbol_table.register_global(cname, ctype)
      end
      @program.external_functions.each do |fname, fret|
        @symbol_table.register_function(fname, TypeInfo.resolve(fret, @target))
      end
      @program.functions.each do |name, def_node|
        if rt = def_node.return_type
          @symbol_table.register_function(name, TypeInfo.resolve(rt.to_s, @target))
        end
      end
    end

    def emit(
      helper_functions : Array(Crystal::Def) = [] of Crystal::Def,
      reachable_identifiers : Set(String)? = nil,
    )
      helper_functions.each do |h|
        if rt = h.return_type
          @symbol_table.register_function(h.name, TypeInfo.resolve(rt.to_s, @target))
        end
      end
      emit_header
      emit_render_modes
      emit_preprocessor
      emit_default_precisions
      emit_constants(reachable_identifiers)
      emit_structs(reachable_identifiers)
      emit_uniforms
      emit_varyings
      emit_helpers(helper_functions)
      emit_shader_stages
    end

    protected def emit_header
      st = @program.shader_type.to_gdshader_keyword
      @io << "shader_type #{st};\n\n"
    end

    protected def emit_preprocessor
      has_content = false
      unless @program.preprocessor_lines.empty?
        @program.preprocessor_lines.each do |line|
          @io << line << "\n"
        end
        has_content = true
      end

      unless @program.includes.empty?
        @program.includes.each do |inc|
          @io << "#include \"#{inc}\"\n" unless @program.preprocessor_lines.any?(&.includes?("\"#{(inc)}\""))
        end
        has_content = true
      end

      @io << "\n" if has_content
    end

    protected def emit_default_precisions
      return if @program.default_precisions.empty?
      @program.default_precisions.each do |typ, prec|
        resolved_type = TypeInfo.resolve(typ, @target)
        @io << "precision #{prec} #{resolved_type};\n"
      end
      @io << "\n"
    end

    protected def emit_render_modes
      return if @program.render_modes.empty?
      @io << "render_mode " << @program.render_modes.join(", ") << ";\n\n"
    end

    protected def emit_constants(reachable_identifiers : Set(String)? = nil)
      return if @program.constants.empty?
      emitted_any = false
      @program.constants.each do |c|
        if @program.imported_constants.includes?(c.name) && reachable_identifiers && !reachable_identifiers.includes?(c.name)
          next
        end
        emitted_any = true
        if c.value.is_a?(Crystal::ArrayLiteral)
          arr = c.value.as(Crystal::ArrayLiteral)
          elem_type = if (arr_of = arr.of)
                        TypeInfo.resolve(arr_of.to_s, @target)
                      elsif c.type_name
                        TypeInfo.resolve(c.type_name.not_nil!, @target)
                      elsif (first = arr.elements.first?)
                        TypeInfo.resolve(@symbol_table.infer_type(first), @target)
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
          resolved_type = TypeInfo.resolve(val_type, @target)
          @symbol_table.register_global(c.name, resolved_type)
          @io << "const #{resolved_type} #{c.name} = "
          c.value.accept(self)
          @io << ";\n"
        end
      end
      @io << "\n" if emitted_any
    end

    protected def emit_structs(reachable_identifiers : Set(String)? = nil)
      return if @program.structs.empty?
      @program.structs.each_value do |st|
        if @program.imported_structs.includes?(st.name) && reachable_identifiers && !reachable_identifiers.includes?(st.name)
          next
        end
        @io << "struct #{st.name} {\n"
        st.fields.each do |f|
          ftype = TypeInfo.resolve(f.type_name, @target)
          @io << "\t#{ftype} #{f.name};\n"
        end
        @io << "};\n\n"
      end
    end

    private def sanitize_group_ident(raw : String) : String
      cleaned = raw.strip.gsub(/[^a-zA-Z0-9_]/, "_").gsub(/_+/, "_").gsub(/^_+|_+$/, "")
      cleaned = "Group" if cleaned.empty?
      cleaned =~ /^[0-9]/ ? "_#{cleaned}" : cleaned
    end

    protected def emit_uniforms(close_trailing_group : Bool = true)
      return if @program.uniforms.empty?

      current_grp : String? = nil
      current_subgrp : String? = nil

      @program.uniforms.each do |u|
        u_grp = u.group.try { |g| sanitize_group_ident(g) }
        u_sub = u.subgroup.try { |s| sanitize_group_ident(s) }
        if u_grp != current_grp || u_sub != current_subgrp
          if u_grp.nil? && u_sub.nil?
            if !current_grp.nil? || !current_subgrp.nil?
              @io << "group_uniforms;\n"
            end
          else
            if u_grp && u_grp != current_grp
              @io << "group_uniforms #{u_grp};\n"
            end
            if u_sub
              if u_grp
                @io << "group_uniforms #{u_grp}.#{u_sub};\n"
              else
                @io << "group_uniforms #{u_sub};\n"
              end
            elsif u_grp == current_grp && !current_subgrp.nil? && u_grp
              # Transitioning from Group.Subgroup back to parent Group
              @io << "group_uniforms #{u_grp};\n"
            end
          end
          current_grp = u_grp
          current_subgrp = u_sub
        end

        if doc = u.doc_comment
          @io << "/** #{doc.gsub("*/", "* /")} */\n"
        end

        qual_prefix = case u.qualifier
                      when UniformQualifier::Instance then "instance uniform"
                      when UniformQualifier::Global   then "global uniform"
                      else                                 "uniform"
                      end

        if u.is_var_array
          array_len = u.array_size || "16"
          @io << "const int #{u.name}_size = #{array_len};\n"
          @symbol_table.register_global("#{u.name}_size", "int")
        end

        utype = TypeInfo.resolve(u.type_name, @target)
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

      if close_trailing_group && (!current_grp.nil? || !current_subgrp.nil?)
        @io << "group_uniforms;\n"
      end
      @io << "\n"
    end

    protected def emit_varyings
      return if @program.varyings.empty?
      @program.varyings.each do |v|
        vtype = TypeInfo.resolve(v.type_name, @target)
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

    protected def emit_helpers(helpers : Array(Crystal::Def))
      helpers.each do |h|
        skey = "#{h.name}/#{h.args.size}"
        next if @emitted_functions.includes?(skey)
        emit_function(h)
        @emitted_functions.add(skey)
      end
    end

    ALL_STAGES = ["vertex", "fragment", "light", "start", "process", "collide", "sky", "fog"]

    protected def emit_shader_stages
      # Only emit unreferenced non-imported functions when no stage entry point exists
      has_stage_entry = ALL_STAGES.any? { |s| @program.functions.has_key?(s) }
      unless has_stage_entry
        @program.functions.each do |name, def_node|
          next if ALL_STAGES.includes?(name) || name == "main"
          next if @program.imported_functions.includes?(name)
          skey = "#{name}/#{def_node.args.size}"
          next if @emitted_functions.includes?(skey)
          emit_function(def_node)
          @emitted_functions.add(skey)
        end
      end

      ALL_STAGES.each do |stage_name|
        if def_node = @program.functions[stage_name]?
          emit_function(def_node, is_stage: true)
          @emitted_functions.add(stage_name)
        end
      end
    end

    protected def emit_function(def_node : Crystal::Def, is_stage : Bool = false)
      @symbol_table.enter_function
      self.in_processor_function = is_stage
      self.current_function_name = def_node.name

      ret_type = if is_stage
                   "void"
                 elsif ret_type_node = def_node.return_type
                   TypeInfo.resolve(ret_type_node.to_s, @target)
                 else
                   "void"
                 end

      @io << "#{ret_type} #{def_node.name}("
      def_node.args.each_with_index do |arg, idx|
        @io << ", " if idx > 0
        arg_type = arg.restriction ? TypeInfo.resolve(arg.restriction.to_s, @target) : "float"
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
