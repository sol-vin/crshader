require "./spec_helper"
require "../src/crshader/optimizer/name_optimizer"
require "../src/crshader/compiler"

describe "CrShader::Optimizer::NameOptimizer" do
  it "renames local variables into compact _v0, _v1 identifiers" do
    source = <<-CRYSTAL
    uniform my_speed : Float32 = 1.0

    def fragment
      local_val = my_speed * 2.0
      another_temp = local_val + 5.0
      COLOR = vec4(another_temp, another_temp, another_temp, 1.0)
    end
    CRYSTAL

    parser = CrShader::DslParser.new
    program = parser.parse(source)

    optimizer = CrShader::Optimizer::NameOptimizer.new(program)
    optimizer.optimize_program(program)

    frag = program.functions["fragment"]
    frag_body = frag.body.to_s

    # Uniforms and built-ins MUST NOT be renamed
    frag_body.should contain("my_speed")
    frag_body.should contain("COLOR")

    # Local variables MUST be renamed to compact _v0, _v1
    frag_body.should contain("_v0")
    frag_body.should contain("_v1")
    frag_body.should_not contain("local_val")
    frag_body.should_not contain("another_temp")

    # MUST NOT contain invalid double-underscore or ugly o_123 patterns
    frag_body.should_not contain("__")
    frag_body.should_not match(/o_\d+/)
    frag_body.should_not match(/o__\d+/)
  end

  it "preserves function parameters while renaming internal locals" do
    source = <<-CRYSTAL
    def calculate_distance(pt_a : Vec3, pt_b : Vec3) : Float32
      diff = pt_a - pt_b
      d_sq = dot(diff, diff)
      return sqrt(d_sq)
    end
    CRYSTAL

    parser = CrShader::DslParser.new
    program = parser.parse(source)

    optimizer = CrShader::Optimizer::NameOptimizer.new(program)
    optimizer.optimize_program(program)

    fn = program.functions["calculate_distance"]
    fn_body = fn.body.to_s

    # Parameters preserved
    fn.args.map(&.name).should eq(["pt_a", "pt_b"])
    fn_body.should contain("pt_a")
    fn_body.should contain("pt_b")

    # Locals renamed
    fn_body.should contain("_v0")
    fn_body.should contain("_v1")
    fn_body.should_not contain("diff")
    fn_body.should_not contain("d_sq")
  end

  it "integrates seamlessly with Compiler(optimize_names: true)" do
    source = <<-CRYSTAL
    shader_type :canvas_item
    uniform my_scale : Float32 = 1.0

    def fragment
      accum = my_scale * 4.0
      COLOR = vec4(accum, accum, accum, 1.0)
    end
    CRYSTAL

    compiler = CrShader::Compiler.new(optimize_names: true)
    gdshader = compiler.compile_source(source)

    gdshader.should contain("uniform float my_scale = 1.0;")
    gdshader.should contain("float _v0 = (my_scale * 4.0);")
    gdshader.should contain("COLOR = vec4(_v0, _v0, _v0, 1.0);")
    gdshader.should_not contain("accum")
  end
end
