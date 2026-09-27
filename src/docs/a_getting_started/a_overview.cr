# ==============================================================================
# Auto-generated from docs_src by Lapis::Docs::Generator
# DO NOT EDIT MANUALLY - Edit corresponding YAML in docs_src/ instead
# ==============================================================================

{% unless flag?(:release) %}
module CrShader
  module Docs
    module A_GETTING_STARTED
      # # CRShader Architecture & Transpiler Pipeline
      #
      # CRShader is a high-performance shader trans-compiler and live runtime development toolchain
      # for Godot Engine 4.8+, powered by Crystal and Lapis. It introduces a declarative, type-safe
      # Crystal shader DSL that transpiles down to optimized Godot GDShader (4.x) and GLSL compute
      # kernels with native machine speed (~1.1ms transpilation, >100,000 LOC/s).
      #
      # CRShader enables game developers to write shaders with clean, readable Crystal syntax,
      # benefiting from typed uniform definitions, modular stages, and IDE autocomplete, while
      # seamlessly deploying to Godot's Vulkan, Direct3D 12, Metal, and OpenGL renderers.
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
      #       <td><strong>Core Architecture & Transpiler Pipeline</strong></td>
      #       <td><code>.topic_01_architecture_overview</code></td>
      #       <td>High-level overview of the lexical parser, typed AST, and dual transpiler backends.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Transparent In-Memory Loading</strong></td>
      #       <td><code>.topic_02_transparent_loading</code></td>
      #       <td>How ResourceFormatLoaderCRShader registers with Godot's ResourceLoader to bypass intermediate disk files.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # ### Related Guides & Source References
      # - bin/crshader/src/crshader/compiler.cr
      # - bin/crshader/src/crshader/ast/types.cr
      # - bin/crshader/src/resource_format.cr
      #
      module A_OVERVIEW
        # **Core Architecture & Transpiler Pipeline**: High-level overview of the lexical parser, typed AST, and dual transpiler backends.
        #
        # CRShader's architecture consists of two cooperating subsystems: the **Toolchain Pipeline**
        # and the **Godot Engine Integration**:
        #
        # 1. **Source Lexer & Parser**: Tokenizes `.crshader` DSL files and builds a strongly typed Abstract Syntax Tree (AST).
        # 2. **Transpiler Backends**: Generates idiomatic Godot GDShader 4.x code for graphics pipelines, or GLSL for compute kernels.
        # 3. **Resource Loader**: Transparently intercepts `.crshader` loading in Godot, caching and feeding compiled `Godot::Shader` objects directly into `ShaderMaterial`.
        # 4. **Editor Tooling**: Provides live ScriptEditor syntax highlighting and the CRShader Studio split-screen inspection dock.
        #
        # #### Working Examples
        #
        # ```
        # .crshader Source --> Lexer & AST Parser --> Typed Shader AST
        #                                                  |
        #                     +----------------------------+---------------------------+
        #                     |                                                        |
        #                     v                                                        v
        #          GDShader 4.x Backend                                     GLSL Compute Backend
        #                     |                                                        |
        #                     v                                                        v
        #              Target .gdshader                                         Target .glsl
        #                     |                                                        |
        #                     +----------------------------+---------------------------+
        #                                                  |
        #                                                  v
        #                                ResourceFormatLoaderCRShader (In-Memory)
        #                                                  |
        #                                                  v
        #                                      Godot ShaderMaterial & GPU
        # ```
        #
        # #### Common Pitfalls & Safety Caveats
        #
        # - **Warning**: Never edit the intermediate transpiled .gdshader directly; always edit the .crshader source so changes are preserved across builds.
        #
        # #### Frequently Asked Questions (FAQ)
        #
        # - **Q: Does CRShader introduce runtime overhead when running the game?**
        #   A: Zero overhead. Shaders are compiled to standard Godot Shader resources in-memory at load time. The GPU executes native driver bytecode identical to hand-written GDShader.
        #
        def self.topic_01_architecture_overview : Nil
        end

        # **Transparent In-Memory Loading**: How ResourceFormatLoaderCRShader registers with Godot's ResourceLoader to bypass intermediate disk files.
        #
        # CRShader implements a custom `ResourceFormatLoaderCRShader` inheriting from `ResourceFormatLoader`.
        # When Godot encounters a resource path ending in `.crshader`:
        #
        # - The loader reads the source file from `res://`.
        # - It invokes `CrShader::Compiler.compile_to_gdshader(source)`.
        # - It instantiates a native `Godot::Shader`, populates `shader.code`, and returns it directly.
        # - Godot caches the compiled resource in its internal resource cache.
        #
        # This means `.crshader` files can be directly dragged and dropped into `ShaderMaterial.shader`
        # slots in the Godot Inspector without generating clutter files on disk.
        #
        # #### Working Examples
        #
        # ```crystal
        # # Inside ResourceFormatLoaderCRShader:
        # def _load(path : String, original_path : String, use_sub_threads : Bool, cache_mode : Int32) : Godot::Resource?
        #   source = File.read(path)
        #   gdshader_code = CrShader::Compiler.compile_to_gdshader(source)
        #
        #   shader = Godot::Shader.new
        #   shader.code = gdshader_code
        #   shader
        # end
        # ```
        #
        def self.topic_02_transparent_loading : Nil
        end
      end
    end
  end
end
{% end %}
