# ==============================================================================
# Auto-generated from docs_src by Lapis::Docs::Generator
# DO NOT EDIT MANUALLY - Edit corresponding YAML in docs_src/ instead
# ==============================================================================

{% unless flag?(:release) %}
module CrShader
  module Docs
    module C_EDITOR_TOOLING
      # # CRShader CLI Tool & IDE Stubs
      #
      # The standalone `crshader` CLI tool provides command-line building, continuous directory watching,
      # and rich Crystal IDE autocompletion stubs for VSCode, Neovim, and Sublime Text.
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
      #       <td><strong>Command-Line Interface Commands</strong></td>
      #       <td><code>.topic_01_cli_commands</code></td>
      #       <td>Complete reference for crshader build, watch, stubs, and install-addon.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>IDE Autocomplete Stubs (stub_generator)</strong></td>
      #       <td><code>.topic_02_ide_stubs</code></td>
      #       <td>Generating typed Crystal definitions for Godot built-in shader functions and types.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # ### Related Guides & Source References
      # - bin/crshader/src/cli.cr
      # - bin/crshader/src/crshader/stubs/stub_generator.cr
      #
      module C_CLI_AND_STUBS
        # **Command-Line Interface Commands**: Complete reference for crshader build, watch, stubs, and install-addon.
        #
        # The `crshader` CLI binary supports several core subcommands:
        #
        # #### Command Options & Flags
        #
        # <table>
        #   <thead>
        #     <tr>
        #       <th>Flag / Option</th>
        #       <th>Description</th>
        #     </tr>
        #   </thead>
        #   <tbody>
        #     <tr>
        #       <td><code>crshader build <file> -t <target></code></td>
        #       <td>Compile a .crshader file to .gdshader or .glsl</td>
        #     </tr>
        #     <tr>
        #       <td><code>crshader watch <dir></code></td>
        #       <td>Watch directory for changes and continuously transpile</td>
        #     </tr>
        #     <tr>
        #       <td><code>crshader stubs -o <path></code></td>
        #       <td>Generate Crystal completion stubs (default: src/libgodot/crshader.cr)</td>
        #     </tr>
        #     <tr>
        #       <td><code>crshader install-addon <godot_dir></code></td>
        #       <td>Copy GDExtension plugin files into a Godot project</td>
        #     </tr>
        #     <tr>
        #       <td><code>-v, --version</code></td>
        #       <td>Print version string</td>
        #     </tr>
        #     <tr>
        #       <td><code>-h, --help</code></td>
        #       <td>Display CLI help information</td>
        #     </tr>
        #   </tbody>
        # </table>
        #
        # #### Working Examples
        #
        # ```bash
        # # Compile a single shader
        # bin/crshader build shaders/water.crshader -t gdshader -o shaders/water.gdshader
        #
        # # Watch shaders folder continuously
        # bin/crshader watch shaders/
        #
        # # Generate IDE autocompletion stubs
        # bin/crshader stubs -o src/libgodot/crshader.cr
        # ```
        #
        def self.topic_01_cli_commands : Nil
        end

        # **IDE Autocomplete Stubs (stub_generator)**: Generating typed Crystal definitions for Godot built-in shader functions and types.
        #
        # Because `.crshader` is valid Crystal syntax, you can use standard Crystal Language Server (LSP)
        # tooling (such as `crystalline` or `scry`) to get full autocompletion, type signatures, and
        # hover documentation.
        #
        # Running `crshader stubs` generates a typed stub file containing every Godot built-in function
        # (`smoothstep`, `mix`, `texture`, `sin`, `cos`, `cross`, `dot`, `inverse`, etc.) with mirrored
        # Godot 4 documentation comments.
        #
        # #### Working Examples
        #
        # ```bash
        # crshader stubs -o src/libgodot/crshader.cr
        # ```
        #
        def self.topic_02_ide_stubs : Nil
        end
      end
    end
  end
end
{% end %}
