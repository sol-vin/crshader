require "../base"
require "../symbol_table"
require "../../ast/shader_ast"

module CrShader
  class GLSLEmitter < BaseVisitor
    getter program : ShaderProgram

    def initialize(io : IO, @program : ShaderProgram, symbol_table : SymbolTable = SymbolTable.new(ShaderTarget::GLSL))
      super(io, ShaderTarget::GLSL, symbol_table)
      register_known_functions
    end

    private def register_known_functions
      @program.functions.each do |name, def_node|
        if rt = def_node.return_type
          @symbol_table.register_function(name, TypeInfo.resolve(rt.to_s, ShaderTarget::GLSL))
        end
      end
    end

    def emit(helper_functions : Array(Crystal::Def) = [] of Crystal::Def)
      helper_functions.each do |h|
        if rt = h.return_type
          @symbol_table.register_function(h.name, TypeInfo.resolve(rt.to_s, ShaderTarget::GLSL))
        end
      end
      emit_header
      emit_layout
      emit_constants
      emit_structs
      emit_buffers
      emit_push_constants
      emit_shared_memories
      emit_images
      emit_uniforms
      emit_helpers(helper_functions)
      emit_main
    end

    private def emit_header
      @io << "#version 450\n\n"
    end

    private def emit_layout
      layout = @program.compute_layout
      @io << "layout(local_size_x = #{layout.x}, local_size_y = #{layout.y}, local_size_z = #{layout.z}) in;\n\n"
    end

    private def emit_constants
      return if @program.constants.empty?
      @program.constants.each do |c|
        if c.value.is_a?(Crystal::ArrayLiteral)
          arr = c.value.as(Crystal::ArrayLiteral)
          elem_type = if (arr_of = arr.of)
                        TypeInfo.resolve(arr_of.to_s, ShaderTarget::GLSL)
                      elsif c.type_name
                        TypeInfo.resolve(c.type_name.not_nil!, ShaderTarget::GLSL)
                      elsif (first = arr.elements.first?)
                        TypeInfo.resolve(@symbol_table.infer_type(first), ShaderTarget::GLSL)
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
          resolved_type = TypeInfo.resolve(val_type, ShaderTarget::GLSL)
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
          ftype = TypeInfo.resolve(f.type_name, ShaderTarget::GLSL)
          @io << "\t#{ftype} #{f.name};\n"
        end
        @io << "};\n\n"
      end
    end

    private def emit_buffers
      return if @program.buffers.empty?
      @program.buffers.each do |b|
        qualifiers = [] of String
        qualifiers << "set = #{b.set}"
        qualifiers << "binding = #{b.binding}"
        qualifiers << b.std

        qual_str = qualifiers.join(", ")
        modifier = ""
        modifier += "readonly " if b.readonly
        modifier += "restrict " if b.restrict

        @io << "layout(#{qual_str}) #{modifier}buffer #{b.name} {\n"
        b.fields.each do |f|
          ftype = TypeInfo.resolve(f.type_name, ShaderTarget::GLSL)
          if f.is_array
            size_str = f.array_size ? "[#{f.array_size}]" : "[]"
            @io << "\t#{ftype} #{f.name}#{size_str};\n"
          else
            @io << "\t#{ftype} #{f.name};\n"
          end
        end
        @io << "} #{b.instance_name};\n\n"

        @symbol_table.register_global(b.instance_name, b.name)
      end
    end

    private def emit_push_constants
      return if @program.push_constants.empty?
      @program.push_constants.each do |pc|
        @io << "layout(push_constant, std430) uniform #{pc.name} {\n"
        pc.fields.each do |f|
          ftype = TypeInfo.resolve(f.type_name, ShaderTarget::GLSL)
          if f.is_array
            size_str = f.array_size ? "[#{f.array_size}]" : "[]"
            @io << "\t#{ftype} #{f.name}#{size_str};\n"
          else
            @io << "\t#{ftype} #{f.name};\n"
          end
        end
        @io << "} #{pc.instance_name};\n\n"

        @symbol_table.register_global(pc.instance_name, pc.name)
      end
    end

    private def emit_shared_memories
      return if @program.shared_memories.empty?
      @program.shared_memories.each do |sm|
        stype = TypeInfo.resolve(sm.type_name, ShaderTarget::GLSL)
        @symbol_table.register_global(sm.name, stype)
        @io << "shared #{stype} #{sm.name}[#{sm.size}];\n"
      end
      @io << "\n"
    end

    private def emit_images
      return if @program.images.empty?
      @program.images.each do |img|
        @symbol_table.register_global(img.name, img.image_type)
        @io << "layout(#{img.format}, set = #{img.set}, binding = #{img.binding}) uniform #{img.image_type} #{img.name};\n"
      end
      @io << "\n"
    end

    private def emit_uniforms
      return if @program.uniforms.empty?
      @program.uniforms.each_with_index do |u, idx|
        if u.is_var_array
          @io << "const int #{u.name}_size = #{u.array_size};\n"
          @symbol_table.register_global("#{u.name}_size", "int")
        end
        utype = TypeInfo.resolve(u.type_name, ShaderTarget::GLSL)
        array_str = u.array_size ? "[#{u.array_size}]" : ""
        @symbol_table.register_global(u.name, "#{utype}#{array_str}")
        @io << "layout(set = 1, binding = #{idx}) uniform #{utype} #{u.name}#{array_str};\n"
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

      # Emit any user-defined non-main functions
      @program.functions.each do |name, def_node|
        next if name == "main"
        next if @emitted_functions.includes?(name)
        emit_function(def_node)
        @emitted_functions.add(name)
      end
    end

    private def emit_main
      if main_def = @program.functions["main"]?
        emit_function(main_def, is_main: true)
      else
        # If no main defined, emit an empty main
        @io << "void main() {\n}\n"
      end
    end

    private def emit_function(def_node : Crystal::Def, is_main : Bool = false)
      @symbol_table.enter_function

      ret_type = if is_main
                   "void"
                 elsif ret_type_node = def_node.return_type
                   TypeInfo.resolve(ret_type_node.to_s, ShaderTarget::GLSL)
                 else
                   "void"
                 end

      @io << "#{ret_type} #{def_node.name}("
      def_node.args.each_with_index do |arg, idx|
        @io << ", " if idx > 0
        arg_type = arg.restriction ? TypeInfo.resolve(arg.restriction.to_s, ShaderTarget::GLSL) : "float"
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
    end
  end
end
