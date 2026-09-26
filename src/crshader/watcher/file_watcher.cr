require "../compiler"
require "../ast/types"

module CrShader
  class FileWatcher
    property compiler : Compiler
    property target_override : ShaderTarget?
    property interval : Time::Span

    def initialize(@compiler : Compiler, @target_override : ShaderTarget? = nil, @interval = 500.milliseconds)
    end

    def watch(path : String, output_dir : String? = nil)
      puts "Watching #{path} for changes... (Press Ctrl+C to stop)"
      timestamps = {} of String => Time

      # Initial scan
      files = find_crshader_files(path)
      files.each do |f|
        timestamps[f] = File.info(f).modification_time
        compile_watched_file(f, output_dir)
      end

      loop do
        sleep @interval

        current_files = find_crshader_files(path)
        current_files.each do |file|
          mod_time = File.info(file).modification_time
          last_time = timestamps[file]?

          if last_time.nil? || mod_time > last_time
            timestamps[file] = mod_time
            compile_watched_file(file, output_dir)
          end
        end
      end
    end

    private def find_crshader_files(path : String) : Array(String)
      if File.file?(path)
        [path]
      elsif Dir.exists?(path)
        files = [] of String
        Dir.glob(File.join(path, "**", "*.crshader")).each do |f|
          files << f
        end
        files
      else
        [] of String
      end
    end

    private def compile_watched_file(input_file : String, output_dir : String?)
      target = @target_override
      # Detect if file content has shader_type :compute
      content = File.read(input_file)
      is_compute = content.includes?("shader_type :compute") || content.includes?("shader_type(\"compute\")")
      ext = is_compute || target == ShaderTarget::GLSL ? ".glsl" : ".gdshader"

      out_file = if output_dir
                   basename = File.basename(input_file, ".crshader") + ext
                   File.join(output_dir, basename)
                 else
                   input_file.sub(/\.crshader$/, ext)
                 end

      begin
        @compiler.compile_file(input_file, out_file)
        time_str = Time.local.to_s("%H:%M:%S")
        puts "[#{time_str}] Recompiled #{input_file} -> #{out_file}"
      rescue ex : ShaderError
        puts ex.formatted_message(content.lines)
      rescue ex
        puts "Error compiling #{input_file}: #{ex.message}"
      end
    end
  end
end
