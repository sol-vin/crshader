require "compiler/crystal/syntax"
require "./types"

module CrShader
  enum UniformQualifier
    Default
    Instance
    Global
  end

  class UniformDecl
    property name : String
    property type_name : String
    property default_value : Crystal::ASTNode?
    property hints : Array(String)
    property group : String?
    property subgroup : String?
    property qualifier : UniformQualifier
    property array_size : String?
    property is_var_array : Bool
    property resource_path : String?
    property is_packed_array : Bool
    property embedded_elements : Array(Crystal::ASTNode)?
    property precision : String?
    property doc_comment : String?
    property set : Int32?
    property binding : Int32?

    def initialize(
      @name : String,
      @type_name : String,
      @default_value : Crystal::ASTNode? = nil,
      @hints : Array(String) = [] of String,
      @group : String? = nil,
      @subgroup : String? = nil,
      @qualifier : UniformQualifier = UniformQualifier::Default,
      @array_size : String? = nil,
      @is_var_array : Bool = false,
      @resource_path : String? = nil,
      @is_packed_array : Bool = false,
      @embedded_elements : Array(Crystal::ASTNode)? = nil,
      @precision : String? = nil,
      @doc_comment : String? = nil,
      @set : Int32? = nil,
      @binding : Int32? = nil,
    )
    end

    def is_array? : Bool
      !@array_size.nil? || @is_var_array || @is_packed_array
    end
  end

  class VaryingDecl
    property name : String
    property type_name : String
    property qualifier : String? # "flat", "smooth"
    property precision : String? # "lowp", "mediump", "highp"

    def initialize(@name : String, @type_name : String, @qualifier : String? = nil, @precision : String? = nil)
    end
  end

  class ConstantDecl
    property name : String
    property type_name : String?
    property value : Crystal::ASTNode

    def initialize(@name : String, @value : Crystal::ASTNode, @type_name : String? = nil)
    end
  end

  class StructField
    property name : String
    property type_name : String

    def initialize(@name : String, @type_name : String)
    end
  end

  class StructDecl
    property name : String
    property fields : Array(StructField)

    def initialize(@name : String, @fields : Array(StructField) = [] of StructField)
    end
  end

  class BufferField
    property name : String
    property type_name : String
    property is_array : Bool
    property array_size : String?

    def initialize(@name : String, @type_name : String, @is_array : Bool = false, @array_size : String? = nil)
    end
  end

  class BufferDecl
    property name : String
    property instance_name : String
    property set : Int32
    property binding : Int32
    property std : String
    property restrict : Bool
    property readonly : Bool
    property fields : Array(BufferField)

    def initialize(
      @name : String,
      @instance_name : String,
      @set : Int32 = 0,
      @binding : Int32 = 0,
      @std : String = "std430",
      @restrict : Bool = false,
      @readonly : Bool = false,
      @fields : Array(BufferField) = [] of BufferField,
    )
    end
  end

  class PushConstantDecl
    property name : String
    property instance_name : String
    property fields : Array(BufferField)

    def initialize(@name : String, @instance_name : String, @fields : Array(BufferField) = [] of BufferField)
    end
  end

  class SharedMemoryDecl
    property name : String
    property type_name : String
    property size : String

    def initialize(@name : String, @type_name : String, @size : String)
    end
  end

  class ImageUniformDecl
    property name : String
    property image_type : String
    property format : String
    property set : Int32
    property binding : Int32
    property writeonly : Bool
    property readonly : Bool
    property restrict : Bool

    def initialize(
      @name : String,
      @image_type : String = "image2D",
      @format : String = "rgba32f",
      @set : Int32 = 0,
      @binding : Int32 = 0,
      @writeonly : Bool = false,
      @readonly : Bool = false,
      @restrict : Bool = false,
    )
    end
  end

  struct ComputeLayout
    property x : Int32 = 8
    property y : Int32 = 8
    property z : Int32 = 1

    def initialize(@x : Int32 = 8, @y : Int32 = 8, @z : Int32 = 1)
    end
  end

  alias FeatureValue = Bool | Int32 | String | Symbol

  enum FeatureKind
    Bool
    Enum
    Int
  end

  class FeatureDecl
    property name : String
    property macro_name : String
    property kind : FeatureKind
    property default_value : String
    property active_value : String
    property options : Array(String)
    property doc_comment : String?

    def initialize(
      @name : String,
      @kind : FeatureKind,
      @default_value : String,
      @active_value : String? = nil,
      @options : Array(String) = [] of String,
      @doc_comment : String? = nil,
    )
      @macro_name = "FEATURE_#{@name.upcase}"
      @active_value = @active_value || @default_value
    end
  end

  struct GradientStop
    property pos : Float32
    property r : Float32
    property g : Float32
    property b : Float32
    property a : Float32

    def initialize(@pos : Float32, @r : Float32, @g : Float32, @b : Float32, @a : Float32 = 1.0_f32)
    end
  end

  class GradientDecl
    property name : String
    property stops : Array(GradientStop)
    property space : String
    property interp : String

    def initialize(
      @name : String,
      @stops : Array(GradientStop),
      @space : String = "srgb",
      @interp : String = "linear",
    )
    end
  end

  struct CurvePoint
    property pos : Float32
    property value : Float32

    def initialize(@pos : Float32, @value : Float32)
    end
  end

  class CurveDecl
    property name : String
    property points : Array(CurvePoint)
    property interp : String

    def initialize(
      @name : String,
      @points : Array(CurvePoint),
      @interp : String = "linear",
    )
    end
  end

  record TraitPixelHook, uv_var : String, color_var : String, body : Crystal::ASTNode

  class TraitDecl
    property name : String
    property requires : Set(String) = Set(String).new
    property features : Array(FeatureDecl) = [] of FeatureDecl
    property uniforms : Array(UniformDecl) = [] of UniformDecl
    property varyings : Array(VaryingDecl) = [] of VaryingDecl
    property constants : Array(ConstantDecl) = [] of ConstantDecl
    property structs : Hash(String, StructDecl) = {} of String => StructDecl
    property functions : Hash(String, Crystal::Def) = {} of String => Crystal::Def
    property gradients : Array(GradientDecl) = [] of GradientDecl
    property curves : Array(CurveDecl) = [] of CurveDecl
    property vertex_hooks : Array(Crystal::ASTNode) = [] of Crystal::ASTNode
    property fragment_hooks : Array(Crystal::ASTNode) = [] of Crystal::ASTNode
    property light_hooks : Array(Crystal::ASTNode) = [] of Crystal::ASTNode
    property pixel_hooks : Array(TraitPixelHook) = [] of TraitPixelHook

    def initialize(@name : String)
    end
  end

  record TraitUse, path_or_name : String, prefix : String? = nil
  record InspectProbe, label : String, capture_var : String, glsl_type : String

  class ShaderProgram
    property target : ShaderTarget = ShaderTarget::GDShader
    property shader_type : ShaderType = ShaderType::Spatial
    property render_modes : Array(String) = [] of String
    property setup_gdshader : Bool = false
    property features : Array(FeatureDecl) = [] of FeatureDecl
    property gradients : Array(GradientDecl) = [] of GradientDecl
    property curves : Array(CurveDecl) = [] of CurveDecl
    property traits : Hash(String, TraitDecl) = {} of String => TraitDecl
    property trait_uses : Array(TraitUse) = [] of TraitUse
    property inspect_probes : Array(InspectProbe) = [] of InspectProbe
    property pixel_stage_vars : Tuple(String, String)? = nil
    property coord_stage_var : String? = nil
    property uniforms : Array(UniformDecl) = [] of UniformDecl
    property varyings : Array(VaryingDecl) = [] of VaryingDecl
    property constants : Array(ConstantDecl) = [] of ConstantDecl
    property structs : Hash(String, StructDecl) = {} of String => StructDecl
    property buffers : Array(BufferDecl) = [] of BufferDecl
    property push_constants : Array(PushConstantDecl) = [] of PushConstantDecl
    property shared_memories : Array(SharedMemoryDecl) = [] of SharedMemoryDecl
    property images : Array(ImageUniformDecl) = [] of ImageUniformDecl
    property includes : Array(String) = [] of String
    property preprocessor_lines : Array(String) = [] of String
    property default_precisions : Hash(String, String) = {} of String => String
    property compute_layout : ComputeLayout = ComputeLayout.new
    property functions : Hash(String, Crystal::Def) = {} of String => Crystal::Def
    property macros : Hash(String, Crystal::Macro) = {} of String => Crystal::Macro
    property requires : Set(String) = Set(String).new
    property raw_top_level_nodes : Array(Crystal::ASTNode) = [] of Crystal::ASTNode
    property node_generations : Array(NodeGenerationTarget) = [] of NodeGenerationTarget
    property is_compositor : Bool = false
    property compositor_stage : String = "PostTransparent"
    property compositor_access_color : Bool = true
    property compositor_access_depth : Bool = false
    property compositor_access_normal_roughness : Bool = false
    property compositor_access_scene_data : Bool = false

    # Provenance & external interop tracking for TreeShaker and .gdshaderinc headers
    property imported_functions : Set(String) = Set(String).new
    property imported_structs : Set(String) = Set(String).new
    property imported_constants : Set(String) = Set(String).new
    property external_structs : Hash(String, StructDecl) = {} of String => StructDecl
    property external_functions : Hash(String, String) = {} of String => String
    property external_constants : Hash(String, String) = {} of String => String

    def initialize(@target : ShaderTarget = ShaderTarget::GDShader)
    end
  end

  record NodeGenerationTarget, node_type : String, class_name : String, output_path : String? = nil
end
