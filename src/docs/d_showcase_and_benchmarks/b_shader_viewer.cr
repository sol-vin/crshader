# ==============================================================================
# Auto-generated from docs_src by Lapis::Docs::Generator
# DO NOT EDIT MANUALLY - Edit corresponding YAML in docs_src/ instead
# ==============================================================================

{% unless flag?(:release) %}
module CrShader
  module Docs
    module D_SHOWCASE_AND_BENCHMARKS
      # # Interactive Shader Viewer & Sandbox
      #
      # CRShader bundles two standalone interactive applications: the **Shader Viewer** (a gallery
      # inspecting 20+ shaders on various 3D primitives and screen quads) and the **Live Shader Sandbox**
      # (a split-screen live coding environment).
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
      #       <td><strong>Shader Viewer Showcase</strong></td>
      #       <td><code>.topic_01_shader_viewer</code></td>
      #       <td>Exploring the bundled gallery of 20+ procedural shaders across 3D meshes and post-processing.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Split-Screen Live Shader Sandbox</strong></td>
      #       <td><code>.topic_02_live_sandbox</code></td>
      #       <td>Live in-game shader authoring environment with real-time viewport feedback.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # ### Related Guides & Source References
      # - bin/crshader/examples/shader_viewer
      # - bin/crshader/examples/shader_sandbox
      # - bin/crshader/Makefile
      #
      module B_SHADER_VIEWER
        # **Shader Viewer Showcase**: Exploring the bundled gallery of 20+ procedural shaders across 3D meshes and post-processing.
        #
        # The Shader Viewer demonstrates real-world CRShader applications across a rich variety of techniques:
        #
        # - **Water & Fluid Simulation**: Dynamic foam lines, refraction, and vertex wave displacement.
        # - **Stylized & Retro**: PSX affine texture warping, vertex snapping, dithering, and CRT phosphor scanlines.
        # - **Painterly Post-Processing**: Kuwahara edge-preserving blur and oil-painting effects.
        # - **Procedural Volumetrics**: Raymarched clouds, fire particles, and plasma spheres.
        #
        # Launch the viewer with:
        # ```bash
        # make viewer
        # ```
        #
        def self.topic_01_shader_viewer : Nil
        end

        # **Split-Screen Live Shader Sandbox**: Live in-game shader authoring environment with real-time viewport feedback.
        #
        # The Shader Sandbox provides an in-game live coding environment:
        #
        # - Left pane contains an embedded text editor with live syntax coloring.
        # - Right viewport renders the active scene in real time (2D canvas, 3D mesh, or screen quad).
        # - Bottom bar provides quick presets to load sample shaders or switch 3D meshes (Cube, Sphere, Cylinder, Torus, Prism, Plane).
        # - Parameter sliders allow live uniform adjustments with immediate GPU visual updates.
        #
        # Launch the sandbox with:
        # ```bash
        # make sandbox
        # ```
        #
        def self.topic_02_live_sandbox : Nil
        end
      end
    end
  end
end
{% end %}
