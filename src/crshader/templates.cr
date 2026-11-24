module CrShader
  # =============================================================================
  # CrShader::Templates - Built-in Authoring Templates Across All Shader Modes
  # =============================================================================
  # Powers Godot 4.8's "Create Shader" dialog (Ctrl+N in the Shader Editor),
  # the CRShader toolbar menu, CrShaderTabEditor template picker, and `crshader new`.
  module Templates
    extend self

    enum Mode
      Spatial
      CanvasItem
      Particles
      Sky
      Fog
      Compute
      ShaderInclude

      def display_name : String
        case self
        when Spatial       then "Spatial"
        when CanvasItem    then "Canvas Item"
        when Particles     then "Particles"
        when Sky           then "Sky"
        when Fog           then "Fog"
        when Compute       then "Compute"
        when ShaderInclude then "Shader Include"
        else                    "Spatial"
        end
      end

      def slug : String
        case self
        when Spatial       then "spatial"
        when CanvasItem    then "canvas_item"
        when Particles     then "particles"
        when Sky           then "sky"
        when Fog           then "fog"
        when Compute       then "compute"
        when ShaderInclude then "shader_include"
        else                    "spatial"
        end
      end

      def self.from_string?(value : String) : Mode?
        case value.strip.downcase.gsub(/[\s\-]+/, "_")
        when "spatial", "3d"
          Spatial
        when "canvas_item", "canvas", "2d"
          CanvasItem
        when "particles", "particle"
          Particles
        when "sky"
          Sky
        when "fog"
          Fog
        when "compute", "glsl", "compositor"
          Compute
        when "shader_include", "gdshaderinc", "include", "inc"
          ShaderInclude
        else
          nil
        end
      end
    end

    struct Entry
      getter id : String
      getter name : String
      getter mode : Mode
      getter summary : String
      getter source : String

      def initialize(
        @id : String,
        @name : String,
        @mode : Mode,
        @summary : String,
        @source : String,
      )
      end

      # Renders template source, dedenting common heredoc margin and substituting `{{STEM}}`.
      def render(file_path : String = "new_shader.crshader") : String
        base = File.basename(file_path.empty? ? "new_shader.crshader" : file_path)
        stem = base.sub(/\.(crshader|gdshader|gdshaderinc|glsl)$/i, "")
        stem = "new_shader" if stem.empty?
        substituted = @source.gsub("{{STEM}}", stem)
        lines = substituted.lines
        min_indent = lines
          .reject(&.strip.empty?)
          .map { |l| l.size - l.lstrip(' ').size }
          .min? || 0
        dedented = if min_indent > 0
                     lines.map { |l| l.strip.empty? ? "" : l[min_indent..] }.join("\n")
                   else
                     substituted
                   end
        dedented.rstrip + "\n"
      end
    end

    ALL_MODES = [
      Mode::Spatial,
      Mode::CanvasItem,
      Mode::Particles,
      Mode::Sky,
      Mode::Fog,
      Mode::Compute,
      Mode::ShaderInclude,
    ]

    CATALOG = [
      # =========================================================================
      # 1. SPATIAL (3D Surface & Material Shaders)
      # =========================================================================
      Entry.new(
        id: "spatial_default",
        name: "Default (Standard PBR)",
        mode: Mode::Spatial,
        summary: "Standard 3D physically-based surface shader with albedo, roughness, and metallic uniforms.",
        source: <<-CR
          shader_type :spatial
          render_mode :cull_back, :diffuse_burley, :specular_schlick_ggx

          uniform albedo_color : Color = Color.new(0.22, 0.62, 0.96, 1.0), hint: :source_color
          uniform albedo_tex : Sampler2D, hint: :source_color, filter: :linear_mipmap
          uniform roughness_val : Float32 = 0.35, range: 0.0..1.0
          uniform metallic_val : Float32 = 0.05, range: 0.0..1.0

          vertex do
            # Called for every vertex the material is visible on.
          end

          fragment do
            tex = texture(albedo_tex, UV)
            ALBEDO = albedo_color.rgb * tex.rgb
            ROUGHNESS = roughness_val
            METALLIC = metallic_val
          end
        CR
      ),
      Entry.new(
        id: "spatial_empty",
        name: "Empty",
        mode: Mode::Spatial,
        summary: "Minimal empty 3D Spatial CRShader skeleton.",
        source: <<-CR
          shader_type :spatial

          fragment do
            ALBEDO = vec3(1.0, 1.0, 1.0)
          end
        CR
      ),
      Entry.new(
        id: "spatial_toon",
        name: "Toon / Cel Shaded Surface",
        mode: Mode::Spatial,
        summary: "Stylized cel-shaded 3D material with perceptual Oklab color ramp and rim Fresnel glow.",
        source: <<-CR
          surface_material :toon do
            property base_tint : Color = Color.hex("#38bdf8"), hint: :source_color
            property roughness_val : Float32 = 0.4, range: 0.0..1.0

            gradient :cel_ramp, {
              0.0 => Color.hex("#0f172a"),
              0.5 => Color.hex("#2563eb"),
              1.0 => Color.hex("#bae6fd"),
            }, space: :oklab, interp: :smooth

            use_trait "std/traits/rim_fresnel"

            shade_t = clamp(1.0 - UV.y, 0.0, 1.0)
            ALBEDO = cel_ramp(shade_t).rgb * base_tint.rgb
            ROUGHNESS = roughness_val
          end
        CR
      ),
      Entry.new(
        id: "spatial_dissolve_hitflash",
        name: "Dissolve & Hit Flash VFX",
        mode: Mode::Spatial,
        summary: "Combat-ready 3D surface combining procedural noise dissolve and damage hit-flash traits.",
        source: <<-CR
          surface_material :pbr do
            property albedo_color : Color = Color.hex("#e2e8f0"), hint: :source_color
            property roughness_val : Float32 = 0.45, range: 0.0..1.0

            use_trait "std/traits/dissolve"
            use_trait "std/traits/hit_flash"

            ALBEDO = albedo_color.rgb
            ROUGHNESS = roughness_val
          end
        CR
      ),
      Entry.new(
        id: "spatial_foliage_wind",
        name: "Foliage & Wind Sway",
        mode: Mode::Spatial,
        summary: "Two-sided alpha-prepass foliage material with procedural vertex wind sway and backlight.",
        source: <<-CR
          surface_material :foliage do
            sampler leaf_tex, filter: :linear_mipmap
            property leaf_tint : Color = Color.hex("#4ade80"), hint: :source_color
            property alpha_scissor : Float32 = 0.5, range: 0.0..1.0
            property backlight_tint : Color = Color.hex("#bef264"), hint: :source_color

            use_trait "std/traits/wind_sway"

            tex = texture(leaf_tex, UV)
            ALBEDO = tex.rgb * leaf_tint.rgb
            ALPHA = tex.a
            ALPHA_SCISSOR_THRESHOLD = alpha_scissor
            ROUGHNESS = 0.65
            BACKLIGHT = backlight_tint.rgb * 0.35
          end
        CR
      ),
      Entry.new(
        id: "spatial_water_waves",
        name: "Water / Animated Waves",
        mode: Mode::Spatial,
        summary: "Translucent animated 3D water surface with vertex waves and Fresnel horizon tint.",
        source: <<-CR
          surface_material :glass do
            require "std/math"

            property shallow_color : Color = Color.hex("#22d3ee"), hint: :source_color
            property deep_color : Color = Color.hex("#0c4a6e"), hint: :source_color
            property wave_height : Float32 = 0.12, range: 0.0..1.0
            property wave_speed : Float32 = 1.8, range: 0.0..8.0
            property wave_scale : Float32 = 2.5, range: 0.1..12.0
            property opacity : Float32 = 0.82, range: 0.1..1.0

            vertex do
              phase_x = VERTEX.x * wave_scale + TIME * wave_speed
              phase_z = VERTEX.z * (wave_scale * 0.85) + TIME * (wave_speed * 0.75)
              VERTEX.y += (sin(phase_x) + cos(phase_z)) * 0.5 * wave_height
            end

            fragment do
              fres = fresnel(3.0, NORMAL, VIEW)
              ripple = sin(UV.x * 24.0 + TIME * wave_speed) * cos(UV.y * 24.0 - TIME * wave_speed) * 0.5 + 0.5
              ALBEDO = mix(deep_color.rgb, shallow_color.rgb, clamp(fres + ripple * 0.15, 0.0, 1.0))
              ROUGHNESS = 0.08
              METALLIC = 0.1
              ALPHA = opacity
            end
          end
        CR
      ),
      Entry.new(
        id: "spatial_hologram_shield",
        name: "Hologram / Forcefield Shield",
        mode: Mode::Spatial,
        summary: "Additive glowing energy shield with Fresnel rim, scrolling scanlines, and emission pulse.",
        source: <<-CR
          shader_type :spatial
          render_mode :blend_add, :depth_draw_never, :cull_disabled, :unshaded

          require "std/math"

          uniform shield_color : Color = Color.hex("#38bdf8"), hint: :source_color
          uniform rim_sharpness : Float32 = 2.8, range: 0.5..8.0
          uniform scanline_density : Float32 = 48.0, range: 4.0..200.0
          uniform scanline_speed : Float32 = 2.5, range: 0.0..12.0

          use_trait "std/traits/emission_pulse"

          fragment do
            rim = fresnel(rim_sharpness, NORMAL, VIEW)
            scan = sin(UV.y * scanline_density - TIME * scanline_speed * 6.28318) * 0.5 + 0.5
            mask = clamp(rim * 0.85 + scan * 0.2, 0.0, 1.0)
            ALBEDO = shield_color.rgb * (1.0 + rim * 1.5)
            ALPHA = mask
          end
        CR
      ),
      Entry.new(
        id: "spatial_triplanar",
        name: "Triplanar World-Aligned Surface",
        mode: Mode::Spatial,
        summary: "UV-free world-space triplanar texture projection ideal for terrain, cliffs, and greyboxing.",
        source: <<-CR
          surface_material :pbr do
            property base_color : Color = Color.hex("#cbd5e1"), hint: :source_color
            property roughness_val : Float32 = 0.75, range: 0.0..1.0

            use_trait "std/traits/triplanar_surface"

            ALBEDO = base_color.rgb
            ROUGHNESS = roughness_val
          end
        CR
      ),

      # =========================================================================
      # 2. CANVAS ITEM (2D Sprite, UI & Screen Shaders)
      # =========================================================================
      Entry.new(
        id: "canvas_default",
        name: "Default (2D Sprite)",
        mode: Mode::CanvasItem,
        summary: "Standard 2D CanvasItem shader sampling TEXTURE with customizable color tint.",
        source: <<-CR
          shader_type :canvas_item

          uniform tint_color : Color = Color.new(1.0, 1.0, 1.0, 1.0), hint: :source_color

          vertex do
            # Called for every vertex the CanvasItem is visible on.
          end

          fragment do
            COLOR = texture(TEXTURE, UV) * COLOR * tint_color
          end
        CR
      ),
      Entry.new(
        id: "canvas_empty",
        name: "Empty",
        mode: Mode::CanvasItem,
        summary: "Minimal empty 2D CanvasItem CRShader skeleton.",
        source: <<-CR
          shader_type :canvas_item

          fragment do
            COLOR = texture(TEXTURE, UV) * COLOR
          end
        CR
      ),
      Entry.new(
        id: "canvas_sprite_outline_flash",
        name: "Sprite Hit Flash & Pixel Outline",
        mode: Mode::CanvasItem,
        summary: "2D sprite archetype with 4-neighbor pixel outline stroke and animated damage flash.",
        source: <<-CR
          sprite_effect do |uv, color, px|
            property outline_color : Color = Color.hex("#0f172a"), hint: :source_color
            property outline_width : Float32 = 1.0, range: 0.0..8.0
            property flash_color : Color = Color.hex("#ffffff"), hint: :source_color
            property flash_amount : Float32 = 0.0, range: 0.0..1.0

            step_uv = px * outline_width
            a_up = texture(TEXTURE, uv + vec2(0.0, -step_uv.y)).a
            a_down = texture(TEXTURE, uv + vec2(0.0, step_uv.y)).a
            a_left = texture(TEXTURE, uv + vec2(-step_uv.x, 0.0)).a
            a_right = texture(TEXTURE, uv + vec2(step_uv.x, 0.0)).a
            neighbor_a = clamp(a_up + a_down + a_left + a_right, 0.0, 1.0)

            outlined_rgb = mix(outline_color.rgb, color.rgb, color.a)
            outlined_a = max(color.a, neighbor_a * outline_color.a)
            flashed_rgb = mix(outlined_rgb, flash_color.rgb, clamp(flash_amount, 0.0, 1.0))

            vec4(flashed_rgb, outlined_a)
          end
        CR
      ),
      Entry.new(
        id: "canvas_sprite_dissolve",
        name: "Sprite Dissolve & Burn Edge",
        mode: Mode::CanvasItem,
        summary: "2D sprite procedural noise dissolve with glowing ember border.",
        source: <<-CR
          sprite_effect do |uv, color|
            require "std/noise"

            property dissolve_amount : Float32 = 0.0, range: 0.0..1.0
            property noise_scale : Float32 = 14.0, range: 1.0..64.0
            property burn_width : Float32 = 0.08, range: 0.005..0.3
            property burn_color : Color = Color.hex("#fb923c"), hint: :source_color

            n = value_noise(uv * noise_scale)
            alpha_mask = step(dissolve_amount, n)
            burn_edge = smoothstep(dissolve_amount + burn_width, dissolve_amount, n) * step(0.001, dissolve_amount)
            lit_rgb = mix(color.rgb, burn_color.rgb * 2.0, burn_edge)

            vec4(lit_rgb, color.a * alpha_mask)
          end
        CR
      ),
      Entry.new(
        id: "canvas_wave_distortion",
        name: "2D UV Wave / Distortion",
        mode: Mode::CanvasItem,
        summary: "Animated sine wave UV distortion for underwater sprites, banners, and heat shimmer.",
        source: <<-CR
          sprite_effect do |uv, color|
            property wave_frequency : Float32 = 16.0, range: 1.0..64.0
            property wave_amplitude : Float32 = 0.02, range: 0.0..0.15
            property wave_speed : Float32 = 3.0, range: 0.0..15.0

            offset_x = sin(uv.y * wave_frequency + TIME * wave_speed) * wave_amplitude
            offset_y = cos(uv.x * wave_frequency + TIME * (wave_speed * 0.8)) * (wave_amplitude * 0.5)
            warped_uv = clamp(uv + vec2(offset_x, offset_y), vec2(0.0, 0.0), vec2(1.0, 1.0))

            texture(TEXTURE, warped_uv) * COLOR
          end
        CR
      ),
      Entry.new(
        id: "canvas_ui_sdf_card",
        name: "UI Rounded SDF Card & Glow",
        mode: Mode::CanvasItem,
        summary: "Aspect-corrected 2D UI panel with anti-aliased rounded corners, border stroke, and glow.",
        source: <<-CR
          ui_effect do |uv, centered_uv, color|
            require "std/sdf2d"

            property card_half_size : Vec2 = Vec2.new(0.42, 0.32)
            property corner_radius : Float32 = 0.06, range: 0.0..0.25
            property border_width : Float32 = 0.01, range: 0.001..0.05
            property fill_color : Color = Color.hex("#0f172a"), hint: :source_color
            property border_color : Color = Color.hex("#38bdf8"), hint: :source_color
            property glow_strength : Float32 = 0.5, range: 0.0..2.0

            d = sdf2d_rounded_box(centered_uv, card_half_size, corner_radius)
            fill = sdf_fill(d)
            border = sdf_stroke(d, border_width)
            glow = sdf_glow(d, 0.07, 2.2) * glow_strength

            rgb = fill_color.rgb * fill + border_color.rgb * (border + glow * 0.45)
            alpha = clamp(fill * fill_color.a + border + glow * 0.5, 0.0, 1.0) * color.a
            vec4(rgb, alpha)
          end
        CR
      ),
      Entry.new(
        id: "canvas_screen_postprocess",
        name: "Screen Post-Process (Vignette & Chromatic)",
        mode: Mode::CanvasItem,
        summary: "Fullscreen ColorRect post-processing stack fusing chromatic aberration, color grade, and vignette.",
        source: <<-CR
          screen_effect do |uv, color|
            use_trait "std/traits/chromatic_aberration"
            use_trait "std/traits/color_grade"
            use_trait "std/traits/vignette"
          end
        CR
      ),
      Entry.new(
        id: "canvas_crt_dither",
        name: "Retro CRT & Bayer Dither",
        mode: Mode::CanvasItem,
        summary: "Fullscreen retro CRT curvature, scanlines, and ordered 4x4 Bayer dithering.",
        source: <<-CR
          screen_effect do |uv, color|
            require "std/post_processing"
            require "std/dither"

            property curvature : Float32 = 0.12, range: 0.0..0.5
            property color_levels : Float32 = 16.0, range: 2.0..64.0
            property scanline_strength : Float32 = 0.18, range: 0.0..0.6

            warped = barrel_distortion(uv, curvature)
            sampled = texture(screen_texture, clamp(warped, vec2(0.0, 0.0), vec2(1.0, 1.0)))

            px_coord = ivec2(FRAGCOORD.xy)
            bayer = bayer4x4(px_coord) - 0.5
            quant_r = dither_quantize(sampled.r, color_levels, bayer)
            quant_g = dither_quantize(sampled.g, color_levels, bayer)
            quant_b = dither_quantize(sampled.b, color_levels, bayer)

            scan = 1.0 - (sin(FRAGCOORD.y * 3.14159) * 0.5 + 0.5) * scanline_strength
            vec4(vec3(quant_r, quant_g, quant_b) * scan, 1.0)
          end
        CR
      ),

      # =========================================================================
      # 3. PARTICLES (GPU Particle Process Shaders)
      # =========================================================================
      Entry.new(
        id: "particles_default",
        name: "Default (Velocity & Gravity)",
        mode: Mode::Particles,
        summary: "GPU particle shader with randomized radial launch velocity, gravity, and tint.",
        source: <<-CR
          shader_type :particles

          uniform initial_speed : Float32 = 4.0, range: 0.0..30.0
          uniform spread : Float32 = 1.0, range: 0.0..5.0
          uniform gravity_accel : Vec3 = Vec3.new(0.0, -4.5, 0.0)
          uniform start_color : Color = Color.hex("#38bdf8"), hint: :source_color

          def start
            rx = (fract(sin(float(INDEX) * 12.9898 + float(SEED)) * 43758.5453) - 0.5) * spread
            rz = (fract(cos(float(INDEX) * 78.233 + float(SEED)) * 43758.5453) - 0.5) * spread
            VELOCITY = vec3(rx, initial_speed, rz)
            COLOR = start_color
          end

          def process
            VELOCITY += gravity_accel * DELTA
          end
        CR
      ),
      Entry.new(
        id: "particles_empty",
        name: "Empty",
        mode: Mode::Particles,
        summary: "Minimal GPU particle process shader skeleton.",
        source: <<-CR
          shader_type :particles

          def start
          end

          def process
          end
        CR
      ),
      Entry.new(
        id: "particles_fire_embers",
        name: "Stylized Fire & Smoke Embers",
        mode: Mode::Particles,
        summary: "Buoyant rising embers with turbulent swirl and ignition-to-smoke color transition.",
        source: <<-CR
          shader_type :particles

          uniform launch_speed : Float32 = 3.5, range: 0.5..20.0
          uniform spread_factor : Float32 = 1.2, range: 0.0..5.0
          uniform buoyancy : Float32 = 3.0, range: 0.0..15.0
          uniform turbulence : Float32 = 2.0, range: 0.0..10.0
          uniform flame_hot : Color = Color.hex("#fde047"), hint: :source_color
          uniform flame_mid : Color = Color.hex("#f97316"), hint: :source_color

          def start
            rx = (sin(float(INDEX) * 12.9898 + float(SEED)) - 0.5) * spread_factor
            rz = (cos(float(INDEX) * 78.233 + float(SEED)) - 0.5) * spread_factor
            VELOCITY = vec3(rx, launch_speed, rz)
            COLOR = flame_hot
          end

          def process
            swirl_x = sin(TIME * 4.0 + float(INDEX)) * turbulence
            swirl_z = cos(TIME * 4.0 + float(INDEX)) * turbulence
            VELOCITY += vec3(swirl_x, buoyancy, swirl_z) * DELTA
            COLOR = mix(flame_hot, flame_mid, clamp(DELTA * 8.0, 0.0, 1.0))
          end
        CR
      ),
      Entry.new(
        id: "particles_vortex_swarm",
        name: "Vortex & Orbital Swarm",
        mode: Mode::Particles,
        summary: "Uses std/particles vortex and point-attractor forces for portals and energy swarms.",
        source: <<-CR
          shader_type :particles

          require "std/particles"

          uniform attractor_pos : Vec3 = Vec3.new(0.0, 1.0, 0.0)
          uniform orbit_radius : Float32 = 6.0, range: 0.5..30.0
          uniform vortex_strength : Float32 = 8.0, range: 0.0..30.0
          uniform pull_strength : Float32 = 4.0, range: 0.0..20.0
          uniform drag_amount : Float32 = 0.8, range: 0.0..5.0

          def start
            angle = float(INDEX) * 0.618034 * 6.28318
            VELOCITY = vec3(cos(angle) * 2.0, 0.5, sin(angle) * 2.0)
          end

          def process
            pos = TRANSFORM[3].xyz
            swirl = vortex_force_3d(pos, attractor_pos, vortex_strength, orbit_radius)
            pull = attract_point(pos, attractor_pos, pull_strength, orbit_radius)
            VELOCITY = apply_linear_drag(VELOCITY + (swirl + pull) * DELTA, drag_amount, DELTA)
          end
        CR
      ),

      # =========================================================================
      # 4. SKY (3D Environment Sky Shaders)
      # =========================================================================
      Entry.new(
        id: "sky_default",
        name: "Default (Procedural Horizon & Sun)",
        mode: Mode::Sky,
        summary: "Procedural sky dome blending zenith, horizon, ground, and directional sun disc.",
        source: <<-CR
          shader_type :sky

          uniform sky_top_color : Color = Color.hex("#0f172a"), hint: :source_color
          uniform sky_horizon_color : Color = Color.hex("#38bdf8"), hint: :source_color
          uniform ground_color : Color = Color.hex("#1e293b"), hint: :source_color
          uniform sun_size : Float32 = 0.03, range: 0.002..0.2

          sky do
            up_t = clamp(EYEDIR.y, 0.0, 1.0)
            down_t = clamp(-EYEDIR.y, 0.0, 1.0)
            dome = mix(sky_horizon_color.rgb, sky_top_color.rgb, up_t ** 0.6)
            dome = mix(dome, ground_color.rgb, smoothstep(0.0, 0.15, down_t))

            if LIGHT0_ENABLED
              sun_angle = acos(clamp(dot(EYEDIR, LIGHT0_DIRECTION), -1.0, 1.0))
              sun_disc = smoothstep(sun_size, sun_size * 0.5, sun_angle)
              dome += LIGHT0_COLOR * (sun_disc * LIGHT0_ENERGY)
            end

            COLOR = dome
          end
        CR
      ),
      Entry.new(
        id: "sky_empty",
        name: "Empty",
        mode: Mode::Sky,
        summary: "Minimal 3D Environment Sky shader skeleton.",
        source: <<-CR
          shader_type :sky

          sky do
            COLOR = vec3(0.15, 0.28, 0.52)
          end
        CR
      ),
      Entry.new(
        id: "sky_sunset_stars",
        name: "Stylized Sunset & Starfield",
        mode: Mode::Sky,
        summary: "Perceptual Oklab twilight sky ramp with procedural twinkling zenith stars.",
        source: <<-CR
          shader_type :sky

          require "std/noise"

          uniform star_density : Float32 = 180.0, range: 20.0..500.0
          uniform star_brightness : Float32 = 1.4, range: 0.0..4.0

          gradient :twilight_sky, {
            0.0 => Color.hex("#fb923c"),
            0.35 => Color.hex("#7c3aed"),
            1.0 => Color.hex("#020617"),
          }, space: :oklab, interp: :smooth

          sky do
            t = clamp(EYEDIR.y * 0.85 + 0.15, 0.0, 1.0)
            base_sky = twilight_sky(t).rgb

            star_cell = floor(SKY_COORDS * star_density)
            star_seed = hash11(star_cell.x + star_cell.y * 113.0)
            twinkle = sin(TIME * 3.0 + star_seed * 31.4) * 0.35 + 0.65
            star_mask = step(0.992, star_seed) * smoothstep(0.1, 0.55, EYEDIR.y)

            COLOR = base_sky + vec3(star_mask * twinkle * star_brightness)
          end
        CR
      ),

      # =========================================================================
      # 5. FOG (3D Volumetric Fog Shaders)
      # =========================================================================
      Entry.new(
        id: "fog_default",
        name: "Default (Height-Attenuated Fog)",
        mode: Mode::Fog,
        summary: "Volumetric height fog with smooth exponential altitude falloff.",
        source: <<-CR
          shader_type :fog

          uniform base_density : Float32 = 0.08, range: 0.0..1.0
          uniform fog_tint : Color = Color.hex("#cbd5e1"), hint: :source_color
          uniform height_level : Float32 = 0.0
          uniform height_falloff : Float32 = 0.35, range: 0.01..4.0

          fog do
            rel_h = max(WORLD_POSITION.y - height_level, 0.0)
            DENSITY = base_density * exp(-rel_h * height_falloff)
            FOG_COLOR = fog_tint
          end
        CR
      ),
      Entry.new(
        id: "fog_empty",
        name: "Empty",
        mode: Mode::Fog,
        summary: "Minimal 3D Volumetric Fog shader skeleton.",
        source: <<-CR
          shader_type :fog

          fog do
            DENSITY = 0.04
            FOG_COLOR = vec4(0.8, 0.85, 0.92, 1.0)
          end
        CR
      ),
      Entry.new(
        id: "fog_rolling_mist",
        name: "Animated Rolling Ground Mist",
        mode: Mode::Fog,
        summary: "Scrolling procedural noise mist clinging to low terrain elevations.",
        source: <<-CR
          shader_type :fog

          require "std/noise"

          uniform mist_density : Float32 = 0.15, range: 0.0..1.0
          uniform mist_color : Color = Color.hex("#94a3b8"), hint: :source_color
          uniform wind_velocity : Vec2 = Vec2.new(0.4, 0.2)
          uniform noise_scale : Float32 = 0.18, range: 0.02..2.0
          uniform ceiling_height : Float32 = 4.0, range: 0.5..30.0

          fog do
            sample_uv = WORLD_POSITION.xz * noise_scale + wind_velocity * TIME
            n = value_noise(sample_uv)
            height_mask = clamp(1.0 - WORLD_POSITION.y / max(ceiling_height, 0.01), 0.0, 1.0)
            DENSITY = mist_density * n * height_mask
            FOG_COLOR = mist_color
          end
        CR
      ),

      # =========================================================================
      # 6. COMPUTE (Vulkan GLSL Compute & Forward+ Compositor Effects)
      # =========================================================================
      Entry.new(
        id: "compute_default",
        name: "Default (GLSL Storage Buffer)",
        mode: Mode::Compute,
        summary: "Vulkan GLSL compute shader with std430 storage buffer and push constants.",
        source: <<-CR
          shader_type :compute
          local_size 64, 1, 1

          buffer DataBuffer, set: 0, binding: 0, std: :std430 do
            field values : Array(Float32)
          end

          push_constant Params do
            field count : UInt32
            field scale : Float32
          end

          def main
            idx = gl_GlobalInvocationID.x
            if idx >= params.count
              return
            end

            data_buffer.values[idx] = data_buffer.values[idx] * params.scale
          end
        CR
      ),
      Entry.new(
        id: "compute_empty",
        name: "Empty",
        mode: Mode::Compute,
        summary: "Minimal Vulkan GLSL compute shader skeleton.",
        source: <<-CR
          shader_type :compute
          local_size 8, 8, 1

          def main
          end
        CR
      ),
      Entry.new(
        id: "compute_compositor_post",
        name: "Compositor Post-Process Effect",
        mode: Mode::Compute,
        summary: "Forward+ CompositorEffect compute pass reading and writing viewport color.",
        source: <<-CR
          compositor_effect :post_transparent do
            access :color

            property tint_color : Color = Color.hex("#e0f2fe"), hint: :source_color
            property saturation : Float32 = 1.15, range: 0.0..2.5

            process_pixel do |pos, curr_color|
              luma = dot(curr_color.rgb, vec3(0.2126, 0.7152, 0.0722))
              graded = mix(vec3(luma, luma, luma), curr_color.rgb, saturation) * tint_color.rgb
              curr_color = vec4(graded, curr_color.a)
            end
          end
        CR
      ),
      Entry.new(
        id: "compute_compositor_depth_outline",
        name: "Compositor Depth Silhouette Outline",
        mode: Mode::Compute,
        summary: "Hardware Forward+ Compositor compute pass sampling Reverse-Z depth for crisp 3D outlines.",
        source: <<-CR
          compositor_effect :post_transparent do
            access :color, :depth

            property outline_color : Color = Color.new(0.05, 0.05, 0.08, 1.0), hint: :source_color
            property outline_thickness : Int32 = 1, hint: hint_range(1, 4)
            property depth_threshold : Float32 = 0.005, hint: hint_range(0.0001, 0.05, 0.0005)

            process_pixel do |pos, curr_color|
              max_coord = size - ivec2(1, 1)
              center_d = texelFetch(depth_texture, pos, 0).r
              d_up = texelFetch(depth_texture, clamp(pos + ivec2(0, -outline_thickness), ivec2(0, 0), max_coord), 0).r
              d_down = texelFetch(depth_texture, clamp(pos + ivec2(0, outline_thickness), ivec2(0, 0), max_coord), 0).r
              d_left = texelFetch(depth_texture, clamp(pos + ivec2(-outline_thickness, 0), ivec2(0, 0), max_coord), 0).r
              d_right = texelFetch(depth_texture, clamp(pos + ivec2(outline_thickness, 0), ivec2(0, 0), max_coord), 0).r

              diff = abs(center_d - d_up) + abs(center_d - d_down) + abs(center_d - d_left) + abs(center_d - d_right)
              if diff > depth_threshold
                curr_color = vec4(outline_color.rgb, 1.0)
              end
            end
          end
        CR
      ),
      Entry.new(
        id: "compute_image_filter",
        name: "2D Image Compute Filter",
        mode: Mode::Compute,
        summary: "2D Image2D read/write compute kernel for procedural textures or convolution blurs.",
        source: <<-CR
          shader_type :compute
          local_size 8, 8, 1

          image2d input_image, format: :rgba32f, set: 0, binding: 0
          image2d output_image, format: :rgba32f, set: 0, binding: 1

          uniform exposure : Float32 = 1.0

          def main
            coord = ivec2(gl_GlobalInvocationID.xy)
            dims = imageSize(input_image)
            if coord.x >= dims.x || coord.y >= dims.y
              return
            end

            src = imageLoad(input_image, coord)
            imageStore(output_image, coord, vec4(src.rgb * exposure, src.a))
          end
        CR
      ),
      Entry.new(
        id: "compute_particle_sim",
        name: "GPU Particle Simulation (Compute)",
        mode: Mode::Compute,
        summary: "High-throughput compute particle simulation DSL with Euler integration and linear drag.",
        source: <<-CR
          particle_simulation 64 do
            step_particles do |idx, pos, vel, life|
              life = life - sim_params.delta_time
              vel = apply_linear_drag(vel + sim_params.gravity * sim_params.delta_time, sim_params.drag, sim_params.delta_time)
              pos = integrate_euler(pos, vel, sim_params.delta_time)
            end
          end
        CR
      ),

      # =========================================================================
      # 7. SHADER INCLUDE (Reusable .gdshaderinc Libraries)
      # =========================================================================
      Entry.new(
        id: "include_default",
        name: "Default (Shared Math & Lighting Helpers)",
        mode: Mode::ShaderInclude,
        summary: "Reusable .gdshaderinc library compiled automatically with header guards on save.",
        source: <<-CR
          emit_target "{{STEM}}.gdshaderinc", target: :gdshaderinc

          shader :gdshaderinc

          def remap_range(val : Float32, in_min : Float32, in_max : Float32, out_min : Float32, out_max : Float32) : Float32
            t = clamp((val - in_min) / max(in_max - in_min, 0.00001), 0.0, 1.0)
            mix(out_min, out_max, t)
          end

          def rim_factor(normal : Vec3, view_dir : Vec3, power : Float32) : Float32
            clamp(1.0 - dot(normal, view_dir), 0.0, 1.0) ** power
          end
        CR
      ),
      Entry.new(
        id: "include_empty",
        name: "Empty",
        mode: Mode::ShaderInclude,
        summary: "Minimal .gdshaderinc include library skeleton.",
        source: <<-CR
          emit_target "{{STEM}}.gdshaderinc", target: :gdshaderinc

          shader :gdshaderinc

          def helper_identity(x : Float32) : Float32
            x
          end
        CR
      ),
      Entry.new(
        id: "include_oop_struct",
        name: "OOP Shader Class & Methods",
        mode: Mode::ShaderInclude,
        summary: "Demonstrates Crystal class/struct lowering into reusable .gdshaderinc types and helpers.",
        source: <<-CR
          emit_target "{{STEM}}.gdshaderinc", target: :gdshaderinc

          shader :gdshaderinc

          class SurfaceSample
            albedo : Vec3
            roughness : Float32

            def initialize(@albedo : Vec3 = vec3(1.0, 1.0, 1.0), @roughness : Float32 = 0.5)
            end

            def tinted(tint : Vec3, factor : Float32 = 1.0) : Vec3
              mix(albedo, albedo * tint, clamp(factor, 0.0, 1.0))
            end
          end

          def make_tinted_sample(base : Vec3, tint : Vec3) : Vec3
            s = SurfaceSample.new(base, 0.4)
            s.tinted(tint, 0.75)
          end
        CR
      ),
    ]

    def all : Array(Entry)
      CATALOG
    end

    def modes : Array(Mode)
      ALL_MODES
    end

    def for_mode(mode : Mode) : Array(Entry)
      CATALOG.select { |entry| entry.mode == mode }
    end

    def find(id_or_name : String) : Entry?
      needle = id_or_name.strip.downcase
      CATALOG.find { |e| e.id.downcase == needle || e.name.downcase == needle } ||
        Mode.from_string?(needle).try { |m| for_mode(m).first? }
    end

    def default_for_mode(mode : Mode) : Entry
      for_mode(mode).first? || CATALOG.first
    end
  end
end
