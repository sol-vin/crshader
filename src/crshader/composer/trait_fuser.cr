require "compiler/crystal/syntax"
require "../ast/shader_ast"
require "../std/registry"
require "../transpiler/symbol_table"
require "../language/gradients_and_curves"

module CrShader
  module TraitFuser
    extend self

    # Parses `shader_trait :name do ... end` into a TraitDecl
    def parse_trait_decl(call : Crystal::Call, parent_parser : DslParser) : TraitDecl?
      return nil unless (first_arg = call.args.first?) && (blk = call.block)
      tname = extract_ident(first_arg)
      return nil if tname.empty?

      decl = TraitDecl.new(tname)
      sub_parser = DslParser.new(
        filename: parent_parser.filename,
        default_target: parent_parser.program.target,
        loaded_modules: parent_parser.loaded_modules,
        force_target: true,
        feature_overrides: parent_parser.feature_overrides
      )

      stmts = flatten_exprs(blk.body)
      stmts.each do |stmt|
        if stmt.is_a?(Crystal::Call) && stmt.obj.nil? && stmt.block
          case stmt.name
          when "on_vertex"
            decl.vertex_hooks << stmt.block.not_nil!.body
            next
          when "on_fragment"
            decl.fragment_hooks << stmt.block.not_nil!.body
            next
          when "on_light"
            decl.light_hooks << stmt.block.not_nil!.body
            next
          when "on_pixel"
            pblk = stmt.block.not_nil!
            uv_v = pblk.args[0]?.try(&.name) || "uv"
            col_v = pblk.args[1]?.try(&.name) || "color"
            decl.pixel_hooks << TraitPixelHook.new(uv_v, col_v, pblk.body)
            next
          end
        end
        sub_parser.process_hoisted_node(stmt)
      end

      sub_prog = sub_parser.program
      decl.requires = sub_prog.requires
      decl.features = sub_prog.features
      decl.uniforms = sub_prog.uniforms
      decl.varyings = sub_prog.varyings
      decl.constants = sub_prog.constants
      decl.structs = sub_prog.structs
      decl.functions = sub_prog.functions
      decl.gradients = sub_prog.gradients
      decl.curves = sub_prog.curves
      decl
    end

    # Resolves a TraitUse against in-file traits, std/traits/*, or external .crshader files
    def resolve_trait(
      use_item : TraitUse,
      program : ShaderProgram,
      filename : String?,
      feature_overrides : Hash(String, FeatureValue),
    ) : TraitDecl
      raw = use_item.path_or_name.strip
      short = Std.normalize_trait_key(raw)

      if local_t = program.traits[raw]? || program.traits[short]?
        return local_t
      end

      if Std.has_trait?(raw)
        if src = Std.trait_source(raw)
          tp = DslParser.new(
            filename: "<std/traits/#{short}>",
            default_target: program.target,
            force_target: true,
            feature_overrides: feature_overrides
          )
          tprog = tp.parse(src)
          if found = tprog.traits[short]? || tprog.traits.values.first?
            return found
          end
        end
      end

      if file_path = DslParser.resolve_crshader_file(raw, filename)
        tp = DslParser.new(
          filename: file_path,
          default_target: program.target,
          force_target: true,
          feature_overrides: feature_overrides
        )
        tprog = tp.parse(File.read(file_path))
        base_name = File.basename(file_path, ".crshader")
        if found = tprog.traits[base_name]? || tprog.traits[short]? || tprog.traits.values.first?
          return found
        end
      end

      raise ShaderError.new(
        "Unknown shader trait '#{raw}'.",
        filename: filename,
        tip: "Available built-in traits: #{Std.trait_names.map { |n| "std/traits/#{n}" }.join(", ")}"
      )
    end

    # Fuses all `program.trait_uses` into `program` in declaration order
    def fuse!(
      program : ShaderProgram,
      filename : String? = nil,
      feature_overrides : Hash(String, FeatureValue) = {} of String => FeatureValue,
    ) : Void
      return if program.trait_uses.empty?

      collected_vertex = [] of Crystal::ASTNode
      collected_fragment = [] of Crystal::ASTNode
      collected_light = [] of Crystal::ASTNode
      collected_pixel = [] of Tuple(String, String, Crystal::ASTNode)

      program.trait_uses.each_with_index do |use_item, idx|
        trait = resolve_trait(use_item, program, filename, feature_overrides)
        prefix = use_item.prefix.try(&.strip)
        prefix = nil if prefix && prefix.empty?

        slug = sanitize_ident(prefix ? "#{prefix}_#{trait.name}" : trait.name)
        group_title = prefix ? "#{prefix.camelcase}_#{trait.name.camelcase}" : trait.name.camelcase
        renames = {} of String => String

        # 1. Requires & Features
        trait.requires.each { |r| program.requires.add(r) }
        trait.features.each do |f|
          unless program.features.any? { |ef| ef.name == f.name }
            program.features << f
          end
        end

        # 2. Structs & Constants
        trait.structs.each do |sname, sdecl|
          target_sname = prefix ? "#{prefix.camelcase}#{sname}" : sname
          renames[sname] = target_sname if target_sname != sname
          unless program.structs.has_key?(target_sname)
            program.structs[target_sname] = StructDecl.new(target_sname, sdecl.fields.dup)
          end
        end

        trait.constants.each do |c|
          target_cname = prefix ? "#{prefix.upcase}_#{c.name}" : c.name
          renames[c.name] = target_cname if target_cname != c.name
          unless program.constants.any? { |ec| ec.name == target_cname }
            program.constants << ConstantDecl.new(target_cname, clone_ast(c.value), c.type_name)
            program.imported_constants.add(target_cname)
          end
        end

        # 3. Uniforms & Varyings
        trait.uniforms.each do |u|
          target_uname = prefix ? "#{prefix}_#{u.name}" : u.name
          renames[u.name] = target_uname if target_uname != u.name
          unless program.uniforms.any? { |eu| eu.name == target_uname }
            program.uniforms << UniformDecl.new(
              name: target_uname,
              type_name: u.type_name,
              default_value: u.default_value ? clone_ast(u.default_value.not_nil!) : nil,
              hints: u.hints.dup,
              group: u.group || group_title,
              subgroup: u.subgroup,
              qualifier: u.qualifier,
              array_size: u.array_size,
              is_var_array: u.is_var_array,
              resource_path: u.resource_path,
              is_packed_array: u.is_packed_array,
              embedded_elements: u.embedded_elements,
              precision: u.precision,
              doc_comment: u.doc_comment,
              set: u.set,
              binding: u.binding
            )
          end
        end

        trait.varyings.each do |v|
          target_vname = prefix ? "#{prefix}_#{v.name}" : v.name
          renames[v.name] = target_vname if target_vname != v.name
          unless program.varyings.any? { |ev| ev.name == target_vname }
            program.varyings << VaryingDecl.new(target_vname, v.type_name, v.qualifier, v.precision)
          end
        end

        # 4. Gradients, Curves & Helper Functions
        trait.gradients.each do |g|
          target_gname = prefix ? "#{prefix}_#{g.name}" : g.name
          renames[g.name] = target_gname if target_gname != g.name
          g_copy = GradientDecl.new(target_gname, g.stops.dup, g.space, g.interp)
          program.gradients << g_copy
          program.functions[target_gname] = GradientsAndCurves.synthesize_gradient_def(g_copy)
          program.imported_functions.add(target_gname)
        end

        trait.curves.each do |cv|
          target_cvname = prefix ? "#{prefix}_#{cv.name}" : cv.name
          renames[cv.name] = target_cvname if target_cvname != cv.name
          cv_copy = CurveDecl.new(target_cvname, cv.points.dup, cv.interp)
          program.curves << cv_copy
          program.functions[target_cvname] = GradientsAndCurves.synthesize_curve_def(cv_copy)
          program.imported_functions.add(target_cvname)
        end

        trait.functions.each do |fname, fdef|
          target_fname = prefix ? "#{prefix}_#{fname}" : fname
          renames[fname] = target_fname if target_fname != fname
          cloned_def = clone_ast(fdef).as(Crystal::Def)
          cloned_def.name = target_fname
          cloned_def.body = apply_renames(cloned_def.body, renames)
          program.functions[target_fname] = cloned_def
          program.imported_functions.add(target_fname)
        end

        protected_names = collect_protected_names(program, renames)

        # 5. Stage Hooks with AST Local-Variable Hygiene
        trait.vertex_hooks.each_with_index do |vhook, h_idx|
          hygienic = rewrite_hook_hygiene(vhook, "_#{slug}_v#{idx}_#{h_idx}", renames, protected_names)
          collected_vertex.concat(flatten_exprs(hygienic))
        end

        trait.fragment_hooks.each_with_index do |fhook, h_idx|
          hygienic = rewrite_hook_hygiene(fhook, "_#{slug}_f#{idx}_#{h_idx}", renames, protected_names)
          collected_fragment.concat(flatten_exprs(hygienic))
        end

        trait.light_hooks.each_with_index do |lhook, h_idx|
          hygienic = rewrite_hook_hygiene(lhook, "_#{slug}_l#{idx}_#{h_idx}", renames, protected_names)
          collected_light.concat(flatten_exprs(hygienic))
        end

        trait.pixel_hooks.each_with_index do |phook, h_idx|
          p_prot = protected_names.dup
          p_prot.add(phook.uv_var)
          p_prot.add(phook.color_var)
          hygienic = rewrite_hook_hygiene(phook.body, "_#{slug}_p#{idx}_#{h_idx}", renames, p_prot)
          collected_pixel << {phook.uv_var, phook.color_var, hygienic}
        end
      end

      append_stage_hooks(program, "vertex", collected_vertex) unless collected_vertex.empty?
      append_stage_hooks(program, "fragment", collected_fragment) unless collected_fragment.empty?
      append_stage_hooks(program, "light", collected_light) unless collected_light.empty?
      fuse_pixel_hooks(program, collected_pixel) unless collected_pixel.empty?
    end

    private def append_stage_hooks(program : ShaderProgram, stage_name : String, hook_stmts : Array(Crystal::ASTNode)) : Void
      if existing = program.functions[stage_name]?
        exprs = flatten_exprs(existing.body)
        # If fragment ends with archetype output (e.g. builtin_COLOR = color), insert before final builtin output
        insert_idx = find_trailing_output_index(exprs)
        if stage_name == "fragment" && insert_idx
          combined = exprs[0...insert_idx] + hook_stmts + exprs[insert_idx..-1]
          program.functions[stage_name] = Crystal::Def.new(stage_name, body: Crystal::Expressions.new(combined))
        else
          exprs.concat(hook_stmts)
          program.functions[stage_name] = Crystal::Def.new(stage_name, body: Crystal::Expressions.new(exprs))
        end
      else
        # Provide sensible default ALBEDO when spatial fragment is created purely from traits
        base_stmts = [] of Crystal::ASTNode
        if stage_name == "fragment" && program.shader_type == ShaderType::Spatial
          base_stmts.concat(flatten_exprs(Crystal::Parser.new("builtin_ALBEDO = vec3(0.85, 0.85, 0.85)").parse))
        end
        base_stmts.concat(hook_stmts)
        program.functions[stage_name] = Crystal::Def.new(stage_name, body: Crystal::Expressions.new(base_stmts))
      end
    end

    private def fuse_pixel_hooks(
      program : ShaderProgram,
      pixel_hooks : Array(Tuple(String, String, Crystal::ASTNode)),
    ) : Void
      if program.target == ShaderTarget::GLSL || program.is_compositor
        fuse_pixel_hooks_glsl(program, pixel_hooks)
      else
        fuse_pixel_hooks_gdshader(program, pixel_hooks)
      end
    end

    private def fuse_pixel_hooks_glsl(
      program : ShaderProgram,
      pixel_hooks : Array(Tuple(String, String, Crystal::ASTNode)),
    ) : Void
      unless program.images.any? { |img| img.name == "color_image" }
        program.images << ImageUniformDecl.new("color_image", "image2D", "rgba16f", set: 0, binding: 0)
      end

      unless program.functions.has_key?("main")
        scaffold = <<-CR
          def main
            coord = ivec2(gl_GlobalInvocationID.xy)
            size = imageSize(color_image)
            if coord.x >= size.x || coord.y >= size.y
              return
            end
            uv = (vec2(float(coord.x), float(coord.y)) + vec2(0.5, 0.5)) / vec2(float(size.x), float(size.y))
            color = imageLoad(color_image, coord)
            imageStore(color_image, coord, color)
          end
        CR
        program.functions["main"] = Crystal::Parser.new(scaffold).parse.as(Crystal::Def)
        program.pixel_stage_vars = {"uv", "color"}
        program.coord_stage_var = "coord"
      end

      host_uv, host_color = program.pixel_stage_vars || {"uv", "color"}
      main_def = program.functions["main"]
      exprs = flatten_exprs(main_def.body)

      bound_stmts = build_bound_pixel_stmts(pixel_hooks, host_uv, host_color)

      store_idx = exprs.rindex do |e|
        e.is_a?(Crystal::Call) && (e.name == "imageStore" || e.name == "image_store")
      end

      if store_idx
        combined = exprs[0...store_idx] + bound_stmts + exprs[store_idx..-1]
        program.functions["main"] = Crystal::Def.new("main", body: Crystal::Expressions.new(combined))
      else
        exprs.concat(bound_stmts)
        program.functions["main"] = Crystal::Def.new("main", body: Crystal::Expressions.new(exprs))
      end
    end

    private def fuse_pixel_hooks_gdshader(
      program : ShaderProgram,
      pixel_hooks : Array(Tuple(String, String, Crystal::ASTNode)),
    ) : Void
      if (vars = program.pixel_stage_vars) && (frag_def = program.functions["fragment"]?)
        host_uv, host_color = vars
        exprs = flatten_exprs(frag_def.body)
        bound_stmts = build_bound_pixel_stmts(pixel_hooks, host_uv, host_color)
        out_idx = find_trailing_output_index(exprs)
        if out_idx
          combined = exprs[0...out_idx] + bound_stmts + exprs[out_idx..-1]
          program.functions["fragment"] = Crystal::Def.new("fragment", body: Crystal::Expressions.new(combined))
        else
          exprs.concat(bound_stmts)
          program.functions["fragment"] = Crystal::Def.new("fragment", body: Crystal::Expressions.new(exprs))
        end
        return
      end

      # Host did not use an archetype: synthesize clean pixel wrapper in fragment
      has_screen_tex = program.uniforms.any? { |u| u.name == "screen_texture" }
      uv_src = has_screen_tex ? "SCREEN_UV" : "UV"
      col_src = if has_screen_tex
                  "texture(screen_texture, __px_uv)"
                elsif program.shader_type == ShaderType::CanvasItem
                  "texture(TEXTURE, __px_uv) * COLOR"
                else
                  "vec4(ALBEDO, ALPHA)"
                end

      exprs = if existing = program.functions["fragment"]?
                flatten_exprs(existing.body)
              else
                [] of Crystal::ASTNode
              end

      # If existing fragment already wrote COLOR, start from COLOR
      if !exprs.empty? && program.shader_type == ShaderType::CanvasItem
        col_src = "COLOR"
      end

      exprs.concat(flatten_exprs(Crystal::Parser.new("__px_uv = #{uv_src}\n__px_color = #{col_src}").parse))
      exprs.concat(build_bound_pixel_stmts(pixel_hooks, "__px_uv", "__px_color"))
      if program.shader_type == ShaderType::Spatial
        exprs.concat(flatten_exprs(Crystal::Parser.new("builtin_ALBEDO = __px_color.rgb\nbuiltin_ALPHA = __px_color.a").parse))
      else
        exprs.concat(flatten_exprs(Crystal::Parser.new("builtin_COLOR = __px_color").parse))
      end

      program.pixel_stage_vars = {"__px_uv", "__px_color"}
      program.functions["fragment"] = Crystal::Def.new("fragment", body: Crystal::Expressions.new(exprs))
    end

    private def build_bound_pixel_stmts(
      pixel_hooks : Array(Tuple(String, String, Crystal::ASTNode)),
      host_uv : String,
      host_color : String,
    ) : Array(Crystal::ASTNode)
      result = [] of Crystal::ASTNode
      pixel_hooks.each do |uv_param, col_param, body|
        param_map = {
          uv_param  => host_uv,
          col_param => host_color,
        }
        mapped = apply_renames(body, param_map)
        result.concat(flatten_exprs(mapped))
      end
      result
    end

    private def find_trailing_output_index(exprs : Array(Crystal::ASTNode)) : Int32?
      return nil if exprs.empty?
      last = exprs.last
      if last.is_a?(Crystal::Assign) && last.target.to_s == "builtin_COLOR"
        return exprs.size - 1
      end
      if exprs.size >= 2 &&
         exprs[-2].is_a?(Crystal::Assign) && exprs[-2].as(Crystal::Assign).target.to_s == "builtin_ALBEDO" &&
         last.is_a?(Crystal::Assign) && last.target.to_s == "builtin_ALPHA"
        return exprs.size - 2
      end
      nil
    end

    private def collect_protected_names(program : ShaderProgram, renames : Hash(String, String)) : Set(String)
      prot = Set(String).new
      SymbolTable::GDSHADER_BUILTINS.each_key { |k| prot.add(k) }
      SymbolTable::GLSL_BUILTINS.each_key { |k| prot.add(k) }
      program.uniforms.each { |u| prot.add(u.name) }
      program.varyings.each { |v| prot.add(v.name) }
      program.constants.each { |c| prot.add(c.name) }
      program.functions.each_key { |f| prot.add(f) }
      program.images.each { |i| prot.add(i.name) }
      program.buffers.each { |b| prot.add(b.instance_name) }
      program.push_constants.each { |p| prot.add(p.instance_name) }
      renames.each do |k, v|
        prot.add(k)
        prot.add(v)
      end
      prot
    end

    private def rewrite_hook_hygiene(
      body : Crystal::ASTNode,
      local_prefix : String,
      symbol_renames : Hash(String, String),
      protected_names : Set(String),
    ) : Crystal::ASTNode
      cloned = clone_ast(body)
      locals = Set(String).new
      collect_local_declarations(cloned, locals, protected_names)

      combined_map = symbol_renames.dup
      locals.each do |lv|
        combined_map[lv] = "#{local_prefix}_#{lv}"
      end

      combined_map.empty? ? cloned : apply_renames(cloned, combined_map)
    end

    private def collect_local_declarations(
      node : Crystal::ASTNode,
      locals : Set(String),
      protected_names : Set(String),
    ) : Void
      case node
      when Crystal::Expressions
        node.expressions.each { |c| collect_local_declarations(c, locals, protected_names) }
      when Crystal::Assign
        if (t = node.target).is_a?(Crystal::Var)
          vname = t.name
          if !vname.starts_with?("builtin_") && !protected_names.includes?(vname) && vname != vname.upcase
            locals.add(vname)
          end
        end
        collect_local_declarations(node.value, locals, protected_names)
      when Crystal::OpAssign
        collect_local_declarations(node.value, locals, protected_names)
      when Crystal::TypeDeclaration
        vname = node.var.to_s
        if !vname.starts_with?("builtin_") && !protected_names.includes?(vname)
          locals.add(vname)
        end
        node.value.try { |v| collect_local_declarations(v, locals, protected_names) }
      when Crystal::Call
        if (blk = node.block)
          blk.args.each do |barg|
            locals.add(barg.name) unless protected_names.includes?(barg.name)
          end
          collect_local_declarations(blk.body, locals, protected_names)
        end
        node.obj.try { |o| collect_local_declarations(o, locals, protected_names) }
        node.args.each { |a| collect_local_declarations(a, locals, protected_names) }
      when Crystal::If
        collect_local_declarations(node.cond, locals, protected_names)
        collect_local_declarations(node.then, locals, protected_names)
        node.else.try { |e| collect_local_declarations(e, locals, protected_names) }
      when Crystal::Unless
        collect_local_declarations(node.cond, locals, protected_names)
        collect_local_declarations(node.then, locals, protected_names)
        node.else.try { |e| collect_local_declarations(e, locals, protected_names) }
      when Crystal::While, Crystal::Until
        collect_local_declarations(node.cond, locals, protected_names)
        collect_local_declarations(node.body, locals, protected_names)
      end
    end

    class IdentifierRenamer < Crystal::Transformer
      def initialize(@map : Hash(String, String))
      end

      def transform(node : Crystal::Var) : Crystal::ASTNode
        if mapped = @map[node.name]?
          Crystal::Var.new(mapped)
        else
          node
        end
      end

      def transform(node : Crystal::TypeDeclaration) : Crystal::ASTNode
        node.value = node.value.try(&.transform(self))
        if (v = node.var).is_a?(Crystal::Var)
          if mapped = @map[v.name]?
            node.var = Crystal::Var.new(mapped)
          end
        end
        node
      end

      def transform(node : Crystal::Path) : Crystal::ASTNode
        if node.names.size == 1 && (mapped = @map[node.names[0]]?)
          Crystal::Path.new([mapped])
        else
          node
        end
      end

      def transform(node : Crystal::Block) : Crystal::ASTNode
        node.args.each do |arg|
          if mapped = @map[arg.name]?
            arg.name = mapped
          end
        end
        node.body = node.body.transform(self)
        node
      end

      def transform(node : Crystal::Call) : Crystal::ASTNode
        node.obj = node.obj.try(&.transform(self))
        node.args = node.args.map(&.transform(self).as(Crystal::ASTNode))
        if node.obj.nil? && (mapped = @map[node.name]?)
          if node.args.empty? && node.block.nil? && node.named_args.nil?
            return Crystal::Var.new(mapped)
          else
            node.name = mapped
          end
        end
        node.block = node.block.try(&.transform(self).as(Crystal::Block))
        node
      end
    end

    private def apply_renames(node : Crystal::ASTNode, map : Hash(String, String)) : Crystal::ASTNode
      return node if map.empty?
      node.transform(IdentifierRenamer.new(map))
    end

    private def clone_ast(node : Crystal::ASTNode) : Crystal::ASTNode
      Crystal::Parser.new(node.to_s).parse
    rescue
      node
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

    private def sanitize_ident(raw : String) : String
      raw.gsub(/[^a-zA-Z0-9_]/, "_").gsub(/_+/, "_").gsub(/^_+|_+$/, "")
    end

    private def extract_ident(node : Crystal::ASTNode) : String
      case node
      when Crystal::SymbolLiteral, Crystal::StringLiteral
        node.value
      when Crystal::Var
        node.name
      when Crystal::Path
        node.names.join("::")
      else
        node.to_s
      end
    end
  end
end
