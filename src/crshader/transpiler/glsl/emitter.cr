require "../base"
require "../symbol_table"
require "../../ast/shader_ast"
require "./layout_packer"

module CrShader
  class GLSLEmitter < BaseVisitor
    getter program : ShaderProgram

    SCENE_DATA_BUILTINS = Set{
      "INV_PROJECTION_MATRIX", "PROJECTION_MATRIX",
      "INV_VIEW_MATRIX", "VIEW_MATRIX",
      "VIEWPORT_SIZE", "TIME",
    }

    property godot_compute_header : Bool = false

    def initialize(
      io : IO,
      @program : ShaderProgram,
      symbol_table : SymbolTable = SymbolTable.new(ShaderTarget::GLSL),
      @godot_compute_header : Bool = false,
    )
      super(io, ShaderTarget::GLSL, symbol_table)
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
        @symbol_table.register_function(fname, TypeInfo.resolve(fret, ShaderTarget::GLSL))
      end
      @program.functions.each do |name, def_node|
        if rt = def_node.return_type
          @symbol_table.register_function(name, TypeInfo.resolve(rt.to_s, ShaderTarget::GLSL))
        end
      end
    end

    def emit(
      helper_functions : Array(Crystal::Def) = [] of Crystal::Def,
      reachable_identifiers : Set(String)? = nil,
    )
      helper_functions.each do |h|
        if rt = h.return_type
          @symbol_table.register_function(h.name, TypeInfo.resolve(rt.to_s, ShaderTarget::GLSL))
        end
      end
      emit_header
      emit_layout
      emit_constants(reachable_identifiers)
      emit_structs(reachable_identifiers)
      emit_scene_data_ubo(reachable_identifiers)
      emit_buffers
      emit_push_constants
      emit_shared_memories
      emit_images
      emit_uniforms
      emit_helpers(helper_functions)
      emit_main
    end

    private def emit_header
      @io << "#[compute]\n" if @godot_compute_header
      @io << "#version 450\n\n"
    end

    private def emit_layout
      layout = @program.compute_layout
      @io << "layout(local_size_x = #{layout.x}, local_size_y = #{layout.y}, local_size_z = #{layout.z}) in;\n\n"
    end

    private def emit_constants(reachable_identifiers : Set(String)? = nil)
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
      @io << "\n" if emitted_any
    end

    private def emit_structs(reachable_identifiers : Set(String)? = nil)
      return if @program.structs.empty?
      @program.structs.each_value do |st|
        if @program.imported_structs.includes?(st.name) && reachable_identifiers && !reachable_identifiers.includes?(st.name)
          next
        end
        @io << "struct #{st.name} {\n"
        st.fields.each do |f|
          ftype = TypeInfo.resolve(f.type_name, ShaderTarget::GLSL)
          @io << "\t#{ftype} #{f.name};\n"
        end
        @io << "};\n\n"
      end
    end

    private def emit_scene_data_ubo(reachable_identifiers : Set(String)? = nil)
      needs_scene = @program.compositor_access_scene_data ||
                    (@program.is_compositor && reachable_identifiers.try { |ids| SCENE_DATA_BUILTINS.any? { |b| ids.includes?(b) } })
      return unless needs_scene

      @program.compositor_access_scene_data = true
      @symbol_table.register_global("INV_PROJECTION_MATRIX", "mat4")
      @symbol_table.register_global("PROJECTION_MATRIX", "mat4")
      @symbol_table.register_global("INV_VIEW_MATRIX", "mat4")
      @symbol_table.register_global("VIEW_MATRIX", "mat4")
      @symbol_table.register_global("VIEWPORT_SIZE", "vec2")
      @symbol_table.register_global("TIME", "float")

      @io << "layout(set = 0, binding = 3, std140) uniform CrShaderSceneData {\n"
      @io << "\tmat4 INV_PROJECTION_MATRIX;\n"
      @io << "\tmat4 PROJECTION_MATRIX;\n"
      @io << "\tmat4 INV_VIEW_MATRIX;\n"
      @io << "\tmat4 VIEW_MATRIX;\n"
      @io << "\tvec2 VIEWPORT_SIZE;\n"
      @io << "\tfloat TIME;\n"
      @io << "\tfloat _crshader_scene_pad0;\n"
      @io << "};\n\n"
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
            @symbol_table.register_global("#{b.instance_name}.#{f.name}", "#{ftype}#{size_str}")
          else
            @io << "\t#{ftype} #{f.name};\n"
            @symbol_table.register_global("#{b.instance_name}.#{f.name}", ftype)
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
            @symbol_table.register_global("#{pc.instance_name}.#{f.name}", "#{ftype}#{size_str}")
          else
            @io << "\t#{ftype} #{f.name};\n"
            @symbol_table.register_global("#{pc.instance_name}.#{f.name}", ftype)
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
        @symbol_table.register_global(sm.name, "#{stype}[#{sm.size}]")
        @io << "shared #{stype} #{sm.name}[#{sm.size}];\n"
      end
      @io << "\n"
    end

    private def emit_images
      return if @program.images.empty?
      @program.images.each do |img|
        @symbol_table.register_global(img.name, img.image_type)
        modifier = ""
        modifier += "writeonly " if img.writeonly
        modifier += "readonly " if img.readonly
        modifier += "restrict " if img.restrict
        @io << "layout(#{img.format}, set = #{img.set}, binding = #{img.binding}) uniform #{modifier}#{img.image_type} #{img.name};\n"
      end
      @io << "\n"
    end

    private def emit_uniforms
      return if @program.uniforms.empty?

      opaques, values = GLSLLayoutPacker.split_uniforms(@program.uniforms)

      # 1. Emit opaque sampler / image uniforms
      used_set0_bindings = Set(Int32).new
      @program.images.each { |img| used_set0_bindings.add(img.binding) if img.set == 0 }
      @program.buffers.each { |buf| used_set0_bindings.add(buf.binding) if buf.set == 0 }
      used_set0_bindings.add(3) if @program.compositor_access_scene_data

      next_opaque_binding = 0
      opaques.each do |u|
        utype = TypeInfo.resolve(u.type_name, ShaderTarget::GLSL)
        set_idx = u.set || 0
        bind_idx = if explicit_b = u.binding
                     explicit_b
                   else
                     while set_idx == 0 && used_set0_bindings.includes?(next_opaque_binding)
                       next_opaque_binding += 1
                     end
                     b = next_opaque_binding
                     next_opaque_binding += 1
                     b
                   end
        used_set0_bindings.add(bind_idx) if set_idx == 0
        @symbol_table.register_global(u.name, utype)
        @io << "layout(set = #{set_idx}, binding = #{bind_idx}) uniform #{utype} #{u.name};\n"
      end
      @io << "\n" unless opaques.empty?

      return if values.empty?

      # 2. Emit array size constants for variable-size arrays
      values.each do |u|
        if u.is_var_array
          @io << "const int #{u.name}_size = #{u.array_size || "16"};\n"
          @symbol_table.register_global("#{u.name}_size", "int")
        end
      end

      # 3. Pack scalar/vector/array uniforms into Vulkan-valid push_constant or std140 UBO block
      packed = GLSLLayoutPacker.compute_layout(@program)
      case packed.kind
      when GLSLLayoutPacker::PackingKind::PushConstant
        @io << "layout(push_constant, std430) uniform CrShaderParams {\n"
      when GLSLLayoutPacker::PackingKind::UniformBuffer
        @io << "layout(set = 1, binding = 0, std140) uniform CrShaderUniforms {\n"
      else
        return
      end

      values.each do |u|
        utype = TypeInfo.resolve(u.type_name, ShaderTarget::GLSL)
        array_str = u.array_size ? "[#{u.array_size}]" : ""
        @symbol_table.register_global(u.name, "#{utype}#{array_str}")
        @io << "\t#{utype} #{u.name}#{array_str};\n"
      end
      @io << "};\n\n"
    end

    property emitted_functions : Set(String) = Set(String).new

    private def emit_helpers(helpers : Array(Crystal::Def))
      helpers.each do |h|
        skey = "#{h.name}/#{h.args.size}"
        next if @emitted_functions.includes?(skey)
        emit_function(h)
        @emitted_functions.add(skey)
      end

      # Only emit unreferenced non-imported functions when no main entry point exists
      unless @program.functions.has_key?("main")
        @program.functions.each do |name, def_node|
          next if name == "main"
          next if @program.imported_functions.includes?(name)
          skey = "#{name}/#{def_node.args.size}"
          next if @emitted_functions.includes?(skey)
          emit_function(def_node)
          @emitted_functions.add(skey)
        end
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
