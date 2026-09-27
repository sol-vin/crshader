require "./spec_helper"
require "../src/crshader/compiler"

describe "CrShader DSL Syntactic Sugar" do
  compiler = CrShader::Compiler.new

  it "supports property and export keywords as uniform declarations" do
    source = <<-CR
      shader_type :spatial

      property speed : Float32 = 5.0
      export wind : Float32 = 1.0

      def fragment
        ALBEDO = vec3(speed + wind)
      end
    CR

    code = compiler.compile_source(source)
    code.should contain("uniform float speed = 5.0;")
    code.should contain("uniform float wind = 1.0;")
  end

  it "supports range literal syntax with step for hints and ranges" do
    source = <<-CR
      shader_type :spatial

      property speed : Float32 = 5.0, range: 0.1..20.0, step: 0.5
      uniform roughness : Float32 = 0.5, hint: 0.0..1.0

      def fragment
        ALBEDO = vec3(speed)
        ROUGHNESS = roughness
      end
    CR

    code = compiler.compile_source(source)
    code.should contain("uniform float speed : hint_range(0.1, 20.0, 0.5) = 5.0;")
    code.should contain("uniform float roughness : hint_range(0.0, 1.0) = 0.5;")
  end

  it "supports scoped block uniform groups and subgroups without state leakage" do
    source = <<-CR
      shader_type :spatial

      group "Optics" do
        property refraction : Float32 = 0.2

        subgroup "Fresnel" do
          property rim_power : Float32 = 2.0
        end
      end

      # Standalone property outside of block group
      property unparented_val : Float32 = 1.0

      def fragment
        ALBEDO = vec3(refraction + rim_power + unparented_val)
      end
    CR

    parser = CrShader::DslParser.new
    program = parser.parse(source)

    u_ref = program.uniforms.find { |u| u.name == "refraction" }.not_nil!
    u_ref.group.should eq("Optics")
    u_ref.subgroup.should be_nil

    u_rim = program.uniforms.find { |u| u.name == "rim_power" }.not_nil!
    u_rim.group.should eq("Optics")
    u_rim.subgroup.should eq("Fresnel")

    u_unp = program.uniforms.find { |u| u.name == "unparented_val" }.not_nil!
    u_unp.group.should be_nil
    u_unp.subgroup.should be_nil
  end

  it "supports record declarations" do
    source = <<-CR
      shader_type :spatial

      record RayHit, position : Vec3, normal : Vec3, distance : Float32, hit : Bool

      def fragment
        ALBEDO = vec3(0.5)
      end
    CR

    code = compiler.compile_source(source)
    code.should contain("struct RayHit {")
    code.should contain("vec3 position;")
    code.should contain("vec3 normal;")
    code.should contain("float distance;")
    code.should contain("bool hit;")
  end

  it "supports stage :name do ... end block syntax" do
    source = <<-CR
      shader_type :spatial

      stage :vertex do
        VERTEX.y += 0.5
      end

      stage :fragment do
        ALBEDO = vec3(0.8, 0.2, 0.1)
      end
    CR

    code = compiler.compile_source(source)
    code.should contain("void vertex()")
    code.should contain("void fragment()")
    code.should contain("VERTEX.y += 0.5;")
  end

  it "normalizes shorthand lowercase types" do
    source = <<-CR
      shader_type :spatial

      property tint : color = Color.new(1.0, 1.0, 1.0, 1.0)
      property offset : vec3 = vec3(0.0)
      property factor : float = 1.0

      def fragment
        ALBEDO = tint.rgb + offset * factor
      end
    CR

    code = compiler.compile_source(source)
    code.should contain("uniform vec4 tint = vec4(1.0, 1.0, 1.0, 1.0);")
    code.should contain("uniform vec3 offset = vec3(0.0);")
    code.should contain("uniform float factor = 1.0;")
  end

  it "supports sampler directive shorthand" do
    source = <<-CR
      shader_type :spatial

      sampler :albedo_map, filter: :linear, repeat: :enable

      def fragment
        ALBEDO = texture(albedo_map, UV).rgb
      end
    CR

    code = compiler.compile_source(source)
    code.should contain("uniform sampler2D albedo_map : filter_linear, repeat_enable;")
  end

  it "evaluates compile-time Color.hex literals" do
    source = <<-CR
      shader_type :spatial

      property sky_color : Color = Color.hex("#3498db"), hint: :source_color

      def fragment
        ALBEDO = sky_color.rgb
      end
    CR

    code = compiler.compile_source(source)
    # #3498db -> 0.2039, 0.5961, 0.8588
    code.should contain("uniform vec4 sky_color : source_color = vec4(0.2039, 0.5961, 0.8588, 1.0);")
  end

  it "supports array syntax for render_mode" do
    source = <<-CR
      shader_type :spatial
      render_mode [:unshaded, :cull_disabled]

      def fragment
        ALBEDO = vec3(1.0)
      end
    CR

    code = compiler.compile_source(source)
    code.should contain("render_mode unshaded, cull_disabled;")
  end
end
