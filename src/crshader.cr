require "option_parser"
require "file_utils"
require "./crshader/version"
require "./crshader/ast/types"
require "./crshader/compiler"
require "./crshader/watcher/file_watcher"
require "./crshader/language"
require "./crshader/stubs/stub_generator"
require "./crshader/stubs"
require "./crshader/generator/node_generator"
{% unless flag?(:release) %}
require "./docs"
{% end %}

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
      when "generate-node", "gen-node"
        sub_args = args[1..-1]
        node_type_str = "mesh3d"
        class_name : String? = nil
        node_out_target : String? = nil
        input_file : String? = nil

        parser = OptionParser.parse(sub_args) do |opts|
          opts.banner = "Usage: crshader generate-node <input.crshader> [options]"
          opts.on("-t TYPE", "--type TYPE", "Node type: mesh3d, canvas2d, compositor, or host (default: mesh3d)") { |t| node_type_str = t }
          opts.on("-n NAME", "--name NAME", "Class name for generated Godot node") { |n| class_name = n }
          opts.on("-o PATH", "--output PATH", "Output .cr file path") { |o| node_out_target = o }
          opts.on("-h", "--help", "Show help") { puts opts; exit 0 }
          opts.unknown_args { |unknown| input_file = unknown.first? }
        end

        target_file = input_file
        unless target_file && File.exists?(target_file)
          STDERR.puts "Error: input .crshader file not found. Usage: crshader generate-node <input.crshader>"
          exit 1
        end

        type = case node_type_str.downcase
               when "mesh3d", "screenspacemesh", "mesh"
                 NodeGenerator::NodeType::ScreenSpaceMesh
               when "canvas2d", "screenspacecanvas", "canvas"
                 NodeGenerator::NodeType::ScreenSpaceCanvas
               when "compositor", "compositoreffect"
                 NodeGenerator::NodeType::CompositorEffect
               else
                 NodeGenerator::NodeType::MaterialHost
               end

        cname = class_name ? class_name.to_s : "#{File.basename(target_file, ".crshader").camelcase}Node"
        generated_code = NodeGenerator.generate_from_file(target_file, type, cname)

        if out_file = node_out_target
          FileUtils.mkdir_p(File.dirname(out_file))
          File.write(out_file, generated_code)
          puts "Generated #{type} node '#{cname}' -> #{out_file}"
        else
          puts generated_code
        end
        return
      when "build", "compile"
        sub_args = args[1..-1]
        input_files = [] of String
        optimize_names = false

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
          parser.on("-O", "--optimize-names", "Optimize and minify local variable names") { optimize_names = true }
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

        compiler = Compiler.new(target_override: target_override, verbose: verbose, optimize_names: optimize_names)
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

      when "check", "lint"
        sub_args = args[1..-1]
        if sub_args.empty?
          STDERR.puts "Error: specify .crshader file to check. Usage: crshader check <file.crshader>"
          exit 1
        end
        target_file = sub_args.first
        unless File.exists?(target_file)
          STDERR.puts "Error: file not found: #{target_file}"
          exit 1
        end
        compiler = Compiler.new
        begin
          compiler.compile_source(File.read(target_file), filename: target_file)
          puts "✔ Syntax & schema valid: #{target_file}"
        rescue ex : ShaderError
          STDERR.puts ex.formatted_message(File.read(target_file).lines)
          exit 1
        rescue ex
          STDERR.puts "Error: #{ex.message}"
          exit 1
        end
        return

      when "inspect"
        sub_args = args[1..-1]
        if sub_args.empty?
          STDERR.puts "Error: specify .crshader file to inspect. Usage: crshader inspect <file.crshader>"
          exit 1
        end
        target_file = sub_args.first
        unless File.exists?(target_file)
          STDERR.puts "Error: file not found: #{target_file}"
          exit 1
        end
        parser = DslParser.new(filename: target_file)
        program = parser.parse(File.read(target_file))
        puts "Shader: #{target_file}"
        puts "Type: #{program.shader_type} (Target: #{program.target})"
        puts "Uniforms (#{program.uniforms.size}):"
        program.uniforms.each do |u|
          hints_str = u.hints.empty? ? "" : " [#{u.hints.join(", ")}]"
          grp_str = u.group ? " (Group: #{u.group})" : ""
          puts "  - #{u.name} : #{u.type_name}#{hints_str}#{grp_str}"
        end
        puts "Stages:"
        program.functions.each_key do |f|
          puts "  - #{f}" if ["vertex", "fragment", "light", "main", "start", "process", "sky", "fog"].includes?(f)
        end
        return

      when "new"
        sub_args = args[1..-1]
        tmpl = "spatial"
        new_out_file : String? = nil
        OptionParser.parse(sub_args) do |opts|
          opts.banner = "Usage: crshader new <output.crshader> [options]"
          opts.on("-t TYPE", "--template TYPE", "Template type: spatial, canvas, postprocess, or compute (default: spatial)") { |t| tmpl = t }
          opts.unknown_args { |unknown| new_out_file = unknown.first? }
        end
        unless new_out_file
          STDERR.puts "Error: specify output file name. Usage: crshader new <filename.crshader>"
          exit 1
        end
        content = case tmpl.downcase
                  when "canvas", "canvas_item", "2d"
                    <<-CR
                      shader_type :canvas_item
                      render_mode :unshaded

                      uniform tint : Color = Color.new(1.0, 1.0, 1.0, 1.0), hint: :source_color

                      def fragment
                        COLOR = texture(TEXTURE, UV) * tint
                      end
                    CR
                  when "postprocess", "post_process", "screen"
                    <<-CR
                      shader_type :canvas_item
                      render_mode :unshaded

                      require "std/post_processing"

                      uniform screen_tex : Sampler2D, hint: :screen_texture, filter: :linear
                      uniform vignette_radius : Float32 = 0.75, hint: range(0.1, 1.0, 0.05)

                      def fragment
                        col = texture(screen_tex, SCREEN_UV)
                        vig = vignette(SCREEN_UV, vignette_radius, 0.4)
                        COLOR = vec4(col.rgb * vig, 1.0)
                      end
                    CR
                  when "compute"
                    <<-CR
                      shader_type :compute

                      local_size 8, 8, 1

                      image2d output_image, format: :rgba32f, set: 0, binding: 0

                      def main
                        pos = ivec2(gl_GlobalInvocationID.xy)
                        color = vec4(float(pos.x) / 512.0, float(pos.y) / 512.0, 0.5, 1.0)
                        imageStore(output_image, pos, color)
                      end
                    CR
                  else
                    <<-CR
                      shader_type :spatial
                      render_mode :cull_back, :diffuse_lambert

                      uniform albedo : Color = Color.new(0.2, 0.6, 0.95, 1.0), hint: :source_color
                      uniform roughness : Float32 = 0.3, hint: range(0.0, 1.0, 0.05)
                      uniform metallic : Float32 = 0.1, hint: range(0.0, 1.0, 0.05)

                      def fragment
                        ALBEDO = albedo.rgb
                        ROUGHNESS = roughness
                        METALLIC = metallic
                      end
                    CR
                  end
        File.write(new_out_file.not_nil!, content.strip + "\n")
        puts "Created new #{tmpl} shader -> #{new_out_file}"
        return

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
  crshader build <file.crshader> [-o output] [--target gdshader|glsl] [-O]
  crshader check <file.crshader>
  crshader inspect <file.crshader>
  crshader new <file.crshader> [-t spatial|canvas|postprocess|compute]
  crshader generate-node <file.crshader> [-t mesh3d|canvas2d|compositor] [-o output.cr]
  crshader watch <path> [-o output_dir] [--target gdshader|glsl]
  crshader stubs [-o output_path]
  crshader install-addon [godot_project_dir]
  crshader --version
  crshader --help

Examples:
  crshader check examples/stylized_toon_pbr.crshader
  crshader inspect examples/water_caustics_ocean.crshader
  crshader new my_water.crshader -t spatial
  crshader build player.crshader
  crshader build compute.crshader --target glsl
  crshader generate-node effect.crshader -t compositor -o src/effect_node.cr
  crshader watch shaders/
HELP
    end
  end
end

if PROGRAM_NAME.ends_with?("crshader.cr")
  CrShader::CLI.run
end
