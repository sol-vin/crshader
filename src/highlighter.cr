require "lapis"

module CrShader
  include Godot

  # =============================================================================
  # Highlighter - Rich Syntax Tokenization for CrShader in Godot CodeEdit
  # =============================================================================
  class Highlighter
    # Creates and returns a configured CodeHighlighter with full CrShader keywords, stages, types, builtins
    def self.create_code_highlighter : CodeHighlighter?
      highlighter = Godot.create(Godot::CodeHighlighter)
      return nil unless highlighter

      # Colors
      kw_color = Color.new(0.85_f32, 0.45_f32, 0.9_f32, 1.0_f32)     # Purple
      type_color = Color.new(0.35_f32, 0.75_f32, 1.0_f32, 1.0_f32)   # Cyan / Blue
      builtin_color = Color.new(1.0_f32, 0.75_f32, 0.3_f32, 1.0_f32) # Orange
      fn_color = Color.new(0.45_f32, 0.85_f32, 0.6_f32, 1.0_f32)     # Light Green
      comment_color = Color.new(0.5_f32, 0.55_f32, 0.6_f32, 1.0_f32) # Gray
      string_color = Color.new(0.95_f32, 0.85_f32, 0.4_f32, 1.0_f32) # Gold
      num_color = Color.new(0.8_f32, 0.6_f32, 1.0_f32, 1.0_f32)      # Violet

      # 1. Keywords
      keywords = [
        "shader", "shader_type", "render_mode", "setup_gdshader", "emit_target", "output_target",
        "uniform", "property", "sampler", "instance_uniform", "global_uniform",
        "varying", "flat_varying", "smooth_varying", "const", "constant_decl",
        "include", "gd_include", "define", "undefine", "undef", "pragma", "default_precision", "precision",
        "feature", "when_feature", "unless_feature", "shader_trait", "use_trait", "gradient", "curve", "inspect",
        "buffer", "storage_buffer", "push_constant", "push_constants", "shared", "image2d", "storage_image", "local_size", "require",
        "group", "uniform_group", "subgroup", "uniform_subgroup", "field", "record",
        "def", "end", "class", "struct", "module", "if", "else", "elsif", "unless",
        "while", "until", "for", "in", "case", "when", "return", "break", "next", "discard",
        "true", "false", "nil", "macro", "do",
      ]
      keywords.each do |kw|
        highlighter.call("add_keyword_color", kw, kw_color)
      end

      # 2. Stages & Archetypes
      stages = [
        "vertex", "fragment", "light", "start", "process", "sky", "fog", "main",
        "sprite_effect", "screen_effect", "ui_effect", "surface_material",
        "compositor_effect", "process_pixel", "on_vertex", "on_fragment", "on_light", "on_pixel",
      ]
      stages.each do |st|
        highlighter.call("add_keyword_color", st, Color.new(1.0_f32, 0.4_f32, 0.6_f32, 1.0_f32))
      end

      # 3. Types
      types = [
        "Float32", "Float64", "Float", "Int32", "UInt32", "Int", "UInt", "Bool", "Void",
        "Vec2", "Vec3", "Vec4", "IVec2", "IVec3", "IVec4", "UVec2", "UVec3", "UVec4",
        "BVec2", "BVec3", "BVec4", "Mat2", "Mat3", "Mat4", "Color",
        "Sampler2D", "SamplerCube", "Sampler2DArray", "Sampler3D",
        "Sampler2DShadow", "SamplerCubeShadow", "Sampler2DArrayShadow",
        "ISampler2D", "USampler2D", "Image2D", "IImage2D", "UImage2D", "Image3D",
        "SubpassInput", "Array", "InOut", "Out",
      ]
      types.each do |t|
        highlighter.call("add_keyword_color", t, type_color)
      end

      # 4. Built-in Variables & Constants
      builtins = [
        "VERTEX", "NORMAL", "TANGENT", "BINORMAL", "COLOR", "UV", "UV2",
        "ROUGHNESS", "METALLIC", "SPECULAR", "ALBEDO", "ALPHA", "ALPHA_SCISSOR_THRESHOLD",
        "EMISSION", "NORMAL_MAP", "NORMAL_MAP_DEPTH", "RIM", "RIM_TINT", "CLEARCOAT",
        "CLEARCOAT_ROUGHNESS", "CLEARCOAT_GLOSS", "ANISOTROPY", "ANISOTROPY_FLOW",
        "AO", "AO_LIGHT_AFFECT", "SSS_STRENGTH", "TRANSMISSION", "BACKLIGHT", "DEPTH",
        "POINT_SIZE", "POSITION", "TIME", "PI", "TAU", "E", "FRAGCOORD", "FRONT_FACING", "POINT_COORD",
        "MODEL_MATRIX", "VIEW_MATRIX", "PROJECTION_MATRIX", "MODELVIEW_MATRIX", "MODELVIEW_NORMAL_MATRIX",
        "INV_VIEW_MATRIX", "INV_PROJECTION_MATRIX", "NODE_POSITION_WORLD", "CAMERA_POSITION_WORLD",
        "CAMERA_DIRECTION_WORLD", "VIEWPORT_SIZE", "INSTANCE_ID", "CUSTOM0", "CUSTOM1", "CUSTOM2", "CUSTOM3",
        "SCREEN_UV", "SCREEN_PIXEL_SIZE", "TEXTURE_PIXEL_SIZE", "VIEW",
        "LIGHT", "LIGHT_COLOR", "LIGHT_ENERGY", "LIGHT_POSITION", "LIGHT_DIRECTION", "LIGHT_IS_DIRECTIONAL",
        "ATTENUATION", "DIFFUSE_LIGHT", "SPECULAR_LIGHT",
        "TRANSFORM", "VELOCITY", "CUSTOM", "MASS", "ACTIVE", "RESTART", "LIFETIME", "DELTA",
        "INDEX", "NUMBER", "SEED", "EYEDIR", "HALF_RES_COLOR", "QUARTER_RES_COLOR",
        "WORLD_POSITION", "FOG_COLOR", "DENSITY", "SDF",
        "gl_NumWorkGroups", "gl_WorkGroupSize", "gl_WorkGroupID",
        "gl_LocalInvocationID", "gl_GlobalInvocationID", "gl_LocalInvocationIndex",
      ]
      builtins.each do |b|
        highlighter.call("add_member_keyword_color", b, builtin_color)
      end

      # 5. Functions & Built-in Helpers
      highlighter.call("set_function_color", fn_color)
      highlighter.call("set_number_color", num_color)

      # 6. Regions (Strings and Comments)
      highlighter.call("add_color_region", "\"", "\"", string_color, false)
      highlighter.call("add_color_region", "#", "", comment_color, true)

      highlighter
    end

    # Applies syntax highlighting to a CodeEdit instance
    def self.apply_to_code_edit(edit : CodeEdit) : Void
      if hl = create_code_highlighter
        edit.call("set_syntax_highlighter", hl)
      end
    end
  end
end
