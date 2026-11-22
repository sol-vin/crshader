require "compiler/crystal/syntax"
require "../ast/types"
require "../parser/error_formatter"

module CrShader
  class MacroEngine
    property macros : Hash(String, Crystal::Macro) = {} of String => Crystal::Macro
    property constants : Hash(String, Crystal::ASTNode) = {} of String => Crystal::ASTNode
    property features : Hash(String, Crystal::ASTNode) = {} of String => Crystal::ASTNode

    def initialize(target : ShaderTarget = ShaderTarget::GDShader, shader_type : ShaderType = ShaderType::Spatial)
      configure_target(target, shader_type)
    end

    def configure_target(target : ShaderTarget, shader_type : ShaderType = ShaderType::Spatial) : Void
      @constants["TARGET"] = Crystal::StringLiteral.new(target.to_target_keyword)
      @constants["SHADER_TYPE"] = Crystal::StringLiteral.new(shader_type.to_gdshader_keyword)
      @constants["IS_GLSL"] = Crystal::BoolLiteral.new(target == ShaderTarget::GLSL)
      @constants["IS_GDSHADER"] = Crystal::BoolLiteral.new(target.gdshader_like?)
      @constants["IS_GDSHADERINC"] = Crystal::BoolLiteral.new(target == ShaderTarget::GDShaderInc)
    end

    # Register a compile-time constant for macro evaluation
    def register_constant(name : String, value : Crystal::ASTNode) : Void
      @constants[name] = value
    end

    # Register a specialization feature and its `FEATURE_<NAME>` macro constant
    def register_feature(name : String, value : Crystal::ASTNode) : Void
      clean = name.strip
      @features[clean] = value
      @constants["FEATURE_#{clean.upcase}"] = value
    end

    # Register a macro definition
    def register_macro(macro_node : Crystal::Macro)
      @macros[macro_node.name] = macro_node
    end

    # Expand all macros in an AST node recursively
    def expand(node : Crystal::ASTNode) : Crystal::ASTNode
      transformer = MacroExpanderTransformer.new(@macros, @constants, @features)
      transformed = node.transform(transformer)
      transformed
    end

    class MacroExpanderTransformer < Crystal::Transformer
      property macros : Hash(String, Crystal::Macro)
      property constants : Hash(String, Crystal::ASTNode)
      property features : Hash(String, Crystal::ASTNode)

      def initialize(@macros, @constants, @features = {} of String => Crystal::ASTNode)
      end

      # Intercept Expressions to unroll loops, conditionals, feature guards, and macro calls
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
            if (exp.name == "when_feature" || exp.name == "unless_feature") && exp.obj.nil? && exp.block
              new_expressions.concat(expand_feature_guard(exp))
            elsif @macros.has_key?(exp.name) && exp.obj.nil?
              # Expand macro call
              expanded = expand_macro_call(exp)
              new_expressions.concat(expanded)
            else
              transformed_child = exp.transform(self)
              new_expressions << transformed_child unless transformed_child.is_a?(Crystal::Nop)
            end
          else
            transformed_child = exp.transform(self)
            new_expressions << transformed_child unless transformed_child.is_a?(Crystal::Nop)
          end
        end

        node.expressions = new_expressions
        node
      end

      # Handle single macro call or feature guard expression
      def transform(node : Crystal::Call) : Crystal::ASTNode
        if (node.name == "when_feature" || node.name == "unless_feature") && node.obj.nil? && node.block
          expanded = expand_feature_guard(node)
          if expanded.empty?
            Crystal::Nop.new
          elsif expanded.size == 1
            expanded.first
          else
            Crystal::Expressions.new(expanded)
          end
        elsif @macros.has_key?(node.name) && node.obj.nil?
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

      private def expand_feature_guard(call : Crystal::Call) : Array(Crystal::ASTNode)
        matched = evaluate_feature_guard(call)
        matched = !matched if call.name == "unless_feature"
        return [] of Crystal::ASTNode unless matched
        blk = call.block
        return [] of Crystal::ASTNode unless blk

        transformed_body = blk.body.transform(self)
        if transformed_body.is_a?(Crystal::Expressions)
          transformed_body.expressions
        elsif transformed_body.is_a?(Crystal::Nop)
          [] of Crystal::ASTNode
        else
          [transformed_body]
        end
      end

      private def lookup_feature_node(raw_name : String) : Crystal::ASTNode?
        @features[raw_name]? || @constants["FEATURE_#{raw_name.upcase}"]? || @constants[raw_name]?
      end

      private def feature_node_truthy?(val : Crystal::ASTNode?) : Bool
        case val
        when Nil
          false
        when Crystal::BoolLiteral
          val.value
        when Crystal::NumberLiteral
          val.value != "0" && val.value != "0.0"
        when Crystal::StringLiteral
          v = val.value.downcase
          !v.empty? && v != "false" && v != "0" && v != "off" && v != "none"
        when Crystal::SymbolLiteral
          v = val.value.downcase
          !v.empty? && v != "false" && v != "0" && v != "off" && v != "none"
        else
          true
        end
      end

      private def evaluate_feature_guard(call : Crystal::Call) : Bool
        return false if call.args.empty?
        fname = node_to_literal_str(call.args[0])
        actual_node = lookup_feature_node(fname)

        if call.args.size == 1
          return feature_node_truthy?(actual_node)
        end

        expected = call.args[1]
        actual_str = actual_node ? node_to_literal_str(actual_node) : "false"
        case expected
        when Crystal::BoolLiteral
          feature_node_truthy?(actual_node) == expected.value
        when Crystal::ArrayLiteral
          expected.elements.any? { |el| node_to_literal_str(el) == actual_str }
        else
          node_to_literal_str(expected) == actual_str
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
        when Crystal::Path
          pname = node.names.join("::")
          if val = env[pname]?
            node_to_literal_str(val)
          elsif const_val = @constants[pname]?
            node_to_literal_str(const_val)
          else
            pname
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
                       else          nil
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
        when Crystal::Path
          pname = node.names.join("::")
          val = env[pname]? || @constants[pname]?
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
            else           true
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
          if bound = env[node.name]? || @constants[node.name]?
            resolve_collection(bound, env)
          elsif count = evaluate_to_int(node, env)
            (0...count).map { |i| Crystal::NumberLiteral.new(i).as(Crystal::ASTNode) }
          else
            [] of Crystal::ASTNode
          end
        when Crystal::Path
          pname = node.names.join("::")
          if bound = env[pname]? || @constants[pname]?
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
          if bound = env[node.name]? || @constants[node.name]?
            evaluate_to_int(bound, env)
          else
            nil
          end
        when Crystal::Path
          pname = node.names.join("::")
          if bound = env[pname]? || @constants[pname]?
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
