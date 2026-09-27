# ==============================================================================
# Auto-generated from docs_src by Lapis::Docs::Generator
# DO NOT EDIT MANUALLY - Edit corresponding YAML in docs_src/ instead
# ==============================================================================

{% unless flag?(:release) %}
module CrShader
  module Docs
    module A_GETTING_STARTED
      # # Quick Start: Authoring Your First Shader
      #
      # This tutorial guides you through creating your first `.crshader` file, assigning it to a 2D sprite
      # in Godot, tweaking uniform parameters, and understanding how CRShader compiles your code into
      # Godot's native shader pipeline.
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
      #       <td><strong>Writing a CanvasItem Shader</strong></td>
      #       <td><code>.topic_01_first_canvas_shader</code></td>
      #       <td>Creating a water tint shader using CRShader's declarative Crystal syntax.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Assigning Directly to a ShaderMaterial</strong></td>
      #       <td><code>.topic_02_assigning_to_material</code></td>
      #       <td>Hooking up the .crshader resource in the Godot Inspector without manual export.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Inspecting Transpiled Output in CRShader Studio</strong></td>
      #       <td><code>.topic_03_inspecting_output</code></td>
      #       <td>Opening the dock to inspect generated GDShader code and verify syntax.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # ### Related Guides & Source References
      # - bin/crshader/examples/shader_viewer/shaders/water_2d.crshader
      # - bin/crshader/src/crshader_resource.cr
      #
      module C_QUICK_START
        # **Writing a CanvasItem Shader**: Creating a water tint shader using CRShader's declarative Crystal syntax.
        #
        # Create a new text file named `res://shaders/water_tint.crshader`.
        # In this file, declare the shader type, uniforms with inspector hints, and the fragment stage:
        #
        # #### Working Examples
        #
        # ```crystal
        # shader_type :canvas_item
        # render_mode :unshaded
        #
        # # Uniform parameters with default values
        # uniform tint : vec4 = vec4(0.2, 0.6, 1.0, 1.0)
        # uniform speed : float = 1.5
        # uniform frequency : float = 10.0
        #
        # # Fragment stage calculates animated wave distortion and color tint
        # stage :fragment do
        #   uv = UV + vec2(sin(TIME * speed + UV.y * frequency) * 0.02, 0.0)
        #   col = texture(TEXTURE, uv) * tint
        #   COLOR = col
        # end
        # ```
        #
        def self.topic_01_first_canvas_shader : Nil; end

        # **Assigning Directly to a ShaderMaterial**: Hooking up the .crshader resource in the Godot Inspector without manual export.
        #
        # 1. In your Godot scene, select any `Sprite2D`, `TextureRect`, or `ColorRect` node.
        # 2. In the Inspector, expand the **Material** property and choose **New ShaderMaterial**.
        # 3. Click on the newly created `ShaderMaterial` to open its properties.
        # 4. Drag `res://shaders/water_tint.crshader` from the FileSystem dock into the **Shader** slot.
        # 5. The sprite immediately updates in the editor viewport!
        # 6. Expand **Shader Parameters** to see your declared `tint`, `speed`, and `frequency` uniforms ready for adjustment.
        #
        def self.topic_02_assigning_to_material : Nil; end

        # **Inspecting Transpiled Output in CRShader Studio**: Opening the dock to inspect generated GDShader code and verify syntax.
        #
        # With `water_tint.crshader` selected, open the **CRShader Studio** dock at the bottom of the Godot Editor.
        # The left pane displays your Crystal source code, while the right pane shows the transpiled GDShader 4.x code:
        #
        # ```glsl
        # shader_type canvas_item;
        # render_mode unshaded;
        #
        # uniform vec4 tint = vec4(0.2, 0.6, 1.0, 1.0);
        # uniform float speed = 1.5;
        # uniform float frequency = 10.0;
        #
        # void fragment() {
        #     vec2 uv = UV + vec2(sin(TIME * speed + UV.y * frequency) * 0.02, 0.0);
        #     vec4 col = texture(TEXTURE, uv) * tint;
        #     COLOR = col;
        # }
        # ```
        #
        def self.topic_03_inspecting_output : Nil; end
      end
    end
  end
end
{% end %}
