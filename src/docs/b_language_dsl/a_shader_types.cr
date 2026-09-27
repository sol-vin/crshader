# ==============================================================================
# Auto-generated from docs_src by Lapis::Docs::Generator
# DO NOT EDIT MANUALLY - Edit corresponding YAML in docs_src/ instead
# ==============================================================================

{% unless flag?(:release) %}
module CrShader
  module Docs
    module B_LANGUAGE_DSL
      # # Shader Types & Render Modes
      #
      # CRShader supports all Godot 4 shader types (`canvas_item`, `spatial`, `particles`, `sky`, `fog`)
      # as well as GLSL compute kernels. The shader type and render modes determine the target graphics
      # pipeline, available built-in variables, and execution context.
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
      #       <td><strong>Declaring Shader Types</strong></td>
      #       <td><code>.topic_01_shader_types</code></td>
      #       <td>The shader_type directive and supported graphics domains.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Render Modes & Pipeline Flags</strong></td>
      #       <td><code>.topic_02_render_modes</code></td>
      #       <td>Configuring pipeline flags such as unshaded, blend modes, depth draw, and culling.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # ### Related Guides & Source References
      # - bin/crshader/src/crshader/ast/types.cr
      # - bin/crshader/src/crshader/language/shader_types.cr
      #
      module A_SHADER_TYPES
        # **Declaring Shader Types**: The shader_type directive and supported graphics domains.
        #
        # Every `.crshader` file begins with a `shader_type` declaration:
        #
        # - `:canvas_item`: 2D rendering for UI, Sprites, TileMaps, and 2D post-processing.
        # - `:spatial`: 3D rendering for meshes, models, terrain, and PBR surfaces.
        # - `:particles`: GPU-accelerated particle simulation (2D or 3D).
        # - `:sky`: Custom skyboxes, atmospheric scattering, and panoramic backgrounds.
        # - `:fog`: Volumetric fog shading for atmospheric 3D environments.
        # - `:compute`: Parallel GPU compute kernels running arbitrary arithmetic or image processing.
        #
        # #### Working Examples
        #
        # ```crystal
        # # 2D Shader
        # shader_type :canvas_item
        #
        # # 3D Spatial Shader
        # shader_type :spatial
        #
        # # Compute Kernel
        # shader_type :compute
        # ```
        #
        def self.topic_01_shader_types : Nil; end

        # **Render Modes & Pipeline Flags**: Configuring pipeline flags such as unshaded, blend modes, depth draw, and culling.
        #
        # Render modes modify the default behavior of Godot's rendering pipeline. Multiple render modes
        # can be declared on a single line or across multiple statements:
        #
        # - `render_mode :unshaded`: Disables lighting calculations; fragment output is treated as direct RGB color.
        # - `render_mode :blend_add`, `:blend_sub`, `:blend_mul`: Non-standard alpha blending equations.
        # - `render_mode :cull_disabled`, `:cull_front`, `:cull_back`: Polygon face culling rules.
        # - `render_mode :depth_draw_always`, `:depth_draw_never`: Custom depth buffer writing behavior.
        # - `render_mode :world_vertex_coords`: Forces vertex processing in global world coordinates instead of local object space.
        #
        # #### Working Examples
        #
        # ```crystal
        # shader_type :spatial
        # render_mode :unshaded, :cull_disabled, :depth_draw_always
        # ```
        #
        def self.topic_02_render_modes : Nil; end
      end
    end
  end
end
{% end %}
