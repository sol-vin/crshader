# ==============================================================================
# Auto-generated from docs_src by Lapis::Docs::Generator
# DO NOT EDIT MANUALLY - Edit corresponding YAML in docs_src/ instead
# ==============================================================================

{% unless flag?(:release) %}
module CrShader
  module Docs
    module B_LANGUAGE_DSL
      # # Pipeline Stages: Vertex, Fragment & Light
      #
      # Shaders in Godot operate in discrete stages of the GPU rendering pipeline. CRShader models
      # these stages via explicit `stage :name do ... end` blocks, mapping directly to `void vertex()`,
      # `void fragment()`, and `void light()` in the generated GDShader output.
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
      #       <td><strong>Vertex Processing (stage :vertex)</strong></td>
      #       <td><code>.topic_01_vertex_stage</code></td>
      #       <td>Transforming 3D or 2D vertex positions, mesh animation, and custom UVs.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Pixel / Fragment Shading (stage :fragment)</strong></td>
      #       <td><code>.topic_02_fragment_stage</code></td>
      #       <td>Computing per-pixel color, roughness, metallic, normal mapping, and alpha discard.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Custom Lighting Models (stage :light)</strong></td>
      #       <td><code>.topic_03_light_stage</code></td>
      #       <td>Overriding standard PBR lighting with toon/cel shading or custom BRDFs.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # ### Related Guides & Source References
      # - bin/crshader/src/crshader/compiler.cr
      # - bin/crshader/src/crshader/language/stages.cr
      #
      module C_PIPELINE_STAGES
        # **Vertex Processing (stage :vertex)**: Transforming 3D or 2D vertex positions, mesh animation, and custom UVs.
        #
        # The `stage :vertex` block runs once per vertex in the geometry mesh. You can perturb vertex
        # coordinates (e.g. for wave displacement, cloth simulation, or grass wind sway), recompute
        # normals, and set up varying variables:
        #
        # ```crystal
        # stage :vertex do
        #   # Wave displacement along normal
        #   offset = sin(TIME * 2.0 + VERTEX.x * 4.0) * 0.1
        #   VERTEX += NORMAL * offset
        # end
        # ```
        #
        # #### Working Examples
        #
        # ```glsl
        # // Generated GDShader output:
        # void vertex() {
        #     float offset = sin((TIME * 2.0) + (VERTEX.x * 4.0)) * 0.1;
        #     VERTEX += NORMAL * offset;
        # }
        # ```
        #
        def self.topic_01_vertex_stage : Nil
        end

        # **Pixel / Fragment Shading (stage :fragment)**: Computing per-pixel color, roughness, metallic, normal mapping, and alpha discard.
        #
        # The `stage :fragment` block runs once per rasterized pixel (or subpixel sample). In spatial
        # shaders, this stage sets PBR material properties:
        #
        # - `ALBEDO`: Surface diffuse RGB color (`vec3`).
        # - `ALPHA`: Opacity value from 0.0 (transparent) to 1.0 (opaque).
        # - `ROUGHNESS`: Surface microsurface roughness (0.0 = mirror, 1.0 = matte).
        # - `METALLIC`: Conductor vs dielectric ratio (0.0 = plastic/wood, 1.0 = metal).
        # - `NORMAL_MAP`: Tangent-space normal map texture sample.
        # - `NORMAL_MAP_DEPTH`: Intensity of the normal map displacement.
        # - `EMISSION`: Radiance RGB color emitted by the surface.
        #
        # #### Working Examples
        #
        # ```crystal
        # stage :fragment do
        #   albedo_tex = texture(texture_albedo, UV).rgb
        #   ALBEDO = albedo_tex * base_color.rgb
        #   ROUGHNESS = roughness_val
        #   METALLIC = metallic_val
        # end
        # ```
        #
        def self.topic_02_fragment_stage : Nil
        end

        # **Custom Lighting Models (stage :light)**: Overriding standard PBR lighting with toon/cel shading or custom BRDFs.
        #
        # The `stage :light` block runs once per light source affecting the current fragment. If present,
        # it bypasses Godot's built-in PBR lighting calculation, allowing you to implement stylized
        # rendering:
        #
        # ```crystal
        # stage :light do
        #   # Toon / Cel Shading band calculation
        #   n_dot_l = max(dot(NORMAL, LIGHT), 0.0)
        #   band = smoothstep(0.4, 0.45, n_dot_l)
        #   DIFFUSE_LIGHT += LIGHT_COLOR * band * ATTENUATION
        # end
        # ```
        #
        def self.topic_03_light_stage : Nil
        end
      end
    end
  end
end
{% end %}
