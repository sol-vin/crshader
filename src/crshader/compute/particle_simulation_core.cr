module CrShader
  module Compute
    # =========================================================================
    # Core Engine Layer: Pure Compute Particle Simulation Primitives
    # =========================================================================
    # Zero-allocation, strongly-typed structs and math algorithms for GPU
    # compute particle simulation, std430 byte buffer packing, and force fields.

    enum IntegratorMode
      Euler
      SemiImplicitEuler
      Verlet
    end

    enum BoundaryMode
      None
      Bounce
      Wrap
      Kill
      Clamp
    end

    enum AttractorType
      Point
      Directional
      Vortex
      Spring
    end

    # Aligned 32-byte (2 x vec4) or 48-byte (3 x vec4) std430 particle state
    # Layout in std430 storage buffer:
    # - vec4(px, py, pz, life)
    # - vec4(vx, vy, vz, max_life)
    # - vec4(r, g, b, scale)
    struct ParticleState
      property px : Float32
      property py : Float32
      property pz : Float32
      property life : Float32

      property vx : Float32
      property vy : Float32
      property vz : Float32
      property max_life : Float32

      property r : Float32
      property g : Float32
      property b : Float32
      property scale : Float32

      BYTE_STRIDE = 48 # 12 * 4 bytes (3 x vec4 aligned for std430)

      def initialize(
        @px : Float32 = 0.0_f32, @py : Float32 = 0.0_f32, @pz : Float32 = 0.0_f32, @life : Float32 = 1.0_f32,
        @vx : Float32 = 0.0_f32, @vy : Float32 = 0.0_f32, @vz : Float32 = 0.0_f32, @max_life : Float32 = 1.0_f32,
        @r : Float32 = 1.0_f32, @g : Float32 = 1.0_f32, @b : Float32 = 1.0_f32, @scale : Float32 = 1.0_f32
      )
      end

      def alive? : Bool
        @life > 0.0_f32
      end

      def normalized_age : Float32
        return 0.0_f32 if @max_life <= 0.0_f32
        age = 1.0_f32 - (@life / @max_life)
        age < 0.0_f32 ? 0.0_f32 : (age > 1.0_f32 ? 1.0_f32 : age)
      end

      def speed : Float32
        Math.sqrt(@vx * @vx + @vy * @vy + @vz * @vz)
      end

      # Writes the 12 Float32 components (48 bytes) into a Slice(UInt8) at byte_offset
      def write_to_bytes(buffer : Bytes, byte_offset : Int32 = 0) : Void
        ptr = (buffer.to_unsafe + byte_offset).as(Pointer(Float32))
        ptr[0] = @px
        ptr[1] = @py
        ptr[2] = @pz
        ptr[3] = @life
        ptr[4] = @vx
        ptr[5] = @vy
        ptr[6] = @vz
        ptr[7] = @max_life
        ptr[8] = @r
        ptr[9] = @g
        ptr[10] = @b
        ptr[11] = @scale
      end

      # Reads a ParticleState from a Slice(UInt8) at byte_offset
      def self.read_from_bytes(buffer : Bytes, byte_offset : Int32 = 0) : ParticleState
        ptr = (buffer.to_unsafe + byte_offset).as(Pointer(Float32))
        new(
          ptr[0], ptr[1], ptr[2], ptr[3],
          ptr[4], ptr[5], ptr[6], ptr[7],
          ptr[8], ptr[9], ptr[10], ptr[11]
        )
      end
    end

    # Point, Directional, Vortex, or Spring force attractor specification
    struct ForceAttractor
      property type : AttractorType
      property x : Float32
      property y : Float32
      property z : Float32
      property strength : Float32
      property radius : Float32
      property falloff : Float32

      def initialize(
        @type : AttractorType = AttractorType::Point,
        @x : Float32 = 0.0_f32,
        @y : Float32 = 0.0_f32,
        @z : Float32 = 0.0_f32,
        @strength : Float32 = 10.0_f32,
        @radius : Float32 = 25.0_f32,
        @falloff : Float32 = 2.0_f32
      )
      end
    end

    # Axis-Aligned Bounding Box (AABB) or Spherical simulation domain
    struct DomainBounds
      property mode : BoundaryMode
      property min_x : Float32
      property min_y : Float32
      property min_z : Float32
      property max_x : Float32
      property max_y : Float32
      property max_z : Float32
      property restitution : Float32

      def initialize(
        @mode : BoundaryMode = BoundaryMode::Bounce,
        @min_x : Float32 = -10.0_f32, @min_y : Float32 = 0.0_f32, @min_z : Float32 = -10.0_f32,
        @max_x : Float32 = 10.0_f32, @max_y : Float32 = 20.0_f32, @max_z : Float32 = 10.0_f32,
        @restitution : Float32 = 0.7_f32
      )
      end
    end

    # Push constant payload packed into 32 bytes (std430 aligned)
    struct SimulationPushConstants
      property delta_time : Float32
      property particle_count : UInt32
      property gravity_x : Float32
      property gravity_y : Float32
      property gravity_z : Float32
      property drag : Float32
      property turbulence_strength : Float32
      property time : Float32

      BYTE_SIZE = 32 # 8 * 4 bytes

      def initialize(
        @delta_time : Float32 = 0.016666_f32,
        @particle_count : UInt32 = 1024_u32,
        @gravity_x : Float32 = 0.0_f32,
        @gravity_y : Float32 = -9.8_f32,
        @gravity_z : Float32 = 0.0_f32,
        @drag : Float32 = 0.05_f32,
        @turbulence_strength : Float32 = 1.0_f32,
        @time : Float32 = 0.0_f32
      )
      end

      def to_bytes : Bytes
        bytes = Bytes.new(BYTE_SIZE)
        write_to_bytes(bytes)
        bytes
      end

      def write_to_bytes(buffer : Bytes) : Void
        f_ptr = buffer.to_unsafe.as(Pointer(Float32))
        u_ptr = buffer.to_unsafe.as(Pointer(UInt32))
        f_ptr[0] = @delta_time
        u_ptr[1] = @particle_count
        f_ptr[2] = @gravity_x
        f_ptr[3] = @gravity_y
        f_ptr[4] = @gravity_z
        f_ptr[5] = @drag
        f_ptr[6] = @turbulence_strength
        f_ptr[7] = @time
      end
    end

    # Pure Core Engine for CPU/GPU Particle Simulation & Buffer Management
    class ParticleSimulationEngine
      getter capacity : Int32
      getter local_size_x : Int32
      property integrator : IntegratorMode
      property bounds : DomainBounds
      property attractors : Array(ForceAttractor)
      property push_constants : SimulationPushConstants
      getter particles : Slice(ParticleState)
      getter raw_buffer : Bytes

      def initialize(
        @capacity : Int32 = 1024,
        @local_size_x : Int32 = 64,
        @integrator : IntegratorMode = IntegratorMode::SemiImplicitEuler,
        @bounds : DomainBounds = DomainBounds.new
      )
        @capacity = 1 if @capacity < 1
        @local_size_x = 1 if @local_size_x < 1
        @attractors = [] of ForceAttractor
        @push_constants = SimulationPushConstants.new(particle_count: @capacity.to_u32)
        @particles = Slice(ParticleState).new(@capacity) { ParticleState.new }
        @raw_buffer = Bytes.new(@capacity * ParticleState::BYTE_STRIDE)
      end

      # Number of 1D compute workgroups needed to cover capacity
      def workgroup_count_x : Int32
        (@capacity + @local_size_x - 1) // @local_size_x
      end

      # Total byte size of the std430 storage buffer
      def buffer_byte_size : Int32
        @capacity * ParticleState::BYTE_STRIDE
      end

      # Deterministic hash for procedural seeding (matches std/particles GPU hash)
      def self.hash11(p : Float32) : Float32
        x = (p * 0.1031_f32)
        x = x - x.floor
        x *= x + 33.33_f32
        x *= x + x
        x - x.floor
      end

      # Seeds particles within a radial or box emitter volume
      def seed_radial(origin_x : Float32 = 0.0_f32, origin_y : Float32 = 5.0_f32, origin_z : Float32 = 0.0_f32, spread : Float32 = 2.0_f32, base_speed : Float32 = 3.0_f32, lifetime : Float32 = 4.0_f32) : Void
        @capacity.times do |i|
          fi = i.to_f32
          rx = (self.class.hash11(fi * 1.13_f32) * 2.0_f32 - 1.0_f32) * spread
          ry = (self.class.hash11(fi * 2.71_f32) * 2.0_f32 - 1.0_f32) * spread
          rz = (self.class.hash11(fi * 3.97_f32) * 2.0_f32 - 1.0_f32) * spread

          vx = (self.class.hash11(fi * 5.31_f32) * 2.0_f32 - 1.0_f32) * base_speed
          vy = (self.class.hash11(fi * 7.19_f32) * 0.5_f32 + 0.5_f32) * base_speed
          vz = (self.class.hash11(fi * 9.43_f32) * 2.0_f32 - 1.0_f32) * base_speed

          life = lifetime * (0.25_f32 + 0.75_f32 * self.class.hash11(fi * 11.09_f32))
          @particles[i] = ParticleState.new(
            px: origin_x + rx, py: origin_y + ry, pz: origin_z + rz, life: life,
            vx: vx, vy: vy, vz: vz, max_life: lifetime,
            r: 1.0_f32, g: 0.7_f32, b: 0.2_f32, scale: 1.0_f32
          )
        end
        pack_buffer!
      end

      # Packs all ParticleState structs into the contiguous std430 byte buffer
      def pack_buffer! : Bytes
        @capacity.times do |i|
          @particles[i].write_to_bytes(@raw_buffer, i * ParticleState::BYTE_STRIDE)
        end
        @raw_buffer
      end

      # Unpacks the contiguous std430 byte buffer back into ParticleState structs
      def unpack_buffer!(bytes : Bytes = @raw_buffer) : Slice(ParticleState)
        count = Math.min(@capacity, bytes.size // ParticleState::BYTE_STRIDE)
        count.times do |i|
          @particles[i] = ParticleState.read_from_bytes(bytes, i * ParticleState::BYTE_STRIDE)
        end
        @particles
      end

      # Reference CPU step matching the GPU compute shader physics kernel
      def step_cpu(dt : Float32) : Void
        @push_constants.delta_time = dt
        @push_constants.time += dt

        gx = @push_constants.gravity_x
        gy = @push_constants.gravity_y
        gz = @push_constants.gravity_z
        drag_factor = Math.max(0.0_f32, 1.0_f32 - @push_constants.drag * dt)

        @capacity.times do |i|
          p = @particles[i]
          p.life -= dt

          if p.life <= 0.0_f32
            if @bounds.mode == BoundaryMode::Kill
              p.scale = 0.0_f32
              @particles[i] = p
              next
            else
              # Respawn at origin with initial max_life
              p.life = p.max_life > 0.0_f32 ? p.max_life : 1.0_f32
              p.px = 0.0_f32
              p.py = (@bounds.min_y + @bounds.max_y) * 0.5_f32
              p.pz = 0.0_f32
            end
          end

          # Accumulate forces
          ax = gx
          ay = gy
          az = gz

          @attractors.each do |attr|
            dx = attr.x - p.px
            dy = attr.y - p.py
            dz = attr.z - p.pz
            dist_sq = dx * dx + dy * dy + dz * dz
            dist = Math.sqrt(dist_sq)

            if dist > 0.0001_f32 && dist < attr.radius
              inv_dist = 1.0_f32 / dist
              nx = dx * inv_dist
              ny = dy * inv_dist
              nz = dz * inv_dist
              attenuation = 1.0_f32 - (dist / attr.radius)
              force_mag = attr.strength * (attenuation ** attr.falloff)

              case attr.type
              when AttractorType::Point
                ax += nx * force_mag
                ay += ny * force_mag
                az += nz * force_mag
              when AttractorType::Directional
                ax += attr.x * attr.strength
                ay += attr.y * attr.strength
                az += attr.z * attr.strength
              when AttractorType::Vortex
                # Swirl around Y axis relative to attractor center
                ax += (-nz * force_mag) + (nx * force_mag * 0.25_f32)
                az += (nx * force_mag) + (nz * force_mag * 0.25_f32)
              when AttractorType::Spring
                ax += dx * attr.strength
                ay += dy * attr.strength
                az += dz * attr.strength
              end
            end
          end

          # Integrate velocity & position
          case @integrator
          when IntegratorMode::Euler
            p.px += p.vx * dt
            p.py += p.vy * dt
            p.pz += p.vz * dt
            p.vx = (p.vx + ax * dt) * drag_factor
            p.vy = (p.vy + ay * dt) * drag_factor
            p.vz = (p.vz + az * dt) * drag_factor
          when IntegratorMode::SemiImplicitEuler, IntegratorMode::Verlet
            p.vx = (p.vx + ax * dt) * drag_factor
            p.vy = (p.vy + ay * dt) * drag_factor
            p.vz = (p.vz + az * dt) * drag_factor
            p.px += p.vx * dt
            p.py += p.vy * dt
            p.pz += p.vz * dt
          end

          # Apply domain boundaries
          p = apply_bounds(p)
          @particles[i] = p
        end
      end

      private def apply_bounds(p : ParticleState) : ParticleState
        case @bounds.mode
        when BoundaryMode::Bounce
          if p.px < @bounds.min_x
            p.px = @bounds.min_x
            p.vx = -p.vx * @bounds.restitution
          elsif p.px > @bounds.max_x
            p.px = @bounds.max_x
            p.vx = -p.vx * @bounds.restitution
          end

          if p.py < @bounds.min_y
            p.py = @bounds.min_y
            p.vy = -p.vy * @bounds.restitution
          elsif p.py > @bounds.max_y
            p.py = @bounds.max_y
            p.vy = -p.vy * @bounds.restitution
          end

          if p.pz < @bounds.min_z
            p.pz = @bounds.min_z
            p.vz = -p.vz * @bounds.restitution
          elsif p.pz > @bounds.max_z
            p.pz = @bounds.max_z
            p.vz = -p.vz * @bounds.restitution
          end
        when BoundaryMode::Wrap
          span_x = @bounds.max_x - @bounds.min_x
          span_y = @bounds.max_y - @bounds.min_y
          span_z = @bounds.max_z - @bounds.min_z
          p.px += span_x if p.px < @bounds.min_x && span_x > 0
          p.px -= span_x if p.px > @bounds.max_x && span_x > 0
          p.py += span_y if p.py < @bounds.min_y && span_y > 0
          p.py -= span_y if p.py > @bounds.max_y && span_y > 0
          p.pz += span_z if p.pz < @bounds.min_z && span_z > 0
          p.pz -= span_z if p.pz > @bounds.max_z && span_z > 0
        when BoundaryMode::Clamp
          p.px = p.px.clamp(@bounds.min_x, @bounds.max_x)
          p.py = p.py.clamp(@bounds.min_y, @bounds.max_y)
          p.pz = p.pz.clamp(@bounds.min_z, @bounds.max_z)
        when BoundaryMode::Kill
          if p.px < @bounds.min_x || p.px > @bounds.max_x ||
             p.py < @bounds.min_y || p.py > @bounds.max_y ||
             p.pz < @bounds.min_z || p.pz > @bounds.max_z
            p.life = 0.0_f32
            p.scale = 0.0_f32
          end
        end
        p
      end
    end
  end
end
