require "lapis"

module CrShader
  include Godot

  # Represents a single colored span at a character column for Godot's TextEdit / CodeEdit.
  struct HighlightSpan
    getter column : Int32
    getter r : Float32
    getter g : Float32
    getter b : Float32
    getter a : Float32

    def initialize(@column : Int32, @r : Float32, @g : Float32, @b : Float32, @a : Float32 = 1.0_f32)
    end
  end

  # =============================================================================
  # Highlighter - Rich Dark-Theme Syntax Highlighting for .crshader & Shader Targets
  # =============================================================================
  class Highlighter
    # High-contrast, balanced dark-editor palette (zero black/dark tokens)
    COLOR_DEFAULT   = {0.88_f32, 0.89_f32, 0.92_f32, 1.0_f32} # Crisp Off-White (#E0E3EB)
    COLOR_PUNCT     = {0.74_f32, 0.79_f32, 0.86_f32, 1.0_f32} # Cool Silver (#BDCADB)
    COLOR_KEYWORD   = {0.86_f32, 0.48_f32, 0.93_f32, 1.0_f32} # Vibrant Orchid Purple (#DB7AED)
    COLOR_CONTROL   = {0.96_f32, 0.46_f32, 0.58_f32, 1.0_f32} # Coral Pink (#F57594)
    COLOR_STAGE     = {1.00_f32, 0.42_f32, 0.65_f32, 1.0_f32} # Rose (#FF6BA6)
    COLOR_LITERAL   = {0.80_f32, 0.56_f32, 1.00_f32, 1.0_f32} # Bright Violet (#CC8FFF)
    COLOR_SYMBOL    = {0.35_f32, 0.86_f32, 0.92_f32, 1.0_f32} # Bright Cyan (#59DBE8)
    COLOR_NAMED_ARG = {0.58_f32, 0.80_f32, 0.98_f32, 1.0_f32} # Crisp Sky Blue (#94CCFA)
    COLOR_TYPE      = {0.38_f32, 0.78_f32, 1.00_f32, 1.0_f32} # Azure / Cyan-Blue (#61C7FF)
    COLOR_BUILTIN   = {1.00_f32, 0.76_f32, 0.34_f32, 1.0_f32} # Warm Amber (#FFC257)
    COLOR_FUNCTION  = {0.48_f32, 0.88_f32, 0.64_f32, 1.0_f32} # Mint / Spring Green (#7AE0A3)
    COLOR_MEMBER    = {0.68_f32, 0.86_f32, 0.98_f32, 1.0_f32} # Ice Blue (#ADDBFA)
    COLOR_STRING    = {0.95_f32, 0.85_f32, 0.42_f32, 1.0_f32} # Warm Gold (#F2D96B)
    COLOR_NUMBER    = {0.82_f32, 0.64_f32, 1.00_f32, 1.0_f32} # Soft Lavender (#D1A3FF)
    COLOR_PREPROC   = {1.00_f32, 0.58_f32, 0.38_f32, 1.0_f32} # Coral Orange (#FF9461)
    COLOR_ANNOT     = {0.96_f32, 0.58_f32, 0.82_f32, 1.0_f32} # Soft Rose Pink (#F594D1)
    COLOR_COMMENT   = {0.52_f32, 0.58_f32, 0.64_f32, 1.0_f32} # Muted Slate (#8594A3)

    KEYWORDS_DSL = Set{
      "shader", "shader_type", "render_mode", "setup_gdshader", "emit_target", "output_target",
      "uniform", "property", "sampler", "instance_uniform", "global_uniform",
      "varying", "flat_varying", "smooth_varying", "const", "constant_decl",
      "include", "gd_include", "define", "undefine", "undef", "pragma", "default_precision", "precision",
      "feature", "when_feature", "unless_feature", "shader_trait", "use_trait", "gradient", "curve", "inspect",
      "buffer", "storage_buffer", "push_constant", "push_constants", "shared", "image2d", "storage_image",
      "local_size", "require", "group", "uniform_group", "subgroup", "uniform_subgroup", "field", "record",
      "def", "end", "class", "struct", "module", "macro", "do", "alias", "enum", "private", "protected",
    }

    KEYWORDS_CONTROL = Set{
      "if", "else", "elsif", "unless", "while", "until", "for", "in",
      "case", "when", "then", "return", "break", "next", "discard",
      "begin", "rescue", "ensure", "raise",
    }

    KEYWORDS_LITERAL = Set{
      "true", "false", "nil", "self", "super",
    }

    STAGES = Set{
      "vertex", "fragment", "light", "start", "process", "sky", "fog", "main",
      "sprite_effect", "screen_effect", "ui_effect", "surface_material",
      "compositor_effect", "process_pixel", "on_vertex", "on_fragment", "on_light", "on_pixel",
      "compute_kernel", "kernel_2d", "particle_simulation", "step_particles",
    }

    TYPES = Set{
      "Float32", "Float64", "Float", "Int32", "UInt32", "Int64", "UInt64", "Int", "UInt", "Bool", "Void",
      "Vec2", "Vec3", "Vec4", "IVec2", "IVec3", "IVec4", "UVec2", "UVec3", "UVec4",
      "BVec2", "BVec3", "BVec4", "Mat2", "Mat3", "Mat4", "Color",
      "Sampler2D", "SamplerCube", "Sampler2DArray", "Sampler3D",
      "Sampler2DShadow", "SamplerCubeShadow", "Sampler2DArrayShadow",
      "ISampler2D", "USampler2D", "Image2D", "IImage2D", "UImage2D", "Image3D",
      "SubpassInput", "Array", "InOut", "Out",
      "float", "int", "uint", "bool", "void",
    }

    BUILTINS = Set{
      "VERTEX", "NORMAL", "TANGENT", "BINORMAL", "COLOR", "UV", "UV2",
      "ROUGHNESS", "METALLIC", "SPECULAR", "ALBEDO", "ALPHA", "ALPHA_SCISSOR_THRESHOLD",
      "ALPHA_HASH_SCALE", "ALPHA_ANTIALIASING_EDGE", "ALPHA_TEXTURE_COORDINATE",
      "EMISSION", "NORMAL_MAP", "NORMAL_MAP_DEPTH", "RIM", "RIM_TINT", "CLEARCOAT",
      "CLEARCOAT_ROUGHNESS", "CLEARCOAT_GLOSS", "ANISOTROPY", "ANISOTROPY_FLOW",
      "AO", "AO_LIGHT_AFFECT", "SSS_STRENGTH", "SSS_TRANSMITTANCE_COLOR", "SSS_TRANSMITTANCE_DEPTH",
      "SSS_TRANSMITTANCE_BOOST", "TRANSMISSION", "BACKLIGHT", "DEPTH",
      "POINT_SIZE", "POSITION", "TIME", "PI", "TAU", "E", "FRAGCOORD", "FRONT_FACING", "POINT_COORD",
      "MODEL_MATRIX", "VIEW_MATRIX", "PROJECTION_MATRIX", "MODELVIEW_MATRIX", "MODELVIEW_NORMAL_MATRIX",
      "MODEL_NORMAL_MATRIX", "INV_VIEW_MATRIX", "INV_PROJECTION_MATRIX", "MAIN_CAM_INV_VIEW_MATRIX",
      "NODE_POSITION_WORLD", "NODE_POSITION_VIEW", "CAMERA_POSITION_WORLD",
      "CAMERA_DIRECTION_WORLD", "CAMERA_VISIBLE_LAYERS", "VIEWPORT_SIZE",
      "INSTANCE_ID", "INSTANCE_CUSTOM", "VERTEX_ID", "VIEW_INDEX", "VIEW_MONO_LEFT", "VIEW_RIGHT",
      "CUSTOM0", "CUSTOM1", "CUSTOM2", "CUSTOM3",
      "SCREEN_UV", "SCREEN_PIXEL_SIZE", "TEXTURE", "TEXTURE_PIXEL_SIZE", "AT_LIGHT_PASS", "VIEW",
      "LIGHT", "LIGHT_COLOR", "LIGHT_ENERGY", "LIGHT_POSITION", "LIGHT_DIRECTION", "LIGHT_IS_DIRECTIONAL",
      "LIGHT_VERTEX", "SHADOW_ATTENUATION", "ATTENUATION", "DIFFUSE_LIGHT", "SPECULAR_LIGHT",
      "TRANSFORM", "VELOCITY", "CUSTOM", "MASS", "ACTIVE", "RESTART", "LIFETIME", "DELTA",
      "INDEX", "NUMBER", "SEED", "EYEDIR", "HALF_RES_COLOR", "QUARTER_RES_COLOR",
      "WORLD_POSITION", "OBJECT_POSITION", "UVW", "SIZE", "ALBEDO_FOG", "FOG_COLOR", "DENSITY", "SDF",
      "OUTPUT_IS_SRGB", "CLIP_SPACE_FAR",
      "gl_NumWorkGroups", "gl_WorkGroupSize", "gl_WorkGroupID",
      "gl_LocalInvocationID", "gl_GlobalInvocationID", "gl_LocalInvocationIndex",
    }

    INTRINSICS = Set{
      "vec2", "vec3", "vec4", "ivec2", "ivec3", "ivec4", "uvec2", "uvec3", "uvec4",
      "bvec2", "bvec3", "bvec4", "mat2", "mat3", "mat4",
      "radians", "degrees", "sin", "cos", "tan", "asin", "acos", "atan", "sinh", "cosh", "tanh",
      "pow", "exp", "log", "exp2", "log2", "sqrt", "inversesqrt",
      "abs", "sign", "floor", "trunc", "round", "roundEven", "ceil", "fract", "mod",
      "min", "max", "clamp", "mix", "step", "smoothstep", "isnan", "isinf",
      "floatBitsToInt", "floatBitsToUint", "intBitsToFloat", "uintBitsToFloat",
      "packHalf2x16", "unpackHalf2x16", "packUnorm2x16", "unpackUnorm2x16", "packSnorm2x16", "unpackSnorm2x16",
      "length", "distance", "dot", "cross", "normalize", "faceforward", "reflect", "refract",
      "matrixCompMult", "outerProduct", "transpose", "determinant", "inverse",
      "lessThan", "lessThanEqual", "greaterThan", "greaterThanEqual", "equal", "notEqual", "any", "all",
      "texture", "textureProj", "textureLod", "textureOffset", "texelFetch", "texelFetchOffset",
      "textureGrad", "textureGather", "textureSize", "textureQueryLod", "textureQueryLevels",
      "imageLoad", "imageStore", "imageSize", "barrier", "memoryBarrier", "groupMemoryBarrier",
      "dFdx", "dFdy", "dFdxCoarse", "dFdyCoarse", "dFdxFine", "dFdyFine", "fwidth",
    }

    PREPROC_DIRECTIVES = Set{
      "include", "define", "undef", "ifdef", "ifndef", "if", "elif", "else", "endif", "pragma", "version", "extension",
    }

    GLSL_TARGET_KEYWORDS = [
      "shader_type", "render_mode", "group_uniforms", "global", "instance", "uniform",
      "varying", "flat", "smooth", "noperspective", "const", "in", "out", "inout",
      "layout", "set", "binding", "std140", "std430", "push_constant", "buffer", "shared",
      "readonly", "writeonly", "coherent", "volatile", "restrict",
      "lowp", "mediump", "highp", "precision",
      "struct", "if", "else", "for", "while", "do", "switch", "case", "default",
      "return", "break", "continue", "discard", "true", "false",
    ]

    GLSL_TARGET_TYPES = [
      "void", "bool", "int", "uint", "float", "double",
      "vec2", "vec3", "vec4", "dvec2", "dvec3", "dvec4",
      "bvec2", "bvec3", "bvec4", "ivec2", "ivec3", "ivec4", "uvec2", "uvec3", "uvec4",
      "mat2", "mat3", "mat4", "mat2x2", "mat2x3", "mat2x4", "mat3x2", "mat3x3", "mat3x4", "mat4x2", "mat4x3", "mat4x4",
      "sampler2D", "sampler3D", "samplerCube", "sampler2DArray", "sampler2DShadow", "samplerCubeShadow",
      "isampler2D", "usampler2D", "image2D", "iimage2D", "uimage2D", "image3D",
    ]

    private def self.to_color(rgba : Tuple(Float32, Float32, Float32, Float32)) : Color
      Color.new(rgba[0], rgba[1], rgba[2], rgba[3])
    end

    private def self.push_span(spans : Array(HighlightSpan), col : Int32, color : Tuple(Float32, Float32, Float32, Float32)) : Void
      if spans.empty? || spans.last.column != col
        spans << HighlightSpan.new(col, color[0], color[1], color[2], color[3])
      else
        spans[spans.size - 1] = HighlightSpan.new(col, color[0], color[1], color[2], color[3])
      end
    end

    # Pure Crystal single-line tokenizer for `.crshader` source code.
    # Character-column indexed to match Godot's UTF-32 TextEdit column map.
    def self.highlight_crshader_line(line : String) : Array(HighlightSpan)
      spans = [] of HighlightSpan
      return spans if line.empty?

      chars = line.chars
      len = chars.size
      return spans if len == 0

      i = 0
      prev_non_space : Char = '\0'

      while i < len
        c = chars[i]

        # 1. Whitespace
        if c == ' ' || c == '\t' || c == '\r' || c == '\n'
          i += 1
          next
        end

        # 2. Preprocessor (`#include`, `#define`, `#ifndef`, `#[compute]`, etc.) vs `#` Comment
        if c == '#'
          if i + 1 < len && chars[i + 1] == '['
            start_col = i
            i += 2
            while i < len && chars[i] != ']'
              i += 1
            end
            i += 1 if i < len && chars[i] == ']'
            push_span(spans, start_col, COLOR_PREPROC)
            push_span(spans, i, COLOR_DEFAULT) if i < len
            prev_non_space = ']'
            next
          elsif i + 1 < len && chars[i + 1].ascii_letter?
            word_start = i + 1
            j = word_start
            while j < len && (chars[j].ascii_alphanumeric? || chars[j] == '_')
              j += 1
            end
            directive = line[word_start, j - word_start]
            if PREPROC_DIRECTIVES.includes?(directive)
              push_span(spans, i, COLOR_PREPROC)
              i = j
              push_span(spans, i, COLOR_DEFAULT) if i < len
              prev_non_space = directive[-1]
              next
            end
          end

          # Standard Crystal `#` comment to end of line
          push_span(spans, i, COLOR_COMMENT)
          break
        end

        # 3. Annotations `@[...]` & instance/class variables `@var` / `@@var`
        if c == '@'
          start_col = i
          if i + 1 < len && chars[i + 1] == '['
            i += 2
            depth = 1
            while i < len && depth > 0
              if chars[i] == '['
                depth += 1
              elsif chars[i] == ']'
                depth -= 1
              end
              i += 1
            end
            push_span(spans, start_col, COLOR_ANNOT)
            push_span(spans, i, COLOR_DEFAULT) if i < len
            prev_non_space = ']'
            next
          else
            i += 1
            i += 1 if i < len && chars[i] == '@'
            while i < len && (chars[i].alphanumeric? || chars[i] == '_')
              i += 1
            end
            push_span(spans, start_col, COLOR_MEMBER)
            push_span(spans, i, COLOR_DEFAULT) if i < len
            prev_non_space = chars[i - 1]
            next
          end
        end

        # 4. Strings `"..."`, `'...'`, `` `...` `` (with `#{...}` interpolation highlighting)
        if c == '"' || c == '\'' || c == '`'
          quote = c
          push_span(spans, i, COLOR_STRING)
          i += 1
          escaped = false
          while i < len
            ch = chars[i]
            if escaped
              escaped = false
              i += 1
            elsif ch == '\\'
              escaped = true
              i += 1
            elsif quote == '"' && ch == '#' && i + 1 < len && chars[i + 1] == '{'
              interp_start = i
              i += 2
              brace_depth = 1
              while i < len && brace_depth > 0
                if chars[i] == '{'
                  brace_depth += 1
                elsif chars[i] == '}'
                  brace_depth -= 1
                end
                i += 1
              end
              push_span(spans, interp_start, COLOR_SYMBOL)
              push_span(spans, i, COLOR_STRING) if i < len
            elsif ch == quote
              i += 1
              break
            else
              i += 1
            end
          end
          push_span(spans, i, COLOR_DEFAULT) if i < len
          prev_non_space = quote
          next
        end

        # 5. Crystal Symbol Literals `:spatial`, `:ambient_light_disabled`, `:source_color` (excluding `::`)
        if c == ':' && i + 1 < len && (chars[i + 1].ascii_letter? || chars[i + 1] == '_') && (i == 0 || chars[i - 1] != ':')
          start_col = i
          i += 1
          while i < len && (chars[i].alphanumeric? || chars[i] == '_' || chars[i] == '?' || chars[i] == '!')
            i += 1
          end
          push_span(spans, start_col, COLOR_SYMBOL)
          push_span(spans, i, COLOR_DEFAULT) if i < len
          prev_non_space = chars[i - 1]
          next
        end

        # 6. Numeric Literals (`0`, `1.0_f32`, `0xFF_u32`, `0b1010`, `-0.866`, stopping before `..` ranges!)
        can_unary_minus = (c == '-' && i + 1 < len && chars[i + 1].ascii_number? &&
                           !(prev_non_space.alphanumeric? || prev_non_space == '_' || prev_non_space == ')' || prev_non_space == ']'))
        if c.ascii_number? || can_unary_minus
          start_col = i
          i += 1 if c == '-'
          if i + 1 < len && chars[i] == '0' && (chars[i + 1] == 'x' || chars[i + 1] == 'X')
            i += 2
            while i < len && (chars[i].ascii_number? || ('a'..'f').includes?(chars[i].downcase) || chars[i] == '_')
              i += 1
            end
          elsif i + 1 < len && chars[i] == '0' && (chars[i + 1] == 'b' || chars[i + 1] == 'B')
            i += 2
            while i < len && (chars[i] == '0' || chars[i] == '1' || chars[i] == '_')
              i += 1
            end
          else
            while i < len
              nc = chars[i]
              if nc.ascii_number? || nc == '_'
                i += 1
              elsif nc == '.' && i + 1 < len && chars[i + 1].ascii_number?
                i += 1
              elsif (nc == 'e' || nc == 'E') && i + 1 < len && (chars[i + 1].ascii_number? || ((chars[i + 1] == '+' || chars[i + 1] == '-') && i + 2 < len && chars[i + 2].ascii_number?))
                i += 2
              else
                break
              end
            end
            # Optional Crystal type suffix (`_f32`, `_f64`, `_i32`, `_u32`, etc.)
            if i < len && chars[i].ascii_letter? && chars[i - 1] == '_'
              while i < len && chars[i].alphanumeric?
                i += 1
              end
            end
          end
          push_span(spans, start_col, COLOR_NUMBER)
          push_span(spans, i, COLOR_DEFAULT) if i < len
          prev_non_space = chars[i - 1]
          next
        end

        # 7. Identifiers, Named Argument Keys (`default:`), Member/Swizzles (`.rgb`), Keywords, Types & Calls
        if c.ascii_letter? || c == '_'
          start_col = i
          while i < len && (chars[i].alphanumeric? || chars[i] == '_' || chars[i] == '?' || chars[i] == '!')
            i += 1
          end
          word = line[start_col, i - start_col]

          # Named argument key (`pattern_default_enabled:`, `default:`, `range:`, excluding `Foo::Bar`)
          if i < len && chars[i] == ':' && !(i + 1 < len && chars[i + 1] == ':')
            i += 1
            push_span(spans, start_col, COLOR_NAMED_ARG)
            push_span(spans, i, COLOR_DEFAULT) if i < len
            prev_non_space = ':'
            next
          end

          is_after_dot = (start_col > 0 && chars[start_col - 1] == '.')
          is_call = (i < len && chars[i] == '(')

          token_color = if is_after_dot
                          is_call ? COLOR_FUNCTION : COLOR_MEMBER
                        elsif KEYWORDS_DSL.includes?(word)
                          COLOR_KEYWORD
                        elsif KEYWORDS_CONTROL.includes?(word)
                          COLOR_CONTROL
                        elsif KEYWORDS_LITERAL.includes?(word)
                          COLOR_LITERAL
                        elsif STAGES.includes?(word)
                          COLOR_STAGE
                        elsif BUILTINS.includes?(word)
                          COLOR_BUILTIN
                        elsif TYPES.includes?(word)
                          COLOR_TYPE
                        elsif INTRINSICS.includes?(word) || is_call
                          COLOR_FUNCTION
                        elsif word.size >= 2 && word.each_char.all? { |ch| ch.ascii_uppercase? || ch.ascii_number? || ch == '_' }
                          COLOR_BUILTIN
                        elsif word[0].ascii_uppercase?
                          COLOR_TYPE
                        else
                          COLOR_DEFAULT
                        end

          push_span(spans, start_col, token_color)
          push_span(spans, i, COLOR_DEFAULT) if i < len && token_color != COLOR_DEFAULT
          prev_non_space = chars[i - 1]
          next
        end

        # 8. Operators & Punctuation (`,`, `:`, `(`, `)`, `[`, `]`, `{`, `}`, `=`, `+`, `-`, `*`, `/`, `?`, `.`, etc.)
        start_col = i
        i += 1
        while i < len
          nc = chars[i]
          break if nc == ' ' || nc == '\t' || nc == '\r' || nc == '\n' ||
                   nc.alphanumeric? || nc == '_' || nc == '"' || nc == '\'' || nc == '`' || nc == '#' || nc == '@'
          # Stop before a `:symbol` literal so `:spatial` is lexed by rule 5!
          break if nc == ':' && i + 1 < len && (chars[i + 1].ascii_letter? || chars[i + 1] == '_') && chars[i - 1] != ':'
          i += 1
        end
        push_span(spans, start_col, COLOR_PUNCT)
        push_span(spans, i, COLOR_DEFAULT) if i < len
        prev_non_space = chars[i - 1]
      end

      spans
    end

    # Creates a configured Godot::CodeHighlighter for `.crshader` (used in standalone runtime builds
    # where EditorSyntaxHighlighter is unavailable, with all symbol/member colors explicitly configured).
    def self.create_code_highlighter : CodeHighlighter?
      highlighter = Godot.create(Godot::CodeHighlighter)
      return nil if highlighter.nil? || highlighter.pointer.null?

      # Explicitly set ALL base CodeHighlighter colors so nothing ever defaults to Color(0, 0, 0, 1) black!
      highlighter.call("set_symbol_color", to_color(COLOR_PUNCT))
      highlighter.call("set_member_variable_color", to_color(COLOR_MEMBER))
      highlighter.call("set_function_color", to_color(COLOR_FUNCTION))
      highlighter.call("set_number_color", to_color(COLOR_NUMBER))

      kw_col = to_color(COLOR_KEYWORD)
      ctrl_col = to_color(COLOR_CONTROL)
      lit_col = to_color(COLOR_LITERAL)
      stage_col = to_color(COLOR_STAGE)
      type_col = to_color(COLOR_TYPE)
      builtin_col = to_color(COLOR_BUILTIN)

      KEYWORDS_DSL.each { |kw| highlighter.call("add_keyword_color", kw, kw_col) }
      KEYWORDS_CONTROL.each { |kw| highlighter.call("add_keyword_color", kw, ctrl_col) }
      KEYWORDS_LITERAL.each { |kw| highlighter.call("add_keyword_color", kw, lit_col) }
      STAGES.each { |st| highlighter.call("add_keyword_color", st, stage_col) }
      TYPES.each { |t| highlighter.call("add_keyword_color", t, type_col) }
      BUILTINS.each do |b|
        highlighter.call("add_keyword_color", b, builtin_col)
        highlighter.call("add_member_keyword_color", b, builtin_col)
      end

      highlighter.call("add_color_region", "\"", "\"", to_color(COLOR_STRING), false)
      highlighter.call("add_color_region", "'", "'", to_color(COLOR_STRING), false)
      highlighter.call("add_color_region", "#", "", to_color(COLOR_COMMENT), true)

      highlighter
    end

    # Creates a configured Godot::CodeHighlighter tailored for compiled `.gdshader`, `.gdshaderinc`, and `.glsl` targets.
    def self.create_target_code_highlighter : CodeHighlighter?
      highlighter = Godot.create(Godot::CodeHighlighter)
      return nil if highlighter.nil? || highlighter.pointer.null?

      highlighter.call("set_symbol_color", to_color(COLOR_PUNCT))
      highlighter.call("set_member_variable_color", to_color(COLOR_MEMBER))
      highlighter.call("set_function_color", to_color(COLOR_FUNCTION))
      highlighter.call("set_number_color", to_color(COLOR_NUMBER))

      kw_col = to_color(COLOR_KEYWORD)
      stage_col = to_color(COLOR_STAGE)
      type_col = to_color(COLOR_TYPE)
      builtin_col = to_color(COLOR_BUILTIN)

      GLSL_TARGET_KEYWORDS.each { |kw| highlighter.call("add_keyword_color", kw, kw_col) }
      ["vertex", "fragment", "light", "start", "process", "sky", "fog", "main"].each do |st|
        highlighter.call("add_keyword_color", st, stage_col)
      end
      GLSL_TARGET_TYPES.each { |t| highlighter.call("add_keyword_color", t, type_col) }
      BUILTINS.each do |b|
        highlighter.call("add_keyword_color", b, builtin_col)
        highlighter.call("add_member_keyword_color", b, builtin_col)
      end

      highlighter.call("add_color_region", "\"", "\"", to_color(COLOR_STRING), false)
      highlighter.call("add_color_region", "//", "", to_color(COLOR_COMMENT), true)
      highlighter.call("add_color_region", "/*", "*/", to_color(COLOR_COMMENT), false)
      highlighter.call("add_color_region", "#", "", to_color(COLOR_PREPROC), true)

      highlighter
    end

    # Applies `.crshader` syntax highlighting to a CodeEdit instance.
    # Uses the exact Crystal/CrShader line tokenizer (`CrShaderSyntaxHighlighter`) in the Godot Editor,
    # and falls back to the full-palette `CodeHighlighter` in standalone runtime builds.
    def self.apply_to_code_edit(edit : CodeEdit) : Void
      return if edit.pointer.null?
      edit.call("add_theme_color_override", "font_color", to_color(COLOR_DEFAULT)) rescue nil

      if Godot.editor_hint? && (Godot::ClassDB.class_exists("CrShaderSyntaxHighlighter") rescue false)
        custom_hl = Godot.create(CrShader::CrShaderSyntaxHighlighter) rescue nil
        if custom_hl && !custom_hl.pointer.null?
          edit.call("set_syntax_highlighter", custom_hl)
          return
        end
      end

      if hl = create_code_highlighter
        edit.call("set_syntax_highlighter", hl)
      end
    end

    # Applies `.gdshader` / `.gdshaderinc` / `.glsl` target syntax highlighting to a preview CodeEdit instance.
    def self.apply_target_to_code_edit(edit : CodeEdit) : Void
      return if edit.pointer.null?
      edit.call("add_theme_color_override", "font_color", to_color(COLOR_DEFAULT)) rescue nil
      if hl = create_target_code_highlighter
        edit.call("set_syntax_highlighter", hl)
      end
    end
  end

  # =============================================================================
  # CrShaderSyntaxHighlighter - Native EditorSyntaxHighlighter for .crshader DSL
  # =============================================================================
  @[Tool]
  node CrShaderSyntaxHighlighter < Godot::EditorSyntaxHighlighter do
    def self.new(pointer : Void* = Pointer(Void).null) : self
      inst = allocate
      inst.initialize(pointer)
      inst
    end

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def self._godot_has_virtual_method(method_name : String) : Bool
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_get_name", "_get_supported_languages", "_get_line_syntax_highlighting",
           "_create", "_clear_highlighting_cache", "_update_cache"
        true
      else
        false
      end
    end

    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_get_name"
        Bridge.ret_string(ret, "CRShader")
      when "_get_supported_languages"
        Bridge.ret_packed_string_array(ret, ["CRShader", "crshader", "Shader"])
      when "_create"
        begin
          hl = Godot.create(CrShader::CrShaderSyntaxHighlighter)
          if hl && !hl.pointer.null?
            Bridge.ret_ref(ret, hl.pointer)
          else
            Bridge.ret_ref(ret, Pointer(Void).null)
          end
        rescue
          Bridge.ret_ref(ret, Pointer(Void).null)
        end
      when "_clear_highlighting_cache", "_update_cache"
        return
      when "_get_line_syntax_highlighting"
        begin
          Bridge.ret_dictionary_empty(ret)
          return if args.null? || args[0].null?
          line_num = args[0].as(Int32*).value.to_i64
          return if line_num < 0

          text_edit = (get_text_edit rescue nil)
          if text_edit && !text_edit.pointer.null? && text_edit.alive? && Bridge.is_object_valid(text_edit.pointer)
            line_text = Bridge.text_edit_get_line(text_edit.pointer, line_num)
            spans = Highlighter.highlight_crshader_line(line_text)
            spans.each do |span|
              Bridge.highlighter_add_span(ret, span.column.to_i64, span.r, span.g, span.b, span.a)
            end
          end
        rescue ex
          Godot.printerr("[CrShaderSyntaxHighlighter] Highlighting error: #{ex.message}") rescue nil
        end
      else
        super
      end
    end
  end
end
