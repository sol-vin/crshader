require "compiler/crystal/syntax"
require "../ast/types"
require "./symbol_table"

module CrShader
  abstract class BaseVisitor < Crystal::Visitor
    property io : IO
    property target : ShaderTarget
    property symbol_table : SymbolTable
    property indent_level : Int32 = 0

    def initialize(@io : IO, @target : ShaderTarget, @symbol_table : SymbolTable)
    end

    property current_return_type : String? = nil

    def emit_indent
      @io << ("\t" * @indent_level)
    end

    def indent(&block)
      @indent_level += 1
      yield
      @indent_level -= 1
    end

    def visit(node : Crystal::ASTNode)
      true
    end

    def emit_block_body(node : Crystal::ASTNode, is_function_body : Bool = false)
      if node.is_a?(Crystal::Expressions)
        last_idx = node.expressions.size - 1
        node.expressions.each_with_index do |child, idx|
          next if child.is_a?(Crystal::Nop)
          emit_indent
          is_last = (idx == last_idx)
          should_return = is_function_body && is_last && @current_return_type && @current_return_type != "void" && can_auto_return?(child)
          @io << "return " if should_return
          child.accept(self)
          if needs_semicolon?(child)
            @io << ";\n"
          else
            @io << "\n"
          end
        end
      elsif !node.is_a?(Crystal::Nop)
        emit_indent
        should_return = is_function_body && @current_return_type && @current_return_type != "void" && can_auto_return?(node)
        @io << "return " if should_return
        node.accept(self)
        if needs_semicolon?(node)
          @io << ";\n"
        else
          @io << "\n"
        end
      end
    end

    private def can_auto_return?(node : Crystal::ASTNode) : Bool
      case node
      when Crystal::Return, Crystal::Assign, Crystal::OpAssign, Crystal::If, Crystal::While, Crystal::Until
        false
      else
        true
      end
    end

    def visit(node : Crystal::Expressions)
      if node.expressions.size == 1
        node.expressions.first.accept(self)
      else
        emit_block_body(node)
      end
      false
    end

    property in_expression : Bool = false

    def visit(node : Crystal::Assign)
      # Check target: Var or Path or Swizzle Call
      target_node = node.target
      value_node = node.value

      if target_node.is_a?(Crystal::Var)
        var_name = target_node.name
        is_builtin = @symbol_table.is_builtin?(var_name)
        resolved_name = @symbol_table.resolve_builtin_name(var_name)

        if !is_builtin && !@symbol_table.variable_declared?(var_name)
          # First assignment of a local variable: emit type declaration!
          inferred = @symbol_table.infer_type(value_node)
          @symbol_table.mark_variable_declared(var_name, inferred)
          @io << "#{inferred} #{var_name} = "
        else
          @io << "#{resolved_name} = "
        end
      else
        target_node.accept(self)
        @io << " = "
      end

      old_expr = @in_expression
      @in_expression = true
      value_node.accept(self)
      @in_expression = old_expr
      false
    end

    def visit(node : Crystal::OpAssign)
      node.target.accept(self)
      @io << " #{node.op}= "
      old_expr = @in_expression
      @in_expression = true
      node.value.accept(self)
      @in_expression = old_expr
      false
    end

    def visit(node : Crystal::TypeDeclaration)
      # e.g. pos : Vec3 = Vec3.new(...)
      var_name = node.var.to_s
      resolved_type = TypeInfo.resolve(node.declared_type.to_s, @target)
      @symbol_table.mark_variable_declared(var_name, resolved_type)

      @io << "#{resolved_type} #{var_name}"
      if val = node.value
        @io << " = "
        old_expr = @in_expression
        @in_expression = true
        val.accept(self)
        @in_expression = old_expr
      end
      false
    end

    def visit(node : Crystal::If)
      if @in_expression
        @io << "(("
        node.cond.accept(self)
        @io << ") ? ("
        node.then.accept(self)
        @io << ") : ("
        if else_node = node.else
          else_node.accept(self)
        else
          @io << "0.0"
        end
        @io << "))"
        return false
      end

      @io << "if ("
      node.cond.accept(self)
      @io << ") {\n"
      indent do
        emit_block_body(node.then)
      end
      emit_indent
      @io << "}"

      if else_node = node.else
        if else_node.is_a?(Crystal::If)
          @io << " else "
          else_node.accept(self)
        elsif !else_node.is_a?(Crystal::Nop)
          @io << " else {\n"
          indent do
            emit_block_body(else_node)
          end
          emit_indent
          @io << "}"
        end
      end
      false
    end

    def visit(node : Crystal::Case)
      if cond = node.cond
        @io << "switch ("
        cond.accept(self)
        @io << ") {\n"
        indent do
          node.whens.each do |w|
            w.conds.each do |c|
              emit_indent
              @io << "case "
              c.accept(self)
              @io << ": {\n"
              indent do
                emit_block_body(w.body)
                emit_indent
                @io << "break;\n"
              end
              emit_indent
              @io << "}\n"
            end
          end
          if else_node = node.else
            emit_indent
            @io << "default: {\n"
            indent do
              emit_block_body(else_node)
            end
            emit_indent
            @io << "}\n"
          end
        end
        emit_indent
        @io << "}"
      end
      false
    end

    def visit(node : Crystal::For)
      var_name = node.var.to_s
      if (exp = node.exp).is_a?(Crystal::RangeLiteral)
        cmp_op = exp.exclusive? ? "<" : "<="
        @symbol_table.mark_variable_declared(var_name, "int")
        @io << "for (int #{var_name} = "
        exp.from.accept(self)
        @io << "; #{var_name} #{cmp_op} "
        exp.to.accept(self)
        @io << "; #{var_name}++) {\n"
        indent do
          emit_block_body(node.body)
        end
        emit_indent
        @io << "}"
      end
      false
    end

    def visit(node : Crystal::Unless)
      @io << "if (!("
      node.cond.accept(self)
      @io << ")) {\n"
      indent do
        emit_block_body(node.then)
      end
      emit_indent
      @io << "}"
      false
    end

    def visit(node : Crystal::While)
      @io << "while ("
      node.cond.accept(self)
      @io << ") {\n"
      indent do
        emit_block_body(node.body)
      end
      emit_indent
      @io << "}"
      false
    end

    def visit(node : Crystal::Until)
      @io << "while (!("
      node.cond.accept(self)
      @io << ")) {\n"
      indent do
        emit_block_body(node.body)
      end
      emit_indent
      @io << "}"
      false
    end

    def visit(node : Crystal::Return)
      @io << "return"
      if exp = node.exp
        @io << " "
        exp.accept(self)
      end
      false
    end

    def visit(node : Crystal::Break)
      @io << "break"
      false
    end

    def visit(node : Crystal::Next)
      @io << "continue"
      false
    end

    def visit(node : Crystal::And)
      @io << "("
      node.left.accept(self)
      @io << " && "
      node.right.accept(self)
      @io << ")"
      false
    end

    def visit(node : Crystal::Or)
      @io << "("
      node.left.accept(self)
      @io << " || "
      node.right.accept(self)
      @io << ")"
      false
    end

    def visit(node : Crystal::Not)
      @io << "!("
      node.exp.accept(self)
      @io << ")"
      false
    end

    def visit(node : Crystal::Var)
      name = node.name
      clean_name = name.sub(/^builtin_/, "")
      if @symbol_table.is_builtin?(name)
        @io << @symbol_table.resolve_builtin_name(name)
      else
        @io << clean_name
      end
      false
    end

    def visit(node : Crystal::Path)
      @io << node.names.join("::")
      false
    end

    def visit(node : Crystal::NumberLiteral)
      val = node.value
      if node.kind == :f32 || node.kind == :f64 || (val.includes?('.') && !val.ends_with?('.'))
        @io << val
        @io << ".0" unless val.includes?('.')
      else
        @io << val
      end
      false
    end

    def visit(node : Crystal::BoolLiteral)
      @io << (node.value ? "true" : "false")
      false
    end

    def visit(node : Crystal::StringLiteral)
      @io << '"' << node.value << '"'
      false
    end

    def visit(node : Crystal::RangeLiteral)
      node.from.accept(self)
      @io << (node.exclusive? ? "..." : "..")
      node.to.accept(self)
      false
    end

    def visit(node : Crystal::Call)
      # 1. Constructor call: Type.new(...)
      if node.name == "new" && (obj = node.obj)
        target_type = TypeInfo.resolve(obj.to_s, @target)
        @io << "#{target_type}("
        emit_args(node.args)
        # If Color.new with 3 args, supply 1.0 alpha default
        if obj.to_s == "Color" && node.args.size == 3
          @io << ", 1.0"
        end
        @io << ")"
        return false
      end

      # Unwrap parenthesized object if needed (e.g. (0...10))
      actual_obj = if (o = node.obj).is_a?(Crystal::Expressions) && o.as(Crystal::Expressions).expressions.size == 1
                     o.as(Crystal::Expressions).expressions.first
                   else
                     node.obj
                   end

      # 2. Check for (a...b).each do |i|
      if node.name == "each" && (obj = actual_obj).is_a?(Crystal::RangeLiteral) && (block = node.block)
        var_name = block.args.first?.try(&.name) || "i"
        cmp_op = obj.exclusive? ? "<" : "<="
        @symbol_table.mark_variable_declared(var_name, "int")
        @io << "for (int #{var_name} = "
        obj.from.accept(self)
        @io << "; #{var_name} #{cmp_op} "
        obj.to.accept(self)
        @io << "; #{var_name}++) {\n"
        indent do
          emit_block_body(block.body)
        end
        emit_indent
        @io << "}"
        return false
      end

      # 3. Check for count.times do |i|
      if node.name == "times" && (obj = node.obj) && (block = node.block)
        var_name = block.args.first?.try(&.name) || "i"
        @symbol_table.mark_variable_declared(var_name, "int")
        @io << "for (int #{var_name} = 0; #{var_name} < "
        obj.accept(self)
        @io << "; #{var_name}++) {\n"
        indent do
          emit_block_body(block.body)
        end
        emit_indent
        @io << "}"
        return false
      end

      # 4. Operator or method call on object: e.g. val.clamp(min, max), a + b, val.xy, tex.sample(uv)
      if obj = node.obj
        handle_method_call(obj, node)
        return false
      end

      # 5. Direct function call: e.g. color(0.1, 0.1, 0.1), vec3(...), sin(...), dot(...)
      handle_direct_call(node)
      false
    end

    private def handle_method_call(obj : Crystal::ASTNode, node : Crystal::Call)
      name = node.name

      # Unary operators: -val, +val, ~val
      if ["-", "+", "~"].includes?(name) && node.args.empty?
        @io << name
        obj.accept(self)
        return
      end

      # Binary arithmetic and comparison operators
      if ["+", "-", "*", "/", "%", "==", "!=", "<", "<=", ">", ">=", "&", "|", "^", "<<", ">>"].includes?(name) && node.args.size == 1
        @io << "("
        obj.accept(self)
        @io << " #{name} "
        node.args[0].accept(self)
        @io << ")"
        return
      end

      # Power operator `**`
      if name == "**" && node.args.size == 1
        @io << "pow("
        obj.accept(self)
        @io << ", "
        node.args[0].accept(self)
        @io << ")"
        return
      end

      # Array index `arr[i]`
      if name == "[]" && !node.args.empty?
        obj.accept(self)
        @io << "["
        node.args[0].accept(self)
        @io << "]"
        return
      end

      # Array index assign `arr[i] = val`
      if name == "[]=" && node.args.size >= 2
        obj.accept(self)
        @io << "["
        node.args[0].accept(self)
        @io << "] = "
        node.args[1].accept(self)
        return
      end

      case name
      when "sample"
        func = "texture"
        @io << "#{func}("
        obj.accept(self)
        if !node.args.empty?
          @io << ", "
          emit_args(node.args)
        end
        @io << ")"
        return
      when "sample_lod"
        func = "textureLod"
        @io << "#{func}("
        obj.accept(self)
        if !node.args.empty?
          @io << ", "
          emit_args(node.args)
        end
        @io << ")"
        return
      when "size"
        func = "textureSize"
        @io << "#{func}("
        obj.accept(self)
        if !node.args.empty?
          @io << ", "
          emit_args(node.args)
        else
          @io << ", 0"
        end
        @io << ")"
        return
      when "fetch"
        func = "texelFetch"
        @io << "#{func}("
        obj.accept(self)
        if !node.args.empty?
          @io << ", "
          emit_args(node.args)
        end
        @io << ")"
        return
      when "clamp", "mix", "step", "smoothstep"
        @io << "#{name}("
        obj.accept(self)
        if !node.args.empty?
          @io << ", "
          emit_args(node.args)
        end
        @io << ")"
      when "length", "normalize", "abs", "floor", "ceil", "fract", "sin", "cos", "tan", "sqrt", "exp", "sign"
        @io << "#{name}("
        obj.accept(self)
        @io << ")"
      when "dot", "cross", "distance", "reflect", "refract", "pow", "min", "max"
        @io << "#{name}("
        obj.accept(self)
        @io << ", "
        emit_args(node.args)
        @io << ")"
      when "discard"
        @io << "discard"
      else
        # Swizzle or field access (e.g. pos.xyz, color.rgb, uv.x)
        obj.accept(self)
        @io << ".#{name}"
        if !node.args.empty?
          @io << "("
          emit_args(node.args)
          @io << ")"
        end
      end
    end

    private def handle_direct_call(node : Crystal::Call)
      name = node.name
      clean_name = name.sub(/^builtin_/, "")

      # Check if this call is actually an identifier/variable reference without parens (e.g. gl_GlobalInvocationID, input_buffer)
      if node.args.empty? && (@symbol_table.is_builtin?(name) || @symbol_table.global_symbols.has_key?(clean_name) || @symbol_table.declared_vars_in_scope.includes?(clean_name))
        @io << @symbol_table.resolve_builtin_name(name)
        return
      end

      # Barrier and synchronization builtins for compute
      case name
      when "barrier"
        @io << "barrier()"
        return
      when "group_memory_barrier"
        @io << "groupMemoryBarrier()"
        return
      when "memory_barrier_shared"
        @io << "memoryBarrierShared()"
        return
      when "memory_barrier_buffer"
        @io << "memoryBarrierBuffer()"
        return
      end

      # Constructor helpers: color(...) -> vec4(...)
      target_func = case name
                    when "color"
                      @target == ShaderTarget::GDShader ? "vec4" : "vec4"
                    when "vec2", "vec3", "vec4", "mat2", "mat3", "mat4", "ivec2", "ivec3", "ivec4", "uvec2", "uvec3", "uvec4"
                      name
                    when "rand"
                      # GDShader has no built-in zero-arg rand(), but our stdlib or custom expression can provide one
                      # If 0 args in GDShader, map to fract(sin(dot(UV, vec2(12.9898, 78.233))) * 43758.5453)
                      # or pass through if defined in stdlib!
                      @symbol_table.referenced_functions.add(name)
                      name
                    when "discard"
                      @io << "discard"
                      return
                    else
                      @symbol_table.referenced_functions.add(name)
                      name
                    end

      @io << "#{target_func}("
      emit_args(node.args)
      # If color() helper had 3 arguments, append 1.0 alpha
      if name == "color" && node.args.size == 3
        @io << ", 1.0"
      end
      @io << ")"
    end

    private def emit_args(args : Array(Crystal::ASTNode))
      args.each_with_index do |arg, idx|
        @io << ", " if idx > 0
        arg.accept(self)
      end
    end

    private def needs_semicolon?(node : Crystal::ASTNode) : Bool
      case node
      when Crystal::If, Crystal::Unless, Crystal::While, Crystal::Until, Crystal::Def
        false
      else
        true
      end
    end
  end
end
