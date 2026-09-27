# ==============================================================================
# Auto-generated from docs_src by Lapis::Docs::Generator
# DO NOT EDIT MANUALLY - Edit corresponding YAML in docs_src/ instead
# ==============================================================================

{% unless flag?(:release) %}
module CrShader
  module Docs
    module B_LANGUAGE_DSL
      # # Compositor Passes & Compute Shaders
      #
      # Beyond traditional mesh and surface shaders, CRShader natively supports Godot 4.8's Compositor
      # Effect architecture for post-processing pipelines, as well as general-purpose GLSL compute kernels
      # dispatched via `RenderingDevice`.
      #
      # ### Executive Summary & Key Topics
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Topic</th>
      #       <th>Method / Anchor</th>
      #       <th>Description</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><strong>Compositor Effect Passes</strong></td>
      #       <td><code>.topic_01_compositor_effects</code></td>
      #       <td>Creating multi-pass post-processing filters with CompositorEffect in Godot 4.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Authoring GLSL Compute Kernels</strong></td>
      #       <td><code>.topic_02_compute_kernels</code></td>
      #       <td>Defining workgroups, buffer bindings, and parallel compute logic.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Transpilation to GLSL & Dispatch via RenderingDevice</strong></td>
      #       <td><code>.topic_03_compilation_and_dispatch</code></td>
      #       <td>Compiling .crshader compute kernels to SPIR-V bytecode and executing via Godot's RenderingDevice.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # ### Related Guides & Source References
      # - bin/crshader/src/crshader/compositor/compositor_effect.cr
      # - bin/crshader/src/crshader/compute/compute_kernel.cr
      #
      module D_COMPOSITOR_AND_COMPUTE
        # **Compositor Effect Passes**: Creating multi-pass post-processing filters with CompositorEffect in Godot 4.
        #
        # Godot 4 introduces `CompositorEffect` for inserting custom render passes into the engine's
        # 3D rendering pipeline. CRShader provides high-level helpers to bind input color and depth
        # textures, execute a full-screen quad shader, and write the output buffer:
        #
        # - Kuwahara painterly edge-preserving filters.
        # - CRT phosphor scanlines with barrel distortion.
        # - Custom tonemapping and color grading LUTs.
        # - Screen-space god rays and volumetric bloom.
        #
        # #### Working Examples
        #
        # ```crystal
        # # Screen-space CRT filter
        # shader_type :canvas_item
        # render_mode :unshaded
        #
        # uniform scanline_count : float = 240.0
        # uniform scanline_intensity : float = 0.25
        #
        # stage :fragment do
        #   col = texture(TEXTURE, UV).rgb
        #   scanline = sin(UV.y * scanline_count * TAU) * 0.5 + 0.5
        #   col -= col * scanline * scanline_intensity
        #   COLOR = vec4(col, 1.0)
        # end
        # ```
        #
        def self.topic_01_compositor_effects : Nil
        end

        # **Authoring GLSL Compute Kernels**: Defining workgroups, buffer bindings, and parallel compute logic.
        #
        # Compute shaders perform massively parallel computations independently of rasterization.
        # Declare workgroup sizes and storage buffers using the `:compute` target:
        #
        # ```crystal
        # shader_type :compute
        # workgroup_size x: 8, y: 8, z: 1
        #
        # storage_buffer 0, :particles, layout: :std430 do
        #   positions : Array(vec4)
        #   velocities : Array(vec4)
        # end
        #
        # stage :compute do
        #   idx = gl_GlobalInvocationID.x
        #   positions[idx] += velocities[idx] * delta_time
        # end
        # ```
        #
        def self.topic_02_compute_kernels : Nil
        end

        # **Transpilation to GLSL & Dispatch via RenderingDevice**: Compiling .crshader compute kernels to SPIR-V bytecode and executing via Godot's RenderingDevice.
        #
        # When compiling a compute shader, CRShader generates standard GLSL 450:
        # ```bash
        # crshader build compute_physics.crshader -t glsl -o compute_physics.glsl
        # ```
        # In your Crystal or GDScript game logic, load the compiled shader bytecode, create uniform sets,
        # and dispatch the compute list via `RenderingDevice`:
        # ```crystal
        # rd = Godot::RenderingServer.create_local_rendering_device
        # # Bind buffers, create pipeline, and dispatch workgroups
        # ```
        #
        def self.topic_03_compilation_and_dispatch : Nil
        end
      end
    end
  end
end
{% end %}
