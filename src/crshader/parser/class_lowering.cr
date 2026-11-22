require "compiler/crystal/syntax"
require "../ast/shader_ast"
require "../ast/types"
require "../transpiler/symbol_table"
require "../std/registry"

module CrShader
  # Lowers Crystal `class` and `struct` declarations (fields, `initialize`, `def self.*`
  # static factories, non-mutating instance methods, and mutating `inout` methods) into
  # standard shader `struct` declarations and tree-shakeable free helper functions across
  # GDShader, GDShaderInc, and Vulkan GLSL 450.
  module ClassLoweringPass
    extend self

    def sanitize_method_name(class_name : String, raw_method : String) : String
      if raw_method.ends_with?('?')
        base = raw_method.rchop
        prefix = (base.starts_with?("is_") || base.starts_with?("has_")) ? "" : "is_"
        "#{class_name}_#{prefix}#{base}"
      elsif raw_method.ends_with?('!')
        "#{class_name}_#{raw_method.rchop}"
      elsif raw_method.ends_with?('=')
        "#{class_name}_set_#{raw_method.rchop}"
      else
        "#{class_name}_#{raw_method}"
      end
    end

    def run!(program : ShaderProgram) : Void
      return if program.classes.empty?

      # 1. Compute direct and transitive `self` mutation across all class methods
      program.classes.each_value do |cls|
        analyze_mutations!(cls)
      end

      # 2. Synthesize custom constructors (`ClassName__new`) and lowered method `Crystal::Def`s
      custom_constructors = Set(String).new
      program.classes.each_value do |cls|
        if needs_custom_constructor?(cls)
          ctor_def = synthesize_constructor(cls)
          program.functions[ctor_def.name] = ctor_def
          program.imported_functions.add(ctor_def.name) if cls.is_imported
          custom_constructors.add(cls.name)
        end

        cls.methods.each_value do |mdecl|
          lowered_def = synthesize_method_def(cls, mdecl)
          program.functions[lowered_def.name] = lowered_def
          program.imported_functions.add(lowered_def.name) if cls.is_imported
        end
      end

      # 3. Rewrite all constructor, static, and instance method call sites across the program
      sym = build_program_symbol_table(program)

      program.constants.each do |c|
        rewriter = CallSiteRewriter.new(program, sym, custom_constructors)
        c.value = c.value.transform(rewriter)
      end

      program.uniforms.each do |u|
        if dv = u.default_value
          rewriter = CallSiteRewriter.new(program, sym, custom_constructors)
          u.default_value = dv.transform(rewriter)
        end
      end

      program.functions.each do |fname, def_node|
        sym.enter_function
        def_node.args.each do |arg|
          raw_t = arg.restriction ? TypeInfo.resolve(arg.restriction.to_s, program.target) : "float"
          clean_t = raw_t.sub(/^(inout|out)\s+/, "")
          sym.register_param(arg.name, clean_t)
        end
        skip_ctor = fname.ends_with?("__new") ? fname.sub(/__new$/, "") : nil
        rewriter = CallSiteRewriter.new(program, sym, custom_constructors, skip_custom_ctor_for: skip_ctor)
        def_node.body = def_node.body.transform(rewriter)
        sym.exit_function
        program.functions[fname] = def_node
      end
    end

    private def needs_custom_constructor?(cls : ClassDecl) : Bool
      !cls.initializer.nil? || cls.fields.any? { |f| !f.default_value.nil? }
    end

    private def analyze_mutations!(cls : ClassDecl) : Void
      cls.methods.each_value do |mdecl|
        next if mdecl.is_static
        scanner = SelfMutationScanner.new
        mdecl.def_node.body.accept(scanner)
        mdecl.mutates_self = scanner.mutates_self
      end

      changed = true
      while changed
        changed = false
        cls.methods.each_value do |mdecl|
          next if mdecl.is_static || mdecl.mutates_self
          call_scanner = SiblingCallScanner.new(cls.methods)
          mdecl.def_node.body.accept(call_scanner)
          if call_scanner.calls_mutating_sibling
            mdecl.mutates_self = true
            changed = true
          end
        end
      end
    end

    private def synthesize_constructor(cls : ClassDecl) : Crystal::Def
      ctor_name = "#{cls.name}__new"
      field_map = {} of String => StructField
      cls.fields.each { |f| field_map[f.name] = f }

      if init = cls.initializer
        clean_args = init.args.map do |arg|
          clean_name = arg.name.empty? ? arg.external_name.sub(/^@/, "") : arg.name
          rest = arg.restriction || field_map[clean_name]?.try { |f| Crystal::Path.new([f.type_name]).as(Crystal::ASTNode) }
          Crystal::Arg.new(clean_name, restriction: rest)
        end

        param_names = Set(String).new
        clean_args.each { |a| param_names.add(a.name) }

        default_ctor_args = cls.fields.map do |f|
          if dv = f.default_value
            clone_ast(dv)
          else
            zero_ast_for_type(f.type_name)
          end
        end

        self_init_call = Crystal::Call.new(Crystal::Path.new([cls.name]), "new", default_ctor_args)
        self_decl = Crystal::TypeDeclaration.new(
          Crystal::Var.new("_self"),
          Crystal::Path.new([cls.name]),
          self_init_call
        )

        # Handle `@field` ivar args in `def initialize(@color : Vec3, ...)`
        # Note: Crystal::Parser already prepends `@color = color` into `init.body`,
        # which `MethodBodyRewriter` converts to `_self.color = color`.
        local_vars = collect_local_vars(init.body)
        rewriter = MethodBodyRewriter.new(cls, is_static: false, shadowed_names: param_names | local_vars)
        rewritten_body = clone_ast(init.body).transform(rewriter)

        stmts = [self_decl.as(Crystal::ASTNode)]
        stmts.concat(flatten_exprs(rewritten_body))
        stmts << Crystal::Var.new("_self").as(Crystal::ASTNode)

        Crystal::Def.new(
          ctor_name,
          args: clean_args,
          body: Crystal::Expressions.new(stmts),
          return_type: Crystal::Path.new([cls.name])
        )
      else
        # Struct/class with field default values and no explicit `initialize`
        clean_args = cls.fields.map do |f|
          Crystal::Arg.new(f.name, restriction: Crystal::Path.new([f.type_name]))
        end
        pass_args = cls.fields.map { |f| Crystal::Var.new(f.name).as(Crystal::ASTNode) }
        body_call = Crystal::Call.new(Crystal::Path.new([cls.name]), "new", pass_args)
        Crystal::Def.new(
          ctor_name,
          args: clean_args,
          body: body_call,
          return_type: Crystal::Path.new([cls.name])
        )
      end
    end

    private def synthesize_method_def(cls : ClassDecl, mdecl : ClassMethodDecl) : Crystal::Def
      orig = mdecl.def_node
      args = [] of Crystal::Arg

      unless mdecl.is_static
        self_type = if mdecl.mutates_self
                      Crystal::Generic.new(Crystal::Path.new(["InOut"]), [Crystal::Path.new([cls.name]).as(Crystal::ASTNode)]).as(Crystal::ASTNode)
                    else
                      Crystal::Path.new([cls.name]).as(Crystal::ASTNode)
                    end
        args << Crystal::Arg.new("_self", restriction: self_type)
      end

      param_names = Set(String).new
      orig.args.each do |arg|
        param_names.add(arg.name)
        args << Crystal::Arg.new(arg.name, restriction: arg.restriction)
      end

      local_vars = collect_local_vars(orig.body)
      rewriter = MethodBodyRewriter.new(cls, is_static: mdecl.is_static, shadowed_names: param_names | local_vars)
      rewritten_body = clone_ast(orig.body).transform(rewriter)

      ret_type = orig.return_type
      if ret_type.nil?
        if mdecl.name.ends_with?('?')
          ret_type = Crystal::Path.new(["Bool"])
        elsif mdecl.name.ends_with?('!') || mdecl.name.ends_with?('=')
          ret_type = Crystal::Path.new(["Void"])
        end
      end

      Crystal::Def.new(
        mdecl.lowered_name,
        args: args,
        body: rewritten_body,
        return_type: ret_type
      )
    end

    private def build_program_symbol_table(program : ShaderProgram) : SymbolTable
      sym = SymbolTable.new(program.target, program.shader_type)
      program.external_structs.each_value do |st|
        sym.register_struct(st.name, st.fields.map { |f| {f.name, f.type_name} })
      end
      program.structs.each_value do |st|
        sym.register_struct(st.name, st.fields.map { |f| {f.name, f.type_name} })
      end
      program.uniforms.each do |u|
        utype = TypeInfo.resolve(u.type_name, program.target)
        arr_str = u.array_size ? "[#{u.array_size}]" : ""
        sym.register_global(u.name, "#{utype}#{arr_str}")
      end
      program.varyings.each { |v| sym.register_global(v.name, v.type_name) }
      program.images.each { |img| sym.register_global(img.name, img.image_type) }
      program.constants.each do |c|
        t = c.type_name || sym.infer_type(c.value)
        sym.register_global(c.name, t)
      end
      program.buffers.each do |b|
        sym.register_global(b.instance_name, b.name)
        b.fields.each do |f|
          ftype = TypeInfo.resolve(f.type_name, program.target)
          sz = f.is_array ? (f.array_size ? "[#{f.array_size}]" : "[]") : ""
          sym.register_global("#{b.instance_name}.#{f.name}", "#{ftype}#{sz}")
        end
      end
      program.push_constants.each do |pc|
        sym.register_global(pc.instance_name, pc.name)
        pc.fields.each do |f|
          ftype = TypeInfo.resolve(f.type_name, program.target)
          sz = f.is_array ? (f.array_size ? "[#{f.array_size}]" : "[]") : ""
          sym.register_global("#{pc.instance_name}.#{f.name}", "#{ftype}#{sz}")
        end
      end

      ["math", "color", "blend", "uv"].each do |mod|
        Std.load_module(mod).each do |d|
          if rt = d.return_type
            sym.register_function(d.name, TypeInfo.resolve(rt.to_s, program.target))
          end
        end
      end
      program.requires.each do |req|
        Std.load_module(req).each do |d|
          if rt = d.return_type
            sym.register_function(d.name, TypeInfo.resolve(rt.to_s, program.target))
          end
        end
      end
      program.external_functions.each do |fname, fret|
        sym.register_function(fname, TypeInfo.resolve(fret, program.target))
      end
      program.functions.each do |fname, fdef|
        if rt = fdef.return_type
          sym.register_function(fname, TypeInfo.resolve(rt.to_s, program.target))
        end
      end
      sym
    end

    # Scans a method body for direct writes to `@ivar` or `self.field`
    class SelfMutationScanner < Crystal::Visitor
      getter mutates_self : Bool = false

      def visit(node : Crystal::Assign) : Bool
        @mutates_self = true if targets_self_ivar?(node.target)
        true
      end

      def visit(node : Crystal::OpAssign) : Bool
        @mutates_self = true if targets_self_ivar?(node.target)
        true
      end

      def visit(node : Crystal::Call) : Bool
        if (obj = node.obj) && node.name.ends_with?('=') && !["==", "!=", "<=", ">=", "==="].includes?(node.name)
          @mutates_self = true if targets_self_ivar?(obj) || obj.is_a?(Crystal::Self)
        end
        true
      end

      def visit(node : Crystal::ASTNode) : Bool
        true
      end

      private def targets_self_ivar?(target : Crystal::ASTNode) : Bool
        case target
        when Crystal::InstanceVar, Crystal::Self
          true
        when Crystal::Call
          if o = target.obj
            targets_self_ivar?(o)
          else
            false
          end
        else
          false
        end
      end
    end

    # Scans for calls to sibling methods on `self` that mutate `self`
    class SiblingCallScanner < Crystal::Visitor
      getter calls_mutating_sibling : Bool = false

      def initialize(@methods : Hash(String, ClassMethodDecl))
      end

      def visit(node : Crystal::Call) : Bool
        if node.obj.nil? || node.obj.is_a?(Crystal::Self)
          if (sib = @methods[node.name]?) && !sib.is_static && sib.mutates_self
            @calls_mutating_sibling = true
          end
        end
        true
      end

      def visit(node : Crystal::ASTNode) : Bool
        true
      end
    end

    # Rewrites `@field`, `self`, bare field getters, and sibling calls inside a class method body
    class MethodBodyRewriter < Crystal::Transformer
      def initialize(
        @cls : ClassDecl,
        @is_static : Bool,
        @shadowed_names : Set(String),
      )
        @field_names = Set(String).new
        @cls.fields.each { |f| @field_names.add(f.name) }
      end

      def transform(node : Crystal::InstanceVar) : Crystal::ASTNode
        return node if @is_static
        fname = node.name.sub(/^@+/, "")
        Crystal::Call.new(Crystal::Var.new("_self"), fname)
      end

      def transform(node : Crystal::Self) : Crystal::ASTNode
        @is_static ? Crystal::Path.new([@cls.name]) : Crystal::Var.new("_self")
      end

      def transform(node : Crystal::Var) : Crystal::ASTNode
        if !@is_static && @field_names.includes?(node.name) && !@shadowed_names.includes?(node.name) && node.name != "_self"
          Crystal::Call.new(Crystal::Var.new("_self"), node.name)
        else
          node
        end
      end

      def transform(node : Crystal::Assign) : Crystal::ASTNode
        val = node.value.transform(self)
        if !@is_static && (ivar = node.target).is_a?(Crystal::InstanceVar)
          fname = ivar.name.sub(/^@+/, "")
          return Crystal::Call.new(Crystal::Var.new("_self"), "#{fname}=", [val])
        end
        target = node.target.transform(self)
        Crystal::Assign.new(target, val)
      end

      def transform(node : Crystal::OpAssign) : Crystal::ASTNode
        val = node.value.transform(self)
        if !@is_static && (ivar = node.target).is_a?(Crystal::InstanceVar)
          fname = ivar.name.sub(/^@+/, "")
          return Crystal::OpAssign.new(Crystal::Call.new(Crystal::Var.new("_self"), fname), node.op, val)
        end
        target = node.target.transform(self)
        Crystal::OpAssign.new(target, node.op, val)
      end

      def transform(node : Crystal::Call) : Crystal::ASTNode
        was_explicit_self = node.obj.is_a?(Crystal::Self)
        node.obj = node.obj.try(&.transform(self))
        node.args = node.args.map(&.transform(self).as(Crystal::ASTNode))
        node.block = node.block.try(&.transform(self).as(Crystal::Block))

        # Unqualified call or `self.foo(...)` inside class method
        if node.obj.nil? || (was_explicit_self && !@is_static)
          # 1. Sibling method call
          if sib = @cls.methods[node.name]?
            filled = ClassLoweringPass.fill_default_args(node.args, sib.def_node.args)
            if sib.is_static
              return Crystal::Call.new(nil, sib.lowered_name, filled)
            elsif !@is_static
              return Crystal::Call.new(nil, sib.lowered_name, [Crystal::Var.new("_self").as(Crystal::ASTNode)] + filled)
            end
          end

          # 2. Bare field getter read (e.g. `power` instead of `@power`)
          if node.obj.nil? && !@is_static && node.args.empty? && node.block.nil? &&
             @field_names.includes?(node.name) && !@shadowed_names.includes?(node.name)
            return Crystal::Call.new(Crystal::Var.new("_self"), node.name)
          end
        end

        node
      end
    end

    # Scope-aware rewriter converting `ClassName.new(...)`, `ClassName.static(...)`,
    # and `instance.method(...)` across all shader stages and helper functions.
    class CallSiteRewriter < Crystal::Transformer
      def initialize(
        @program : ShaderProgram,
        @sym : SymbolTable,
        @custom_constructors : Set(String),
        @skip_custom_ctor_for : String? = nil,
      )
      end

      def transform(node : Crystal::TypeDeclaration) : Crystal::ASTNode
        node.value = node.value.try(&.transform(self))
        resolved_t = TypeInfo.resolve(node.declared_type.to_s, @program.target)
        @sym.mark_variable_declared(node.var.to_s, resolved_t)
        node
      end

      def transform(node : Crystal::Assign) : Crystal::ASTNode
        new_val = node.value.transform(self)
        new_target = node.target.transform(self)
        if new_target.is_a?(Crystal::Var)
          vname = new_target.name
          if !@sym.is_builtin?(vname) && !@sym.variable_declared?(vname)
            inferred = @sym.infer_type(new_val)
            @sym.mark_variable_declared(vname, inferred)
          end
        end
        Crystal::Assign.new(new_target, new_val)
      end

      def transform(node : Crystal::If) : Crystal::ASTNode
        cond = node.cond.transform(self)
        @sym.enter_scope
        then_b = node.then.transform(self)
        @sym.exit_scope
        else_b = if !(en = node.else).is_a?(Crystal::Nop) && en
                   @sym.enter_scope
                   eb = en.transform(self)
                   @sym.exit_scope
                   eb
                 else
                   node.else
                 end
        Crystal::If.new(cond, then_b, else_b)
      end

      def transform(node : Crystal::Call) : Crystal::ASTNode
        # Transform receiver and arguments bottom-up first so chained calls infer accurately
        if blk = node.block
          @sym.enter_scope
          blk.args.each { |ba| @sym.mark_variable_declared(ba.name, "int") }
          node.obj = node.obj.try(&.transform(self))
          node.args = node.args.map(&.transform(self).as(Crystal::ASTNode))
          blk.body = blk.body.transform(self)
          @sym.exit_scope
          return node
        end

        node.obj = node.obj.try(&.transform(self))
        node.args = node.args.map(&.transform(self).as(Crystal::ASTNode))

        if obj = node.obj
          # Case 1: Static or constructor call on ClassName Path (`FresnelRim.new`, `FresnelRim.icy`)
          if obj.is_a?(Crystal::Path)
            cname = obj.names.last
            if cls = @program.classes[cname]?
              if node.name == "new"
                if @custom_constructors.includes?(cname) && @skip_custom_ctor_for != cname
                  filled = if init = cls.initializer
                             ClassLoweringPass.fill_default_args(node.args, init.args)
                           else
                             ClassLoweringPass.fill_field_default_args(node.args, cls.fields)
                           end
                  return Crystal::Call.new(nil, "#{cname}__new", filled)
                end
              elsif (sdecl = cls.methods[node.name]?) && sdecl.is_static
                filled = ClassLoweringPass.fill_default_args(node.args, sdecl.def_node.args)
                return Crystal::Call.new(nil, sdecl.lowered_name, filled)
              end
            end
          end

          # Case 2: Instance method call (`rim.evaluate(NORMAL, VIEW)`, `rim.boost!(1.2)`)
          recv_type = @sym.infer_type(obj)
          if (cls = @program.classes[recv_type]?) && (mdecl = cls.methods[node.name]?) && !mdecl.is_static
            filled = ClassLoweringPass.fill_default_args(node.args, mdecl.def_node.args)
            return Crystal::Call.new(nil, mdecl.lowered_name, [obj] + filled)
          end
        end

        node
      end
    end

    def fill_default_args(call_args : Array(Crystal::ASTNode), def_args : Array(Crystal::Arg)) : Array(Crystal::ASTNode)
      result = call_args.dup
      if result.size < def_args.size
        (result.size...def_args.size).each do |idx|
          if dv = def_args[idx].default_value
            result << clone_ast(dv)
          end
        end
      end
      result
    end

    def fill_field_default_args(call_args : Array(Crystal::ASTNode), fields : Array(StructField)) : Array(Crystal::ASTNode)
      result = call_args.dup
      if result.size < fields.size
        (result.size...fields.size).each do |idx|
          if dv = fields[idx].default_value
            result << clone_ast(dv)
          else
            result << zero_ast_for_type(fields[idx].type_name)
          end
        end
      end
      result
    end

    private def collect_local_vars(node : Crystal::ASTNode) : Set(String)
      collector = LocalVarNameScanner.new
      node.accept(collector)
      collector.names
    end

    class LocalVarNameScanner < Crystal::Visitor
      getter names : Set(String) = Set(String).new

      def visit(node : Crystal::Assign) : Bool
        if (t = node.target).is_a?(Crystal::Var)
          @names.add(t.name)
        end
        true
      end

      def visit(node : Crystal::TypeDeclaration) : Bool
        if (v = node.var).is_a?(Crystal::Var)
          @names.add(v.name)
        end
        true
      end

      def visit(node : Crystal::Call) : Bool
        node.block.try &.args.each { |a| @names.add(a.name) }
        true
      end

      def visit(node : Crystal::ASTNode) : Bool
        true
      end
    end

    private def zero_ast_for_type(type_name : String) : Crystal::ASTNode
      norm = TypeInfo.normalize(type_name)
      code = case norm
             when "Float32", "Float", "Float64" then "0.0"
             when "Int32", "Int"                then "0"
             when "UInt32", "UInt"              then "0_u32"
             when "Bool"                        then "false"
             when "Vec2"                        then "vec2(0.0, 0.0)"
             when "Vec3"                        then "vec3(0.0, 0.0, 0.0)"
             when "Vec4", "Color"               then "vec4(0.0, 0.0, 0.0, 1.0)"
             when "IVec2"                       then "ivec2(0, 0)"
             when "IVec3"                       then "ivec3(0, 0, 0)"
             when "IVec4"                       then "ivec4(0, 0, 0, 0)"
             when "Mat2"                        then "mat2(1.0)"
             when "Mat3"                        then "mat3(1.0)"
             when "Mat4"                        then "mat4(1.0)"
             else                                    "0.0"
             end
      Crystal::Parser.new(code).parse
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
  end
end
