require "compiler/crystal/syntax"
require "./extension"
require "../transpiler/symbol_table"
require "../std/registry"

module CrShader
  # =============================================================================
  # VisualInspectorExtension - One-Line `inspect(var)` Visual Shader Debugger
  # =============================================================================
  # Transforms `inspect(expr)` and `inspect(:label, expr)` probes in `fragment`
  # and `process_pixel` (`main`) into live selectable `debug_view` (`hint_enum`)
  # visualizations with negative/HDR/NaN-Inf heatmaps.
  # Completely stripped with zero uniform or ALU cost when `strip_debug_inspects`
  # (`--release`) is enabled.
  class VisualInspectorExtension < Extension
    getter name : String = "visual_inspector"
    property strip_debug_inspects : Bool = false

    def initialize(@strip_debug_inspects : Bool = false)
    end

    def transform_program(program : ShaderProgram) : Nil
      program.inspect_probes.clear

      if @strip_debug_inspects
        program.functions.each do |fname, fdef|
          program.functions[fname] = strip_inspects_in_def(fdef)
        end
        return
      end

      if program.target == ShaderTarget::GLSL
        if main_def = program.functions["main"]?
          transform_stage(program, "main", main_def, is_glsl_main: true)
        end
      elsif program.target == ShaderTarget::GDShader
        if frag_def = program.functions["fragment"]?
          transform_stage(program, "fragment", frag_def, is_glsl_main: false)
        end
      end
    end

    private def strip_inspects_in_def(def_node : Crystal::Def) : Crystal::Def
      stripper = InspectStripper.new
      def_node.body = def_node.body.transform(stripper)
      def_node
    end

    class InspectStripper < Crystal::Transformer
      def transform(node : Crystal::Expressions) : Crystal::ASTNode
        result = [] of Crystal::ASTNode
        node.expressions.each do |child|
          if child.is_a?(Crystal::Call) && child.obj.nil? && child.name == "inspect"
            next
          end
          t = child.transform(self)
          result << t unless t.is_a?(Crystal::Nop)
        end
        node.expressions = result
        node
      end

      def transform(node : Crystal::Call) : Crystal::ASTNode
        if node.obj.nil? && node.name == "inspect"
          if node.args.size >= 2
            return node.args[1].transform(self)
          elsif node.args.size == 1
            return node.args[0].transform(self)
          else
            return Crystal::Nop.new
          end
        end
        super
      end
    end

    private def transform_stage(
      program : ShaderProgram,
      stage_name : String,
      def_node : Crystal::Def,
      is_glsl_main : Bool,
    ) : Void
      sym = build_symbol_table(program)
      probes = [] of InspectProbe
      used_labels = Set(String).new

      orig_stmts = flatten_exprs(def_node.body)
      rewritten_stmts = rewrite_stmt_list(orig_stmts, sym, probes, used_labels)
      return if probes.empty?

      program.inspect_probes.concat(probes)

      # 1. Pre-declare capture variables at top of stage (after early bounds return in GLSL main)
      init_stmts = probes.map do |pr|
        Crystal::Parser.new("#{pr.capture_var} = #{zero_literal_for(pr.glsl_type)}").parse
      end

      insert_top_idx = 0
      if is_glsl_main
        # Insert after `coord = ...; size = ...; if ... return end`
        rewritten_stmts.each_with_index do |st, idx|
          if st.is_a?(Crystal::If) && st.to_s.includes?("return")
            insert_top_idx = idx + 1
            break
          end
        end
      end

      with_inits = rewritten_stmts[0...insert_top_idx] + init_stmts + rewritten_stmts[insert_top_idx..-1]

      # 2. Synthesize `debug_view` uniform under group "Debug"
      enum_labels = ["Off"] + probes.map(&.label) + ["NaN_Inf_Detector"]
      enum_hint = "hint_enum(#{enum_labels.map { |l| "\"#{l}\"" }.join(", ")})"
      unless program.uniforms.any? { |u| u.name == "debug_view" }
        program.uniforms << UniformDecl.new(
          name: "debug_view",
          type_name: "Int32",
          default_value: Crystal::NumberLiteral.new(0),
          hints: [enum_hint],
          group: "Debug",
          doc_comment: "Live visual variable inspector (stripped automatically in --release)"
        )
      end

      # 3. Synthesize stage-exit visualization block
      viz_stmts = build_visualization_ast(program, probes, is_glsl_main)

      final_stmts = if is_glsl_main
                      store_idx = with_inits.rindex do |e|
                        e.is_a?(Crystal::Call) && (e.name == "imageStore" || e.name == "image_store")
                      end
                      if store_idx
                        with_inits[0...store_idx] + viz_stmts + with_inits[store_idx..-1]
                      else
                        with_inits + viz_stmts
                      end
                    else
                      with_inits + viz_stmts
                    end

      program.functions[stage_name] = Crystal::Def.new(stage_name, body: Crystal::Expressions.new(final_stmts))
    end

    private def rewrite_stmt_list(
      stmts : Array(Crystal::ASTNode),
      sym : SymbolTable,
      probes : Array(InspectProbe),
      used_labels : Set(String),
    ) : Array(Crystal::ASTNode)
      result = [] of Crystal::ASTNode

      stmts.each do |stmt|
        if stmt.is_a?(Crystal::Call) && stmt.obj.nil? && stmt.name == "inspect" && !stmt.args.empty?
          cap_stmt = make_probe_capture(stmt, sym, probes, used_labels)
          result << cap_stmt if cap_stmt
          next
        end

        hoisted = [] of Crystal::ASTNode
        rewritten = rewrite_nested_inspects(stmt, sym, probes, used_labels, hoisted)
        result.concat(hoisted)

        case rewritten
        when Crystal::Assign
          if (t = rewritten.target).is_a?(Crystal::Var)
            vname = t.name
            unless sym.is_builtin?(vname) || sym.variable_declared?(vname)
              inferred = sym.infer_type(rewritten.value)
              sym.mark_variable_declared(vname, inferred)
            end
          end
          result << rewritten
        when Crystal::TypeDeclaration
          vname = rewritten.var.to_s
          sym.mark_variable_declared(vname, TypeInfo.resolve(rewritten.declared_type.to_s, sym.target))
          result << rewritten
        when Crystal::If
          sym.enter_scope
          then_list = rewrite_stmt_list(flatten_exprs(rewritten.then), sym, probes, used_labels)
          sym.exit_scope
          else_node = if !(en = rewritten.else).is_a?(Crystal::Nop) && en
                        sym.enter_scope
                        el = rewrite_stmt_list(flatten_exprs(en), sym, probes, used_labels)
                        sym.exit_scope
                        Crystal::Expressions.new(el).as(Crystal::ASTNode)
                      else
                        rewritten.else
                      end
          result << Crystal::If.new(rewritten.cond, Crystal::Expressions.new(then_list), else_node)
        else
          result << rewritten
        end
      end

      result
    end

    private def rewrite_nested_inspects(
      node : Crystal::ASTNode,
      sym : SymbolTable,
      probes : Array(InspectProbe),
      used_labels : Set(String),
      hoisted : Array(Crystal::ASTNode),
    ) : Crystal::ASTNode
      case node
      when Crystal::Assign
        Crystal::Assign.new(node.target, rewrite_nested_inspects(node.value, sym, probes, used_labels, hoisted))
      when Crystal::OpAssign
        Crystal::OpAssign.new(node.target, node.op, rewrite_nested_inspects(node.value, sym, probes, used_labels, hoisted))
      when Crystal::Call
        if node.obj.nil? && node.name == "inspect" && !node.args.empty?
          # Rewrite inner expression first, then capture into `_cr_dbg_k`
          new_args = node.args.map { |a| rewrite_nested_inspects(a, sym, probes, used_labels, hoisted).as(Crystal::ASTNode) }
          rebuilt = Crystal::Call.new(nil, "inspect", new_args)
          if cap_assign = make_probe_capture(rebuilt, sym, probes, used_labels)
            hoisted << cap_assign
            return Crystal::Var.new(probes.last.capture_var)
          end
        end
        new_obj = node.obj.try { |o| rewrite_nested_inspects(o, sym, probes, used_labels, hoisted) }
        new_args = node.args.map { |a| rewrite_nested_inspects(a, sym, probes, used_labels, hoisted).as(Crystal::ASTNode) }
        node.obj = new_obj
        node.args = new_args
        node
      else
        node
      end
    end

    private def make_probe_capture(
      call : Crystal::Call,
      sym : SymbolTable,
      probes : Array(InspectProbe),
      used_labels : Set(String),
    ) : Crystal::ASTNode?
      raw_label, expr = if call.args.size >= 2
                          {extract_label(call.args[0]), call.args[1]}
                        else
                          {extract_label(call.args[0]), call.args[0]}
                        end

      clean_label = unique_enum_label(raw_label, used_labels)
      raw_type = sym.infer_type(expr)
      norm_type = normalize_probe_type(raw_type)
      idx = probes.size + 1
      cap_var = "_cr_dbg_#{idx}"

      probes << InspectProbe.new(label: clean_label, capture_var: cap_var, glsl_type: norm_type)
      sym.mark_variable_declared(cap_var, norm_type)
      Crystal::Assign.new(Crystal::Var.new(cap_var), expr)
    end

    private def build_visualization_ast(
      program : ShaderProgram,
      probes : Array(InspectProbe),
      is_glsl_main : Bool,
    ) : Array(Crystal::ASTNode)
      px_expr = is_glsl_main ? "vec2(gl_GlobalInvocationID.xy)" : "FRAGCOORD.xy"
      color_var = if is_glsl_main
                    if vars = program.pixel_stage_vars
                      vars[1]
                    else
                      "color"
                    end
                  else
                    "COLOR"
                  end

      ref_rgb = if is_glsl_main
                  "#{color_var}.rgb"
                elsif program.shader_type == ShaderType::Spatial
                  "ALBEDO"
                else
                  "COLOR.rgb"
                end

      lines = [] of String
      lines << "if debug_view > 0"
      lines << "  _cr_px = #{px_expr}"
      lines << "  _cr_chk = (mod(floor(_cr_px.x * 0.125) + floor(_cr_px.y * 0.125), 2.0) < 0.5) ? vec3(1.0, 0.0, 1.0) : vec3(0.12, 0.0, 0.12)"
      lines << "  _cr_dbg_rgb = vec3(0.0, 0.0, 0.0)"

      probes.each_with_index do |pr, i|
        cond_kw = (i == 0) ? "if" : "elsif"
        idx = i + 1
        v = pr.capture_var
        lines << "  #{cond_kw} debug_view == #{idx}"
        case pr.glsl_type
        when "float"
          lines << "    if isnan(#{v}) || isinf(#{v})"
          lines << "      _cr_dbg_rgb = _cr_chk"
          lines << "    elsif #{v} < 0.0"
          lines << "      _cr_dbg_rgb = mix(vec3(0.05, 0.18, 0.48), vec3(0.0, 0.72, 1.0), clamp(-#{v}, 0.0, 1.0))"
          lines << "    elsif #{v} > 1.0"
          lines << "      _cr_dbg_rgb = mix(vec3(1.0, 0.85, 0.2), vec3(1.0, 0.22, 0.0), clamp((#{v} - 1.0) * 0.25, 0.0, 1.0))"
          lines << "    else"
          lines << "      _cr_dbg_rgb = vec3(#{v}, #{v}, #{v})"
          lines << "    end"
        when "vec2"
          lines << "    if any(isnan(#{v})) || any(isinf(#{v}))"
          lines << "      _cr_dbg_rgb = _cr_chk"
          lines << "    else"
          lines << "      _cr_grid = max(step(0.94, fract(#{v}.x * 8.0)), step(0.94, fract(#{v}.y * 8.0))) * 0.12"
          lines << "      _cr_dbg_rgb = clamp(vec3(fract(#{v}.x), fract(#{v}.y), 0.08) + vec3(_cr_grid, _cr_grid, _cr_grid), vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0))"
          lines << "    end"
        when "vec3"
          lines << "    if any(isnan(#{v})) || any(isinf(#{v}))"
          lines << "      _cr_dbg_rgb = _cr_chk"
          lines << "    else"
          lines << "      _cr_dbg_rgb = clamp(#{v}, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0))"
          lines << "    end"
        when "vec4"
          lines << "    if any(isnan(#{v})) || any(isinf(#{v}))"
          lines << "      _cr_dbg_rgb = _cr_chk"
          lines << "    else"
          lines << "      _cr_dbg_rgb = clamp(#{v}.rgb, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0))"
          lines << "    end"
        when "int", "uint"
          lines << "    _cr_fv = float(#{v})"
          lines << "    _cr_dbg_rgb = fract(vec3(_cr_fv * 0.173, _cr_fv * 0.371, _cr_fv * 0.619))"
        when "bool"
          lines << "    _cr_dbg_rgb = #{v} ? vec3(0.15, 0.92, 0.48) : vec3(0.08, 0.09, 0.14)"
        else
          lines << "    _cr_dbg_rgb = vec3(0.5, 0.5, 0.5)"
        end
      end

      nan_idx = probes.size + 1
      lines << "  elsif debug_view == #{nan_idx}"
      lines << "    _cr_ref = #{ref_rgb}"
      lines << "    if any(isnan(_cr_ref)) || any(isinf(_cr_ref))"
      lines << "      _cr_dbg_rgb = _cr_chk"
      lines << "    else"
      lines << "      _cr_luma = dot(clamp(_cr_ref, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0)), vec3(0.2126, 0.7152, 0.0722)) * 0.25"
      lines << "      _cr_dbg_rgb = vec3(_cr_luma, _cr_luma, _cr_luma)"
      lines << "    end"
      lines << "  end"

      if is_glsl_main
        lines << "  #{color_var} = vec4(_cr_dbg_rgb, 1.0)"
      elsif program.shader_type == ShaderType::Spatial
        lines << "  builtin_ALBEDO = _cr_dbg_rgb"
        lines << "  builtin_EMISSION = _cr_dbg_rgb * 0.25"
        lines << "  builtin_ROUGHNESS = 1.0"
        lines << "  builtin_METALLIC = 0.0"
      else
        lines << "  builtin_COLOR = vec4(_cr_dbg_rgb, 1.0)"
      end
      lines << "end"

      parsed = Crystal::Parser.new(lines.join("\n")).parse
      flatten_exprs(parsed)
    end

    private def build_symbol_table(program : ShaderProgram) : SymbolTable
      sym = SymbolTable.new(program.target, program.shader_type)
      program.uniforms.each { |u| sym.register_global(u.name, u.type_name) }
      program.varyings.each { |v| sym.register_global(v.name, v.type_name) }
      program.images.each { |i| sym.register_global(i.name, i.image_type) }
      program.constants.each do |c|
        t = c.type_name || sym.infer_type(c.value)
        sym.register_global(c.name, t)
      end
      program.structs.each_value do |st|
        sym.register_struct(st.name, st.fields.map { |f| {f.name, f.type_name} })
      end

      ["math", "color", "blend", "easing", "uv", "sdf2d"].each do |m|
        Std.load_module(m).each do |d|
          if rt = d.return_type
            sym.register_function(d.name, TypeInfo.resolve(rt.to_s, program.target))
          end
        end
      end
      program.requires.each do |r|
        Std.load_module(r).each do |d|
          if rt = d.return_type
            sym.register_function(d.name, TypeInfo.resolve(rt.to_s, program.target))
          end
        end
      end
      program.functions.each do |fname, fdef|
        if rt = fdef.return_type
          sym.register_function(fname, TypeInfo.resolve(rt.to_s, program.target))
        end
      end
      sym
    end

    private def normalize_probe_type(raw : String) : String
      case raw
      when "float", "vec2", "vec3", "vec4", "int", "uint", "bool"
        raw
      when "ivec2", "uvec2", "bvec2"
        "vec2"
      when "ivec3", "uvec3", "bvec3"
        "vec3"
      when "ivec4", "uvec4", "bvec4", "Color"
        "vec4"
      else
        "float"
      end
    end

    private def zero_literal_for(glsl_type : String) : String
      case glsl_type
      when "vec2" then "vec2(0.0, 0.0)"
      when "vec3" then "vec3(0.0, 0.0, 0.0)"
      when "vec4" then "vec4(0.0, 0.0, 0.0, 0.0)"
      when "int"  then "0"
      when "uint" then "0_u32"
      when "bool" then "false"
      else             "0.0"
      end
    end

    private def extract_label(node : Crystal::ASTNode) : String
      case node
      when Crystal::SymbolLiteral, Crystal::StringLiteral
        node.value
      when Crystal::Var
        node.name.sub(/^builtin_/, "")
      when Crystal::Path
        node.names.join("_")
      else
        node.to_s.sub(/^builtin_/, "")
      end
    end

    private def unique_enum_label(raw : String, used : Set(String)) : String
      cleaned = raw.strip.gsub(/[^a-zA-Z0-9_]/, "_").gsub(/_+/, "_").gsub(/^_+|_+$/, "")
      cleaned = "probe" if cleaned.empty?
      cleaned = cleaned[0, 28] if cleaned.size > 28
      candidate = cleaned
      suffix = 2
      while used.includes?(candidate) || candidate == "Off" || candidate == "NaN_Inf_Detector"
        candidate = "#{cleaned}_#{suffix}"
        suffix += 1
      end
      used.add(candidate)
      candidate
    end

    private def flatten_exprs(node : Crystal::ASTNode) : Array(Crystal::ASTNode)
      if node.is_a?(Crystal::Expressions)
        node.expressions.dup
      elsif node.is_a?(Crystal::Nop)
        [] of Crystal::ASTNode
      else
        [node]
      end
    end
  end
end
