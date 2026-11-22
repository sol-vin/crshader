require "./emitter"

module CrShader
  # Emits reusable Godot 4 `.gdshaderinc` include headers from `.crshader` modules.
  # Strips `shader_type`, `render_mode`, and processor entry points, wraps in an
  # `#ifndef` include guard, closes any trailing `group_uniforms;`, and emits all
  # public constants, structs, uniform groups, varyings, and helper functions.
  class GDShaderIncEmitter < GDShaderEmitter
    getter guard_name : String

    def initialize(
      io : IO,
      program : ShaderProgram,
      filename : String? = nil,
      symbol_table : SymbolTable = SymbolTable.new(ShaderTarget::GDShaderInc),
    )
      super(io, program, symbol_table, ShaderTarget::GDShaderInc)
      base = filename ? File.basename(filename, File.extname(filename)) : "CRSHADER_SHARED"
      sanitized = base.upcase.gsub(/[^A-Z0-9_]/, "_")
      sanitized = "CRSHADER_#{sanitized}" if sanitized.empty? || sanitized[0].ascii_number?
      @guard_name = "#{sanitized}_GDSHADERINC"
    end

    def emit(
      helper_functions : Array(Crystal::Def) = [] of Crystal::Def,
      reachable_identifiers : Set(String)? = nil,
    )
      helper_functions.each do |h|
        if rt = h.return_type
          @symbol_table.register_function(h.name, TypeInfo.resolve(rt.to_s, @target))
        end
      end

      @io << "#ifndef #{@guard_name}\n"
      @io << "#define #{@guard_name}\n\n"

      emit_preprocessor
      emit_default_precisions
      emit_constants(reachable_identifiers)
      emit_structs(reachable_identifiers)
      emit_uniforms(close_trailing_group: true)
      emit_varyings
      emit_helpers(helper_functions)

      # Emit any remaining non-imported, non-stage functions
      @program.functions.each do |name, def_node|
        next if ALL_STAGES.includes?(name) || name == "main"
        next if @program.imported_functions.includes?(name)
        next if @emitted_functions.includes?(name)
        emit_function(def_node)
        @emitted_functions.add(name)
      end

      @io << "#endif // #{@guard_name}\n"
    end
  end
end
