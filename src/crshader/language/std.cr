# ==============================================================================
# CrShader Language: Standard Library Modules Reference
# ==============================================================================

module CrShader
  module Language
    # CrShader standard library modules available via `require "std/<name>"`.
    #
    # The standard library bundles battle-tested, high-performance shading algorithms
    # that can be imported on-demand into any `.crshader` file with zero runtime overhead.
    # Unused routines are automatically tree-shaken by the CrShader compiler.
    module Std
      # **Standard Math & Geometry (`require "std/math"`)**:
      #
      # Provides essential mathematical functions and utility curves:
      # - `saturate(x)`: Clamps input to `[0.0, 1.0]`.
      # - `lerp(a, b, t)`: Linear interpolation alias.
      # - `remap(val, in_min, in_max, out_min, out_max)`: Linear range remapping.
      # - `rotate_2d(p, angle)`: Fast 2D vector rotation around origin.
      # - `fresnel(power, normal, view)`: Power-law optical Fresnel reflection factor.
      # - `rand(uv)`: 2D UV hashing pseudo-random generator.
      module Math
      end

      # **Procedural Noise & Hashes (`require "std/noise"`)**:
      #
      # Procedural noise routines requiring zero texture fetches:
      # - `hash11(p)` .. `hash33(p)`: Jarzynski & Olano hash functions for procedural seeds.
      # - `value_noise(p)`: Smooth 2D value noise.
      # - `voronoi(p)`: Cellular Voronoi distance calculation.
      # - `simplex_noise_2d(p)`: 2D simplex noise gradient.
      # - `fbm(p, octaves)`: Multi-octave Fractal Brownian Motion for clouds, terrain, and smoke.
      module Noise
      end

      # **Color Science & Grading (`require "std/color"`)**:
      #
      # Professional color space conversion and grading algorithms:
      # - `hsv2rgb(c)`: Converts Hue/Saturation/Value to RGB.
      # - `rgb2hsv(c)`: Converts RGB to Hue/Saturation/Value.
      # - `grayscale(c)`: Photometric ITU-R BT.709 grayscale luminance.
      # - `adjust_contrast(c, contrast)`: S-curve contrast adjustment around midpoint.
      # - `adjust_saturation(c, saturation)`: Saturation adjustment preserving luminance.
      module Color
      end

      # **Stylized & PBR Lighting (`require "std/lighting"`)**:
      #
      # Custom lighting models for the `light` stage:
      # - `cel_shade(n_dot_l, steps)`: Quantized cel/toon shading bands.
      # - `blinn_phong(normal, light_dir, view_dir, shininess)`: Blinn-Phong specular lobe.
      module Lighting
      end

      # **Signed Distance Fields (`require "std/sdf"`)**:
      #
      # Raymarching and procedural geometry SDF primitives:
      # - `sdf_sphere(p, radius)`: Exact distance to a sphere.
      # - `sdf_box(p, b)`: Exact distance to a 3D box.
      # - `smin(a, b, k)`: Polynomial smooth minimum for organic union blending.
      # - `smax(a, b, k)`: Polynomial smooth maximum for organic carving.
      module Sdf
      end

      # **Tonemapping Curves (`require "std/tonemap"`)**:
      #
      # High dynamic range (HDR) display curves:
      # - `aces_tonemap(x)`: Stephen Hill's fitted ACES filmic tonemapper.
      # - `reinhard_tonemap(x)`: Classic photographic Reinhard compression curve.
      module Tonemap
      end

      # **Triplanar Mapping (`require "std/triplanar"`)**:
      #
      # Texture mapping utilities without UV unwrap requirements:
      # - `triplanar_weights(normal)`: Normalized blending weights for X, Y, and Z projections.
      module Triplanar
      end

      # **Post-Processing Utilities (`require "std/post_processing"`)**:
      #
      # Camera and screen-space viewport shader operations:
      # - `linear_depth(depth_sample, inv_proj)`: Linear camera view distance reconstruction.
      # - `luminance(c)`: Perceptual luminance calculation.
      # - `barrel_distortion(uv, distortion)`: Optical lens barrel/pincushion curvature.
      # - `vignette(uv, radius, softness)`: Smooth radial vignette darkening factor.
      module PostProcessing
      end
    end
  end
end
