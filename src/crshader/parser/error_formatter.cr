module CrShader
  class ShaderError < Exception
    getter filename : String?
    getter line_number : Int32?
    getter column_number : Int32?

    def initialize(message : String, @filename : String? = nil, @line_number : Int32? = nil, @column_number : Int32? = nil)
      super(message)
    end

    def formatted_message(source_lines : Array(String)? = nil) : String
      String.build do |str|
        loc = if @filename && @line_number
                "#{@filename}:#{@line_number}:#{@column_number || 1}"
              elsif @line_number
                "line #{@line_number}:#{@column_number || 1}"
              else
                "crshader"
              end

        str.puts "Error in #{loc}: #{message}"

        if source_lines && (ln = @line_number) && ln > 0 && ln <= source_lines.size
          line_idx = ln - 1
          # Print 1 line of context before if available
          if line_idx > 0
            str.puts sprintf("  %4d | %s", ln - 1, source_lines[line_idx - 1])
          end

          code_line = source_lines[line_idx]
          str.puts sprintf("> %4d | %s", ln, code_line)

          if col = @column_number
            pad = " " * (col - 1)
            str.puts sprintf("       | %s^", pad)
          end

          # Print 1 line of context after if available
          if line_idx + 1 < source_lines.size
            str.puts sprintf("  %4d | %s", ln + 1, source_lines[line_idx + 1])
          end
        end
      end
    end
  end
end
