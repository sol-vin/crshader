require "compiler/crystal/syntax"
require "../ast/shader_ast"

module CrShader
  class TreeShaker
    property pool : Hash(String, Crystal::Def) = {} of String => Crystal::Def
    property alive_functions : Hash(String, Crystal::Def) = {} of String => Crystal::Def
    property reachable_names : Set(String) = Set(String).new

    def initialize
    end

    def add_library_def(def_node : Crystal::Def)
      @pool[def_node.name] = def_node
    end

    STAGES = ["vertex", "fragment", "light", "start", "process", "collide", "sky", "fog", "main"]

    def process(program : ShaderProgram) : Array(Crystal::Def)
      @reachable_names.clear
      @alive_functions.clear
      ordered_helpers = [] of Crystal::Def

      # 1. Non-entry custom functions defined in main file
      program.functions.each do |name, d|
        unless STAGES.includes?(name)
          collect_references(d.body, ordered_helpers)
        end
      end

      # 2. Traverse from shader stage entry points
      STAGES.each do |entry|
        if d = program.functions[entry]?
          collect_references(d.body, ordered_helpers)
        end
      end

      ordered_helpers.uniq { |d| d.name }
    end

    private def collect_references(node : Crystal::ASTNode, ordered_helpers : Array(Crystal::Def))
      case node
      when Crystal::Call
        func_name = node.name
        if @pool.has_key?(func_name) && !@reachable_names.includes?(func_name)
          @reachable_names.add(func_name)
          helper_def = @pool[func_name]
          # Post-order: visit dependencies FIRST
          collect_references(helper_def.body, ordered_helpers)
          # Then add callee before caller!
          ordered_helpers << helper_def
        end

        node.obj.try { |o| collect_references(o, ordered_helpers) }
        node.args.each { |arg| collect_references(arg, ordered_helpers) }

      when Crystal::Expressions
        node.expressions.each { |child| collect_references(child, ordered_helpers) }

      when Crystal::Assign, Crystal::OpAssign
        collect_references(node.target, ordered_helpers)
        collect_references(node.value, ordered_helpers)

      when Crystal::If
        collect_references(node.cond, ordered_helpers)
        collect_references(node.then, ordered_helpers)
        node.else.try { |e| collect_references(e, ordered_helpers) }

      when Crystal::While
        collect_references(node.cond, ordered_helpers)
        collect_references(node.body, ordered_helpers)

      when Crystal::BinaryOp
        collect_references(node.left, ordered_helpers)
        collect_references(node.right, ordered_helpers)

      when Crystal::Not
        collect_references(node.exp, ordered_helpers)

      when Crystal::Return
        node.exp.try { |e| collect_references(e, ordered_helpers) }
      end
    end
  end
end
