module CrShader::Validator
  class Rules
    # Allowed render modes per ShaderType in Godot 4.x
    VALID_RENDER_MODES = {
      ShaderType::Spatial => Set{
        "blend_mix", "blend_add", "blend_sub", "blend_mul",
        "depth_draw_opaque", "depth_draw_always", "depth_draw_never",
        "depth_prepass_alpha", "depth_test_disabled",
        "cull_back", "cull_front", "cull_disabled",
        "unshaded", "wireframe",
        "diffuse_burley", "diffuse_lambert", "diffuse_lambert_wrap", "diffuse_toon",
        "specular_schlick_ggx", "specular_toon", "specular_disabled",
        "skip_vertex_transform", "world_vertex_coords", "ensure_correct_normals",
        "shadows_disabled", "ambient_light_disabled", "fog_disabled",
        "particle_trails", "alpha_to_coverage", "alpha_to_coverage_and_one",
        "shadow_to_opacity", "vertex_lighting"
      },
      ShaderType::CanvasItem => Set{
        "blend_mix", "blend_add", "blend_sub", "blend_mul", "blend_premult_alpha", "blend_disabled",
        "unshaded", "light_only", "skip_vertex_transform", "world_vertex_coords"
      },
      ShaderType::Particles => Set{
        "keep_data", "disable_force", "disable_velocity", "collision_use_scale"
      },
      ShaderType::Sky => Set{
        "use_half_res_pass", "use_quarter_res_pass", "disable_fog"
      },
      ShaderType::Fog => Set{
        "disabled"
      },
      ShaderType::Compute => Set(String).new
    }

    # All known render modes across all types
    ALL_RENDER_MODES = VALID_RENDER_MODES.values.reduce(Set(String).new) { |acc, set| acc | set }

    # Built-in variables that are strictly writable ONLY in specific stages
    # Format: variable_name => Allowed stages
    STAGE_WRITABLE_BUILTINS = {
      # Vertex outputs
      "VERTEX"                  => Set{"vertex"},
      "POSITION"                => Set{"vertex", "sky"},
      "NORMAL"                  => Set{"vertex", "fragment"},
      "TANGENT"                 => Set{"vertex", "fragment"},
      "BINORMAL"                => Set{"vertex", "fragment"},
      "UV"                      => Set{"vertex"},
      "UV2"                     => Set{"vertex"},
      "POINT_SIZE"              => Set{"vertex"},
      "COLOR"                   => Set{"vertex", "fragment", "light", "start", "process", "collide", "sky"},

      # Spatial Fragment outputs
      "ALBEDO"                  => Set{"fragment"},
      "ALPHA"                   => Set{"fragment"},
      "ALPHA_SCISSOR_THRESHOLD" => Set{"fragment"},
      "ALPHA_HASH_SCALE"        => Set{"fragment"},
      "ROUGHNESS"               => Set{"fragment"},
      "METALLIC"                => Set{"fragment"},
      "SPECULAR"                => Set{"fragment"},
      "EMISSION"                => Set{"fragment"},
      "NORMAL_MAP"              => Set{"fragment"},
      "NORMAL_MAP_DEPTH"        => Set{"fragment"},
      "RIM"                     => Set{"fragment"},
      "RIM_TINT"                => Set{"fragment"},
      "CLEARCOAT"               => Set{"fragment"},
      "CLEARCOAT_ROUGHNESS"     => Set{"fragment"},
      "ANISOTROPY"              => Set{"fragment"},
      "ANISOTROPY_FLOW"         => Set{"fragment"},
      "AO"                      => Set{"fragment"},
      "AO_LIGHT_AFFECT"         => Set{"fragment"},
      "SSS_STRENGTH"            => Set{"fragment"},
      "TRANSMISSION"            => Set{"fragment"},
      "BACKLIGHT"               => Set{"fragment"},
      "DEPTH"                   => Set{"fragment"},

      # Light outputs
      "DIFFUSE_LIGHT"           => Set{"light"},
      "SPECULAR_LIGHT"          => Set{"light"},
      "SHADOW_MODULATE"         => Set{"light"},
      "LIGHT_VERTEX"            => Set{"light"},
      "SHADOW_VERTEX"           => Set{"light"},

      # Fog outputs
      "DENSITY"                 => Set{"fog"},
      "FOG_COLOR"               => Set{"fog"},

      # Particle outputs
      "TRANSFORM"               => Set{"start", "process", "collide"},
      "VELOCITY"                => Set{"start", "process", "collide"},
      "CUSTOM"                  => Set{"start", "process", "collide"},
      "ACTIVE"                  => Set{"start", "process", "collide"}
    }

    # Built-in variables that can only be READ in specific stages
    STAGE_READABLE_ONLY = {
      "DIFFUSE_LIGHT"  => Set{"light"},
      "SPECULAR_LIGHT" => Set{"light"},
      "LIGHT"          => Set{"light"},
      "LIGHT_COLOR"    => Set{"light"},
      "ATTENUATION"    => Set{"light"},
      "EYEDIR"         => Set{"sky"},
      "SKY_COORDS"     => Set{"sky"},
      "SDF"            => Set{"fog"},
      "SDF_NORMAL"     => Set{"fog"}
    }

    # Levenshtein distance calculation for fuzzy suggestions
    def self.levenshtein_distance(s1 : String, s2 : String) : Int32
      m = s1.size
      n = s2.size
      return m if n == 0
      return n if m == 0

      d = Array.new(m + 1) { Array.new(n + 1, 0) }
      (0..m).each { |i| d[i][0] = i }
      (0..n).each { |j| d[0][j] = j }

      (1..m).each do |i|
        (1..n).each do |j|
          cost = s1[i - 1] == s2[j - 1] ? 0 : 1
          d[i][j] = Math.min(
            d[i - 1][j] + 1,      # deletion
            Math.min(
              d[i][j - 1] + 1,    # insertion
              d[i - 1][j - 1] + cost # substitution
            )
          )
        end
      end
      d[m][n]
    end

    # Finds the closest matching string from candidates, or nil if distance > max_distance
    def self.find_closest_match(target : String, candidates : Enumerable(String), max_distance : Int32 = 3) : String?
      candidates
        .map { |c| {c, levenshtein_distance(target.downcase, c.downcase)} }
        .select { |_, dist| dist <= max_distance }
        .min_by? { |_, dist| dist }
        .try(&.first)
    end
  end
end
