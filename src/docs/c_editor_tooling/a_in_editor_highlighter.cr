# ==============================================================================
# Auto-generated from docs_src by Lapis::Docs::Generator
# DO NOT EDIT MANUALLY - Edit corresponding YAML in docs_src/ instead
# ==============================================================================

{% unless flag?(:release) %}
module CrShader
  module Docs
    module C_EDITOR_TOOLING
      # # ScriptEditor Syntax Highlighting
      #
      # CRShader includes a custom `EditorSyntaxHighlighter` implementation that integrates directly into
      # Godot's built-in `ScriptEditor`. When opening any `.crshader` file in Godot, the editor automatically
      # highlights keywords, types, built-ins, and numbers according to your active editor theme.
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
      #       <td><strong>Syntax Highlighter Architecture</strong></td>
      #       <td><code>.topic_01_highlighter_architecture</code></td>
      #       <td>Extending Godot::EditorSyntaxHighlighter to tokenize CRShader source files.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Highlighted Token Categories</strong></td>
      #       <td><code>.topic_02_token_categories</code></td>
      #       <td>Color mappings for language constructs, types, and stage declarations.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # ### Related Guides & Source References
      # - bin/crshader/src/highlighter.cr
      # - bin/crshader/src/main.cr
      #
      module A_IN_EDITOR_HIGHLIGHTER
        # **Syntax Highlighter Architecture**: Extending Godot::EditorSyntaxHighlighter to tokenize CRShader source files.
        #
        # The syntax highlighter is implemented in `src/highlighter.cr` via `CRShaderSyntaxHighlighter < EditorSyntaxHighlighter`.
        # Godot queries this class line-by-line during text editing in `ScriptEditor`:
        #
        # - The class overrides `_get_line_syntax_highlighting(line_idx : Int32) : Dictionary`.
        # - It returns a color dictionary mapping column offsets to token colors.
        # - Colors are dynamically queried from the editor's active theme settings so highlighting respects dark and light themes.
        #
        # #### Working Examples
        #
        # ```crystal
        # node CRShaderSyntaxHighlighter < EditorSyntaxHighlighter do
        #   def _get_name : String
        #     "CRShader"
        #   end
        #
        #   def _get_supported_languages : PackedStringArray
        #     PackedStringArray.new(["crshader", "cr"])
        #   end
        # end
        # ```
        #
        def self.topic_01_highlighter_architecture : Nil; end

        # **Highlighted Token Categories**: Color mappings for language constructs, types, and stage declarations.
        #
        # The highlighter recognizes several distinct token categories:
        #
        # - **Keywords**: `shader_type`, `render_mode`, `uniform`, `varying`, `stage`, `do`, `end`, `if`, `else`, `return`.
        # - **Types**: `float`, `int`, `uint`, `bool`, `vec2`, `vec3`, `vec4`, `mat2`, `mat3`, `mat4`, `sampler2D`.
        # - **Built-in Variables**: `TIME`, `PI`, `UV`, `COLOR`, `VERTEX`, `NORMAL`, `ALBEDO`, `ROUGHNESS`, `METALLIC`.
        # - **Numbers & Constants**: Floats (`1.5`, `0.1_f32`), hex literals, and boolean literals (`true`, `false`).
        # - **Comments**: Full-line or trailing `# comments` are highlighted with editor comment styling.
        #
        def self.topic_02_token_categories : Nil; end
      end
    end
  end
end
{% end %}
