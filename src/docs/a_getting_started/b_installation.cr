# ==============================================================================
# Auto-generated from docs_src by Lapis::Docs::Generator
# DO NOT EDIT MANUALLY - Edit corresponding YAML in docs_src/ instead
# ==============================================================================

{% unless flag?(:release) %}
module CrShader
  module Docs
    module A_GETTING_STARTED
      # # Installation & Project Setup
      #
      # Setting up CRShader can be done either as an in-project GDExtension addon for the Godot Editor,
      # or as a standalone command-line compiler for automated CI pipelines and pre-compilation workflows.
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
      #       <td><strong>Adding the Shard Dependency</strong></td>
      #       <td><code>.topic_01_shard_dependency</code></td>
      #       <td>Configuring shard.yml to include CRShader in your Crystal project.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Building the Standalone CLI</strong></td>
      #       <td><code>.topic_02_cli_compilation</code></td>
      #       <td>Compiling the standalone crshader executable for command-line use.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Installing the Godot Editor Addon</strong></td>
      #       <td><code>.topic_03_addon_installation</code></td>
      #       <td>Installing the GDExtension plugin into a target Godot project.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # ### Related Guides & Source References
      # - bin/crshader/shard.yml
      # - bin/crshader/Makefile
      # - bin/crshader/src/cli.cr
      #
      module B_INSTALLATION
        # **Adding the Shard Dependency**: Configuring shard.yml to include CRShader in your Crystal project.
        #
        # To author shaders or use the programmatic compiler API inside your Crystal game or tooling,
        # add `crshader` to your project's `shard.yml`:
        #
        # ```yaml
        # dependencies:
        #   crshader:
        #     github: sol-vin/crshader
        #     branch: master
        # ```
        #
        # Run `shards install` to fetch CRShader and its dependencies.
        #
        # #### Working Examples
        #
        # ```bash
        # shards install
        # shards check
        # ```
        #
        def self.topic_01_shard_dependency : Nil; end

        # **Building the Standalone CLI**: Compiling the standalone crshader executable for command-line use.
        #
        # The standalone `crshader` executable provides batch compilation, file watching, and IDE
        # stub generation without launching the Godot Editor.
        #
        # Run `make` inside the `crshader` repository, or compile `src/cli.cr` directly:
        #
        # #### Working Examples
        #
        # ```bash
        # # Via Makefile:
        # make
        #
        # # Or direct crystal build:
        # crystal build src/cli.cr -o bin/crshader --release
        # ```
        #
        def self.topic_02_cli_compilation : Nil; end

        # **Installing the Godot Editor Addon**: Installing the GDExtension plugin into a target Godot project.
        #
        # To install CRShader into an existing Godot project:
        #
        # 1. Use the CLI tool:
        #    ```bash
        #    bin/crshader install-addon /path/to/godot_project
        #    ```
        # 2. Or copy the `addons/crshader` folder directly into your project's `addons/` directory.
        # 3. Open Godot, navigate to **Project -> Project Settings -> Plugins**, and check **Enable** next to **CRShader**.
        #
        # #### Common Pitfalls & Safety Caveats
        #
        # - **Warning**: Ensure your Godot project uses Godot 4.8 or later; earlier 4.x versions lack certain GDExtension resource loader hooks.
        #
        def self.topic_03_addon_installation : Nil; end
      end
    end
  end
end
{% end %}
