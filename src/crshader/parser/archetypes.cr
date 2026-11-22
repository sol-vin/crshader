require "compiler/crystal/syntax"
require "../ast/shader_ast"

module CrShader
  module Archetypes
    extend self

    DECLARATION_CALLS = Set{
      "shader_type", "render_mode", "setup_gdshader", "require",
      "group", "uniform_group", "subgroup", "uniform_subgroup",
      "generate_node", "node_generator", "export_node",
      "uniform", "property", "export", "instance_uniform", "global_uniform",
      "sampler", "record", "constant_decl", "const",
      "feature", "shader_trait", "use_trait", "gradient", "curve",
      "varying", "flat_varying", "smooth_varying",
      "include", "gd_include", "define", "undefine", "undef", "pragma",
      "default_precision", "precision",
    }

    STAGE_BLOCK_CALLS = Set{
      "vertex", "fragment", "light", "start", "process", "collide", "sky", "fog", "stage",
    }

    def archetype_call?(name : String) : Bool
      case name
      when "sprite_effect", "screen_effect", "ui_effect", "surface_material"
        true
      else
        false
      end
    end

    def process(call : Crystal::Call, parser : DslParser) : Void
      case call.name
      when "sprite_effect"
        process_sprite_effect(call, parser)
      when "screen_effect"
        process_screen_effect(call, parser)
      when "ui_effect"
        process_ui_effect(call, parser)
      when "surface_material"
        process_surface_material(call, parser)
      end
    end

    private def process_sprite_effect(call : Crystal::Call, parser : DslParser) : Void
      prog = parser.program
      prog.shader_type = ShaderType::CanvasItem

      call.named_args.try &.each do |narg|
        case narg.name
        when "unshaded"
          add_render_mode(prog, "unshaded") if narg.value.to_s == "true"
        when "blend"
          add_render_mode(prog, "blend_#{ident_str(narg.value)}")
        end
      end

      blk = call.block
      uv_var = blk.try(&.args[0]?.try(&.name)) || "uv"
      color_var = blk.try(&.args[1]?.try(&.name)) || "color"
      px_var = blk.try(&.args[2]?.try(&.name))

      body_stmts = extract_and_hoist(blk.try(&.body), parser)

      preamble_lines = [
        "#{uv_var} = UV",
        "#{color_var} = texture(TEXTURE, #{uv_var}) * COLOR",
      ]
      preamble_lines << "#{px_var} = TEXTURE_PIXEL_SIZE" if px_var

      prog.pixel_stage_vars = {uv_var, color_var}
      frag_exprs = parse_statements(preamble_lines.join("\n"))
      frag_exprs.concat(bind_trailing_value(body_stmts, color_var))

      unless assigns_builtin?(body_stmts, "COLOR")
        frag_exprs.concat(parse_statements("builtin_COLOR = #{color_var}"))
      end

      prog.functions["fragment"] = Crystal::Def.new("fragment", body: Crystal::Expressions.new(frag_exprs))
    end

    private def process_screen_effect(call : Crystal::Call, parser : DslParser) : Void
      prog = parser.program
      mode = "canvas"
      wants_depth = false

      if first = call.args.first?
        mode = ident_str(first).downcase
      end

      call.named_args.try &.each do |narg|
        case narg.name
        when "mode"
          mode = ident_str(narg.value).downcase
        when "depth", "needs_depth"
          wants_depth = (narg.value.to_s == "true")
        end
      end

      is_spatial = (mode == "spatial" || mode == "3d" || wants_depth)
      if is_spatial
        prog.shader_type = ShaderType::Spatial
        ["unshaded", "cull_disabled", "depth_test_disabled", "fog_disabled"].each { |rm| add_render_mode(prog, rm) }
      else
        prog.shader_type = ShaderType::CanvasItem
        add_render_mode(prog, "unshaded")
      end

      unless prog.uniforms.any? { |u| u.name == "screen_texture" }
        prog.uniforms << UniformDecl.new(
          name: "screen_texture",
          type_name: "Sampler2D",
          hints: ["hint_screen_texture", "repeat_disable", "filter_linear_mipmap"]
        )
      end

      if wants_depth && !prog.uniforms.any? { |u| u.name == "depth_texture" }
        prog.uniforms << UniformDecl.new(
          name: "depth_texture",
          type_name: "Sampler2D",
          hints: ["hint_depth_texture", "repeat_disable", "filter_nearest"]
        )
      end

      if is_spatial && !prog.functions.has_key?("vertex")
        v_exprs = parse_statements("builtin_POSITION = vec4(VERTEX.xy, 1.0, 1.0)")
        prog.functions["vertex"] = Crystal::Def.new("vertex", body: Crystal::Expressions.new(v_exprs))
      end

      blk = call.block
      uv_var = blk.try(&.args[0]?.try(&.name)) || "uv"
      color_var = blk.try(&.args[1]?.try(&.name)) || "color"

      body_stmts = extract_and_hoist(blk.try(&.body), parser)
      prog.pixel_stage_vars = {uv_var, color_var}

      frag_exprs = parse_statements("#{uv_var} = SCREEN_UV\n#{color_var} = texture(screen_texture, #{uv_var})")
      frag_exprs.concat(bind_trailing_value(body_stmts, color_var))

      if is_spatial
        unless assigns_builtin?(body_stmts, "ALBEDO")
          frag_exprs.concat(parse_statements("builtin_ALBEDO = #{color_var}.rgb\nbuiltin_ALPHA = #{color_var}.a"))
        end
      else
        unless assigns_builtin?(body_stmts, "COLOR")
          frag_exprs.concat(parse_statements("builtin_COLOR = #{color_var}"))
        end
      end

      prog.functions["fragment"] = Crystal::Def.new("fragment", body: Crystal::Expressions.new(frag_exprs))
    end

    private def process_ui_effect(call : Crystal::Call, parser : DslParser) : Void
      prog = parser.program
      prog.shader_type = ShaderType::CanvasItem

      call.named_args.try &.each do |narg|
        case narg.name
        when "unshaded"
          add_render_mode(prog, "unshaded") if narg.value.to_s == "true"
        when "blend"
          add_render_mode(prog, "blend_#{ident_str(narg.value)}")
        end
      end

      blk = call.block
      arg_count = blk.try(&.args.size) || 0
      uv_var, centered_var, color_var = case arg_count
                                        when 0
                                          {"uv", "centered_uv", "color"}
                                        when 1
                                          {"__ui_uv", blk.not_nil!.args[0].name, "color"}
                                        when 2
                                          {blk.not_nil!.args[0].name, blk.not_nil!.args[1].name, "color"}
                                        else
                                          {blk.not_nil!.args[0].name, blk.not_nil!.args[1].name, blk.not_nil!.args[2].name}
                                        end

      body_stmts = extract_and_hoist(blk.try(&.body), parser)
      prog.pixel_stage_vars = {uv_var, color_var}

      preamble = <<-CR
        #{uv_var} = UV
        __duv_x = length(vec2(dFdx(#{uv_var}.x), dFdy(#{uv_var}.x)))
        __duv_y = length(vec2(dFdx(#{uv_var}.y), dFdy(#{uv_var}.y)))
        __ui_aspect = (__duv_x > 0.000001 && __duv_y > 0.000001) ? (__duv_y / __duv_x) : 1.0
        #{centered_var} = (#{uv_var} - vec2(0.5, 0.5)) * vec2(__ui_aspect, 1.0)
        #{color_var} = texture(TEXTURE, #{uv_var}) * COLOR
      CR

      frag_exprs = parse_statements(preamble)
      frag_exprs.concat(bind_trailing_value(body_stmts, color_var))

      unless assigns_builtin?(body_stmts, "COLOR")
        frag_exprs.concat(parse_statements("builtin_COLOR = #{color_var}"))
      end

      prog.functions["fragment"] = Crystal::Def.new("fragment", body: Crystal::Expressions.new(frag_exprs))
    end

    private def process_surface_material(call : Crystal::Call, parser : DslParser) : Void
      prog = parser.program
      prog.shader_type = ShaderType::Spatial

      preset = call.args.first?.try { |a| ident_str(a).downcase } || "pbr"
      call.named_args.try &.each do |narg|
        if narg.name == "preset" || narg.name == "shading"
          preset = ident_str(narg.value).downcase
        end
      end

      modes = case preset
              when "toon", "cel"
                ["cull_back", "diffuse_toon", "specular_toon"]
              when "unshaded", "flat"
                ["cull_back", "unshaded"]
              when "glass", "transparent"
                ["blend_mix", "depth_prepass_alpha", "cull_back", "diffuse_burley", "specular_schlick_ggx"]
              when "foliage", "two_sided", "vegetation"
                ["cull_disabled", "depth_prepass_alpha", "diffuse_burley", "specular_schlick_ggx"]
              else
                ["cull_back", "diffuse_burley", "specular_schlick_ggx"]
              end
      modes.each { |rm| add_render_mode(prog, rm) }

      if blk = call.block
        direct_frag_stmts = extract_and_hoist(blk.body, parser, allow_stage_blocks: true)
        unless direct_frag_stmts.empty?
          if existing = prog.functions["fragment"]?
            merged = flatten_exprs(existing.body)
            merged.concat(direct_frag_stmts)
            prog.functions["fragment"] = Crystal::Def.new("fragment", body: Crystal::Expressions.new(merged))
          else
            prog.functions["fragment"] = Crystal::Def.new("fragment", body: Crystal::Expressions.new(direct_frag_stmts))
          end
        end
      end
    end

    private def extract_and_hoist(
      body : Crystal::ASTNode?,
      parser : DslParser,
      allow_stage_blocks : Bool = false,
    ) : Array(Crystal::ASTNode)
      return [] of Crystal::ASTNode unless body
      stmts = flatten_exprs(body)
      remaining = [] of Crystal::ASTNode

      stmts.each do |stmt|
        case stmt
        when Crystal::Nop
          next
        when Crystal::Require, Crystal::ClassDef, Crystal::Def
          parser.process_hoisted_node(stmt)
        when Crystal::Assign
          raw_target = stmt.target.to_s
          if raw_target.starts_with?("__const_") || stmt.target.is_a?(Crystal::Path)
            parser.process_hoisted_node(stmt)
          else
            remaining << stmt
          end
        when Crystal::Call
          if DECLARATION_CALLS.includes?(stmt.name) && stmt.obj.nil?
            parser.process_hoisted_node(stmt)
          elsif allow_stage_blocks && STAGE_BLOCK_CALLS.includes?(stmt.name) && stmt.obj.nil? && stmt.block
            parser.process_hoisted_node(stmt)
          else
            remaining << stmt
          end
        else
          remaining << stmt
        end
      end

      remaining
    end

    private def bind_trailing_value(stmts : Array(Crystal::ASTNode), color_var : String) : Array(Crystal::ASTNode)
      return stmts if stmts.empty?
      result = stmts.dup
      last = result.last
      if value_expression?(last) && !(last.is_a?(Crystal::Var) && last.name == color_var)
        result[result.size - 1] = Crystal::Assign.new(Crystal::Var.new(color_var), last)
      end
      result
    end

    private def value_expression?(node : Crystal::ASTNode) : Bool
      case node
      when Crystal::Assign, Crystal::OpAssign, Crystal::TypeDeclaration,
           Crystal::If, Crystal::Unless, Crystal::While, Crystal::Until,
           Crystal::Case, Crystal::Return, Crystal::Break, Crystal::Next, Crystal::Nop
        false
      when Crystal::Call
        return false if node.obj.nil? && ["discard", "inspect", "barrier", "imageStore", "image_store"].includes?(node.name)
        return false if (node.name == "each" || node.name == "times") && node.block
        true
      else
        true
      end
    end

    private def assigns_builtin?(stmts : Array(Crystal::ASTNode), builtin_name : String) : Bool
      target_name = "builtin_#{builtin_name}"
      stmts.any? { |s| contains_assign_to?(s, target_name) }
    end

    private def contains_assign_to?(node : Crystal::ASTNode, target_name : String) : Bool
      case node
      when Crystal::Assign
        node.target.to_s == target_name
      when Crystal::OpAssign
        node.target.to_s == target_name
      when Crystal::Expressions
        node.expressions.any? { |c| contains_assign_to?(c, target_name) }
      when Crystal::If
        contains_assign_to?(node.then, target_name) || (node.else ? contains_assign_to?(node.else.not_nil!, target_name) : false)
      when Crystal::Unless
        contains_assign_to?(node.then, target_name) || (node.else ? contains_assign_to?(node.else.not_nil!, target_name) : false)
      else
        false
      end
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

    private def parse_statements(code : String) : Array(Crystal::ASTNode)
      parsed = Crystal::Parser.new(code).parse
      flatten_exprs(parsed)
    end

    private def add_render_mode(prog : ShaderProgram, mode : String) : Void
      prog.render_modes << mode unless prog.render_modes.includes?(mode)
    end

    private def ident_str(node : Crystal::ASTNode) : String
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
