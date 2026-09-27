module CrShader
  class ShaderError < Exception
    getter filename : String?
    getter line_number : Int32?
    getter column_number : Int32?
    getter tip : String?

    def initialize(
      message : String,
      @filename : String? = nil,
      @line_number : Int32? = nil,
      @column_number : Int32? = nil,
      @tip : String? = nil
    )
      super(message)
    end

    def formatted_message(source_lines : Array(String)? = nil, use_color : Bool = true) : String
      red = use_color ? "\e[31;1m" : ""
      cyan = use_color ? "\e[36m" : ""
      yellow = use_color ? "\e[33m" : ""
      bold = use_color ? "\e[1m" : ""
      reset = use_color ? "\e[0m" : ""

      String.build do |str|
        loc = if @filename && @line_number
                "#{@filename}:#{@line_number}:#{@column_number || 1}"
              elsif @line_number
                "line #{@line_number}:#{@column_number || 1}"
              else
                "crshader"
              end

        str.puts "#{red}Error#{reset} in #{cyan}#{loc}#{reset}: #{bold}#{message}#{reset}"

        if source_lines && (ln = @line_number) && ln > 0 && ln <= source_lines.size
          line_idx = ln - 1
          # Print 1 line of context before if available
          if line_idx > 0
            str.puts sprintf("  %4d | %s", ln - 1, source_lines[line_idx - 1])
          end

          code_line = source_lines[line_idx]
          str.puts sprintf("%s> %4d | %s%s", red, ln, code_line, reset)

          if col = @column_number
            pad = " " * Math.max(0, col - 1)
            str.puts sprintf("       | %s%s^^^%s", pad, yellow, reset)
          end

          # Print 1 line of context after if available
          if line_idx + 1 < source_lines.size
            str.puts sprintf("  %4d | %s", ln + 1, source_lines[line_idx + 1])
          end
        end

        if tip_str = @tip
          str.puts "  #{cyan}💡 Suggestion:#{reset} #{tip_str}"
        end

        # Provide helpful hints for common issues
        msg = message || ""
        if msg.includes?("linear_depth") || msg.includes?("depth_sobel")
          str.puts "  #{yellow}💡 Hint:#{reset} Did you forget to add: #{cyan}require \"std/compositor\"#{reset}?"
        elsif msg.includes?("bayer") || msg.includes?("ign")
          str.puts "  #{yellow}💡 Hint:#{reset} Did you forget to add: #{cyan}require \"std/dither\"#{reset}?"
        elsif msg.includes?("curl_noise") || msg.includes?("simplex")
          str.puts "  #{yellow}💡 Hint:#{reset} Did you forget to add: #{cyan}require \"std/curl_noise\"#{reset}?"
        elsif msg.includes?("oklab")
          str.puts "  #{yellow}💡 Hint:#{reset} Did you forget to add: #{cyan}require \"std/color_spaces\"#{reset}?"
        elsif msg.includes?("hg_phase")
          str.puts "  #{yellow}💡 Hint:#{reset} Did you forget to add: #{cyan}require \"std/atmosphere\"#{reset}?"
        elsif msg.includes?("scanline_jitter")
          str.puts "  #{yellow}💡 Hint:#{reset} Did you forget to add: #{cyan}require \"std/glitch\"#{reset}?"
        end
      end
    end
  end
end
