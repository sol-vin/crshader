# ==============================================================================
# CrShader Language: Pipeline Stages & Processors Reference
# ==============================================================================

module CrShader
  module Language
    # Shader execution stages and processor functions.
    #
    # Godot executes shaders across dedicated hardware stages. In CrShader, stages can be
    # declared using either standard Crystal method syntax (`def fragment ... end`) or
    # block DSL syntax (`fragment do ... end`).
    #
    # ### Basic Example
    # ```crystal
    # shader_type :spatial
    #
    # def vertex
    #   VERTEX.y += sin(TIME + VERTEX.x) * 0.1
    # end
    #
    # def fragment
    #   ALBEDO = vec3(0.2, 0.6, 1.0)
    #   ROUGHNESS = 0.1
    # end
    # ```
    module Stages
      extend self
      # **Vertex Stage**: Processor executed once per vertex primitive.
      #
      # Executed on the GPU vertex shader unit. Used to transform geometry, displace vertices,
      # animate meshes via wave equations or bone weights, calculate normals/tangents, and pass
      # interpolated values to the fragment stage via `varying`.
      #
      # #### Built-in Variables Available:
      # - 3D Spatial: `VERTEX`, `NORMAL`, `TANGENT`, `BINORMAL`, `UV`, `UV2`, `COLOR`, `MODELVIEW_MATRIX`, `PROJECTION_MATRIX`, `POINT_SIZE`.
      # - 2D CanvasItem: `VERTEX`, `UV`, `COLOR`, `POINT_SIZE`, `TEXTURE_PIXEL_SIZE`.
      #
      # #### Note:
      # GDShader prohibits early `return` statements inside processor functions.
      #
      # #### Example:
      # ```crystal
      # def vertex
      #   world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz
      #   VERTEX.y += sin(TIME * 2.0 + world_pos.x) * 0.2
      # end
      # ```
      def vertex(&block) : Nil
      end

      # **Fragment Stage**: Processor executed once per rasterized pixel (fragment).
      #
      # Executed on the GPU pixel/fragment unit. Used to calculate final surface albedo,
      # roughness, metallic, normal mapping, emission, transmission, or 2D canvas color.
      #
      # #### Built-in Variables Available:
      # - 3D Spatial: `ALBEDO`, `ALPHA`, `ROUGHNESS`, `METALLIC`, `SPECULAR`, `NORMAL_MAP`, `NORMAL_MAP_DEPTH`, `EMISSION`, `AO`, `RIM`, `CLEARCOAT`, `SSS_STRENGTH`, `BACKLIGHT`.
      # - 2D CanvasItem: `COLOR`, `UV`, `SCREEN_UV`, `POINT_COORD`, `FRAGCOORD`.
      #
      # #### Example:
      # ```crystal
      # def fragment
      #   col = texture(main_texture, UV).rgb
      #   ALBEDO = col
      #   ROUGHNESS = 0.4
      #   METALLIC = 0.8
      # end
      # ```
      def fragment(&block) : Nil
      end

      # **Light Stage**: Processor executed once per active light source affecting the fragment.
      #
      # Executed for each OmniLight3D, SpotLight3D, or DirectionalLight3D intersecting the surface.
      # Used to implement custom lighting models such as toon shading, cel shading, anisotropic hair,
      # or custom subsurface scattering models.
      #
      # #### Built-in Variables Available:
      # - `LIGHT`: Direction vector to the light source.
      # - `LIGHT_COLOR`: Radiance color and intensity of the light.
      # - `ATTENUATION`: Combined distance attenuation and shadow factor.
      # - `ALBEDO`, `NORMAL`, `ROUGHNESS`, `SPECULAR`, `VIEW`.
      # - `DIFFUSE_LIGHT`, `SPECULAR_LIGHT`: Accumulator outputs.
      #
      # #### Example:
      # ```crystal
      # def light
      #   n_dot_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0)
      #   cel = floor(n_dot_l * 3.0) / 3.0
      #   DIFFUSE_LIGHT += LIGHT_COLOR * ALBEDO * cel * ATTENUATION
      # end
      # ```
      def light(&block) : Nil
      end

      # **Particle Start Stage**: Processor executed when a GPU particle spawns or restarts.
      #
      # Used in `shader_type :particles` to assign initial particle transforms, velocities,
      # colors, scales, rotations, and custom random data attributes.
      #
      # #### Built-in Variables Available:
      # - `TRANSFORM`: 4x4 matrix position and orientation.
      # - `VELOCITY`: Linear velocity vector.
      # - `CUSTOM`: 4-component user-defined payload vector.
      # - `COLOR`: Initial particle tint color.
      # - `LIFETIME`: Total simulation duration.
      # - `SEED`, `INDEX`, `NUMBER`.
      #
      # #### Example:
      # ```crystal
      # def start
      #   VELOCITY = vec3(0.0, 5.0, 0.0) + vec3(hash11(float(INDEX)), 0.0, 0.0)
      #   COLOR = vec4(1.0, 0.6, 0.1, 1.0)
      # end
      # ```
      def start(&block) : Nil
      end

      # **Particle Process Stage**: Processor executed every frame step for active GPU particles.
      #
      # Used in `shader_type :particles` to update particle physics, apply gravitational forces,
      # curl noise turbulence, angular rotation, collision responses, and color fading over time.
      #
      # #### Built-in Variables Available:
      # - `TRANSFORM`: Current transform matrix.
      # - `VELOCITY`: Current velocity vector.
      # - `CUSTOM`: User-defined payload vector.
      # - `DELTA`: Simulation frame time delta in seconds.
      # - `ACTIVE`: Boolean indicating whether particle continues living.
      #
      # #### Example:
      # ```crystal
      # def process
      #   VELOCITY.y -= 9.8 * DELTA # Gravity
      #   TRANSFORM[3].xyz += VELOCITY * DELTA
      # end
      # ```
      def process(&block) : Nil
      end

      # **Sky Stage**: Processor executed for background sky radiance rendering.
      #
      # Used in `shader_type :sky` to render procedural sky atmospheres, stars, clouds,
      # sun discs, and panoramic environment maps.
      #
      # #### Built-in Variables Available:
      # - `EYEDIR`: Direction vector from camera looking into the sky dome.
      # - `SKY_COORDS`: Equirectangular coordinates on the celestial sphere.
      # - `LIGHT0_DIRECTION`, `LIGHT0_COLOR`, `LIGHT0_ENERGY`, `LIGHT0_ENABLED`.
      # - `HALF_RES_COLOR`, `QUARTER_RES_COLOR`: Downsampled background samples.
      # - `COLOR`: Final output radiance color.
      #
      # #### Example:
      # ```crystal
      # def sky
      #   sun_disc = clamp(dot(EYEDIR, LIGHT0_DIRECTION), 0.0, 1.0) ** 64.0
      #   COLOR = mix(vec3(0.2, 0.4, 0.8), vec3(1.0, 0.9, 0.5), sun_disc)
      # end
      # ```
      def sky(&block) : Nil
      end

      # **Fog Stage**: Processor executed for volumetric fog voxels and SDF scattering.
      #
      # Used in `shader_type :fog` to compute 3D volumetric fog density, volumetric lighting,
      # ambient phase functions, and signed-distance-field (SDF) interactions.
      #
      # #### Built-in Variables Available:
      # - `WORLD_POSITION`: 3D world coordinates of the fog voxel.
      # - `SDF`: Distance to nearest solid geometry.
      # - `SDF_NORMAL`: Gradient normal of the signed distance field.
      # - `DENSITY`: Output fog extinction density factor.
      # - `FOG_COLOR`: Output scattering and emissive color.
      #
      # #### Example:
      # ```crystal
      # def fog
      #   DENSITY = clamp(0.1 + sin(WORLD_POSITION.x * 0.5) * 0.05, 0.0, 1.0)
      #   FOG_COLOR = vec4(0.8, 0.85, 0.9, 1.0)
      # end
      # ```
      def fog(&block) : Nil
      end

      # **Compute Kernel**: Main entry point for Vulkan compute shaders.
      #
      # Executed across local workgroups for GPGPU general-purpose computing, GPU particles,
      # image processing, compute blur, and physical simulation.
      #
      # #### Built-in Variables Available:
      # - `gl_GlobalInvocationID`: Global 3D index across the entire dispatch grid.
      # - `gl_LocalInvocationID`: Local 3D index within the current workgroup.
      # - `gl_WorkGroupID`: 3D index of the active workgroup.
      # - `gl_NumWorkGroups`: Total number of workgroups dispatched.
      # - `gl_LocalInvocationIndex`: Linearized 1D index within the workgroup.
      #
      # #### Example:
      # ```crystal
      # def main
      #   coord = ivec2(gl_GlobalInvocationID.xy)
      #   pixel = imageLoad(input_image, coord)
      #   imageStore(output_image, coord, pixel * 1.5)
      # end
      # ```
      def main(&block) : Nil
      end
    end
  end
end
