require "compiler/crystal/syntax"
require "../parser/error_formatter"

module CrShader
  class MacroEngine
    property macros : Hash(String, Crystal::Macro) = {} of String => Crystal::Macro
    property constants : Hash(String, Crystal::ASTNode) = {} of String => Crystal::ASTNode

    def initialize
    end

    # Register a macro definition
    def register_macro(macro_node : Crystal::Macro)
      @macros[macro_node.name] = macro_node
    end

    # Expand all macros in an AST node recursively
    def expand(node : Crystal::ASTNode) : Crystal::ASTNode
      transformer = MacroExpanderTransformer.new(@macros, @constants)
      transformed = node.transform(transformer)
      transformed
    end

    class MacroExpanderTransformer < Crystal::Transformer
      property macros : Hash(String, Crystal::Macro)
      property constants : Hash(String, Crystal::ASTNode)

      def initialize(@macros, @constants)
      end

      # Intercept Expressions to unroll loops, conditionals, and macro calls
      def transform(node : Crystal::Expressions) : Crystal::ASTNode
        new_expressions = [] of Crystal::ASTNode

        node.expressions.each do |exp|
          case exp
          when Crystal::Macro
            # Register macro
            @macros[exp.name] = exp
            # Do not emit macro definition into AST expressions
          when Crystal::MacroFor
            expanded = expand_macro_for(exp, {} of String => Crystal::ASTNode)
            new_expressions.concat(expanded)
          when Crystal::MacroIf
            expanded = expand_macro_if(exp, {} of String => Crystal::ASTNode)
            new_expressions.concat(expanded)
          when Crystal::Call
            if @macros.has_key?(exp.name) && exp.obj.nil?
              # Expand macro call
              expanded = expand_macro_call(exp)
              new_expressions.concat(expanded)
            else
              new_expressions << exp.transform(self)
            end
          else
            new_expressions << exp.transform(self)
          end
        end

        node.expressions = new_expressions
        node
      end

      # Handle single macro call expression
      def transform(node : Crystal::Call) : Crystal::ASTNode
        if @macros.has_key?(node.name) && node.obj.nil?
          expanded = expand_macro_call(node)
          if expanded.size == 1
            expanded.first
          else
            Crystal::Expressions.new(expanded)
          end
        else
          super
        end
      end

      # Handle Def body transformation
      def transform(node : Crystal::Def) : Crystal::ASTNode
        node.body = node.body.transform(self)
        node
      end

      # Expand a call to a registered macro
      def expand_macro_call(call : Crystal::Call) : Array(Crystal::ASTNode)
        macro_def = @macros[call.name]

        # Bind macro arguments
        env = {} of String => Crystal::ASTNode
        macro_def.args.each_with_index do |arg, idx|
          if idx < call.args.size
            env[arg.name] = call.args[idx]
          elsif default_val = arg.default_value
            env[arg.name] = default_val
          end
        end

        # Render macro body to string
        body_text = render_macro_body(macro_def.body, env)
        parse_expanded_snippet(body_text)
      end

      # Expand a MacroFor node
      def expand_macro_for(node : Crystal::MacroFor, env : Hash(String, Crystal::ASTNode)) : Array(Crystal::ASTNode)
        var_name = node.vars.first.name
        elements = resolve_collection(node.exp, env)
        results = [] of Crystal::ASTNode

        elements.each do |elem|
          loop_env = env.dup
          loop_env[var_name] = elem
          body_text = render_macro_body(node.body, loop_env)
          parsed = parse_expanded_snippet(body_text)
          results.concat(parsed)
        end

        results
      end

      # Expand a MacroIf node
      def expand_macro_if(node : Crystal::MacroIf, env : Hash(String, Crystal::ASTNode)) : Array(Crystal::ASTNode)
        cond_val = evaluate_condition(node.cond, env)
        target_body = cond_val ? node.then : node.else

        if target_body
          body_text = render_macro_body(target_body, env)
          parse_expanded_snippet(body_text)
        else
          [] of Crystal::ASTNode
        end
      end

      # Render a macro AST subtree to string with environment bindings
      private def render_macro_body(node : Crystal::ASTNode, env : Hash(String, Crystal::ASTNode)) : String
        String.build do |io|
          render_node_to_text(node, env, io)
        end
      end

      private def render_node_to_text(node : Crystal::ASTNode, env : Hash(String, Crystal::ASTNode), io : IO)
        case node
        when Crystal::MacroLiteral
          io << node.value
        when Crystal::MacroExpression
          evaluated = evaluate_expression(node.exp, env)
          io << evaluated
        when Crystal::MacroFor
          var_name = node.vars.first.name
          elements = resolve_collection(node.exp, env)
          elements.each do |elem|
            loop_env = env.dup
            loop_env[var_name] = elem
            render_node_to_text(node.body, loop_env, io)
          end
        when Crystal::MacroIf
          cond_val = evaluate_condition(node.cond, env)
          branch = cond_val ? node.then : node.else
          if branch
            render_node_to_text(branch, env, io)
          end
        when Crystal::Expressions
          node.expressions.each do |child|
            render_node_to_text(child, env, io)
          end
        else
          # Fallback
          io << node.to_s
        end
      end

      private def evaluate_expression(node : Crystal::ASTNode, env : Hash(String, Crystal::ASTNode)) : String
        case node
        when Crystal::Var
          if val = env[node.name]?
            node_to_literal_str(val)
          elsif const_val = @constants[node.name]?
            node_to_literal_str(const_val)
          else
            node.name
          end
        when Crystal::NumberLiteral
          node.value
        when Crystal::StringLiteral
          node.value
        when Crystal::SymbolLiteral
          node.value
        when Crystal::And
          left = evaluate_condition(node.left, env)
          right = evaluate_condition(node.right, env)
          (left && right) ? "true" : "false"
        when Crystal::Or
          left = evaluate_condition(node.left, env)
          right = evaluate_condition(node.right, env)
          (left || right) ? "true" : "false"
        when Crystal::Call
          if (obj = node.obj) && node.args.size == 1
            left = evaluate_expression(obj, env)
            right = evaluate_expression(node.args[0], env)
            op = node.name
            if left_num = left.to_f64?
              if right_num = right.to_f64?
                calc = case op
                       when "+" then left_num + right_num
                       when "-" then left_num - right_num
                       when "*" then left_num * right_num
                       when "/" then right_num != 0 ? left_num / right_num : 0.0
                       else nil
                       end
                if calc
                  return calc % 1 == 0 ? calc.to_i64.to_s : calc.to_s
                end
              end
            end
            "#{left} #{op} #{right}"
          else
            node.to_s
          end
        else
          node.to_s
        end
      end

      private def evaluate_condition(node : Crystal::ASTNode, env : Hash(String, Crystal::ASTNode)) : Bool
        case node
        when Crystal::BoolLiteral
          node.value
        when Crystal::Var
          val = env[node.name]? || @constants[node.name]?
          if val.is_a?(Crystal::BoolLiteral)
            val.value
          elsif val.nil?
            false
          else
            true
          end
        when Crystal::Not
          !evaluate_condition(node.exp, env)
        when Crystal::And
          evaluate_condition(node.left, env) && evaluate_condition(node.right, env)
        when Crystal::Or
          evaluate_condition(node.left, env) || evaluate_condition(node.right, env)
        when Crystal::Call
          if (obj = node.obj) && node.args.size == 1
            left = evaluate_expression(obj, env)
            right = evaluate_expression(node.args[0], env)
            case node.name
            when "==" then left == right
            when "!=" then left != right
            when ">"  then (left.to_f64? || 0.0) > (right.to_f64? || 0.0)
            when ">=" then (left.to_f64? || 0.0) >= (right.to_f64? || 0.0)
            when "<"  then (left.to_f64? || 0.0) < (right.to_f64? || 0.0)
            when "<=" then (left.to_f64? || 0.0) <= (right.to_f64? || 0.0)
            else true
            end
          else
            true
          end
        else
          true
        end
      end

      private def resolve_collection(node : Crystal::ASTNode, env : Hash(String, Crystal::ASTNode)) : Array(Crystal::ASTNode)
        case node
        when Crystal::RangeLiteral
          from = evaluate_to_int(node.from, env) || 0
          to = evaluate_to_int(node.to, env) || 0
          exclusive = node.exclusive?
          range = exclusive ? (from...to) : (from..to)
          range.map { |i| Crystal::NumberLiteral.new(i).as(Crystal::ASTNode) }
        when Crystal::ArrayLiteral
          node.elements.map { |elem| elem.as(Crystal::ASTNode) }
        when Crystal::Var
          if bound = env[node.name]?
            resolve_collection(bound, env)
          elsif count = evaluate_to_int(node, env)
            (0...count).map { |i| Crystal::NumberLiteral.new(i).as(Crystal::ASTNode) }
          else
            [] of Crystal::ASTNode
          end
        when Crystal::NumberLiteral
          count = node.value.to_i
          (0...count).map { |i| Crystal::NumberLiteral.new(i).as(Crystal::ASTNode) }
        else
          [] of Crystal::ASTNode
        end
      end

      private def evaluate_to_int(node : Crystal::ASTNode, env : Hash(String, Crystal::ASTNode)) : Int32?
        case node
        when Crystal::NumberLiteral
          node.value.to_i?
        when Crystal::Var
          if bound = env[node.name]?
            evaluate_to_int(bound, env)
          else
            nil
          end
        else
          nil
        end
      end

      private def node_to_literal_str(node : Crystal::ASTNode) : String
        case node
        when Crystal::NumberLiteral
          node.value
        when Crystal::StringLiteral
          node.value
        when Crystal::SymbolLiteral
          node.value
        when Crystal::Var
          node.name
        else
          node.to_s
        end
      end

      private def parse_expanded_snippet(snippet : String) : Array(Crystal::ASTNode)
        trimmed = snippet.strip
        return [] of Crystal::ASTNode if trimmed.empty?

        # Try parsing directly first
        begin
          parsed = Crystal::Parser.new(trimmed).parse
          if parsed.is_a?(Crystal::Expressions)
            return parsed.expressions.map { |child| child.transform(self).as(Crystal::ASTNode) }
          else
            return [parsed.transform(self).as(Crystal::ASTNode)]
          end
        rescue
          # If direct parse fails (e.g. self-referencing variable assignment like `total = total + 0`),
          # wrap snippet inside a scoped method with pre-bound dummy parameter defaults
          begin
            var_names = trimmed.scan(/\b([a-z_][a-z0-9_]*)\b/).map(&.[1]).uniq.reject do |n|
              ["def", "end", "if", "else", "elsif", "while", "until", "for", "in", "true", "false", "nil", "return"].includes?(n)
            end
            params = var_names.map { |v| "#{v} = nil" }.join(", ")
            wrapped = "def __scope(#{params})\n#{trimmed}\nend"
            parsed_def = Crystal::Parser.new(wrapped).parse
            if parsed_def.is_a?(Crystal::Def)
              body = parsed_def.body
              if body.is_a?(Crystal::Expressions)
                return body.expressions.map { |child| child.transform(self).as(Crystal::ASTNode) }
              elsif !body.is_a?(Crystal::Nop)
                return [body.transform(self).as(Crystal::ASTNode)]
              end
            end
          rescue
            [] of Crystal::ASTNode
          end
        end

        [] of Crystal::ASTNode
      end
    end
  end
end
