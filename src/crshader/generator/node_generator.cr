require "../ast/shader_ast"
require "../parser/dsl_parser"

module CrShader
  # =============================================================================
  # NodeGenerator - DSL-Driven Godot 4 Node Class Synthesizer
  # =============================================================================
  # Analyzes any .crshader uniform declarations and emits a complete, typed Crystal
  # Godot node class (MeshInstance3D, CanvasLayer, or CompositorEffect) with @[Export]
  # properties, ranges, enums, ColorPalette support, and live parameter forwarding.
  class NodeGenerator
    enum NodeType
      ScreenSpaceMesh
      ScreenSpaceCanvas
      CompositorEffect
      MaterialHost
    end

    def self.generate_from_source(
      source : String,
      node_type : NodeType,
      class_name : String,
      shader_path : String = ""
    ) : String
      parser = DslParser.new
      program = parser.parse(source)
      generate(program, node_type, class_name, shader_path)
    end

    def self.generate_from_file(
      file_path : String,
      node_type : NodeType,
      class_name : String
    ) : String
      source = File.read(file_path)
      generate_from_source(source, node_type, class_name, file_path)
    end

    def self.generate(
      program : ShaderProgram,
      node_type : NodeType,
      class_name : String,
      shader_path : String = ""
    ) : String
      base_class = case node_type
                   when NodeType::ScreenSpaceMesh   then "MeshInstance3D"
                   when NodeType::ScreenSpaceCanvas then "CanvasLayer"
                   when NodeType::CompositorEffect  then "CompositorEffect"
                   when NodeType::MaterialHost      then "Node"
                   end

      io = IO::Memory.new
      io.puts "# ============================================================================="
      io.puts "# Auto-Generated Godot Node: #{class_name} < #{base_class}"
      io.puts "# Synthesized directly from CRShader DSL by CrShader::NodeGenerator"
      io.puts "# ============================================================================="
      io.puts "require \"lapis\""
      io.puts ""
      io.puts "module CrShader"
      io.puts "  include Godot"
      io.puts ""
      io.puts "  @[Tool]"
      io.puts "  node #{class_name} < #{base_class} do"

      # 1. Emit Exported Properties from Uniforms
      emit_properties(io, program.uniforms)

      # 2. Emit Lifecycle & Setup
      case node_type
      when NodeType::ScreenSpaceMesh
        emit_screenspace_mesh_lifecycle(io, shader_path)
      when NodeType::ScreenSpaceCanvas
        emit_screenspace_canvas_lifecycle(io, shader_path)
      when NodeType::CompositorEffect
        emit_compositor_effect_lifecycle(io, shader_path)
      when NodeType::MaterialHost
        emit_material_host_lifecycle(io, shader_path)
      end

      # 3. Emit Parameter Forwarding
      emit_parameter_forwarding(io, program.uniforms, node_type)

      io.puts "  end"
      io.puts "end"
      io.to_s
    end

    private def self.emit_properties(io : IO, uniforms : Array(UniformDecl)) : Void
      uniforms.each do |u|
        # Detect ColorPalette uniforms (arrays of colors or resource references)
        if u.is_packed_array || u.resource_path || u.is_var_array || (u.type_name == "Color" && u.array_size)
          io.puts "    # Color Palette Resource"
          io.puts "    @[Export]"
          io.puts "    property #{u.name} : Godot::ColorPalette? = nil"
          io.puts ""
          next
        end

        export_annotation = parse_export_annotation(u)
        crystal_type, default_val = parse_property_type(u)

        if export_annotation
          io.puts "    #{export_annotation}"
        else
          io.puts "    @[Export]"
        end
        io.puts "    property #{u.name} : #{crystal_type} = #{default_val}"
        io.puts ""
      end
    end

    private def self.parse_export_annotation(u : UniformDecl) : String?
      u.hints.each do |h|
        if m = h.match(/hint_range\(\s*([-\d.]+)\s*,\s*([-\d.]+)(?:\s*,\s*([-\d.]+))?\s*\)/)
          min_val = m[1]
          max_val = m[2]
          step_val = m[3]?
          if step_val
            return "@[Export(range: #{min_val}_f32..#{max_val}_f32, step: #{step_val}_f32)]"
          else
            return "@[Export(range: #{min_val}_f32..#{max_val}_f32)]"
          end
        elsif m = h.match(/hint_enum\((.+)\)/)
          return "@[ExportEnum(#{m[1]})]"
        end
      end
      nil
    end

    private def self.parse_property_type(u : UniformDecl) : Tuple(String, String)
      case u.type_name.downcase
      when "float", "float32"
        def_v = u.default_value.try(&.to_s) || "0.0"
        def_v = "#{def_v}_f32" unless def_v.includes?("_f32")
        {"Float32", def_v}
      when "int", "int32"
        def_v = u.default_value.try(&.to_s) || "0"
        {"Int32", def_v}
      when "bool"
        def_v = u.default_value.try(&.to_s) || "false"
        {"Bool", def_v}
      when "color", "vec4"
        {"Color", "Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)"}
      when "texture2d", "sampler2d"
        {"Godot::Texture2D?", "nil"}
      else
        {"Float32", "0.0_f32"}
      end
    end

    private def self.emit_screenspace_mesh_lifecycle(io : IO, shader_path : String) : Void
      io.puts <<-LIFECYCLE
    def _ready : Void
      setup_screenspace_mesh
    end

    def setup_screenspace_mesh : Void
      curr_mesh = call_obj("get_mesh")
      if curr_mesh.nil? || curr_mesh.pointer.null?
        quad = Godot.create(Godot::QuadMesh)
        if quad
          quad.call("set_size", Vector2.new(2.0_f32, 2.0_f32))
          call("set_mesh", quad)
        end
      end
      call("set_extra_cull_margin", 16384.0_f32)
      apply_parameters
    end
