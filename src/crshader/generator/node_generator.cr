require "../ast/shader_ast"
require "../parser/dsl_parser"
require "../compiler"
require "../transpiler/glsl/layout_packer"

module CrShader
  # =============================================================================
  # NodeGenerator - DSL-Driven Godot 4 Node & CompositorEffect Class Synthesizer
  # =============================================================================
  # Analyzes any .crshader uniform declarations and emits a complete, typed Crystal
  # Godot class (MeshInstance3D, CanvasLayer, CompositorEffect, or Node3D) with
  # @[Export] properties, harvested doc comments, ranges, enums, ColorPalette support,
  # and live parameter forwarding (including std430/std140 GPU packing for CompositorEffect).
  class NodeGenerator
    enum NodeType
      ScreenSpaceMesh
      ScreenSpaceCanvas
      CompositorEffect
      ComputeParticles
      MaterialHost
    end

    def self.generate_from_source(
      source : String,
      node_type : NodeType,
      class_name : String,
      shader_path : String = "",
    ) : String
      target = (node_type == NodeType::CompositorEffect || node_type == NodeType::ComputeParticles) ? ShaderTarget::GLSL : ShaderTarget::GDShader
      parser = DslParser.new(default_target: target, force_target: true)
      program = parser.parse(source)
      generate(program, node_type, class_name, shader_path, source)
    end

    def self.generate_from_file(
      file_path : String,
      node_type : NodeType,
      class_name : String,
    ) : String
      source = File.read(file_path)
      generate_from_source(source, node_type, class_name, file_path)
    end

    def self.generate(
      program : ShaderProgram,
      node_type : NodeType,
      class_name : String,
      shader_path : String = "",
      raw_source : String? = nil,
    ) : String
      base_class = case node_type
                   when NodeType::ScreenSpaceMesh   then "MeshInstance3D"
                   when NodeType::ScreenSpaceCanvas then "CanvasLayer"
                   when NodeType::CompositorEffect  then "CompositorEffect"
                   when NodeType::ComputeParticles  then "Node3D"
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

      # 1. Emit Exported Properties from Uniforms (excluding internal compositor opaque samplers)
      emit_properties(io, program.uniforms, node_type)

      # 2. Emit Lifecycle & Execution Pipeline
      case node_type
      when NodeType::ScreenSpaceMesh
        emit_screenspace_mesh_lifecycle(io, shader_path)
      when NodeType::ScreenSpaceCanvas
        emit_screenspace_canvas_lifecycle(io, shader_path)
      when NodeType::CompositorEffect
        emit_compositor_effect_lifecycle(io, shader_path, program, raw_source)
      when NodeType::ComputeParticles
        emit_compute_particles_lifecycle(io, shader_path, program)
      when NodeType::MaterialHost
        emit_material_host_lifecycle(io, shader_path)
      end

      # 3. Emit Parameter Forwarding
      emit_parameter_forwarding(io, program, node_type)

      io.puts "  end"
      io.puts "end"
      io.to_s
    end

    INTERNAL_COMPOSITOR_SAMPLERS = Set{"depth_texture", "normal_roughness_texture"}

    private def self.emit_properties(io : IO, uniforms : Array(UniformDecl), node_type : NodeType) : Void
      uniforms.each do |u|
        next if node_type == NodeType::CompositorEffect && INTERNAL_COMPOSITOR_SAMPLERS.includes?(u.name)
        next if node_type == NodeType::CompositorEffect && GLSLLayoutPacker.opaque_uniform?(u)

        if doc = u.doc_comment
          io.puts "    # #{doc}"
        end

        # Detect ColorPalette uniforms (arrays of colors or resource references)
        if u.is_packed_array || u.resource_path || u.is_var_array || (u.type_name == "Color" && u.array_size)
          io.puts "    # Color Palette Resource" unless u.doc_comment
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
      is_int = ["int", "int32", "uint", "uint32"].includes?(u.type_name.downcase)
      u.hints.each do |h|
        if m = h.match(/hint_range\(\s*([-\d.]+)\s*,\s*([-\d.]+)(?:\s*,\s*([-\d.]+))?\s*\)/)
          if is_int
            min_i = m[1].to_f64.to_i32
            max_i = m[2].to_f64.to_i32
            step_i = m[3]?.try(&.to_f64.to_i32)
            return step_i ? "@[Export(range: #{min_i}..#{max_i}, step: #{step_i})]" : "@[Export(range: #{min_i}..#{max_i})]"
          else
            min_val = m[1].includes?('.') ? m[1] : "#{m[1]}.0"
            max_val = m[2].includes?('.') ? m[2] : "#{m[2]}.0"
            if step_s = m[3]?
              step_val = step_s.includes?('.') ? step_s : "#{step_s}.0"
              return "@[Export(range: #{min_val}_f32..#{max_val}_f32, step: #{step_val}_f32)]"
            else
              return "@[Export(range: #{min_val}_f32..#{max_val}_f32)]"
            end
          end
        elsif m = h.match(/hint_enum\((.+)\)/)
          return "@[ExportEnum(#{m[1]})]"
        end
      end
      nil
    end

    private def self.parse_property_type(u : UniformDecl) : Tuple(String, String)
      if u.hints.includes?("source_color") || u.hints.includes?("hint_color")
        return {"Color", "Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)"}
      end

      case u.type_name.downcase
      when "float", "float32"
        def_v = u.default_value.try(&.to_s) || "0.0"
        def_v = "#{def_v}.0" unless def_v.includes?('.') || def_v.includes?("_f32")
        def_v = "#{def_v}_f32" unless def_v.includes?("_f32")
        {"Float32", def_v}
      when "int", "int32"
        def_v = u.default_value.try(&.to_s.gsub(/_i32/, "")) || "0"
        {"Int32", def_v.to_i32?.try(&.to_s) || "0"}
      when "uint", "uint32"
        def_v = u.default_value.try(&.to_s.gsub(/_u32|u$/, "")) || "0"
        {"Int32", def_v.to_i32?.try(&.to_s) || "0"}
      when "bool"
        def_v = u.default_value.try(&.to_s) == "true" ? "true" : "false"
        {"Bool", def_v}
      when "color"
        {"Color", "Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)"}
      when "vec2"
        {"Vector2", "Vector2.new(0.0_f32, 0.0_f32)"}
      when "vec3"
        {"Vector3", "Vector3.new(0.0_f32, 0.0_f32, 0.0_f32)"}
      when "vec4"
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
      call("set_layer", 128) if call_i64("get_layer") == 1
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

    private def self.emit_compositor_effect_lifecycle(
      io : IO,
      shader_path : String,
      program : ShaderProgram? = nil,
      raw_source : String? = nil,
    ) : Void
      access_color = program && program.is_compositor ? program.compositor_access_color : true
      access_depth = program && program.is_compositor ? program.compositor_access_depth : true
      access_nr = program && program.is_compositor ? program.compositor_access_normal_roughness : false
      access_scene = program && program.is_compositor ? program.compositor_access_scene_data : false
      stage_num = if program && program.is_compositor
                    case program.compositor_stage
                    when "PostTransparent" then 4
                    when "PreTransparent"  then 3
                    when "PostSky"         then 2
                    when "PostOpaque"      then 1
                    when "PreOpaque"       then 0
                    else                        4
                    end
                  else
                    4
                  end

      glsl_code = if src = raw_source
                    begin
                      Compiler.new(target_override: ShaderTarget::GLSL).compile_source(src, filename: shader_path.empty? ? nil : shader_path)
                    rescue
                      ""
                    end
                  else
                    ""
                  end

      local_x = program ? program.compute_layout.x : 8
      local_y = program ? program.compute_layout.y : 8

      io.puts "    EMBEDDED_GLSL = #{glsl_code.inspect}"
      io.puts ""
      io.puts "    @compute_helper : ComputeHelper? = nil"
      io.puts "    @params_ubo_rid : Int64 = 0_i64"
      io.puts "    @scene_ubo_rid : Int64 = 0_i64" if access_scene
      io.puts "    @start_ticks_usec : Int64 = 0_i64" if access_scene
      io.puts ""
      io.puts "    def initialize(pointer : Void* = Pointer(Void).null)"
      io.puts "      super(pointer)"
      io.puts "      configure_compositor unless @pointer.null?"
      io.puts "    end"
      io.puts ""
      io.puts "    def configure_compositor : Void"
      io.puts "      call(\"set_access_resolved_color\", #{access_color})"
      io.puts "      call(\"set_access_resolved_depth\", #{access_depth})"
      io.puts "      call(\"set_needs_normal_roughness\", #{access_nr})" if access_nr
      io.puts "      call(\"set_effect_callback_type\", #{stage_num})"
      io.puts "    end"
      io.puts ""
      io.puts "    def self._godot_has_virtual_method(method_name : String) : Bool"
      io.puts "      norm = method_name.starts_with?('_') ? method_name : \"_\#{method_name}\""
      io.puts "      return true if norm == \"_render_callback\""
      io.puts "      super"
      io.puts "    end"
      io.puts ""
      io.puts "    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void"
      io.puts "      norm = method_name.starts_with?('_') ? method_name : \"_\#{method_name}\""
      io.puts "      if norm == \"_render_callback\" && !args.null? && !args[0].null? && !args[1].null?"
      io.puts "        cb_type = args[0].as(Int64*).value"
      io.puts "        rd_ptr = args[1].as(Void**).value"
      io.puts "        _render_callback(cb_type, Godot::RenderData.new(rd_ptr)) unless rd_ptr.null?"
      io.puts "        return"
      io.puts "      end"
      io.puts "      super"
      io.puts "    end"
      io.puts ""
      io.puts "    def _render_callback(effect_callback_type : Int64, render_data : Godot::RenderData) : Void"
      io.puts "      return if render_data.pointer.null? || EMBEDDED_GLSL.empty?"
      io.puts "      helper = @compute_helper || (@compute_helper = ComputeHelper.new)"
      io.puts "      if helper.pipeline_rid <= 0"
      io.puts "        helper.compile_glsl(EMBEDDED_GLSL)"
      io.puts "      end"
      io.puts "      return if helper.pipeline_rid <= 0"
      io.puts ""
      io.puts "      buffers_base = render_data.get_render_scene_buffers"
      io.puts "      return if buffers_base.pointer.null?"
      io.puts "      buffers = Godot::RenderSceneBuffersRD.new(buffers_base.pointer)"
      io.puts "      size = buffers.get_internal_size"
      io.puts "      return if size.x <= 0 || size.y <= 0"
      io.puts ""
      io.puts "      apply_parameters(helper)"
      io.puts "      scene_data = render_data.get_render_scene_data" if access_scene
      io.puts "      views = Math.max(buffers.get_view_count, 1_i64)"
      io.puts "      views.times do |view|"
      io.puts "        color_tex = buffers.get_color_layer(view)"
      io.puts "        next if color_tex <= 0"
      io.puts "        helper.bind_image(0, color_tex, set_index: 0)"
      if access_depth
        io.puts "        depth_tex = buffers.get_depth_layer(view)"
        io.puts "        helper.bind_sampler_with_texture(1, depth_tex, linear: false, set_index: 0) if depth_tex > 0"
      end
      if access_nr
        io.puts "        if buffers.has_texture(\"forward_clustered\", \"normal_roughness\")"
        io.puts "          nr_tex = buffers.get_texture_slice(\"forward_clustered\", \"normal_roughness\", view, 0_i64, 1_i64, 1_i64)"
        io.puts "          helper.bind_sampler_with_texture(2, nr_tex, linear: false, set_index: 0) if nr_tex > 0"
        io.puts "        end"
      end
      if access_scene
        io.puts "        if !scene_data.pointer.null?"
        io.puts "          now_u = Time.monotonic.total_microseconds.to_i64"
        io.puts "          @start_ticks_usec = now_u if @start_ticks_usec == 0_i64"
        io.puts "          elapsed = ((now_u - @start_ticks_usec).to_f64 / 1_000_000.0).to_f32"
        io.puts "          sbytes = CRShaderCompositorEffect.build_scene_ubo_bytes(scene_data, view, size, elapsed)"
        io.puts "          @scene_ubo_rid = helper.ensure_uniform_buffer(@scene_ubo_rid, sbytes, binding: 3, set_index: 0)"
        io.puts "        end"
      end
      io.puts "        helper.dispatch(size.x.to_i32, size.y.to_i32, 1, #{local_x}, #{local_y}, 1)"
      io.puts "      end"
      io.puts "    end"
    end

    private def self.emit_compute_particles_lifecycle(io : IO, shader_path : String, program : ShaderProgram? = nil) : Void
      local_x = program ? program.compute_layout.x : 64
      io.puts <<-LIFECYCLE
    @[Export]
    property particle_count : Int32 = 1024

    @[Export]
    property gravity : Vector3 = Vector3.new(0.0_f32, -9.8_f32, 0.0_f32)

    @[Export(range: 0.0_f32..1.0_f32, step: 0.01_f32)]
    property drag : Float32 = 0.05_f32

    @compute_helper : ComputeHelper? = nil
    @particle_buffer_rid : Int64 = 0_i64

    def _ready : Void
      setup_compute_particles
    end

    def setup_compute_particles : Void
      helper = ComputeHelper.new
      @compute_helper = helper
      byte_size = @particle_count * 48
      @particle_buffer_rid = helper.create_storage_buffer(byte_size, binding: 0)
    end

    def _process(delta : Float64) : Void
      if helper = @compute_helper
        helper.dispatch_1d(@particle_count, #{local_x})
      end
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

    private def self.emit_parameter_forwarding(io : IO, program : ShaderProgram, node_type : NodeType) : Void
      return if node_type == NodeType::ComputeParticles

      if node_type == NodeType::CompositorEffect
        emit_compositor_parameter_packing(io, program)
        return
      end

      uniforms = program.uniforms
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

    private def self.emit_compositor_parameter_packing(io : IO, program : ShaderProgram) : Void
      packed = GLSLLayoutPacker.compute_layout(program)
      io.puts ""
      io.puts "    def apply_parameters(helper : ComputeHelper) : Void"
      if packed.kind == GLSLLayoutPacker::PackingKind::None || packed.total_bytes <= 0
        io.puts "    end"
        return
      end

      io.puts "      buf = Bytes.new(#{packed.total_bytes}, 0_u8)"
      io.puts "      base_ptr = buf.to_unsafe"
      packed.fields.each do |slot|
        next if slot.is_array
        case slot.glsl_type
        when "float"
          io.puts "      (base_ptr + #{slot.byte_offset}).as(Float32*).value = @#{slot.name}.to_f32"
        when "int"
          io.puts "      (base_ptr + #{slot.byte_offset}).as(Int32*).value = @#{slot.name}.to_i32"
        when "uint"
          io.puts "      (base_ptr + #{slot.byte_offset}).as(UInt32*).value = @#{slot.name}.to_u32"
        when "bool"
          io.puts "      (base_ptr + #{slot.byte_offset}).as(UInt32*).value = @#{slot.name} ? 1_u32 : 0_u32"
        when "vec2"
          io.puts "      (base_ptr + #{slot.byte_offset}).as(Float32*)[0] = @#{slot.name}.x"
          io.puts "      (base_ptr + #{slot.byte_offset}).as(Float32*)[1] = @#{slot.name}.y"
        when "vec3"
          io.puts "      (base_ptr + #{slot.byte_offset}).as(Float32*)[0] = @#{slot.name}.x"
          io.puts "      (base_ptr + #{slot.byte_offset}).as(Float32*)[1] = @#{slot.name}.y"
          io.puts "      (base_ptr + #{slot.byte_offset}).as(Float32*)[2] = @#{slot.name}.z"
        when "vec4"
          io.puts "      (base_ptr + #{slot.byte_offset}).as(Float32*)[0] = @#{slot.name}.r"
          io.puts "      (base_ptr + #{slot.byte_offset}).as(Float32*)[1] = @#{slot.name}.g"
          io.puts "      (base_ptr + #{slot.byte_offset}).as(Float32*)[2] = @#{slot.name}.b"
          io.puts "      (base_ptr + #{slot.byte_offset}).as(Float32*)[3] = @#{slot.name}.a"
        end
      end

      if packed.kind == GLSLLayoutPacker::PackingKind::PushConstant
        io.puts "      helper.set_push_constant(buf)"
      else
        io.puts "      @params_ubo_rid = helper.ensure_uniform_buffer(@params_ubo_rid, buf, binding: 0, set_index: 1)"
      end
      io.puts "    end"
    end
  end
end
