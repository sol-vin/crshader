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

    STAGES = ["vertex", "fragment", "light", "start", "process", "sky", "fog", "main"]

    def process(program : ShaderProgram) : Array(Crystal::Def)
      @reachable_names.clear
      @alive_functions.clear

      # 1. Roots are the shader stage entry points
      root_defs = [] of Crystal::Def
      STAGES.each do |entry|
        if d = program.functions[entry]?
          root_defs << d
        end
      end

      # Also consider any custom non-entry functions defined directly in the main file as potential roots
      program.functions.each do |name, d|
        unless STAGES.includes?(name)
          # Collect references from it
          collect_references(d.body)
        end
      end

      # Traverse from roots
      root_defs.each do |d|
        collect_references(d.body)
      end

      # Build ordered list of alive helper functions
      alive_list = [] of Crystal::Def
      @reachable_names.each do |func_name|
        if def_node = @pool[func_name]?
          alive_list << def_node
        end
      end

      alive_list
    end

    private def collect_references(node : Crystal::ASTNode)
      case node
      when Crystal::Call
        func_name = node.name
        if @pool.has_key?(func_name) && !@reachable_names.includes?(func_name)
          @reachable_names.add(func_name)
          # Recursively collect dependencies of this helper function
          helper_def = @pool[func_name]
          collect_references(helper_def.body)
        end

        node.obj.try { |o| collect_references(o) }
        node.args.each { |arg| collect_references(arg) }

      when Crystal::Expressions
        node.expressions.each { |child| collect_references(child) }

      when Crystal::Assign, Crystal::OpAssign
        collect_references(node.target)
        collect_references(node.value)

      when Crystal::If
        collect_references(node.cond)
        collect_references(node.then)
        node.else.try { |e| collect_references(e) }

      when Crystal::While
        collect_references(node.cond)
        collect_references(node.body)

      when Crystal::BinaryOp
        collect_references(node.left)
        collect_references(node.right)

      when Crystal::Not
        collect_references(node.exp)

      when Crystal::Return
        node.exp.try { |e| collect_references(e) }
      end
    end
  end
end