LIFECYCLE
    end

    private def self.emit_screenspace_canvas_lifecycle(io : IO, shader_path : String) : Void
      io.puts <<-LIFECYCLE
    @color_rect : Godot::ColorRect? = nil

    def _ready : Void
      call("set_layer", 128) if call_int("get_layer") == 1
      setup_canvas_rect
    end

    def setup_canvas_rect : Void
      rect = @color_rect
      if rect.nil? || rect.pointer.null?
        new_rect = Godot.create(Godot::ColorRect)
        if new_rect
          new_rect.call("set_name", "ScreenColorRect")
          new_rect.call("set_anchors_preset", 15)
          new_rect.call("set_mouse_filter", 2)
          call("add_child", new_rect)
          @color_rect = new_rect
        end
      end
      apply_parameters
    end
LIFECYCLE
    end

    private def self.emit_compositor_effect_lifecycle(io : IO, shader_path : String) : Void
      io.puts <<-LIFECYCLE
    def _ready : Void
      call("set_access_resolved_color", true)
      call("set_access_resolved_depth", true)
      call("set_effect_callback_type", 4)
    end
LIFECYCLE
    end

    private def self.emit_material_host_lifecycle(io : IO, shader_path : String) : Void
      io.puts <<-LIFECYCLE
    def _ready : Void
      apply_parameters
    end
LIFECYCLE
    end

    private def self.emit_parameter_forwarding(io : IO, uniforms : Array(UniformDecl), node_type : NodeType) : Void
      return if node_type == NodeType::CompositorEffect

      mat_getter = case node_type
                   when NodeType::ScreenSpaceMesh
                     "mat = call_obj(\"get_material_override\"); if mat.nil? || mat.pointer.null?; mat = Godot.create(Godot::ShaderMaterial); call(\"set_material_override\", mat) if mat; end"
                   when NodeType::ScreenSpaceCanvas
                     "rect = @color_rect; return unless rect && !rect.pointer.null?; mat = rect.call_obj(\"get_material\"); if mat.nil? || mat.pointer.null?; mat = Godot.create(Godot::ShaderMaterial); rect.call(\"set_material\", mat) if mat; end"
                   else
                     "mat = call_obj(\"get_material\"); if mat.nil? || mat.pointer.null?; mat = Godot.create(Godot::ShaderMaterial); call(\"set_material\", mat) if mat; end"
                   end

      io.puts ""
      io.puts "    def apply_parameters : Void"
      io.puts "      #{mat_getter}"
      io.puts "      return unless mat && !mat.pointer.null?"
      io.puts ""

      uniforms.each do |u|
        if u.is_packed_array || u.resource_path || u.is_var_array || (u.type_name == "Color" && u.array_size)
          io.puts "      if pal = @#{u.name}"
          io.puts "        colors = pal.call(\"get_colors\")"
          io.puts "        mat.call(\"set_shader_parameter\", \"#{u.name}\", colors)"
          io.puts "      end"
        else
          io.puts "      mat.call(\"set_shader_parameter\", \"#{u.name}\", @#{u.name})"
        end
      end
      io.puts "    end"
    end
  end
end
