require "compiler/crystal/syntax"
require "./ast/types"
require "./ast/shader_ast"
require "./parser/dsl_parser"
require "./parser/error_formatter"
require "./validator/semantic_validator"
require "./extensions/registry"
require "./extensions/visual_inspector_extension"
require "./std/registry"
require "./optimizer/tree_shaker"
require "./optimizer/name_optimizer"
require "./transpiler/gdshader/emitter"
require "./transpiler/gdshader/gdshaderinc_emitter"
require "./transpiler/glsl/emitter"
require "./runtime/variant_cache"
require "./composer/shader_composer"
require "./builder/shader_builder"

module CrShader
  class Compiler
    property target_override : ShaderTarget? = nil
    property verbose : Bool = false
    property optimize_names : Bool = false
    property skip_validation : Bool = false
    property feature_overrides : Hash(String, FeatureValue)
    property strip_debug_inspects : Bool = false
    property godot_compute_header : Bool = false
    getter last_program : ShaderProgram? = nil

    def initialize(
      @target_override : ShaderTarget? = nil,
      @verbose : Bool = false,
      @optimize_names : Bool = false,
      @skip_validation : Bool = false,
      @feature_overrides : Hash(String, FeatureValue) = {} of String => FeatureValue,
      @strip_debug_inspects : Bool = false,
      @godot_compute_header : Bool = false,
    )
    end

    def compile_file(input_path : String, output_path : String? = nil) : String
      unless File.exists?(input_path)
        raise ShaderError.new("Input file not found: #{input_path}")
      end

      inferred_target = @target_override
      if inferred_target.nil? && output_path
        if output_path.downcase.ends_with?(".gdshaderinc")
          inferred_target = ShaderTarget::GDShaderInc
        elsif output_path.downcase.ends_with?(".glsl")
          inferred_target = ShaderTarget::GLSL
        end
      end

      old_override = @target_override
      @target_override = inferred_target if inferred_target
      begin
        source = File.read(input_path)
        compiled = compile_source(source, filename: input_path)

        if output_path
          parent_dir = File.dirname(output_path)
          Dir.mkdir_p(parent_dir) unless Dir.exists?(parent_dir)
          File.write(output_path, compiled)
        end

        compiled
      ensure
        @target_override = old_override
      end
    end

    def compile(source : String, target : ShaderTarget? = nil) : String
      old_target = @target_override
      @target_override = target if target
      begin
        compile_source(source)
      ensure
        @target_override = old_target
      end
    end

    def compile_source(source : String, filename : String? = nil) : String
      parser = DslParser.new(
        filename: filename,
        default_target: @target_override || ShaderTarget::GDShader,
        force_target: !@target_override.nil?,
        feature_overrides: @feature_overrides
      )
      program = parser.parse(source)
      @last_program = program

      # Determine target early so validation & extensions see final target
      target = @target_override || program.target
      program.target = target

      # Extension AST transformations + Visual Inspector probes
      Extensions.transform_program(program)
      VisualInspectorExtension.new(strip_debug_inspects: @strip_debug_inspects).transform_program(program)

      # Semantic validation pass (early error detection)
      unless @skip_validation
        validator = Validator::SemanticValidator.new(program, filename: filename, source_lines: parser.source_lines)
        Extensions.validate(program, validator.context)
        if target == ShaderTarget::GDShaderInc
          validator.validate_uniforms
          validator.context.check!
        else
          validator.validate!
        end
      end

      # Handle setup_gdshader helper defaults
      if program.setup_gdshader && target == ShaderTarget::GDShader
        apply_setup_gdshader_defaults(program)
      end

      # Set up tree shaker for stdlib, imported modules, and helper functions
      tree_shaker = TreeShaker.new

      # Always include core math, color, blend, and uv helpers in pool for fluent method chains
      ["math", "color", "blend", "uv"].each do |core_mod|
        Std.load_module(core_mod).each do |d|
          tree_shaker.add_library_def(d)
        end
      end

      # Include any required standard libraries in pool
      program.requires.each do |req_name|
        Std.load_module(req_name).each do |d|
          tree_shaker.add_library_def(d)
        end
      end

      # Add all non-stage functions (including imported module functions) to pool
      program.functions.each do |name, d|
        unless TreeShaker::STAGES.includes?(name)
          tree_shaker.add_library_def(d)
        end
      end

      # Get only alive helper functions in post-order dependency sequence
      alive_helpers = tree_shaker.process(program)
      reachable_ids = tree_shaker.reachable_identifiers

      # When specialization features exist, prune unused uniforms & samplers automatically
      if !program.features.empty? && target != ShaderTarget::GDShaderInc && TreeShaker::STAGES.any? { |s| program.functions.has_key?(s) }
        program.uniforms.select! do |u|
          reachable_ids.includes?(u.name) ||
            (program.is_compositor && u.set == 0 && (u.binding == 1 || u.binding == 2))
        end
      end

      # Optimize local variable names if requested
      if @optimize_names
        name_optimizer = Optimizer::NameOptimizer.new(program)
        name_optimizer.optimize_program(program)
      end

      # Emit target shader code
      io = IO::Memory.new
      case target
      when ShaderTarget::GDShader
        emitter = GDShaderEmitter.new(io, program)
        emitter.emit(alive_helpers, reachable_ids)
      when ShaderTarget::GDShaderInc
        emitter = GDShaderIncEmitter.new(io, program, filename: filename)
        emitter.emit(alive_helpers, reachable_ids)
      when ShaderTarget::GLSL
        eff_hdr = @godot_compute_header || program.emit_targets.first?.try(&.godot_compute_header) || false
        emitter = GLSLEmitter.new(io, program, godot_compute_header: eff_hdr)
        emitter.emit(alive_helpers, reachable_ids)
      end

      io.to_s
    end

    # Compiles all `emit_target` outputs declared in `source` (or the single default sibling
    # output when no `emit_target` directive is present). Returns `{output_path, target, code}` tuples.
    def compile_emit_targets(
      source : String,
      filename : String? = nil,
      write_disk : Bool = true,
    ) : Array(Tuple(String, ShaderTarget, String))
      probe_parser = DslParser.new(
        filename: filename,
        default_target: @target_override || ShaderTarget::GDShader,
        force_target: !@target_override.nil?,
        feature_overrides: @feature_overrides
      )
      probe_prog = probe_parser.parse(source)
      results = [] of Tuple(String, ShaderTarget, String)
      base_dir = filename ? File.dirname(filename.not_nil!) : "."

      if !probe_prog.emit_targets.empty?
        probe_prog.emit_targets.each do |et|
          rel = et.output_path
          out_path = if Path.new(rel).absolute? || filename.nil?
                       rel.gsub('\\', '/')
                     else
                       File.join(base_dir, rel).gsub('\\', '/')
                     end
          merged_feats = @feature_overrides.dup
          et.features.each { |k, v| merged_feats[k] = v }
          sub_compiler = Compiler.new(
            target_override: @target_override || et.target,
            verbose: @verbose,
            optimize_names: @optimize_names,
            skip_validation: @skip_validation,
            feature_overrides: merged_feats,
            strip_debug_inspects: @strip_debug_inspects,
            godot_compute_header: @godot_compute_header || et.godot_compute_header
          )
          code = sub_compiler.compile_source(source, filename: filename)
          res_target = sub_compiler.last_program.try(&.target) || et.target || ShaderTarget::GDShader
          if write_disk && !out_path.empty?
            pdir = File.dirname(out_path)
            Dir.mkdir_p(pdir) unless Dir.exists?(pdir)
            File.write(out_path, code)
          end
          results << {out_path, res_target, code}
        end
      else
        code = compile_source(source, filename: filename)
        res_target = @last_program.try(&.target) || @target_override || ShaderTarget::GDShader
        out_ext = case res_target
                  when ShaderTarget::GLSL        then ".glsl"
                  when ShaderTarget::GDShaderInc then ".gdshaderinc"
                  else                                ".gdshader"
                  end
        out_path = if fn = filename
                     fn.sub(/\.crshader$/i, out_ext).gsub('\\', '/')
                   else
                     ""
                   end
        if write_disk && !out_path.empty? && out_path != filename
          pdir = File.dirname(out_path)
          Dir.mkdir_p(pdir) unless Dir.exists?(pdir)
          File.write(out_path, code)
        end
        results << {out_path, res_target, code}
      end

      results
    end

    private def apply_setup_gdshader_defaults(program : ShaderProgram)
      has_albedo = program.uniforms.any? { |u| u.name == "albedo" || u.name == "color" }
      unless has_albedo
        program.uniforms << UniformDecl.new(
          name: "albedo",
          type_name: "Color",
          default_value: Crystal::Parser.new("Color.new(1.0, 1.0, 1.0, 1.0)").parse,
          hints: ["source_color"]
        )
      end
    end
  end

  def self.compile_variant(
    source : String,
    target : ShaderTarget? = nil,
    features : Hash(String, FeatureValue)? = nil,
    strip_debug_inspects : Bool = false,
    cache : VariantCache = VariantCache.global,
  ) : String
    cache.get_or_compile(
      source: source,
      target: target,
      features: features,
      strip_debug_inspects: strip_debug_inspects
    ).code
  end
end
