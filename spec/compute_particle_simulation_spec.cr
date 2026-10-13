require "./spec_helper"
require "../src/crshader/compute/particle_simulation_core"
require "../src/crshader/compute/particle_simulation_dsl"
require "../src/crshader/compute/compute_helper"
require "../src/crshader/generator/node_generator"

describe "CrShader Compute Particle Simulation (Two-Tier Engine & DSL)" do
  describe "Core Engine Layer (CrShader::Compute::ParticleSimulationEngine)" do
    it "packs and unpacks ParticleState into 48-byte std430 byte buffers with zero loss" do
      state = CrShader::Compute::ParticleState.new(
        px: 1.5_f32, py: 2.5_f32, pz: -3.5_f32, life: 4.0_f32,
        vx: 0.25_f32, vy: 5.0_f32, vz: -1.25_f32, max_life: 5.0_f32,
        r: 0.9_f32, g: 0.4_f32, b: 0.1_f32, scale: 1.2_f32
      )

      state.alive?.should be_true
      state.normalized_age.should be_close(0.2_f32, 0.0001_f32)

      buf = Bytes.new(CrShader::Compute::ParticleState::BYTE_STRIDE)
      state.write_to_bytes(buf, 0)
      restored = CrShader::Compute::ParticleState.read_from_bytes(buf, 0)

      restored.px.should eq(1.5_f32)
      restored.py.should eq(2.5_f32)
      restored.pz.should eq(-3.5_f32)
      restored.life.should eq(4.0_f32)
      restored.vx.should eq(0.25_f32)
      restored.vy.should eq(5.0_f32)
      restored.vz.should eq(-1.25_f32)
      restored.max_life.should eq(5.0_f32)
      restored.r.should eq(0.9_f32)
      restored.g.should eq(0.4_f32)
      restored.b.should eq(0.1_f32)
      restored.scale.should eq(1.2_f32)
    end

    it "packs SimulationPushConstants into 32-byte aligned buffer" do
      pc = CrShader::Compute::SimulationPushConstants.new(
        delta_time: 0.016_f32,
        particle_count: 2048_u32,
        gravity_x: 0.0_f32,
        gravity_y: -9.8_f32,
        gravity_z: 0.0_f32,
        drag: 0.1_f32,
        turbulence_strength: 2.0_f32,
        time: 1.5_f32
      )
      bytes = pc.to_bytes
      bytes.size.should eq(32)
    end

    it "computes workgroup dispatch counts and steps CPU simulation with attractors and bounce bounds" do
      engine = CrShader::Compute::ParticleSimulationEngine.new(capacity: 100, local_size_x: 64)
      engine.workgroup_count_x.should eq(2)
      engine.buffer_byte_size.should eq(4800)

      engine.seed_radial(origin_x: 0.0_f32, origin_y: 2.0_f32, origin_z: 0.0_f32, spread: 1.0_f32, base_speed: 2.0_f32, lifetime: 3.0_f32)
      engine.attractors << CrShader::Compute::ForceAttractor.new(
        type: CrShader::Compute::AttractorType::Point,
        x: 0.0_f32, y: 10.0_f32, z: 0.0_f32,
        strength: 25.0_f32, radius: 30.0_f32
      )

      initial_py = engine.particles[0].py
      engine.step_cpu(0.05_f32)
      engine.particles[0].py.should_not eq(initial_py)
      engine.push_constants.time.should be_close(0.05_f32, 0.0001_f32)

      # Verify floor bounce when particle drops below min_y (0.0)
      p0 = engine.particles[0]
      p0.py = -1.0_f32
      p0.vy = -5.0_f32
      engine.particles[0] = p0
      engine.step_cpu(0.01_f32)
      engine.particles[0].py.should be >= 0.0_f32
      engine.particles[0].vy.should be > 0.0_f32
    end
  end

  describe "Declarative Builder Layer (CrShader::Compute.particle_simulation)" do
    it "configures particle simulation via block DSL and compiles to GLSL 450 compute shader" do
      sim = CrShader::Compute.particle_simulation("VortexSwarm") do |s|
        s.workgroup_size(64)
        s.max_particles(4096)
        s.gravity(0.0_f32, -4.5_f32, 0.0_f32)
        s.linear_drag(0.08_f32)
        s.curl_turbulence(1.5_f32, 0.3_f32)
        s.domain_bounds(mode: CrShader::Compute::BoundaryMode::Bounce, min_y: 0.0_f32, restitution: 0.75_f32)
        s.add_attractor(type: CrShader::Compute::AttractorType::Vortex, x: 0.0_f32, y: 5.0_f32, z: 0.0_f32, strength: 12.0_f32, radius: 18.0_f32)
      end

      engine = sim.build_engine
      engine.capacity.should eq(4096)
      engine.local_size_x.should eq(64)
      engine.workgroup_count_x.should eq(64)
      engine.attractors.size.should eq(1)

      crshader_code = sim.to_crshader_source
      glsl = CrShader.compile(crshader_code, target: CrShader::ShaderTarget::GLSL)

      glsl.should contain("#version 450")
      glsl.should contain("layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;")
      glsl.should contain("layout(set = 0, binding = 0, std430) restrict buffer ParticleBuffer {")
      glsl.should contain("layout(push_constant, std430) uniform SimParams {")
      glsl.should contain("vortex_force_3d(")
      glsl.should contain("curl_noise_3d(")
      glsl.should contain("apply_linear_drag(")
      glsl.should contain("integrate_euler(")
    end
  end

  describe "Shader Language DSL (particle_simulation & step_particles)" do
    it "desugars particle_simulation and step_particles into complete GLSL compute shader with std/particles helpers" do
      source = <<-CR
        particle_simulation 64 do
          step_particles do |idx, pos, vel, life|
            life = life - sim_params.delta_time
            force = sim_params.gravity + attract_point(pos, vec3(0.0, 5.0, 0.0), 20.0, 15.0)
            vel = apply_linear_drag(vel + force * sim_params.delta_time, sim_params.drag, sim_params.delta_time)
            pos = integrate_euler(pos, vel, sim_params.delta_time)
          end
        end
      CR

      compiler = CrShader::Compiler.new
      glsl = compiler.compile_source(source)

      glsl.should contain("#version 450")
      glsl.should contain("layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;")
      glsl.should contain("layout(set = 0, binding = 0, std430) restrict buffer ParticleBuffer {")
      glsl.should contain("vec4 positions[];")
      glsl.should contain("vec4 velocities[];")
      glsl.should contain("vec4 colors[];")
      glsl.should contain("layout(push_constant, std430) uniform SimParams {")
      glsl.should contain("vec3 attract_point(")
      glsl.should contain("vec3 apply_linear_drag(")
      glsl.should contain("vec3 integrate_euler(")
      glsl.should contain("vec3 pos = __pos_life.xyz;")
      glsl.should contain("vec3 vel = __vel_max.xyz;")
      glsl.should contain("particle_buffer.positions[idx] = vec4(pos, life);")
      glsl.should contain("particle_buffer.velocities[idx] = vec4(vel, __vel_max.w);")
    end

    it "generates a ComputeParticles Godot Node3D via NodeGenerator" do
      source = <<-CR
        particle_simulation 128 do
          step_particles do |idx, pos, vel, life|
            pos = integrate_euler(pos, vel, sim_params.delta_time)
          end
        end
      CR

      node_code = CrShader::NodeGenerator.generate_from_source(
        source,
        CrShader::NodeGenerator::NodeType::ComputeParticles,
        "SwarmParticlesNode"
      )

      node_code.should contain("node SwarmParticlesNode < Node3D do")
      node_code.should contain("property particle_count : Int32 = 1024")
      node_code.should contain("def setup_compute_particles : Void")
      node_code.should contain("helper.dispatch_1d(@particle_count, 128)")
    end

    it "aligns push constants to 16-byte boundaries in ComputeHelper" do
      helper = CrShader::ComputeHelper.new(nil)
      unaligned = Bytes.new(20, 1_u8)
      helper.set_push_constant(unaligned)
      if pc = helper.push_constant_bytes
        pc.size.should eq(32)
      else
        fail "Expected push_constant_bytes to be set"
      end
    end
  end
end
