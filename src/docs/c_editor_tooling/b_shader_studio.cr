# ==============================================================================
# Auto-generated from docs_src by Lapis::Docs::Generator
# DO NOT EDIT MANUALLY - Edit corresponding YAML in docs_src/ instead
# ==============================================================================

{% unless flag?(:release) %}
module CrShader
  module Docs
    module C_EDITOR_TOOLING
      # # CRShader Studio Dock Panel
      #
      # CRShader Studio is an integrated bottom-dock editor panel in the Godot Editor. It provides a
      # split-pane workspace where developers can write CRShader DSL code on the left, see transpiled
      # GDShader or GLSL on the right, and tweak live uniforms without leaving the scene.
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
      #       <td><strong>Split-Screen Dock Layout</strong></td>
      #       <td><code>.topic_01_dock_layout</code></td>
      #       <td>Overview of the studio workspace, toolbar controls, and inspection panes.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Real-Time Recompilation & Diagnostics</strong></td>
      #       <td><code>.topic_02_live_recompilation</code></td>
      #       <td>Sub-millisecond compilation triggers on keystroke with syntax error reporting.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # ### Related Guides & Source References
      # - bin/crshader/src/crshader/editor/studio_panel.cr
      # - bin/crshader/src/main.cr
      #
      module B_SHADER_STUDIO
        # **Split-Screen Dock Layout**: Overview of the studio workspace, toolbar controls, and inspection panes.
        #
        # CRShader Studio is automatically registered as a bottom-panel dock when the CRShader addon
        # is enabled in Godot. The interface is organized into three primary sections:
        #
        # 1. **Left Editor Pane**: A full-featured text editor with syntax highlighting, line numbers, and auto-indent.
        # 2. **Right Preview Pane**: Read-only display of the generated GDShader 4.x or GLSL compute code.
        # 3. **Bottom Diagnostic Console**: Real-time error messages, warning flags, and compilation timestamps.
        #
        # #### Working Examples
        #
        # ```
        # +-----------------------------------+-----------------------------------+
        # | CRShader Source (.crshader)       | Transpiled Output (.gdshader)     |
        # +-----------------------------------+-----------------------------------+
        # | shader_type :canvas_item          | shader_type canvas_item;          |
        # | uniform tint : vec4               | uniform vec4 tint;                |
        # | stage :fragment do                | void fragment() {                 |
        # |   COLOR = texture(TEXTURE, UV)    |     COLOR = texture(TEXTURE, UV); |
        # | end                               | }                                 |
        # +-----------------------------------+-----------------------------------+
        # | [OK] Transpiled in 0.42ms (0 warnings, 0 errors)                      |
        # +-----------------------------------------------------------------------+
        # ```
        #
        def self.topic_01_dock_layout : Nil; end

        # **Real-Time Recompilation & Diagnostics**: Sub-millisecond compilation triggers on keystroke with syntax error reporting.
        #
        # As you type in the left editor pane, the transpiler compiles the AST asynchronously with a
        # short debounce timer (~150ms). If a syntax error occurs (such as an unclosed `do ... end` block
        # or an undeclared identifier), the diagnostic console highlights the offending line with a red
        # marker and exact column error description.
        #
        def self.topic_02_live_recompilation : Nil; end
      end
    end
  end
end
{% end %}
