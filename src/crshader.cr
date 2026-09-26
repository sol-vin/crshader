require "option_parser"
require "file_utils"
require "./crshader/version"
require "./crshader/ast/types"
require "./crshader/compiler"
require "./crshader/watcher/file_watcher"
require "./crshader/stubs/stub_generator"

module CrShader
  class CLI
    def self.run(args = ARGV)
      new.run(args)
    end

    def run(args)
      target_override : ShaderTarget? = nil
      output_path : String? = nil
      watch_mode = false
      verbose = false

      if args.empty? || args.first == "-h" || args.first == "--help"
        print_help
        return
      end

      command = args.first

      case command
      when "-v", "--version"
        puts "crshader version #{CrShader::VERSION}"
        return
      when "install-addon"
        project_dir = args.size > 1 ? args[1] : "."
        install_godot_addon(project_dir)
        return
      when "stubs", "generate-stubs"
        sub_args = args[1..-1]
        out_target = "src/libgodot/crshader.cr"
        OptionParser.parse(sub_args) do |opts|
          opts.banner = "Usage: crshader stubs [options]"
          opts.on("-o PATH", "--output PATH", "Output path for Crystal stubs (default: src/libgodot/crshader.cr)") { |o| out_target = o }
          opts.on("-h", "--help", "Show help") { puts opts; exit 0 }
        end
        FileUtils.mkdir_p(File.dirname(out_target))
        StubGenerator.write_to_file(out_target)
        puts "Generated CrShader stubs with mirrored Godot documentation -> #{out_target}"
        return
      when "build", "compile"
        sub_args = args[1..-1]
        input_files = [] of String

        parser = OptionParser.parse(sub_args) do |parser|
          parser.banner = "Usage: crshader build <input.crshader...> [options]"
          parser.on("-o PATH", "--output PATH", "Specify output file path (only when single file is provided)") { |o| output_path = o }
          parser.on("-t TARGET", "--target TARGET", "Target language: gdshader or glsl") do |t|
            target_override = ShaderTarget.from_string?(t)
            unless target_override
              STDERR.puts "Error: invalid target '#{t}'. Choose 'gdshader' or 'glsl'."
              exit 1
            end
          end
          parser.on("-V", "--verbose", "Enable verbose output") { verbose = true }
          parser.on("-h", "--help", "Show help") { puts parser; exit 0 }
          parser.unknown_args do |unknown|
            input_files = unknown
          end
        end

        if input_files.empty?
          STDERR.puts "Error: missing input file. Usage: crshader build <input.crshader>"
          exit 1
        end

        compiler = Compiler.new(target_override: target_override, verbose: verbose)
        expanded_files = [] of String
        input_files.each do |f|
          if f.includes?('*') || f.includes?('?')
            matches = Dir.glob(f)
            if matches.empty?
              STDERR.puts "Error: No files matched pattern '#{f}'"
              exit 1
            end
            expanded_files.concat(matches)
          else
            expanded_files << f
          end
        end

        expanded_files.each do |input_file|
          final_output = (expanded_files.size == 1 && output_path) ? output_path : default_output_for(input_file, target_override)

          begin
            res = compiler.compile_file(input_file, final_output)
            puts "Compiled #{input_file} -> #{final_output}"
          rescue ex : ShaderError
            STDERR.puts ex.formatted_message(File.read(input_file).lines)
            exit 1
          rescue ex
            STDERR.puts "Error: #{ex.message}"
            exit 1
          end
        end

      when "watch"
        sub_args = args[1..-1]
        watch_path : String? = nil

        parser = OptionParser.parse(sub_args) do |parser|
          parser.banner = "Usage: crshader watch <directory-or-file> [options]"
          parser.on("-o DIR", "--output DIR", "Output directory for compiled shaders") { |o| output_path = o }
          parser.on("-t TARGET", "--target TARGET", "Target language: gdshader or glsl") do |t|
            target_override = ShaderTarget.from_string?(t)
          end
          parser.on("-h", "--help", "Show help") { puts parser; exit 0 }
          parser.unknown_args do |unknown|
            watch_path = unknown.first?
          end
        end

        target_path = (watch_path || ".").to_s
        compiler = Compiler.new(target_override: target_override, verbose: verbose)
        watcher = FileWatcher.new(compiler, target_override: target_override)
        watcher.watch(target_path, output_path)

      else
        # If first argument is a file ending in .crshader, treat as build
        if command.ends_with?(".crshader")
          compiler = Compiler.new(target_override: target_override)
          final_output = default_output_for(command, target_override)
          compiler.compile_file(command, final_output)
          puts "Compiled #{command} -> #{final_output}"
        else
          print_help
        end
      end
    end

    private def default_output_for(input_file : String, target : ShaderTarget?) : String
      content = File.exists?(input_file) ? File.read(input_file) : ""
      is_compute = content =~ /(?:shader_type\s*:?compute|shader\s*:?compute)/
      ext = is_compute || target == ShaderTarget::GLSL ? ".glsl" : ".gdshader"
      input_file.sub(/\.crshader$/, ext)
    end

    private def install_godot_addon(project_dir : String)
      target_addons_dir = File.join(project_dir, "addons", "crshader")
      source_addon_dir = File.join(__DIR__, "..", "godot_addon", "addons", "crshader")

      unless Dir.exists?(source_addon_dir)
        # Try local path
        source_addon_dir = "godot_addon/addons/crshader"
      end

      if Dir.exists?(source_addon_dir)
        FileUtils.mkdir_p(target_addons_dir)
        FileUtils.cp_r(source_addon_dir, File.dirname(target_addons_dir))
        puts "Installed CRShader addon to #{target_addons_dir}"
      else
        STDERR.puts "Could not find source addon directory at #{source_addon_dir}"
      end
    end

    private def print_help
      puts <<-HELP
CRSHADER: Crystal DSL & Transpiler for Godot GDShader and GLSL Compute

Usage:
  crshader build <file.crshader> [-o output] [--target gdshader|glsl]
  crshader watch <path> [-o output_dir] [--target gdshader|glsl]
  crshader stubs [-o output_path]
  crshader install-addon [godot_project_dir]
  crshader --version
  crshader --help

Examples:
  crshader build player.crshader
  crshader build compute.crshader --target glsl
  crshader watch shaders/
  crshader stubs -o src/libgodot/crshader.cr
  crshader install-addon my_godot_project/
HELP
    end
  end
end

CrShader::CLI.run
