# ==============================================================================
# CRShader Shading Language Documentation & Stubs Hub
# ==============================================================================

require "./language/types"
require "./language/preprocessors"
require "./language/stages"
require "./language/functions"
require "./language/builtins"
require "./language/std"

module CrShader
  # # CRShader Shading Language Reference
  #
  # **CRShader** is a modern, high-performance shading language that brings the elegance,
  # expressiveness, and safety of Crystal syntax directly into the Godot Engine 4.x shading pipeline.

  #
  # `.crshader` source files compile at build-time or on-demand inside the Godot Editor into
  # high-performance Godot GDShader code (for 2D canvas, 3D spatial, sky, fog, and particle shaders)
  # or Vulkan GLSL Compute code (for compute shaders and GPGPU tasks).
  #
  # ### Submodule Reference & Language Architecture
  #
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Module</th>
  #       <th>Description</th>
  #       <th>Key Features</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><a href="Language/PreProcessors.html"><code>Language::PreProcessors</code></a></td>
  #       <td>Compiler directives, storage qualifiers, uniform hints, and render modes.</td>
  #       <td><code>shader_type</code>, <code>render_mode</code>, <code>uniform</code>, <code>varying</code>, <code>buffer</code>, <code>image2d</code></td>
  #     </tr>
  #     <tr>
  #       <td><a href="Language/Stages.html"><code>Language::Stages</code></a></td>
  #       <td>Pipeline execution entry points and processor functions.</td>
  #       <td><code>vertex</code>, <code>fragment</code>, <code>light</code>, <code>start</code>, <code>process</code>, <code>sky</code>, <code>fog</code>, <code>main</code></td>
  #     </tr>
  #     <tr>
  #       <td><a href="Language/Functions.html"><code>Language::Functions</code></a></td>
  #       <td>Mathematical, geometric, matrix, texture, compute, and std library functions.</td>
  #       <td><code>sin</code>, <code>cos</code>, <code>clamp</code>, <code>mix</code>, <code>texture</code>, <code>fresnel</code>, <code>imageStore</code></td>
  #     </tr>
  #     <tr>
  #       <td><a href="Language/Types.html"><code>Language::Types</code></a></td>
  #       <td>Shader primitive vectors, matrices, samplers, colors, and qualifiers.</td>
  #       <td><code>Vec2..4</code>, <code>IVec2..4</code>, <code>Mat2..4</code>, <code>Sampler2D..3D</code>, <code>Color</code></td>
  #     </tr>
  #     <tr>
  #       <td><a href="Language/Builtins.html"><code>Language::Builtins</code></a></td>
  #       <td>Engine-provided built-in variables scoped across all shader stages.</td>
  #       <td><code>CanvasItem</code>, <code>Spatial</code>, <code>Particles</code>, <code>Sky</code>, <code>Fog</code>, <code>Compute</code></td>
  #     </tr>
  #     <tr>
  #       <td><a href="Language/Std.html"><code>Language::Std</code></a></td>
  #       <td>Standard library modules available via <code>require "std/..."</code>.</td>
  #       <td><code>Math</code>, <code>Noise</code>, <code>Color</code>, <code>Lighting</code>, <code>Sdf</code>, <code>Tonemap</code>, <code>PostProcessing</code></td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ### Complete Shader Example
  #
  # ```crystal
  # shader_type :spatial
  # render_mode :cull_disabled, :depth_draw_opaque
  #
  # uniform albedo : Color = Color.new(0.2, 0.6, 1.0, 1.0), hint: :source_color
  # uniform roughness : Float32 = 0.3, hint: hint_range(0.0, 1.0)
  # uniform metallic : Float32 = 0.8, hint: hint_range(0.0, 1.0)
  # uniform wave_speed : Float32 = 2.0
  #
  # varying v_world_normal : Vec3
  #
  # def vertex
  #   v_world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz
  #   VERTEX.y += sin(TIME * wave_speed + VERTEX.x) * 0.15
  # end
  #
  # def fragment
  #   ALBEDO = albedo.rgb
  #   ROUGHNESS = roughness
  #   METALLIC = metallic
  # end
  # ```
  module Language
    include PreProcessors
    include Stages
    include Functions
    include Types
  end

  # Backward compatibility modules
  module DSL
    include Language::PreProcessors
  end

  module Types
    include Language::Types
  end

  module Builtins
    include Language::Builtins
  end

  module Functions
    include Language::Functions
  end

  module Stages
    include Language::Stages
  end

  include Language::PreProcessors
  include Language::Functions
  include Language::Types
  include Language::Stages
end

# Re-export top-level aliases for universal accessibility across docs and IDE tools
CRShader = CrShader
Language = CrShader::Language
