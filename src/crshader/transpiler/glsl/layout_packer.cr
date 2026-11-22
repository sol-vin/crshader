require "../../ast/shader_ast"
require "../../ast/types"

module CrShader
  # Deterministic std430 / std140 byte-offset calculator for Vulkan / RenderingDevice
  # push constants and uniform buffer objects (UBOs).
  module GLSLLayoutPacker
    enum PackingKind
      None
      PushConstant
      UniformBuffer
    end

    record FieldSlot,
      name : String,
      crystal_type : String,
      glsl_type : String,
      byte_offset : Int32,
      byte_size : Int32,
      alignment : Int32,
      is_array : Bool = false,
      array_len : Int32 = 1

    record PackedLayout,
      kind : PackingKind,
      fields : Array(FieldSlot),
      total_bytes : Int32

    OPAQUE_PREFIXES = [
      "sampler", "isampler", "usampler",
      "image", "iimage", "uimage",
      "subpassInput",
    ]

    def self.opaque_uniform?(u : UniformDecl) : Bool
      resolved = TypeInfo.resolve(u.type_name, ShaderTarget::GLSL)
      OPAQUE_PREFIXES.any? { |p| resolved.starts_with?(p) }
    end

    def self.split_uniforms(uniforms : Array(UniformDecl)) : Tuple(Array(UniformDecl), Array(UniformDecl))
      opaques = [] of UniformDecl
      values = [] of UniformDecl
      uniforms.each do |u|
        if opaque_uniform?(u)
          opaques << u
        else
          values << u
        end
      end
      {opaques, values}
    end

    # Computes deterministic layout for non-opaque uniforms in GLSL 450.
    # Uses `push_constant` (std430) when no manual push_constant exists, no arrays are present,
    # and total size <= 128 bytes; otherwise falls back to `set = 1, binding = 0` UBO (std140).
    def self.compute_layout(program : ShaderProgram) : PackedLayout
      _, values = split_uniforms(program.uniforms)
      if values.empty?
        return PackedLayout.new(PackingKind::None, [] of FieldSlot, 0)
      end

      can_try_push = program.push_constants.empty? && values.none?(&.is_array?)
      if can_try_push
        std430_fields, std430_size = pack_fields(values, std140: false)
        if std430_size <= 128
          return PackedLayout.new(PackingKind::PushConstant, std430_fields, std430_size)
        end
      end

      std140_fields, std140_size = pack_fields(values, std140: true)
      PackedLayout.new(PackingKind::UniformBuffer, std140_fields, std140_size)
    end

    def self.pack_fields(uniforms : Array(UniformDecl), std140 : Bool) : Tuple(Array(FieldSlot), Int32)
      slots = [] of FieldSlot
      offset = 0

      uniforms.each do |u|
        glsl_t = TypeInfo.resolve(u.type_name, ShaderTarget::GLSL)
        elem_size, elem_align = type_metrics(glsl_t)
        arr_len = u.array_size.try(&.to_i?) || 1
        is_arr = u.is_array?

        if is_arr
          stride = std140 ? align_up(elem_size, 16) : align_up(elem_size, elem_align)
          align = std140 ? Math.max(elem_align, 16) : elem_align
          offset = align_up(offset, align)
          byte_size = stride * Math.max(arr_len, 1)
          slots << FieldSlot.new(u.name, u.type_name, glsl_t, offset, byte_size, align, true, arr_len)
          offset += byte_size
        else
          offset = align_up(offset, elem_align)
          slots << FieldSlot.new(u.name, u.type_name, glsl_t, offset, elem_size, elem_align, false, 1)
          offset += elem_size
        end
      end

      # Align total block size to 16 bytes for RenderingDevice push_constant / UBO requirements
      total = align_up(offset, 16)
      {slots, total}
    end

    def self.type_metrics(glsl_type : String) : Tuple(Int32, Int32)
      case glsl_type
      when "float", "int", "uint", "bool"
        {4, 4}
      when "vec2", "ivec2", "uvec2", "bvec2"
        {8, 8}
      when "vec3", "ivec3", "uvec3", "bvec3"
        {12, 16}
      when "vec4", "ivec4", "uvec4", "bvec4"
        {16, 16}
      when "mat2"
        {16, 8}
      when "mat3"
        {48, 16}
      when "mat4"
        {64, 16}
      else
        {16, 16}
      end
    end

    def self.align_up(value : Int32, alignment : Int32) : Int32
      return value if alignment <= 1
      ((value + alignment - 1) // alignment) * alignment
    end
  end
end
