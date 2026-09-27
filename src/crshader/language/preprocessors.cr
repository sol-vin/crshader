# ==============================================================================
# CrShader Language: PreProcessors & Directives Reference
# ==============================================================================

module CrShader
  module Language
    # Compiler directives, storage qualifiers, uniform options, and pipeline flags.
    #
    # This module defines the top-level declarative syntax used in `.crshader` files.
    # During compilation, these directives configure shader targets, memory layouts,
    # and expose properties to the Godot Inspector.
    #
    # ### Basic Example
    # ```crystal
    # shader_type :canvas_item
    # render_mode :unshaded, :blend_mix
    #
    # uniform screen_texture : Sampler2D, hint: :screen_texture, filter: :linear
    # uniform intensity : Float32 = 1.0, hint: hint_range(0.0, 5.0)
    #
    # def fragment
    #   col = screen_texture.sample(SCREEN_UV).rgb
    #   COLOR = vec4(col * intensity, 1.0)
    # end
    # ```
    module PreProcessors
      extend self
      # **Shader Target**: Specifies the operating mode of the shader pipeline.
      #
      # Godot divides shaders into distinct operational categories. Setting `shader_type`
      # selects which built-in variables are accessible and which renderer pipeline executes the code.
      #
      # #### Supported Shader Modes:
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Mode Symbol</th>
      #       <th>Target Pipeline</th>
      #       <th>Applicable Nodes</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><code>:spatial</code></td>
      #       <td>3D spatial rendering pipeline (PBR lighting, vertex displacement)</td>
      #       <td>MeshInstance3D, CSGShape3D, GPUParticles3D</td>
      #     </tr>
      #     <tr>
      #       <td><code>:canvas_item</code></td>
      #       <td>2D canvas rendering pipeline (screen-space, UI, sprites)</td>
      #       <td>Sprite2D, Control, ColorRect, TextureRect, SubViewport</td>
      #     </tr>
      #     <tr>
      #       <td><code>:particles</code></td>
      #       <td>GPU particle simulation and update step</td>
      #       <td>GPUParticles2D, GPUParticles3D</td>
      #     </tr>
      #     <tr>
      #       <td><code>:sky</code></td>
      #       <td>Background radiance and panoramic sky dome renderer</td>
      #       <td>Sky, Environment, WorldEnvironment</td>
      #     </tr>
      #     <tr>
      #       <td><code>:fog</code></td>
      #       <td>3D volumetric fog density and scattering voxel renderer</td>
      #       <td>FogVolume</td>
      #     </tr>
      #     <tr>
      #       <td><code>:compute</code></td>
      #       <td>Vulkan compute shader (GPGPU computation, image processing)</td>
      #       <td>RenderingDevice, Compute pipelines</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # #### Example:
      # ```crystal
      # shader_type :spatial
      # ```
      def shader_type(mode : Symbol) : Nil
      end

      # **Render Modes**: Specifies engine pipeline flags and rendering optimizations.
      #
      # Render modes tell Godot how to configure the hardware rasterizer, blend states,
      # face culling, and depth testing before executing shader stages.
      #
      # #### Spatial Render Modes (<code>:spatial</code>):
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Mode</th>
      #       <th>Description</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr><td><code>:unshaded</code></td><td>Disables all lighting calculations; ALBEDO is drawn directly.</td></tr>
      #     <tr><td><code>:wireframe</code></td><td>Renders geometry in wireframe mode (debug / stylized).</td></tr>
      #     <tr><td><code>:cull_disabled</code></td><td>Disables backface culling; renders both sides of triangles.</td></tr>
      #     <tr><td><code>:cull_front</code></td><td>Culls front faces (renders back faces only, useful for outlines).</td></tr>
      #     <tr><td><code>:cull_back</code></td><td>Culls back faces (standard default).</td></tr>
      #     <tr><td><code>:depth_draw_opaque</code></td><td>Draws depth only for opaque pixels (default).</td></tr>
      #     <tr><td><code>:depth_draw_always</code></td><td>Always writes depth buffer, even for transparent surfaces.</td></tr>
      #     <tr><td><code>:depth_draw_never</code></td><td>Never writes depth buffer.</td></tr>
      #     <tr><td><code>:depth_prepass_alpha</code></td><td>Performs an early depth prepass for alpha testing.</td></tr>
      #     <tr><td><code>:blend_mix</code></td><td>Standard alpha blending: <code>src * alpha + dst * (1 - alpha)</code>.</td></tr>
      #     <tr><td><code>:blend_add</code></td><td>Additive blending: <code>src + dst</code> (fire, lasers, magic effects).</td></tr>
      #     <tr><td><code>:blend_sub</code></td><td>Subtractive blending: <code>dst - src</code>.</td></tr>
      #     <tr><td><code>:blend_mul</code></td><td>Multiplicative blending: <code>src * dst</code> (shadows, decals).</td></tr>
      #     <tr><td><code>:fog_disabled</code></td><td>Ignores volumetric and environmental fog.</td></tr>
      #     <tr><td><code>:shadows_disabled</code></td><td>Surface neither receives nor casts real-time shadows.</td></tr>
      #   </tbody>
      # </table>
      #
      # #### CanvasItem Render Modes (<code>:canvas_item</code>):
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Mode</th>
      #       <th>Description</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr><td><code>:unshaded</code></td><td>Disables 2D canvas lighting.</td></tr>
      #     <tr><td><code>:blend_mix</code></td><td>Standard 2D alpha blending.</td></tr>
      #     <tr><td><code>:blend_add</code></td><td>2D additive glow blending.</td></tr>
      #     <tr><td><code>:blend_sub</code></td><td>2D subtractive blending.</td></tr>
      #     <tr><td><code>:blend_mul</code></td><td>2D multiplicative blending.</td></tr>
      #     <tr><td><code>:blend_premul_alpha</code></td><td>Pre-multiplied alpha blending.</td></tr>
      #     <tr><td><code>:skip_vertex_transform</code></td><td>Bypasses engine modelview transformation in vertex stage.</td></tr>
      #   </tbody>
      # </table>
      #
      # #### Example:
      # ```crystal
      # render_mode :unshaded, :cull_disabled, :depth_draw_always
      # ```
      def render_mode(*modes : Symbol) : Nil
      end

      # **Compatibility Setup**: Enables standard Godot GDShader macros and compatibility helpers.
      #
      # Synthesizes helper definitions allowing smooth interoperation with legacy Godot shaders.
      def setup_gdshader : Nil
      end

      # **Workgroup Layout**: Specifies compute shader local invocation workgroup size.
      #
      # Transpiled to GLSL <code>layout(local_size_x = X, local_size_y = Y, local_size_z = Z) in;</code>.
      #
      # #### Parameters:
      # - `x`: Number of invocations in the X dimension (default: 8).
      # - `y`: Number of invocations in the Y dimension (default: 8).
      # - `z`: Number of invocations in the Z dimension (default: 1).
      #
      # #### Example:
      # ```crystal
      # shader_type :compute
      # local_size 16, 16, 1
      # ```
      def local_size(x : Int32 = 8, y : Int32 = 8, z : Int32 = 1) : Nil
      end

      # **Material Uniform**: Declares a variable exposed to the Godot Inspector and script API.
      #
      # Uniforms allow runtime scripts and material properties in the editor to pass values into the shader.
      #
      # #### Inspector Hints & Options:
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Option</th>
      #       <th>Type</th>
      #       <th>Description</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr><td><code>hint: :source_color</code></td><td>Color / Vec4</td><td>Displays a color picker and converts sRGB to linear color space.</td></tr>
      #     <tr><td><code>hint: hint_range(min, max, step)</code></td><td>Float32 / Int32</td><td>Renders a slider with custom bounds and step granularity.</td></tr>
      #     <tr><td><code>hint: :screen_texture</code></td><td>Sampler2D</td><td>Binds the current viewport rendered screen texture.</td></tr>
      #     <tr><td><code>hint: :depth_texture</code></td><td>Sampler2D</td><td>Binds the linear / non-linear depth buffer texture.</td></tr>
      #     <tr><td><code>hint: :normal_roughness_texture</code></td><td>Sampler2D</td><td>Binds the screen-space normal and roughness buffer.</td></tr>
      #     <tr><td><code>hint: :white</code> / <code>:black</code></td><td>Sampler2D</td><td>Provides a fallback solid white or solid black texture if unassigned.</td></tr>
      #     <tr><td><code>filter: :nearest</code> / <code>:linear</code></td><td>Sampler2D</td><td>Specifies texture pixel interpolation mode.</td></tr>
      #     <tr><td><code>filter: :nearest_mipmap</code> / <code>:linear_mipmap</code></td><td>Sampler2D</td><td>Enables mipmap sampling for textures.</td></tr>
      #     <tr><td><code>repeat: :enable</code> / <code>:disable</code></td><td>Sampler2D</td><td>Specifies texture UV tiling and repeating mode.</td></tr>
      #     <tr><td><code>group: "Name"</code></td><td>String</td><td>Places the property inside an inspector accordion group.</td></tr>
      #     <tr><td><code>subgroup: "Name"</code></td><td>String</td><td>Places the property inside an inspector subgroup.</td></tr>
      #   </tbody>
      # </table>
      #
      # #### Examples:
      # ```crystal
      # uniform albedo : Color = Color.new(1.0, 0.5, 0.2, 1.0), hint: :source_color
      # uniform wave_speed : Float32 = 2.5, hint: hint_range(0.0, 10.0, 0.1)
      # uniform roughness : Float32 = 0.5, hint: hint_range(0.0, 1.0)
      # uniform base_texture : Sampler2D, filter: :linear_mipmap, repeat: :enable
      # uniform bone_matrices : Mat4[64] # Array uniform
      # ```
      macro uniform(declaration, **options)
      end

      # **Instance Uniform**: Declares a per-instance uniform stored in InstanceData.
      #
      # Instance uniforms allow multiple nodes sharing the same material (e.g. `MultiMeshInstance3D`
      # or multiple `MeshInstance3D` nodes) to have unique values without duplicating the material.
      #
      # Transpiled to Godot's <code>instance uniform ...</code>.
      #
      # #### Example:
      # ```crystal
      # instance_uniform custom_tint : Color = Color.new(1.0, 1.0, 1.0, 1.0), hint: :source_color
      # instance_uniform instance_offset : Vec3 = vec3(0.0, 0.0, 0.0)
      # ```
      macro instance_uniform(declaration, **options)
      end

      # **Global Uniform**: Declares a project-wide global uniform registered in Project Settings.
      #
      # Global uniforms (Godot 4.x) are shared across all materials in the game simultaneously
      # with zero CPU overhead. Useful for wind direction, player position, or time of day.
      #
      # Transpiled to Godot's <code>global uniform ...</code>.
      #
      # #### Example:
      # ```crystal
      # global_uniform global_wind_dir : Vec3
      # global_uniform global_water_level : Float32
      # ```
      macro global_uniform(declaration, **options)
      end

      # **Varying Variable**: Declares an interpolated variable passed between shader stages.
      #
      # Varying variables are calculated in the `vertex` processor and smoothly interpolated
      # across polygon faces before arriving at the `fragment` or `light` processors.
      #
      # #### Interpolation Qualifiers:
      # - `:smooth`: Standard perspective-correct interpolation (default).
      # - `:flat`: No interpolation; uses the value from the primitive's first vertex.
      #
      # #### Example:
      # ```crystal
      # varying v_world_pos : Vec3
      # varying v_normal : Vec3, qualifier: :smooth
      # varying v_tile_id : Int32, qualifier: :flat
      #
      # def vertex
      #   v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz
      #   v_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz
      # end
      #
      # def fragment
      #   dist = length(v_world_pos)
      # end
      # ```
      macro varying(declaration, **options)
      end

      # **Compile-Time Constant**: Declares a static compile-time constant.
      #
      # Evaluated and emitted as a `const` expression in the target shader.
      #
      # #### Example:
      # ```crystal
      # const PI = 3.14159265359_f32
      # const MAX_LIGHTS = 8
      # ```
      macro const(declaration)
      end

      # Alias for `const`.
      macro constant(declaration)
      end

      # **Shader Storage Buffer (SSBO)**: Declares a structured storage buffer for compute and storage.
      #
      # Transpiled to Vulkan GLSL <code>layout(std430, set = X, binding = Y) buffer ...</code>.
      #
      # #### Options:
      # - `set`: Vulkan descriptor set index (default: 0).
      # - `binding`: Vulkan descriptor binding slot index (default: 0).
      # - `std`: Memory layout standard (`"std430"` or `"std140"`, default: `"std430"`).
      # - `restrict`: Informs compiler that memory does not alias other pointers.
      # - `readonly`: Marks the buffer as read-only for hardware caching optimizations.
      #
      # #### Example:
      # ```crystal
      # buffer ParticleBuffer, set: 0, binding: 0, std: "std430" do
      #   particles : ParticleData[]
      # end
      # ```
      macro buffer(name, **options, &block)
      end

      # **Push Constant Block**: Declares a low-latency Vulkan push constant block.
      #
      # Push constants are stored directly in GPU command registers for maximum transmission speed.
      #
      # #### Example:
      # ```crystal
      # push_constant FrameUniforms do
      #   delta_time : Float32
      #   screen_size : Vec2
      # end
      # ```
      macro push_constant(name, **options, &block)
      end

      # **Workgroup Shared Memory**: Declares memory shared among compute threads in a workgroup.
      #
      # Accessible to all invocations in the current local workgroup. Much faster than VRAM.
      #
      # #### Example:
      # ```crystal
      # shared tile_cache : UInt32[256]
      # ```
      macro shared(declaration)
      end

      # **Image Uniform**: Declares a direct read/write texture image binding for compute shaders.
      #
      # Enables direct pixel access via `imageLoad` and `imageStore`.
      #
      # #### Options:
      # - `format`: Vulkan pixel format (`:rgba32f`, `:rgba16f`, `:r32f`, `:r32ui`, default: `:rgba32f`).
      # - `set`: Vulkan descriptor set index (default: 0).
      # - `binding`: Vulkan descriptor binding index (default: 0).
      #
      # #### Example:
      # ```crystal
      # image2d input_tex, format: :rgba32f, set: 0, binding: 0
      # image2d output_tex, format: :rgba32f, set: 0, binding: 1
      # ```
      macro image2d(name, **options)
      end

      # **Inspector Group**: Groups subsequent uniforms under a categorized accordion section.
      #
      # #### Example:
      # ```crystal
      # group "Water Dynamics"
      # uniform wave_height : Float32 = 0.5
      # uniform wave_speed : Float32 = 1.0
      # ```
      def group(name : String) : Nil
      end

      # **Inspector Subgroup**: Groups subsequent uniforms under an inspector subsection.
      #
      # #### Example:
      # ```crystal
      # subgroup "Foam Parameters"
      # uniform foam_color : Color = Color.new(1.0, 1.0, 1.0, 1.0)
      # uniform foam_threshold : Float32 = 0.8
      # ```
      def subgroup(name : String) : Nil
      end

      # **Module Inclusion**: Imports standard library routines or local shader definitions.
      #
      # #### Available Standard Library Modules:
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Module Path</th>
      #       <th>Included Features</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr><td><code>"std/math"</code></td><td>saturate, lerp, remap, rotate_2d, fresnel, rand</td></tr>
      #     <tr><td><code>"std/noise"</code></td><td>hash11..33, value_noise, voronoi, simplex_noise_2d, fbm</td></tr>
      #     <tr><td><code>"std/color"</code></td><td>hsv2rgb, rgb2hsv, grayscale, adjust_contrast, adjust_saturation</td></tr>
      #     <tr><td><code>"std/lighting"</code></td><td>cel_shade, blinn_phong</td></tr>
      #     <tr><td><code>"std/sdf"</code></td><td>sdf_sphere, sdf_box, smin, smax</td></tr>
      #     <tr><td><code>"std/tonemap"</code></td><td>aces_tonemap, reinhard_tonemap</td></tr>
      #     <tr><td><code>"std/triplanar"</code></td><td>triplanar_weights</td></tr>
      #     <tr><td><code>"std/post_processing"</code></td><td>linear_depth, luminance, barrel_distortion, vignette</td></tr>
      #   </tbody>
      # </table>
      #
      # #### Example:
      # ```crystal
      # require "std/noise"
      # require "std/lighting"
      # ```
      macro require(path)
      end

      # Alias for `require`.
      macro include(path)
      end
    end
  end
end
