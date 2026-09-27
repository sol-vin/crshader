# ==============================================================================
# CrShader Language: Engine Built-in Variables Reference
# ==============================================================================

module CrShader
  module Language
    # Built-in variables provided by the Godot Engine for each shader mode and processor stage.
    #
    # Mirrored directly from the Godot Engine 4.8 Shading Reference.
    module Builtins
      # Built-in variables available in 2D CanvasItem shaders (`shader_type :canvas_item`).
      module CanvasItem
        # Input vertex position in 2D space (vertex processor, read-write) or fragment position (fragment processor, read-only).
        VERTEX = Types::Vec2.new
        # Normalized texture coordinate (UV) in range [0.0, 1.0].
        UV = Types::Vec2.new
        # Output color for fragment stage, or vertex color in vertex stage.
        COLOR = Types::Vec4.new
        # Screen-space UV coordinate in range [0.0, 1.0] for sampling `screen_texture`.
        SCREEN_UV = Types::Vec2.new
        # Normalized point coordinate within a point sprite [0.0, 1.0].
        POINT_COORD = Types::Vec2.new
        # Point size in pixels when rendering point primitives (vertex stage).
        POINT_SIZE = 1.0_f32
        # Size of a single pixel in the base texture: `vec2(1.0 / width, 1.0 / height)`.
        TEXTURE_PIXEL_SIZE = Types::Vec2.new
        # Size of a single pixel on the screen: `vec2(1.0 / viewport_width, 1.0 / viewport_height)`.
        SCREEN_PIXEL_SIZE = Types::Vec2.new
        # Window-relative fragment coordinates: `(x, y, z=depth, w=1/w)`.
        FRAGCOORD = Types::Vec4.new
        # Global game elapsed time in seconds.
        TIME = 0.0_f32
        # Screen depth texture reading coordinate.
        SPECULAR_SHININESS = Types::Vec4.new
      end

      # Built-in variables available in 3D Spatial shaders (`shader_type :spatial`).
      module Spatial
        # Vertex position in model/view space (vertex stage: read-write; fragment stage: read-only view position).
        VERTEX = Types::Vec3.new
        # Normal vector perpendicular to surface in model/view space.
        NORMAL = Types::Vec3.new
        # Tangent vector orthogonal to normal in model/view space.
        TANGENT = Types::Vec3.new
        # Binormal (bitangent) vector perpendicular to normal and tangent.
        BINORMAL = Types::Vec3.new
        # Primary texture coordinates [0.0, 1.0].
        UV = Types::Vec2.new
        # Secondary texture coordinates for lightmapping or detail textures.
        UV2 = Types::Vec2.new
        # Diffuse albedo surface color in range [0.0, 1.0].
        ALBEDO = Types::Vec3.new
        # Opacity / transparency channel in range [0.0, 1.0].
        ALPHA = 1.0_f32
        # Alpha scissor threshold value for alpha-tested materials.
        ALPHA_SCISSOR_THRESHOLD = 0.5_f32
        # Alpha hash scale factor for hashed alpha testing.
        ALPHA_HASH_SCALE = 1.0_f32
        # Surface roughness microfacet factor [0.0, 1.0]. 0 = mirror smooth, 1 = rough diffuse.
        ROUGHNESS = 1.0_f32
        # Metallic dielectric/conductor blend factor [0.0, 1.0]. 0 = dielectric, 1 = metal.
        METALLIC = 0.0_f32
        # Specular reflectivity coefficient for dielectrics (default: 0.5 = 4% reflectivity).
        SPECULAR = 0.5_f32
        # Emissive light color emitted by surface, added to scene radiance.
        EMISSION = Types::Vec3.new
        # Normal map vector unpacked from tangent space texture.
        NORMAL_MAP = Types::Vec3.new
        # Depth scale multiplier for normal map perturbation.
        NORMAL_MAP_DEPTH = 1.0_f32
        # Rim lighting intensity factor.
        RIM = 0.0_f32
        # Tint color blend for rim lighting.
        RIM_TINT = 0.5_f32
        # Secondary clearcoat specular reflection lobe intensity.
        CLEARCOAT = 0.0_f32
        # Roughness of secondary clearcoat layer.
        CLEARCOAT_ROUGHNESS = 0.0_f32
        # Anisotropic highlight direction and flow factor.
        ANISOTROPY = 0.0_f32
        # Anisotropic tangent flow vector.
        ANISOTROPY_FLOW = Types::Vec2.new
        # Ambient occlusion darkening factor [0.0, 1.0].
        AO = 1.0_f32
        # Subsurface scattering strength coefficient.
        SSS_STRENGTH = 0.0_f32
        # Translucent light transmission through thin backfaces.
        TRANSMISSION = Types::Vec3.new
        # Backlight illumination factor.
        BACKLIGHT = Types::Vec3.new
        # Screen-space UV coordinate in range [0.0, 1.0].
        SCREEN_UV = Types::Vec2.new
        # Window-relative fragment coordinates: `(x, y, z=depth, w=1/w)`.
        FRAGCOORD = Types::Vec4.new
        # True if the current primitive is facing towards the camera.
        FRONT_FACING = true
        # Model to world coordinate transformation matrix.
        MODEL_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
        # World to camera view space transformation matrix.
        VIEW_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
        # Camera view space to clip space projection matrix.
        PROJECTION_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
        # Combined modelview matrix: `VIEW_MATRIX * MODEL_MATRIX`.
        MODELVIEW_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
        # Inverse camera view matrix: transforms from camera space back to world space.
        INV_VIEW_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
        # Inverse camera projection matrix: transforms from clip space back to view space.
        INV_PROJECTION_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
        # Global game elapsed time in seconds.
        TIME = 0.0_f32
        # Normalized camera view direction in camera space.
        VIEW = Types::Vec3.new(0.0_f32, 0.0_f32, -1.0_f32)
        # Incident light direction vector (light processor only).
        LIGHT = Types::Vec3.new
        # Radiance color of the light source (light processor only).
        LIGHT_COLOR = Types::Vec3.new
        # Attenuation factor for the light source (light processor only).
        ATTENUATION = 1.0_f32
        # Diffuse light output accumulator (light processor only).
        DIFFUSE_LIGHT = Types::Vec3.new
        # Specular light output accumulator (light processor only).
        SPECULAR_LIGHT = Types::Vec3.new
      end

      # Built-in variables available in Particle shaders (`shader_type :particles`).
      module Particles
        # 4x4 transform matrix representing position, rotation, and scale of the particle.
        TRANSFORM = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
        # Linear velocity vector of the particle in units per second.
        VELOCITY = Types::Vec3.new
        # 4-component custom user attribute vector associated with the particle.
        CUSTOM = Types::Vec4.new
        # Tint color of the particle.
        COLOR = Types::Vec4.new
        # Particle mass multiplier for physics and forces.
        MASS = 1.0_f32
        # True if the particle is currently active and alive in the simulation.
        ACTIVE = true
        # True on the first simulation frame when a particle is spawned or restarted.
        RESTART = false
        # Total lifetime duration of the particle in seconds.
        LIFETIME = 1.0_f32
        # Frame delta time step in seconds.
        DELTA = 0.016666_f32
        # Unique zero-based integer index of this particle instance.
        INDEX = 0_u32
        # Total count of particles in the emitter.
        NUMBER = 100_u32
        # Deterministic pseudo-random seed assigned to this particle.
        SEED = 0_u32
      end

      # Built-in variables available in Sky shaders (`shader_type :sky`).
      module Sky
        # Normalized view direction vector looking out into the sky dome.
        EYEDIR = Types::Vec3.new
        # Equirectangular spherical coordinates on the sky sphere.
        SKY_COORDS = Types::Vec2.new
        # Half-resolution background radiance sample.
        HALF_RES_COLOR = Types::Vec4.new
        # Quarter-resolution background radiance sample.
        QUARTER_RES_COLOR = Types::Vec4.new
        # Direction vector pointing towards the primary directional light (sun).
        LIGHT0_DIRECTION = Types::Vec3.new
        # Radiance color of the primary directional light.
        LIGHT0_COLOR = Types::Vec3.new
        # Energy multiplier of the primary directional light.
        LIGHT0_ENERGY = 1.0_f32
        # True if the primary directional light is enabled.
        LIGHT0_ENABLED = true
        # Output color for the sky fragment.
        COLOR = Types::Vec3.new
      end

      # Built-in variables available in Volumetric Fog shaders (`shader_type :fog`).
      module Fog
        # World-space coordinate of the current fog voxel.
        WORLD_POSITION = Types::Vec3.new
        # Output color and emission for the volumetric fog voxel.
        FOG_COLOR = Types::Vec4.new
        # Volumetric extinction density for the fog voxel.
        DENSITY = 0.0_f32
        # Signed distance field (SDF) distance to the nearest scene geometry.
        SDF = 0.0_f32
        # Surface normal gradient derived from the signed distance field.
        SDF_NORMAL = Types::Vec3.new
      end

      # Built-in variables available in Vulkan Compute shaders (`shader_type :compute`).
      module Compute
        # Global 3D invocation index across the entire dispatch: `uvec3(x, y, z)`.
        gl_GlobalInvocationID = Types::UVec3.new
        # Local 3D invocation index within the current workgroup.
        gl_LocalInvocationID = Types::UVec3.new
        # 3D index of the active workgroup.
        gl_WorkGroupID = Types::UVec3.new
        # Total number of workgroups dispatched across X, Y, and Z dimensions.
        gl_NumWorkGroups = Types::UVec3.new
        # Linear 1D index of the invocation within the workgroup: `0..size-1`.
        gl_LocalInvocationIndex = 0_u32
      end
    end
  end
end
