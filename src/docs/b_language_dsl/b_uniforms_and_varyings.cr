# ==============================================================================
# Auto-generated from docs_src by Lapis::Docs::Generator
# DO NOT EDIT MANUALLY - Edit corresponding YAML in docs_src/ instead
# ==============================================================================

{% unless flag?(:release) %}
module CrShader
  module Docs
    module B_LANGUAGE_DSL
      # # Uniforms, Varyings & Built-In Variables
      #
      # Uniforms allow CPU code or the Godot Inspector to feed parameters into the shader. Varyings pass
      # interpolated data from vertex to fragment stages. Built-ins provide direct access to engine
      # constants such as time, resolution, texture coordinates, and matrices.
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
      #       <td><strong>Declaring Typed Uniforms & Inspector Hints</strong></td>
      #       <td><code>.topic_01_uniform_declarations</code></td>
      #       <td>Syntax for scalar, vector, matrix, and texture uniforms with Godot Inspector hints.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Passing Data with Varyings</strong></td>
      #       <td><code>.topic_02_varyings</code></td>
      #       <td>Inter-stage communication from vertex to fragment calculations.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Built-In Variables by Shader Type</strong></td>
      #       <td><code>.topic_03_builtin_variables</code></td>
      #       <td>Standard Godot 4 engine built-in variables accessible in each stage.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # ### Related Guides & Source References
      # - bin/crshader/src/crshader/ast/types.cr
      # - bin/crshader/src/crshader/language/uniforms.cr
      #
      module B_UNIFORMS_AND_VARYINGS
        # **Declaring Typed Uniforms & Inspector Hints**: Syntax for scalar, vector, matrix, and texture uniforms with Godot Inspector hints.
        #
        # Uniforms are declared using the `uniform` keyword, specifying an identifier, Crystal/Shader type,
        # optional hint, and default value:
        #
        # - **Scalars**: `float`, `int`, `uint`, `bool`
        # - **Vectors**: `vec2`, `vec3`, `vec4`, `ivec2`, `ivec3`, `ivec4`, `uvec2`, `uvec3`, `uvec4`
        # - **Matrices**: `mat2`, `mat3`, `mat4`
        # - **Textures**: `sampler2D`, `sampler2DArray`, `samplerCube`, `sampler3D`
        #
        # Inspector hints configure editor widgets:
        # - `hint_range(min, max, step)`: Renders a numeric slider in the Inspector.
        # - `hint_color`: Renders a color picker dialog.
        # - `hint_default_white`, `hint_default_black`: Fallback colors if no texture is assigned.
        #
        # #### Working Examples
        #
        # ```crystal
        # # Numeric slider from 0.0 to 1.0 with 0.05 step
        # uniform roughness : float = 0.5, hint: hint_range(0.0, 1.0, 0.05)
        #
        # # Color picker
        # uniform base_color : vec4 = vec4(1.0, 0.8, 0.2, 1.0), hint: hint_color
        #
        # # Texture slot with fallback
        # uniform diffuse_tex : sampler2D, hint: hint_default_white
        # ```
        #
        def self.topic_01_uniform_declarations : Nil
        end

        # **Passing Data with Varyings**: Inter-stage communication from vertex to fragment calculations.
        #
        # Varying variables transfer values computed in the `stage :vertex` block to the `stage :fragment`
        # block. The GPU hardware automatically performs perspective-correct interpolation across
        # the triangle surface:
        #
        # ```crystal
        # varying world_pos : vec3
        # varying normal_interp : vec3
        #
        # stage :vertex do
        #   world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz
        #   normal_interp = (MODEL_NORMAL_MATRIX * NORMAL)
        # end
        #
        # stage :fragment do
        #   # world_pos and normal_interp are smoothly interpolated per pixel
        #   dist = length(world_pos - CAMERA_POSITION_WORLD)
        # end
        # ```
        #
        def self.topic_02_varyings : Nil
        end

        # **Built-In Variables by Shader Type**: Standard Godot 4 engine built-in variables accessible in each stage.
        #
        # Godot exposes global and per-stage constants that CRShader passes through directly:
        #
        # - **Global**: `TIME` (elapsed seconds), `PI`, `TAU`
        # - **CanvasItem Fragment**: `UV`, `COLOR`, `TEXTURE`, `TEXTURE_PIXEL_SIZE`, `SCREEN_UV`
        # - **Spatial Vertex**: `VERTEX`, `NORMAL`, `TANGENT`, `BINORMAL`, `MODEL_MATRIX`, `VIEW_MATRIX`, `PROJECTION_MATRIX`
        # - **Spatial Fragment**: `ALBEDO`, `ALPHA`, `METALLIC`, `ROUGHNESS`, `SPECULAR`, `NORMAL_MAP`, `EMISSION`
        # - **Spatial Light**: `LIGHT`, `LIGHT_COLOR`, `ATTENUATION`, `DIFFUSE_LIGHT`, `SPECULAR_LIGHT`
        #
        def self.topic_03_builtin_variables : Nil
        end
      end
    end
  end
end
{% end %}
