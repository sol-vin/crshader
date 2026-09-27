require "./spec_helper"
require "../src/crshader/compiler"

describe "GDShader & GLSL Full Specification Coverage" do
  compiler = CrShader::Compiler.new

  describe "Preprocessor Directives" do
    it "preserves raw preprocessor directives (#include, #define, #pragma)" do
      source = <<-CRSHADER
        #include "res://custom_inc.gdshaderinc"
        #define MAX_LIGHTS 8
        #pragma unroll

        shader_type :spatial

        fragment do
          albedo = vec3(1.0, 1.0, 1.0)
        end
      CRSHADER

      code = compiler.compile(source)
      code.should contain("#include \"res://custom_inc.gdshaderinc\"")
      code.should contain("#define MAX_LIGHTS 8")
      code.should contain("#pragma unroll")
      code.should contain("shader_type spatial;")
    end

    it "supports DSL preprocessor directives (include, define, undefine, pragma)" do
      source = <<-CRSHADER
        shader_type :spatial

        include "res://blur.gdshaderinc"
        define :BLUR_SAMPLES, 16
        undefine :UNUSED_MACRO
        pragma :unroll

        fragment do
          albedo = vec3(0.0, 0.0, 0.0)
        end
      CRSHADER

      code = compiler.compile(source)
      code.should contain("#include \"res://blur.gdshaderinc\"")
      code.should contain("#define BLUR_SAMPLES 16")
      code.should contain("#undef UNUSED_MACRO")
      code.should contain("#pragma unroll")
    end
  end

  describe "Precision Qualifiers & Default Precision" do
    it "supports global default precision declarations" do
      source = <<-CRSHADER
        shader_type :spatial

        default_precision :highp, :float
        precision :mediump, :int

        fragment do
          albedo = vec3(1.0)
        end
      CRSHADER

      code = compiler.compile(source)
      code.should contain("precision highp float;")
      code.should contain("precision mediump int;")
    end

    it "supports precision qualifiers on uniforms" do
      source = <<-CRSHADER
        shader_type :spatial

        uniform tint : Color, precision: :lowp
        instance_uniform scale_factor : Float32, precision: :highp
        global_uniform wind_vector : Vec3, precision: :mediump

        fragment do
          albedo = tint.rgb
        end
      CRSHADER

      code = compiler.compile(source)
      code.should contain("uniform lowp vec4 tint;")
      code.should contain("instance uniform highp float scale_factor;")
      code.should contain("global uniform mediump vec3 wind_vector;")
    end

    it "supports canonical Godot 4 varying interpolation and precision qualifiers" do
      source = <<-CRSHADER
        shader_type :spatial

        varying v_normal : Vec3, precision: :highp
        flat_varying v_cluster_id : Int32, precision: :mediump
        smooth_varying v_uv : Vec2, precision: :highp

        vertex do
          v_normal = NORMAL
          v_cluster_id = 42
          v_uv = UV
        end

        fragment do
          albedo = v_normal
        end
      CRSHADER

      code = compiler.compile(source)
      code.should contain("varying highp vec3 v_normal;")
      code.should contain("flat varying mediump int v_cluster_id;")
      code.should contain("smooth varying highp vec2 v_uv;")
    end
  end

  describe "Complete Shader Stages Coverage" do
    it "supports particle shaders with start, process, and collide stages" do
      source = <<-CRSHADER
        shader_type :particles
        render_mode :keep_data, :collision_use_scale

        start do
          VELOCITY = vec3(0.0, 10.0, 0.0)
          CUSTOM = vec4(1.0, 0.0, 0.0, 1.0)
        end

        process do
          VELOCITY += vec3(0.0, -9.8, 0.0) * DELTA
        end

        collide do
          VELOCITY = -VELOCITY * 0.5
        end
      CRSHADER

      code = compiler.compile(source)
      code.should contain("shader_type particles;")
      code.should contain("render_mode keep_data, collision_use_scale;")
      code.should contain("void start()")
      code.should contain("void process()")
      code.should contain("void collide()")
    end

    it "supports sky shaders with EYEDIR and sky coords" do
      source = <<-CRSHADER
        shader_type :sky
        render_mode :use_half_res_pass

        sky do
          COLOR = vec4(EYEDIR, 1.0)
        end
      CRSHADER

      code = compiler.compile(source)
      code.should contain("shader_type sky;")
      code.should contain("render_mode use_half_res_pass;")
      code.should contain("void sky()")
      code.should contain("COLOR = vec4(EYEDIR, 1.0);")
    end

    it "supports fog shaders with density and fog color" do
      source = <<-CRSHADER
        shader_type :fog

        fog do
          DENSITY = 0.05
          FOG_COLOR = vec4(0.8, 0.8, 0.9, 1.0)
        end
      CRSHADER

      code = compiler.compile(source)
      code.should contain("shader_type fog;")
      code.should contain("void fog()")
      code.should contain("DENSITY = 0.05;")
    end

    it "supports canvas_item shaders with vertex, fragment, and light" do
      source = <<-CRSHADER
        shader_type :canvas_item
        render_mode :blend_mix, :unshaded

        vertex do
          VERTEX += vec2(1.0, 0.0)
        end

        fragment do
          COLOR = texture(TEXTURE, UV)
        end

        light do
          LIGHT = vec3(1.0, 1.0, 1.0)
        end
      CRSHADER

      code = compiler.compile(source)
      code.should contain("shader_type canvas_item;")
      code.should contain("void vertex()")
      code.should contain("void fragment()")
      code.should contain("void light()")
    end
  end

  describe "Extended Transpiler Builtin Functions & Method Chaining" do
    it "transpiles matrix operations via method calls" do
      source = <<-CRSHADER
        shader_type :spatial

        uniform model_view : Mat4

        fragment do
          inv_m = model_view.inverse
          trans_m = model_view.transpose
          det = model_view.determinant
          albedo = vec3(det)
        end
      CRSHADER

      code = compiler.compile(source)
      code.should contain("inverse(model_view)")
      code.should contain("transpose(model_view)")
      code.should contain("determinant(model_view)")
    end

    it "transpiles relational and derivative methods" do
      source = <<-CRSHADER
        shader_type :spatial

        fragment do
          is_bad = ALBEDO.x.isnan? || ALBEDO.y.isinf?
          flags = bvec3(true, false, true)
          has_any = flags.any?
          has_all = flags.all?

          dx = UV.x.dFdx
          dy = UV.y.dFdy
          fw = UV.x.fwidth

          albedo = vec3(dx, dy, fw)
        end
      CRSHADER

      code = compiler.compile(source)
      code.should contain("isnan(ALBEDO.x)")
      code.should contain("isinf(ALBEDO.y)")
      code.should contain("any(flags)")
      code.should contain("all(flags)")
      code.should contain("dFdx(UV.x)")
      code.should contain("dFdy(UV.y)")
      code.should contain("fwidth(UV.x)")
    end

    it "transpiles advanced math and trigonometry methods" do
      source = <<-CRSHADER
        shader_type :spatial

        fragment do
          r = 45.0.radians
          d = 0.785.degrees
          l = 10.0.log
          l2 = 8.0.log2
          e2 = 3.0.exp2
          s_asin = 0.5.asin
          ac = 0.5.acos
          at = 1.0.atan
          sh = 1.0.sinh
          ch = 1.0.cosh
          th = 0.5.tanh
          m = 10.0.mod(3.0)

          albedo = vec3(r, l, m)
        end
      CRSHADER

      code = compiler.compile(source)
      code.should contain("radians(45.0)")
      code.should contain("degrees(0.785)")
      code.should contain("log(10.0)")
      code.should contain("log2(8.0)")
      code.should contain("exp2(3.0)")
      code.should contain("asin(0.5)")
      code.should contain("acos(0.5)")
      code.should contain("atan(1.0)")
      code.should contain("sinh(1.0)")
      code.should contain("cosh(1.0)")
      code.should contain("tanh(0.5)")
      code.should contain("mod(10.0, 3.0)")
    end
  end

  describe "Advanced Sampler & Image Types Coverage" do
    it "resolves Godot 4 sampler and image types correctly" do
      source = <<-CRSHADER
        shader_type :spatial

        uniform tex_arr : Sampler2DArray
        uniform tex_cube_arr : SamplerCubeArray
        uniform tex_shadow : Sampler2DShadow
        uniform itex : ISampler2D
        uniform utex : USampler2D

        fragment do
          albedo = vec3(0.0)
        end
      CRSHADER

      code = compiler.compile(source)
      code.should contain("uniform sampler2DArray tex_arr;")
      code.should contain("uniform samplerCubeArray tex_cube_arr;")
      code.should contain("uniform sampler2DShadow tex_shadow;")
      code.should contain("uniform isampler2D itex;")
      code.should contain("uniform usampler2D utex;")
    end
  end

  describe "Extended Render Modes Coverage" do
    it "validates new Godot 4 render modes without errors" do
      source = <<-CRSHADER
        shader_type :spatial
        render_mode :shadow_to_opacity, :vertex_lighting, :depth_draw_opaque

        fragment do
          albedo = vec3(1.0)
        end
      CRSHADER

      code = compiler.compile(source)
      code.should contain("render_mode shadow_to_opacity, vertex_lighting, depth_draw_opaque;")
    end
  end

  describe "Compute Shader Complete GLSL Coverage" do
    it "compiles compute shader with storage buffers, images, push constants, and barriers" do
      source = <<-CRSHADER
        shader_type :compute
        local_size x: 16, y: 16, z: 1

        storage_buffer ParticleBuffer, set: 0, binding: 0 do
          field pos : Vec4
          field vel : Vec4
        end

        storage_image OutputImage, format: :rgba32f, set: 0, binding: 1

        push_constants PushData do
          field delta_time : Float32
          field particle_count : Int32
        end

        shared cache : Array(Vec4, 256)

        def main
          idx = gl_GlobalInvocationID.x
          group_memory_barrier
          memory_barrier_shared
          barrier
        end
      CRSHADER

      code = compiler.compile(source, target: CrShader::ShaderTarget::GLSL)
      code.should contain("#version 450")
      code.should contain("layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;")
      code.should contain("layout(set = 0, binding = 0, std430) buffer ParticleBuffer")
      code.should contain("layout(rgba32f, set = 0, binding = 1) uniform image2D OutputImage;")
      code.should contain("layout(push_constant, std430) uniform PushData")
      code.should contain("shared vec4 cache[256];")
      code.should contain("groupMemoryBarrier();")
      code.should contain("memoryBarrierShared();")
      code.should contain("barrier();")
    end
  end
end
