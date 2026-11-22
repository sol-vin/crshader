require "compiler/crystal/syntax"
require "../ast/shader_ast"

module CrShader
  class TreeShaker
    property pool : Hash(String, Crystal::Def) = {} of String => Crystal::Def
    property overloads : Hash(String, Array(Crystal::Def)) = {} of String => Array(Crystal::Def)
    property alive_functions : Hash(String, Crystal::Def) = {} of String => Crystal::Def
    property reachable_names : Set(String) = Set(String).new
    property reachable_identifiers : Set(String) = Set(String).new

    def initialize
    end

    def sig_key(def_node : Crystal::Def) : String
      "#{def_node.name}/#{def_node.args.size}"
    end

    def add_library_def(def_node : Crystal::Def)
      @pool[def_node.name] = def_node
      list = (@overloads[def_node.name] ||= [] of Crystal::Def)
      list.reject! { |existing| existing.args.size == def_node.args.size }
      list << def_node
    end

    STAGES = ["vertex", "fragment", "light", "start", "process", "collide", "sky", "fog", "main"]

    def process(program : ShaderProgram) : Array(Crystal::Def)
      @reachable_names.clear
      @reachable_identifiers.clear
      @alive_functions.clear
      ordered_helpers = [] of Crystal::Def

      # 1. Seed identifiers referenced by uniforms, varyings, buffers, and non-imported structs/constants
      program.uniforms.each do |u|
        record_type_identifier(u.type_name)
        u.array_size.try { |sz| @reachable_identifiers.add(sz) }
        u.default_value.try { |dv| collect_references(dv, ordered_helpers) }
      end
      program.varyings.each { |v| record_type_identifier(v.type_name) }
      program.buffers.each do |b|
        b.fields.each do |f|
          record_type_identifier(f.type_name)
          f.array_size.try { |sz| @reachable_identifiers.add(sz) }
        end
      end
      program.push_constants.each do |pc|
        pc.fields.each do |f|
          record_type_identifier(f.type_name)
          f.array_size.try { |sz| @reachable_identifiers.add(sz) }
        end
      end

      program.structs.each do |sname, sdecl|
        unless program.imported_structs.includes?(sname)
          mark_struct_reachable(sname, program)
          sdecl.fields.each { |f| record_type_identifier(f.type_name) }
        end
      end

      program.constants.each do |c|
        unless program.imported_constants.includes?(c.name)
          @reachable_identifiers.add(c.name)
          c.type_name.try { |tn| record_type_identifier(tn) }
          collect_references(c.value, ordered_helpers)
        end
      end

      # 2. For library/header targets (or stage-less files), retain non-imported helper functions;
      #    when shader stages exist, shake dead helpers strictly from stage entry points!
      has_stage_entry = STAGES.any? { |s| program.functions.has_key?(s) }
      if program.target == ShaderTarget::GDShaderInc || !has_stage_entry
        program.functions.each do |name, d|
          next if STAGES.includes?(name)
          next if program.imported_functions.includes?(name)
          visit_function_def(d, ordered_helpers)
        end
      end

      # 3. Traverse from shader stage entry points
      STAGES.each do |entry|
        if d = program.functions[entry]?
          collect_Def_signature(d)
          collect_references(d.body, ordered_helpers)
        end
      end

      # 4. Expand transitive constant and struct dependencies from imported modules
      expand_imported_constants_and_structs(program, ordered_helpers)

      ordered_helpers.uniq { |d| sig_key(d) }
    end

    private def visit_function_def(def_node : Crystal::Def, ordered_helpers : Array(Crystal::Def))
      skey = sig_key(def_node)
      return if @reachable_names.includes?(skey)
      @reachable_names.add(skey)
      collect_Def_signature(def_node)
      collect_references(def_node.body, ordered_helpers)
      ordered_helpers << def_node unless STAGES.includes?(def_node.name)
    end

    private def collect_Def_signature(def_node : Crystal::Def)
      def_node.return_type.try { |rt| record_type_identifier(rt.to_s) }
      def_node.args.each do |arg|
        arg.restriction.try { |r| record_type_identifier(r.to_s) }
      end
    end

    private def record_type_identifier(type_str : String)
      clean = type_str.strip
      if clean.starts_with?("InOut(") && clean.ends_with?(")")
        record_type_identifier(clean[6..-2])
      elsif clean.starts_with?("Out(") && clean.ends_with?(")")
        record_type_identifier(clean[4..-2])
      elsif clean.starts_with?("Array(") && clean.ends_with?(")")
        parts = clean[6..-2].split(",").map(&.strip)
        record_type_identifier(parts[0]) unless parts.empty?
        @reachable_identifiers.add(parts[1]) if parts.size > 1
      else
        @reachable_identifiers.add(clean)
      end
    end

    private def mark_struct_reachable(sname : String, program : ShaderProgram)
      return unless @reachable_identifiers.add?(sname)
      if sdecl = program.structs[sname]?
        sdecl.fields.each do |f|
          record_type_identifier(f.type_name)
        end
      end
    end

    private def expand_imported_constants_and_structs(program : ShaderProgram, ordered_helpers : Array(Crystal::Def))
      changed = true
      while changed
        changed = false
        program.constants.each do |c|
          next unless program.imported_constants.includes?(c.name)
          if @reachable_identifiers.includes?(c.name)
            before = @reachable_identifiers.size + @reachable_names.size
            c.type_name.try { |tn| record_type_identifier(tn) }
            collect_references(c.value, ordered_helpers)
            after = @reachable_identifiers.size + @reachable_names.size
            changed = true if after > before
          end
        end

        program.structs.each do |sname, sdecl|
          next unless program.imported_structs.includes?(sname)
          if @reachable_identifiers.includes?(sname)
            sdecl.fields.each do |f|
              before = @reachable_identifiers.size
              record_type_identifier(f.type_name)
              changed = true if @reachable_identifiers.size > before
            end
          end
        end
      end
    end

    private def collect_references(node : Crystal::ASTNode, ordered_helpers : Array(Crystal::Def))
      case node
      when Crystal::Call
        func_name = node.name
        clean_name = func_name.sub(/^builtin_/, "")
        @reachable_identifiers.add(clean_name)

        call_arity = node.obj ? (node.args.size + 1) : node.args.size
        matched_def = if candidates = @overloads[func_name]?
                        candidates.find { |c| c.args.size == node.args.size } ||
                          (node.obj ? candidates.find { |c| c.args.size == call_arity } : nil) ||
                          @pool[func_name]?
                      else
                        @pool[func_name]?
                      end

        if matched_def
          skey = sig_key(matched_def)
          unless @reachable_names.includes?(skey)
            @reachable_names.add(skey)
            collect_Def_signature(matched_def)
            # Post-order: visit dependencies FIRST
            collect_references(matched_def.body, ordered_helpers)
            # Then add callee before caller!
            ordered_helpers << matched_def
          end
        end

        if !node.obj.nil?
          collect_fluent_method_deps(node, ordered_helpers)
        end

        node.obj.try { |o| collect_references(o, ordered_helpers) }
        node.args.each { |arg| collect_references(arg, ordered_helpers) }
        node.named_args.try &.each { |narg| collect_references(narg.value, ordered_helpers) }
        node.block.try { |blk| collect_references(blk.body, ordered_helpers) }
      when Crystal::Var
        @reachable_identifiers.add(node.name.sub(/^builtin_/, ""))
      when Crystal::Path
        node.names.each { |n| @reachable_identifiers.add(n.sub(/^builtin_/, "")) }
      when Crystal::TypeDeclaration
        record_type_identifier(node.declared_type.to_s)
        node.value.try { |v| collect_references(v, ordered_helpers) }
      when Crystal::Expressions
        node.expressions.each { |child| collect_references(child, ordered_helpers) }
      when Crystal::Assign, Crystal::OpAssign
        collect_references(node.target, ordered_helpers)
        collect_references(node.value, ordered_helpers)
      when Crystal::If
        collect_references(node.cond, ordered_helpers)
        collect_references(node.then, ordered_helpers)
        node.else.try { |e| collect_references(e, ordered_helpers) }
      when Crystal::Unless
        collect_references(node.cond, ordered_helpers)
        collect_references(node.then, ordered_helpers)
        node.else.try { |e| collect_references(e, ordered_helpers) }
      when Crystal::Case
        node.cond.try { |c| collect_references(c, ordered_helpers) }
        node.whens.each do |w|
          w.conds.each { |wc| collect_references(wc, ordered_helpers) }
          collect_references(w.body, ordered_helpers)
        end
        node.else.try { |e| collect_references(e, ordered_helpers) }
      when Crystal::While, Crystal::Until
        collect_references(node.cond, ordered_helpers)
        collect_references(node.body, ordered_helpers)
      when Crystal::ArrayLiteral
        node.of.try { |o| record_type_identifier(o.to_s) }
        node.elements.each { |el| collect_references(el, ordered_helpers) }
      when Crystal::RangeLiteral
        collect_references(node.from, ordered_helpers)
        collect_references(node.to, ordered_helpers)
      when Crystal::BinaryOp
        collect_references(node.left, ordered_helpers)
        collect_references(node.right, ordered_helpers)
      when Crystal::Not
        collect_references(node.exp, ordered_helpers)
      when Crystal::Return
        node.exp.try { |e| collect_references(e, ordered_helpers) }
      end
    end

    private def collect_fluent_method_deps(node : Crystal::Call, ordered_helpers : Array(Crystal::Def)) : Void
      case node.name
      when "scroll"
        @reachable_identifiers.add("TIME") if node.args.size <= 2
      when "rotate"
        mark_helper_by_name("uv_rotate", 3, ordered_helpers)
      when "pixelate"
        mark_helper_by_name("uv_pixelate", 2, ordered_helpers)
      when "polar"
        mark_helper_by_name("uv_polar", 2, ordered_helpers)
      when "wave"
        @reachable_identifiers.add("TIME") if node.args.size <= 2
        mark_helper_by_name("uv_wave", 4, ordered_helpers)
      when "remap"
        mark_helper_by_name("remap", 5, ordered_helpers)
      when "contrast"
        mark_helper_by_name("adjust_contrast", 2, ordered_helpers)
        mark_helper_by_name("adjust_contrast_rgba", 2, ordered_helpers)
      when "saturate_color"
        mark_helper_by_name("adjust_saturation", 2, ordered_helpers)
        mark_helper_by_name("saturate_rgba", 2, ordered_helpers)
      when "hue_shift"
        mark_helper_by_name("hue_shift_rgb", 2, ordered_helpers)
        mark_helper_by_name("hue_shift_rgba", 2, ordered_helpers)
      when "blend"
        mode_raw = if m_arg = node.args[0]?
                     case m_arg
                     when Crystal::SymbolLiteral, Crystal::StringLiteral then m_arg.value
                     when Crystal::Var                                   then m_arg.name
                     else                                                     "overlay"
                     end
                   else
                     "overlay"
                   end
        mode = mode_raw.downcase
        unless ["multiply", "screen", "overlay", "hard_light", "soft_light", "color_dodge", "color_burn", "difference", "exclusion", "add"].includes?(mode)
          mode = "overlay"
        end
        mark_helper_by_name("blend_#{mode}_opacity", 3, ordered_helpers)
        mark_helper_by_name("blend_#{mode}_rgba", 3, ordered_helpers)
      end
    end

    private def mark_helper_by_name(name : String, arity : Int32, ordered_helpers : Array(Crystal::Def)) : Void
      d = if candidates = @overloads[name]?
            candidates.find { |c| c.args.size == arity } || @pool[name]?
          else
            @pool[name]?
          end
      return unless d
      skey = sig_key(d)
      return if @reachable_names.includes?(skey)
      @reachable_names.add(skey)
      collect_Def_signature(d)
      collect_references(d.body, ordered_helpers)
      ordered_helpers << d
    end
  end
end
