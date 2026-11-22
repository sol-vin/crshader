require "./spec_helper"

describe "CrShader Class & Struct Method Lowering" do
  it "lowers class fields, static factories, mutating `!` methods, and instance methods to GDShader" do
    src = <<-CR
    shader_type :spatial

    class FresnelRim
      color : Vec3
      power : Float32
      energy : Float32

      def self.icy : FresnelRim
        FresnelRim.new(vec3(0.35, 0.8, 1.0), 3.0, 1.5)
      end

      def boost!(factor : Float32) : Void
        @energy *= factor
      end

      def evaluate(n : Vec3, v : Vec3) : Vec3
        mask = (1.0 - dot(n, v).saturate) ** @power
        @color * (mask * @energy)
      end

      def debug_luma : Float32
        @color.luminance
      end
    end

    uniform rim_boost : Float32 = 1.25

    def fragment
      rim = FresnelRim.icy
      rim.boost!(rim_boost)
      ALBEDO = vec3(0.12, 0.14, 0.18)
      EMISSION = rim.evaluate(NORMAL, VIEW)
    end
    CR

    gd = CrShader.compile(src, CrShader::ShaderTarget::GDShader)
    gd.should contain("struct FresnelRim {\n\tvec3 color;\n\tfloat power;\n\tfloat energy;\n};")
    gd.should contain("FresnelRim FresnelRim_icy()")
    gd.should contain("void FresnelRim_boost(inout FresnelRim _self, float factor)")
    gd.should contain("_self.energy *= factor;")
    gd.should contain("vec3 FresnelRim_evaluate(FresnelRim _self, vec3 n, vec3 v)")
    gd.should contain("FresnelRim rim = FresnelRim_icy();")
    gd.should contain("FresnelRim_boost(rim, rim_boost);")
    gd.should contain("EMISSION = FresnelRim_evaluate(rim, NORMAL, VIEW);")
    # Unused `debug_luma` method is automatically tree-shaken!
    gd.should_not contain("FresnelRim_debug_luma")
  end

  it "lowers classes to Vulkan GLSL 450 compute shaders and .gdshaderinc headers" do
    compute_src = <<-CR
    shader_type :compute
    local_size 8, 8, 1

    struct KineticParticle
      property pos : Vec3
      property vel : Vec3
      property life : Float32

      def alive? : Bool
        @life > 0.0
      end

      def step!(dt : Float32) : Void
        @pos += @vel * dt
        @life -= dt
      end
    end

    image2d out_img, format: :rgba16f, set: 0, binding: 0

    def main
      px = ivec2(gl_GlobalInvocationID.xy)
      p = KineticParticle.new(vec3(0.0, 1.0, 0.0), vec3(0.5, 0.0, 0.0), 2.0)
      p.step!(0.016)
      col = p.alive? ? p.pos : vec3(0.0, 0.0, 0.0)
      imageStore(out_img, px, vec4(col, 1.0))
    end
    CR

    glsl = CrShader.compile(compute_src, CrShader::ShaderTarget::GLSL)
    glsl.should contain("#version 450")
    glsl.should contain("struct KineticParticle {")
    glsl.should contain("bool KineticParticle_is_alive(KineticParticle _self)")
    glsl.should contain("void KineticParticle_step(inout KineticParticle _self, float dt)")
    glsl.should contain("KineticParticle_step(p, 0.016);")
    glsl.should contain("KineticParticle_is_alive(p)")
    # `property` inside struct must NOT leak into uniform block
    glsl.should_not contain("CrShaderParams")

    inc_src = <<-CR
    shader :gdshaderinc

    class LightProbe
      intensity : Float32

      def initialize(@intensity : Float32 = 1.0)
      end

      def scaled(mult : Float32 = 2.0) : Float32
        intensity * mult
      end
    end

    def default_probe_energy : Float32
      probe = LightProbe.new
      probe.scaled
    end
    CR

    inc = CrShader.compile(inc_src, CrShader::ShaderTarget::GDShaderInc)
    inc.should contain("#ifndef")
    inc.should contain("struct LightProbe {")
    inc.should contain("LightProbe LightProbe__new(float intensity)")
    inc.should contain("float LightProbe_scaled(LightProbe _self, float mult)")
    inc.should contain("LightProbe probe = LightProbe__new(1.0);")
    inc.should contain("return LightProbe_scaled(probe, 2.0);")
  end

  it "supports chained value-returning class methods and sibling method calls" do
    src = <<-CR
    shader_type :canvas_item

    class Ray2D
      origin : Vec2
      dir : Vec2

      def shifted(ofs : Vec2) : Ray2D
        Ray2D.new(@origin + ofs, @dir)
      end

      def at(t : Float32) : Vec2
        @origin + @dir * t
      end

      def sample_mid(ofs : Vec2) : Vec2
        shifted(ofs).at(0.5)
      end
    end

    def fragment
      r = Ray2D.new(UV, vec2(1.0, 0.0))
      pt = r.sample_mid(vec2(0.1, 0.2))
      COLOR = vec4(pt.x, pt.y, 0.0, 1.0)
    end
    CR

    gd = CrShader.compile(src, CrShader::ShaderTarget::GDShader)
    gd.should contain("Ray2D Ray2D_shifted(Ray2D _self, vec2 ofs)")
    gd.should contain("vec2 Ray2D_at(Ray2D _self, float t)")
    gd.should contain("return Ray2D_at(Ray2D_shifted(_self, ofs), 0.5);")
  end

  it "normalizes lowercase def return types without corrupting ternary vector calls" do
    src = <<-CR
    shader_type :canvas_item

    class TintHelper
      tint : vec3

      def eval(scale : float = 1.0) : vec3
        (scale > 0.5) ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0)
      end
    end

    def fragment
      h = TintHelper.new(vec3(0.2, 0.4, 0.8))
      c = h.eval(0.75)
      COLOR = vec4(c, 1.0)
    end
    CR

    gd = CrShader.compile(src, CrShader::ShaderTarget::GDShader)
    gd.should contain("vec3 TintHelper_eval(TintHelper _self, float scale)")
    gd.should contain("(vec3(1.0, 0.0, 0.0)) : (vec3(0.0, 1.0, 0.0))")
  end
end
