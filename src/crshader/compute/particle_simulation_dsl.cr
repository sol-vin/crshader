require "./particle_simulation_core"

module CrShader
  module Compute
    # =========================================================================
    # Declarative DSL Layer: Ergonomic Compute Particle Simulation Builder
    # =========================================================================
    # Provides block-receiver builders (`yield ctx`) to configure compute
    # particle simulations and synthesize either `.crshader` DSL or GLSL 450
    # compute shaders automatically.
    class ParticleSimulationBuilder
      getter name : String
      property capacity : Int32 = 1024
      property local_size_x : Int32 = 64
      property integrator : IntegratorMode = IntegratorMode::SemiImplicitEuler
      property bounds : DomainBounds = DomainBounds.new
      property attractors : Array(ForceAttractor) = [] of ForceAttractor
      property gravity_x : Float32 = 0.0_f32
      property gravity_y : Float32 = -9.8_f32
      property gravity_z : Float32 = 0.0_f32
      property drag : Float32 = 0.05_f32
      property turbulence : Float32 = 0.0_f32
      property noise_scale : Float32 = 0.25_f32
      property buffer_set : Int32 = 0
      property buffer_binding : Int32 = 0

      def initialize(@name : String = "ParticleSimulation")
      end

      def workgroup_size(x : Int32) : self
        @local_size_x = x
        self
      end

      def max_particles(count : Int32) : self
        @capacity = count
        self
      end

      def gravity(x : Float32, y : Float32, z : Float32) : self
        @gravity_x = x
        @gravity_y = y
        @gravity_z = z
        self
      end

      def linear_drag(coeff : Float32) : self
        @drag = coeff
        self
      end

      def curl_turbulence(strength : Float32, scale : Float32 = 0.25_f32) : self
        @turbulence = strength
        @noise_scale = scale
        self
      end

      def integration(mode : IntegratorMode) : self
        @integrator = mode
        self
      end

      def domain_bounds(
        mode : BoundaryMode = BoundaryMode::Bounce,
        min_x : Float32 = -10.0_f32, min_y : Float32 = 0.0_f32, min_z : Float32 = -10.0_f32,
        max_x : Float32 = 10.0_f32, max_y : Float32 = 20.0_f32, max_z : Float32 = 10.0_f32,
        restitution : Float32 = 0.7_f32
      ) : self
        @bounds = DomainBounds.new(mode, min_x, min_y, min_z, max_x, max_y, max_z, restitution)
        self
      end

      def add_attractor(
        type : AttractorType = AttractorType::Point,
        x : Float32 = 0.0_f32, y : Float32 = 5.0_f32, z : Float32 = 0.0_f32,
        strength : Float32 = 15.0_f32, radius : Float32 = 20.0_f32, falloff : Float32 = 2.0_f32
      ) : self
        @attractors << ForceAttractor.new(type, x, y, z, strength, radius, falloff)
        self
      end

      # Builds the pure core engine configured by this declarative builder
      def build_engine : ParticleSimulationEngine
        engine = ParticleSimulationEngine.new(
          capacity: @capacity,
          local_size_x: @local_size_x,
          integrator: @integrator,
          bounds: @bounds
        )
        engine.attractors.concat(@attractors)
        engine.push_constants = SimulationPushConstants.new(
          delta_time: 0.016666_f32,
          particle_count: @capacity.to_u32,
          gravity_x: @gravity_x,
          gravity_y: @gravity_y,
          gravity_z: @gravity_z,
          drag: @drag,
          turbulence_strength: @turbulence,
          time: 0.0_f32
        )
        engine
      end

      # Synthesizes a valid CRShader source string (`.crshader`) for this particle simulation
      def to_crshader_source : String
        String.build do |io|
          io << "shader_type :compute\n"
          io << "local_size #{@local_size_x}, 1, 1\n\n"
          io << "require \"std/particles\"\n"
          io << "require \"std/curl_noise\"\n\n" if @turbulence > 0.0_f32

          io << "buffer ParticleBuffer, set: #{@buffer_set}, binding: #{@buffer_binding}, std: :std430, restrict: true do\n"
          io << "  field positions : Array(Vec4)\n"
          io << "  field velocities : Array(Vec4)\n"
          io << "  field colors : Array(Vec4)\n"
          io << "end\n\n"

          io << "push_constant SimParams do\n"
          io << "  field delta_time : Float32\n"
          io << "  field particle_count : UInt32\n"
          io << "  field gravity : Vec3\n"
          io << "  field drag : Float32\n"
          io << "  field turbulence : Float32\n"
          io << "  field time : Float32\n"
          io << "end\n\n"

          io << "def main\n"
          io << "  idx = gl_GlobalInvocationID.x\n"
          io << "  if idx >= sim_params.particle_count\n"
          io << "    return\n"
          io << "  end\n\n"
          io << "  pos_life = particle_buffer.positions[idx]\n"
          io << "  vel_max = particle_buffer.velocities[idx]\n"
          io << "  col_scale = particle_buffer.colors[idx]\n\n"
          io << "  pos = pos_life.xyz\n"
          io << "  life = pos_life.w - sim_params.delta_time\n"
          io << "  vel = vel_max.xyz\n"
          io << "  max_life = vel_max.w\n\n"

          io << "  if life <= 0.0\n"
          io << "    life = max_life\n"
          io << "    pos = vec3(0.0, #{(@bounds.min_y + @bounds.max_y) * 0.5_f32}, 0.0)\n"
          io << "  end\n\n"

          io << "  accel = sim_params.gravity\n"
          @attractors.each do |attr|
            case attr.type
            when AttractorType::Point
              io << "  accel = accel + attract_point(pos, vec3(#{attr.x}, #{attr.y}, #{attr.z}), #{attr.strength}, #{attr.radius})\n"
            when AttractorType::Vortex
              io << "  accel = accel + vortex_force_3d(pos, vec3(#{attr.x}, #{attr.y}, #{attr.z}), #{attr.strength}, #{attr.radius})\n"
            when AttractorType::Spring
              io << "  accel = accel + (vec3(#{attr.x}, #{attr.y}, #{attr.z}) - pos) * #{attr.strength}\n"
            when AttractorType::Directional
              io << "  accel = accel + vec3(#{attr.x}, #{attr.y}, #{attr.z}) * #{attr.strength}\n"
            end
          end

          if @turbulence > 0.0_f32
            io << "  accel = accel + curl_noise_3d(pos * #{@noise_scale} + vec3(sim_params.time, sim_params.time, sim_params.time), 0.01) * sim_params.turbulence\n"
          end

          io << "  vel = apply_linear_drag(vel + accel * sim_params.delta_time, sim_params.drag, sim_params.delta_time)\n"
          io << "  pos = integrate_euler(pos, vel, sim_params.delta_time)\n\n"

          case @bounds.mode
          when BoundaryMode::Bounce
            io << "  if pos.y < #{@bounds.min_y}\n"
            io << "    pos.y = #{@bounds.min_y}\n"
            io << "    vel.y = -vel.y * #{@bounds.restitution}\n"
            io << "  end\n"
          when BoundaryMode::Clamp
            io << "  pos = clamp(pos, vec3(#{@bounds.min_x}, #{@bounds.min_y}, #{@bounds.min_z}), vec3(#{@bounds.max_x}, #{@bounds.max_y}, #{@bounds.max_z}))\n"
          when BoundaryMode::Wrap
            io << "  pos = wrap_box_3d(pos, vec3(#{@bounds.min_x}, #{@bounds.min_y}, #{@bounds.min_z}), vec3(#{@bounds.max_x}, #{@bounds.max_y}, #{@bounds.max_z}))\n"
          end

          io << "\n  particle_buffer.positions[idx] = vec4(pos, life)\n"
          io << "  particle_buffer.velocities[idx] = vec4(vel, max_life)\n"
          io << "  particle_buffer.colors[idx] = col_scale\n"
          io << "end\n"
        end
      end
    end

    # Top-level Declarative Builder Entrypoint (`CrShader::Compute.particle_simulation do |sim| ... end`)
    def self.particle_simulation(name : String = "ParticleSimulation", &block : ParticleSimulationBuilder ->) : ParticleSimulationBuilder
      builder = ParticleSimulationBuilder.new(name)
      yield builder
      builder
    end
  end
end
