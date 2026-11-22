module CrShader
  module Std
    # =========================================================================
    # std/outline - Reusable Cross-Target Outline & Edge-Detection Toolkit
    # =========================================================================
    # Designed for 100% source compatibility across:
    # - Godot 4 Spatial / CanvasItem `.gdshader` passes
    # - Shared `.gdshaderinc` libraries
    # - Godot 4.8 `CompositorEffect` / `RenderingDevice` `.glsl` compute passes

    OUTLINE_DIRECTIONS_LIB = <<-CR
      DIRS_4 = [
        vec2(0.0, -1.0), vec2(0.0, 1.0), vec2(-1.0, 0.0), vec2(1.0, 0.0)
      ]

      DIRS_8 = [
        vec2(0.0, -1.0), vec2(0.0, 1.0), vec2(-1.0, 0.0), vec2(1.0, 0.0),
        vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0, 1.0)
      ]

      DIRS_16 = [
        vec2(1.0, 0.0),
        vec2(0.92387953, 0.38268343),
        vec2(0.70710678, 0.70710678),
        vec2(0.38268343, 0.92387953),
        vec2(0.0, 1.0),
        vec2(-0.38268343, 0.92387953),
        vec2(-0.70710678, 0.70710678),
        vec2(-0.92387953, 0.38268343),
        vec2(-1.0, 0.0),
        vec2(-0.92387953, -0.38268343),
        vec2(-0.70710678, -0.70710678),
        vec2(-0.38268343, -0.92387953),
        vec2(0.0, -1.0),
        vec2(0.38268343, -0.92387953),
        vec2(0.70710678, -0.70710678),
        vec2(0.92387953, -0.38268343)
      ]

      DIRS_24 = [
        vec2(0.0, -1.0), vec2(0.0, 1.0), vec2(-1.0, 0.0), vec2(1.0, 0.0),
        vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0, 1.0),
        vec2(0.0, -2.0), vec2(2.0, 0.0), vec2(-2.0, 0.0), vec2(0.0, 2.0),
        vec2(-1.0, -2.0), vec2(1.0, -2.0),
        vec2(-1.0, 2.0), vec2(1.0, 2.0),
        vec2(-2.0, -1.0), vec2(2.0, -1.0),
        vec2(-2.0, 1.0), vec2(2.0, 1.0),
        vec2(-2.0, -2.0), vec2(2.0, -2.0),
        vec2(-2.0, 2.0), vec2(2.0, 2.0)
      ]

      OUTLINE_DIRS_4 = [
        vec2(0.0, -1.0), vec2(0.0, 1.0), vec2(-1.0, 0.0), vec2(1.0, 0.0)
      ]

      OUTLINE_DIRS_8 = [
        vec2(0.0, -1.0), vec2(0.0, 1.0), vec2(-1.0, 0.0), vec2(1.0, 0.0),
        vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0, 1.0)
      ]

      OUTLINE_DIRS_16 = [
        vec2(1.0, 0.0),
        vec2(0.92387953, 0.38268343),
        vec2(0.70710678, 0.70710678),
        vec2(0.38268343, 0.92387953),
        vec2(0.0, 1.0),
        vec2(-0.38268343, 0.92387953),
        vec2(-0.70710678, 0.70710678),
        vec2(-0.92387953, 0.38268343),
        vec2(-1.0, 0.0),
        vec2(-0.92387953, -0.38268343),
        vec2(-0.70710678, -0.70710678),
        vec2(-0.38268343, -0.92387953),
        vec2(0.0, -1.0),
        vec2(0.38268343, -0.92387953),
        vec2(0.70710678, -0.70710678),
        vec2(0.92387953, -0.38268343)
      ]

      OUTLINE_DIRS_24 = [
        vec2(0.0, -1.0), vec2(0.0, 1.0), vec2(-1.0, 0.0), vec2(1.0, 0.0),
        vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0, 1.0),
        vec2(0.0, -2.0), vec2(2.0, 0.0), vec2(-2.0, 0.0), vec2(0.0, 2.0),
        vec2(-1.0, -2.0), vec2(1.0, -2.0),
        vec2(-1.0, 2.0), vec2(1.0, 2.0),
        vec2(-2.0, -1.0), vec2(2.0, -1.0),
        vec2(-2.0, 1.0), vec2(2.0, 1.0),
        vec2(-2.0, -2.0), vec2(2.0, -2.0),
        vec2(-2.0, 2.0), vec2(2.0, 2.0)
      ]

      def outline_dir_4(idx : Int32, pixel_step : Vec2) : Vec2
        DIRS_4[idx] * pixel_step
      end

      def outline_dir_8(idx : Int32, pixel_step : Vec2) : Vec2
        DIRS_8[idx] * pixel_step
      end

      def outline_dir_16(idx : Int32, pixel_step : Vec2) : Vec2
        DIRS_16[idx] * pixel_step
      end

      def outline_dir_24(idx : Int32, pixel_step : Vec2) : Vec2
        DIRS_24[idx] * pixel_step
      end
    CR

    OUTLINE_DEPTH_NORMAL_LIB = <<-CR
      # Reconstructs view-space 3D position using Godot 4.3+ / 4.8 Reverse-Z NDC [0..1]
      def reconstruct_view_pos(uv : Vec2, raw_depth : Float32, inv_proj : Mat4) : Vec3
        ndc = vec3(uv * 2.0 - 1.0, raw_depth)
        view_h = inv_proj * vec4(ndc, 1.0)
        view_h.xyz / max(abs(view_h.w), 0.000001)
      end

      # Exact Reverse-Z positive linear view-space depth in meters
      def linear_depth_reverse_z(uv : Vec2, raw_depth : Float32, inv_proj : Mat4) : Float32
        -reconstruct_view_pos(uv, raw_depth, inv_proj).z
      end

      # Alias for linear_depth_reverse_z
      def linear_view_depth(uv : Vec2, raw_depth : Float32, inv_proj : Mat4) : Float32
        -reconstruct_view_pos(uv, raw_depth, inv_proj).z
      end

      # Fast analytical Reverse-Z [1.0 near .. 0.0 far] depth linearization
      def fast_linear_depth_reverse_z(raw_depth : Float32, z_near : Float32, z_far : Float32) : Float32
        (z_near * z_far) / max(z_near + raw_depth * (z_far - z_near), 0.00001)
      end

      # Grazing-angle multiplier >= 1.0 to suppress false flat-floor depth bands
      def grazing_depth_scale(view_normal : Vec3, view_dir : Vec3, grazing_strength : Float32) : Float32
        ndotv = clamp(abs(dot(view_normal, view_dir)), 0.0, 1.0)
        1.0 + (1.0 - ndotv) * grazing_strength
      end

      # Grazing-angle adaptive depth threshold
      def grazing_depth_threshold(base_threshold : Float32, view_normal : Vec3, view_dir : Vec3, grazing_strength : Float32) : Float32
        base_threshold * grazing_depth_scale(view_normal, view_dir, grazing_strength)
      end

      # Relative depth discontinuity test between center and neighbor view depths
      def is_depth_edge(z_center : Float32, z_neighbor : Float32, threshold : Float32, grazing_mult : Float32) : Bool
        rel_diff = abs(z_center - z_neighbor) / max(min(z_center, z_neighbor), 0.001)
        rel_diff > (threshold * grazing_mult)
      end

      # Unpacks [0..1] encoded RGB normal from Forward+ normal_roughness or hint_normal_roughness_texture
      def unpack_view_normal(encoded_rgb : Vec3) : Vec3
        len_sq = dot(encoded_rgb, encoded_rgb)
        if len_sq < 0.00001
          vec3(0.0, 0.0, 1.0)
        else
          normalize(encoded_rgb * 2.0 - 1.0)
        end
      end

      # Unpacks Forward+ normal_roughness RGBA into vec4(view_normal.xyz, roughness)
      def unpack_normal_roughness(raw : Vec4) : Vec4
        n = unpack_view_normal(raw.xyz)
        r = raw.w > 0.5 ? (1.0 - raw.w) * 2.0 : raw.w * 2.0
        vec4(n, clamp(r, 0.0, 1.0))
      end

      # Transforms unpacked view-space normal into world space
      def view_to_world_normal(view_normal : Vec3, inv_view : Mat4) : Vec3
        normalize((inv_view * vec4(view_normal, 0.0)).xyz)
      end

      # Evaluates 4-neighbor normal crease discontinuity in [0..2]
      def normal_crease_edge(n_center : Vec3, n_up : Vec3, n_down : Vec3, n_left : Vec3, n_right : Vec3) : Float32
        d_up = 1.0 - clamp(dot(n_center, n_up), -1.0, 1.0)
        d_down = 1.0 - clamp(dot(n_center, n_down), -1.0, 1.0)
        d_left = 1.0 - clamp(dot(n_center, n_left), -1.0, 1.0)
        d_right = 1.0 - clamp(dot(n_center, n_right), -1.0, 1.0)
        max(max(d_up, d_down), max(d_left, d_right))
      end

      # Evaluates normalized symmetric depth edge discontinuity across 4 neighbors
      def symmetric_depth_edge(d_center : Float32, d_up : Float32, d_down : Float32, d_left : Float32, d_right : Float32) : Float32
        lap_v = abs((d_up + d_down) - 2.0 * d_center)
        lap_h = abs((d_left + d_right) - 2.0 * d_center)
        (lap_v + lap_h) / max(d_center, 0.001)
      end
    CR

    OUTLINE_ID_PACKING_LIB = <<-CR
      OUTLINE_ID_TAG_MASK = 1660944384_u32
      OUTLINE_ID_TAG_BITS = 1090519040_u32

      record PixelOutlineSample,
        rgb : Vec3,
        surface_id : UInt32,
        group_id : UInt32,
        valid : Bool

      record PaletteOutlineSample,
        surface_id : UInt32,
        polygon_id : UInt32,
        outline_id : UInt32,
        depth : Float32

      record OutlineDecision,
        is_outline : Bool,
        outline_id : UInt32,
        edge_strength : Float32

      def float_to_bits_u32(v : Float32) : UInt32
        float_bits_to_uint(v)
      end

      def bits_u32_to_float(b : UInt32) : Float32
        uint_bits_to_float(b)
      end

      # Packs a 14-bit surface_id + 8-bit group_id into finite IEEE-754 float bits (safe in RGBA16F/RGBA32F alpha)
      def pack_outline_meta(surface_id : UInt32, group_id : UInt32) : Float32
        payload = ((surface_id & 16383_u32) << 8_u32) | (group_id & 255_u32)
        bits_u32_to_float(OUTLINE_ID_TAG_BITS | payload)
      end

      def unpack_outline_id(packed_alpha : Float32) : UInt32
        bits = float_to_bits_u32(packed_alpha)
        if (bits & OUTLINE_ID_TAG_MASK) == OUTLINE_ID_TAG_BITS
          (bits >> 8_u32) & 16383_u32
        else
          0_u32
        end
      end

      # Decodes an RGBA color+metadata sample whose alpha was encoded with `pack_outline_meta`
      def decode_outline_pixel(rgba : Vec4) : PixelOutlineSample
        bits = float_to_bits_u32(rgba.a)
        is_tagged = (bits & OUTLINE_ID_TAG_MASK) == OUTLINE_ID_TAG_BITS
        surf = is_tagged ? ((bits >> 8_u32) & 16383_u32) : 0_u32
        grp = is_tagged ? (bits & 255_u32) : 0_u32
        PixelOutlineSample.new(rgba.rgb, surf, grp, is_tagged)
      end

      # Losslessly packs a 0-based palette index into [0..1] float channel
      def pack_palette_id(color_idx : Float32, total_colors : UInt32) : Float32
        (color_idx + 1.0) / float(total_colors + 2_u32)
      end

      # Unpacks a [0..1] float channel back to its 0-based palette index
      def unpack_palette_id(packed_val : Float32, total_colors : UInt32) : UInt32
        raw = round(packed_val * float(total_colors + 2_u32)) - 1.0
        uint(max(raw, 0.0))
      end

      # Packs surface bit-ID + polygon palette index + outline palette index into RGB
      def pack_surface_and_palette_ids(surface_id : UInt32, polygon_id : UInt32, outline_id : UInt32, total_colors : UInt32) : Vec3
        vec3(
          uint_bits_to_float(surface_id),
          pack_palette_id(float(polygon_id), total_colors),
          pack_palette_id(float(outline_id), total_colors)
        )
      end

      # Unpacks an RGB ID-buffer sample + raw depth into a typed PaletteOutlineSample
      def unpack_palette_outline_sample(id_rgb : Vec3, raw_depth : Float32, total_colors : UInt32) : PaletteOutlineSample
        PaletteOutlineSample.new(
          float_bits_to_uint(id_rgb.r),
          unpack_palette_id(id_rgb.g, total_colors),
          unpack_palette_id(id_rgb.b, total_colors),
          raw_depth
        )
      end

      # Exact IEC 61966-2-1 sRGB -> Linear RGB conversion
      def srgb_to_linear_rgb(c : Vec3) : Vec3
        lo = c / 12.92
        hi = ((c + 0.055) / 1.055) ** vec3(2.4, 2.4, 2.4)
        t = step(vec3(0.04045, 0.04045, 0.04045), c)
        mix(lo, hi, t)
      end

      def srgb_to_linear(c : Vec3) : Vec3
        srgb_to_linear_rgb(c)
      end

      # Exact IEC 61966-2-1 Linear RGB -> sRGB conversion
      def linear_to_srgb_rgb(c : Vec3) : Vec3
        clamped = max(c, vec3(0.0, 0.0, 0.0))
        lo = clamped * 12.92
        hi = 1.055 * (clamped ** vec3(1.0 / 2.4, 1.0 / 2.4, 1.0 / 2.4)) - 0.055
        t = step(vec3(0.0031308, 0.0031308, 0.0031308), clamped)
        mix(lo, hi, t)
      end

      def linear_to_srgb(c : Vec3) : Vec3
        linear_to_srgb_rgb(c)
      end
    CR

    OUTLINE_MORPHOLOGY_LIB = <<-CR
      record MorphologyStroke,
        stroke_factor : Float32,
        out_alpha : Float32,
        contour_normal : Vec2

      # 90s Squigglevision / hand-drawn boiling outline radius multiplier
      def outline_boiling_scale(uv : Vec2, time : Float32, boil_amp : Float32, boil_freq : Float32) : Float32
        if boil_amp <= 0.0
          1.0
        else
          boil = sin(uv.x * boil_freq * 6.2831853 + time * 12.0) * cos(uv.y * boil_freq * 6.2831853 - time * 9.0)
          max(0.1, 1.0 + boil * boil_amp)
        end
      end

      # Stepped frame-quantized UV line boil (Squigglevision / hand-drawn wobble)
      def apply_line_boil(uv : Vec2, texel_size : Vec2, time : Float32, fps : Float32, amp_px : Float32, freq : Float32) : Vec2
        if amp_px <= 0.0
          uv
        else
          q_time = floor(time * max(fps, 1.0)) / max(fps, 1.0)
          phase = uv * freq * 18.8495559 + vec2(q_time * 17.3, -q_time * 13.7)
          jitter = vec2(sin(phase.x + cos(phase.y)), cos(phase.y - sin(phase.x)))
          uv + jitter * texel_size * amp_px
        end
      end

      # Classic Win98 / embossed top-left highlight & bottom-right shadow tint on outline stroke
      def apply_win98_bevel(base_rgb : Vec3, edge_dir : Vec2, highlight_strength : Float32, shadow_strength : Float32) : Vec3
        light_axis = normalize(vec2(-0.70710678, -0.70710678))
        n_dir = dot(edge_dir, edge_dir) > 0.00001 ? normalize(edge_dir) : vec2(0.0, -1.0)
        facing = dot(n_dir, light_axis)
        if facing >= 0.0
          mix(base_rgb, vec3(1.0, 1.0, 1.0), clamp(facing * highlight_strength, 0.0, 1.0))
        else
          mix(base_rgb, vec3(0.0, 0.0, 0.0), clamp(-facing * shadow_strength, 0.0, 1.0))
        end
      end

      # Converts pixel/texel stroke offset into UV offset (mesh-scaling texels vs screen-constant pixels)
      def compute_scaled_uv_offset(offset_px : Vec2, tex_size : Vec2, duv_dx : Vec2, duv_dy : Vec2, world_scaling : Bool) : Vec2
        if world_scaling
          offset_px / max(tex_size, vec2(1.0, 1.0))
        else
          duv_dx * offset_px.x + duv_dy * offset_px.y
        end
      end

      # Solves Outer (0), Inner (1), and Center/Hide-Edge (2) morphological stroke + contour normal
      def resolve_morphology_stroke(
        base_alpha : Float32,
        min_alpha : Float32,
        max_alpha : Float32,
        internal_diff : Float32,
        cutoff : Float32,
        smoothness : Float32,
        internal_threshold : Float32,
        outline_alpha : Float32,
        mode : Int32,
        hard_edges : Bool,
        contour_grad : Vec2
      ) : MorphologyStroke
        soft = max(smoothness, 0.0001)
        is_dilated = (max_alpha >= cutoff && max_alpha > 0.0) ? 1.0 : 0.0
        eroded_interior = (smoothness > 0.0) ? smoothstep(cutoff - soft, cutoff + soft, min_alpha) : ((min_alpha >= cutoff) ? 1.0 : 0.0)

        internal_edge = 0.0
        if internal_threshold > 0.0 && internal_diff >= internal_threshold
          internal_edge = (smoothness > 0.0) ? smoothstep(internal_threshold - soft, internal_threshold + soft, internal_diff) : 1.0
        end

        stroke_factor = 0.0
        out_alpha = base_alpha

        if mode == 0
          if base_alpha <= 0.0 && is_dilated > 0.0
            stroke_factor = 1.0
            out_alpha = outline_alpha
          end
        elsif mode == 1
          if base_alpha > 0.0
            stroke_factor = max(1.0 - eroded_interior, internal_edge)
          end
        else
          if is_dilated > 0.0
            stroke_factor = max(1.0 - eroded_interior, internal_edge)
            out_alpha = (base_alpha > 0.0) ? max(base_alpha, outline_alpha * stroke_factor) : (outline_alpha * (hard_edges ? 1.0 : stroke_factor))
          end
        end

        norm_grad = dot(contour_grad, contour_grad) > 0.000001 ? normalize(contour_grad) : vec2(0.0, 0.0)
        MorphologyStroke.new(clamp(stroke_factor, 0.0, 1.0), out_alpha, norm_grad)
      end

      # Evaluates Win98 / enamel-pin signed contour bevel factor in [-strength, +strength]
      def evaluate_contour_bevel(contour_normal : Vec2, light_angle : Float32, strength : Float32) : Float32
        if dot(contour_normal, contour_normal) < 0.000001
          0.0
        else
          light_dir = vec2(cos(light_angle), sin(light_angle))
          dot(normalize(contour_normal), light_dir) * strength
        end
      end
    CR

    OUTLINE_COMBINED_LIB = [
      OUTLINE_DIRECTIONS_LIB,
      OUTLINE_DEPTH_NORMAL_LIB,
      OUTLINE_ID_PACKING_LIB,
      OUTLINE_MORPHOLOGY_LIB,
    ].join("\n\n")
  end
end
