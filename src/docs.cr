# ==============================================================================
# CrShader::Docs System - Master Index & Navigation Hub
# Auto-generated from docs_src/ by Lapis::Docs::Generator
# ==============================================================================

{% unless flag?(:release) %}
module CrShader
  # The `CrShader::Docs` module is the authoritative technical reference, API manual,
  # and learning system for this project.
  #
  # ## Learning Tracks & Topic Index
  #
  # The documentation is paced into 4 distinct tracks:
  #
  # ### 1. Getting started (`A_GETTING_STARTED`)
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Submodule</th>
  #       <th>Title</th>
  #       <th>Description</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>A_OVERVIEW</code></td>
  #       <td><strong>CRShader Architecture & Transpiler Pipeline</strong></td>
  #       <td>Overview of the CRShader language, AST compilation model, and transparent Godot integration.</td>
  #     </tr>
  #     <tr>
  #       <td><code>B_INSTALLATION</code></td>
  #       <td><strong>Installation & Project Setup</strong></td>
  #       <td>Adding CRShader to Godot projects, configuring shards, and building the standalone compiler.</td>
  #     </tr>
  #     <tr>
  #       <td><code>C_QUICK_START</code></td>
  #       <td><strong>Quick Start: Authoring Your First Shader</strong></td>
  #       <td>Writing a canvas_item tint shader, assigning it to a Sprite2D, and inspecting live compilation.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ### 2. Language dsl (`B_LANGUAGE_DSL`)
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Submodule</th>
  #       <th>Title</th>
  #       <th>Description</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>A_SHADER_TYPES</code></td>
  #       <td><strong>Shader Types & Render Modes</strong></td>
  #       <td>Canvas item (2D), spatial (3D), particles, sky, fog, and compute shader types with render modes.</td>
  #     </tr>
  #     <tr>
  #       <td><code>B_UNIFORMS_AND_VARYINGS</code></td>
  #       <td><strong>Uniforms, Varyings & Built-In Variables</strong></td>
  #       <td>Declaring typed uniforms with hints, passing data across stages via varyings, and accessing engine built-ins.</td>
  #     </tr>
  #     <tr>
  #       <td><code>C_PIPELINE_STAGES</code></td>
  #       <td><strong>Pipeline Stages: Vertex, Fragment & Light</strong></td>
  #       <td>Writing code blocks for stage :vertex, stage :fragment, and stage :light.</td>
  #     </tr>
  #     <tr>
  #       <td><code>D_COMPOSITOR_AND_COMPUTE</code></td>
  #       <td><strong>Compositor Passes & Compute Shaders</strong></td>
  #       <td>Authoring screen-space compositor post-processing effects and parallel compute shaders.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ### 3. Editor tooling (`C_EDITOR_TOOLING`)
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Submodule</th>
  #       <th>Title</th>
  #       <th>Description</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>A_IN_EDITOR_HIGHLIGHTER</code></td>
  #       <td><strong>ScriptEditor Syntax Highlighting</strong></td>
  #       <td>How CRShader hooks into Godot's ScriptEditor to provide real-time syntax coloring for .crshader files.</td>
  #     </tr>
  #     <tr>
  #       <td><code>B_SHADER_STUDIO</code></td>
  #       <td><strong>CRShader Studio Dock Panel</strong></td>
  #       <td>Live split-screen editor dock, side-by-side GDShader preview, error diagnostics, and uniform controls.</td>
  #     </tr>
  #     <tr>
  #       <td><code>C_CLI_AND_STUBS</code></td>
  #       <td><strong>CRShader CLI Tool & IDE Stubs</strong></td>
  #       <td>Standalone CLI compiler commands, directory watcher, and Crystal IDE completion stub generation.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ### 4. Showcase and benchmarks (`D_SHOWCASE_AND_BENCHMARKS`)
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Submodule</th>
  #       <th>Title</th>
  #       <th>Description</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>A_PERFORMANCE_BENCHMARKS</code></td>
  #       <td><strong>Compiler Performance & Throughput Benchmarks</strong></td>
  #       <td>Quantitative compiler benchmarks measuring AST parsing, transpilation throughput, and memory overhead.</td>
  #     </tr>
  #     <tr>
  #       <td><code>B_SHADER_VIEWER</code></td>
  #       <td><strong>Interactive Shader Viewer & Sandbox</strong></td>
  #       <td>Standalone showcase application featuring 20+ procedural shaders, 3D mesh switcher, and live sandbox.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  module Docs
    # **Quick-Start Commands**: Essential make and CLI commands for building, running, and testing.
    def self.topic_01_quick_start : String
      <<-HELP
        CrShader Quick Start:
          - make docs        : Build offline HTML documentation site in docs/
          - make test        : Execute specifications and test suites
          - make all         : Build and verify all targets
      HELP
    end

    # **Learning Tracks & Reading Paths**: Curated reading order from beginner to engine architect.
    def self.topic_02_reading_paths : Hash(String, Array(String))
      {
        "1. Getting started" => [
          "A_GETTING_STARTED::A_OVERVIEW",
          "A_GETTING_STARTED::B_INSTALLATION",
          "A_GETTING_STARTED::C_QUICK_START",
        ],
        "2. Language dsl" => [
          "B_LANGUAGE_DSL::A_SHADER_TYPES",
          "B_LANGUAGE_DSL::B_UNIFORMS_AND_VARYINGS",
          "B_LANGUAGE_DSL::C_PIPELINE_STAGES",
          "B_LANGUAGE_DSL::D_COMPOSITOR_AND_COMPUTE",
        ],
        "3. Editor tooling" => [
          "C_EDITOR_TOOLING::A_IN_EDITOR_HIGHLIGHTER",
          "C_EDITOR_TOOLING::B_SHADER_STUDIO",
          "C_EDITOR_TOOLING::C_CLI_AND_STUBS",
        ],
        "4. Showcase and benchmarks" => [
          "D_SHOWCASE_AND_BENCHMARKS::A_PERFORMANCE_BENCHMARKS",
          "D_SHOWCASE_AND_BENCHMARKS::B_SHADER_VIEWER",
        ],
      }
    end

    # **Master Table of Contents**: Complete hierarchical topic index.
    def self.topic_03_table_of_contents : Array(String)
      [
        "A_GETTING_STARTED::A_OVERVIEW",
        "A_GETTING_STARTED::B_INSTALLATION",
        "A_GETTING_STARTED::C_QUICK_START",
        "B_LANGUAGE_DSL::A_SHADER_TYPES",
        "B_LANGUAGE_DSL::B_UNIFORMS_AND_VARYINGS",
        "B_LANGUAGE_DSL::C_PIPELINE_STAGES",
        "B_LANGUAGE_DSL::D_COMPOSITOR_AND_COMPUTE",
        "C_EDITOR_TOOLING::A_IN_EDITOR_HIGHLIGHTER",
        "C_EDITOR_TOOLING::B_SHADER_STUDIO",
        "C_EDITOR_TOOLING::C_CLI_AND_STUBS",
        "D_SHOWCASE_AND_BENCHMARKS::A_PERFORMANCE_BENCHMARKS",
        "D_SHOWCASE_AND_BENCHMARKS::B_SHADER_VIEWER",
      ]
    end

    # :nodoc:
    def self.quick_start : String; topic_01_quick_start; end
    # :nodoc:
    def self.reading_paths : Hash(String, Array(String)); topic_02_reading_paths; end
    # :nodoc:
    def self.table_of_contents : Array(String); topic_03_table_of_contents; end
  end
end

require "./docs/a_getting_started/a_overview"
require "./docs/a_getting_started/b_installation"
require "./docs/a_getting_started/c_quick_start"
require "./docs/b_language_dsl/a_shader_types"
require "./docs/b_language_dsl/b_uniforms_and_varyings"
require "./docs/b_language_dsl/c_pipeline_stages"
require "./docs/b_language_dsl/d_compositor_and_compute"
require "./docs/c_editor_tooling/a_in_editor_highlighter"
require "./docs/c_editor_tooling/b_shader_studio"
require "./docs/c_editor_tooling/c_cli_and_stubs"
require "./docs/d_showcase_and_benchmarks/a_performance_benchmarks"
require "./docs/d_showcase_and_benchmarks/b_shader_viewer"

{% end %}
