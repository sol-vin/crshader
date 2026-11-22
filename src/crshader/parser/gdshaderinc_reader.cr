require "../ast/shader_ast"
require "../ast/types"

module CrShader
  # Lightweight signature extractor for Godot `.gdshaderinc` header files.
  # Scans `struct`, `const`, and function return signatures so `.crshader` files
  # using `#include "res://...gdshaderinc"` or `include "..."` receive accurate
  # return-type, struct-field, and constant-type inference without duplicating emissions.
  class GdshaderincReader
    STRUCT_REGEX = /\bstruct\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{([^}]*)\}\s*;/m
    FIELD_REGEX  = /\b([A-Za-z_][A-Za-z0-9_]*)\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*\[[^\]]*\])?\s*;/
    CONST_REGEX  = /\bconst\s+([A-Za-z_][A-Za-z0-9_]*)\s+([A-Za-z_][A-Za-z0-9_]*)(\s*\[[^\]]*\])?\s*=/
    FUNC_REGEX   = /(?:^|\n)\s*([A-Za-z_][A-Za-z0-9_]*)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)\s*\{/

    RESERVED_RETURN_WORDS = Set{
      "if", "for", "while", "switch", "return", "struct", "uniform", "varying", "const", "layout",
    }

    def self.resolve_path(inc_path : String, base_file : String? = nil) : String?
      clean = inc_path.sub(%r{^res://}, "").gsub('\\', '/')
      candidates = [] of String

      if bf = base_file
        base_dir = File.dirname(bf)
        candidates << File.expand_path(clean, base_dir)
        # Walk up up to 4 parent directories looking for project.godot root
        curr = base_dir
        5.times do
          if File.exists?(File.join(curr, "project.godot"))
            candidates << File.join(curr, clean)
            break
          end
          parent = File.dirname(curr)
          break if parent == curr
          curr = parent
        end
      end

      candidates << clean
      candidates << File.expand_path(clean)
      candidates.find { |c| File.exists?(c) && File.file?(c) }
    end

    def self.import_signatures(inc_path : String, program : ShaderProgram, base_file : String? = nil) : Bool
      resolved = resolve_path(inc_path, base_file)
      return false unless resolved

      raw = File.read(resolved)
      parse_into(raw, program, resolved)
      true
    rescue
      false
    end

    def self.parse_into(raw_source : String, program : ShaderProgram, current_file : String? = nil) : Void
      # Strip C-style block comments and single-line comments first
      cleaned = raw_source
        .gsub(/\/\*.*?\*\//m, "")
        .gsub(/\/\/[^\n]*/, "")

      # Recursively scan nested #include directives
      cleaned.scan(/^\s*#include\s+"([^"]+)"/m) do |m|
        import_signatures(m[1], program, current_file)
      end

      # 1. Extract struct declarations
      cleaned.scan(STRUCT_REGEX) do |m|
        sname = m[1]
        body = m[2]
        fields = [] of StructField
        body.scan(FIELD_REGEX) do |fm|
          ftype = TypeInfo.normalize(fm[1])
          fname = fm[2]
          fields << StructField.new(fname, ftype)
        end
        program.external_structs[sname] = StructDecl.new(sname, fields)
      end

      # 2. Extract const declarations
      cleaned.scan(CONST_REGEX) do |m|
        ctype = m[1]
        cname = m[2]
        arr_suffix = m[3]?.try(&.strip) || ""
        program.external_constants[cname] = "#{ctype}#{arr_suffix}"
      end

      # 3. Extract function return types
      cleaned.scan(FUNC_REGEX) do |m|
        ret_type = m[1]
        fname = m[2]
        next if RESERVED_RETURN_WORDS.includes?(ret_type) || RESERVED_RETURN_WORDS.includes?(fname)
        program.external_functions[fname] = ret_type
      end
    end
  end
end
