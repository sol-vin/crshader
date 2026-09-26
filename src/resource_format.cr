require "lapis"
require "./crshader_resource"

module CrShader
  include Godot

  # =============================================================================
  # ResourceFormatLoaderCRShader - Transparent In-Memory Loader for .crshader
  # =============================================================================
  # Loads .crshader files into CRShader (which inherits natively from Shader).
  # Compiles transparently in-memory without polluting the project file structure.
  @[Tool]
  node ResourceFormatLoaderCRShader < ResourceFormatLoader do
    @@instance : ResourceFormatLoaderCRShader? = nil
    @@registered : Bool = false

    def self.ensure_registered : Void
      return if @@registered
      rl_ptr = Bridge.get_singleton("ResourceLoader")
      return if rl_ptr.null?

      r_loader = Godot::ResourceLoader.new(rl_ptr)
      if loader = Godot.create(CrShader::ResourceFormatLoaderCRShader)
        @@instance = loader
        r_loader.add_resource_format_loader(loader, true) rescue (r_loader.call("add_resource_format_loader", loader, true) rescue nil)
        @@registered = true
        Godot.print("[CRShader] ResourceFormatLoaderCRShader registered.")
      end
    end

    def self.unregister : Void
      return unless @@registered
      loader = @@instance
      @@instance = nil
      @@registered = false

      return unless loader && !loader.pointer.null?

      rl_ptr = Bridge.get_singleton("ResourceLoader")
      unless rl_ptr.null?
        r_loader = Godot::ResourceLoader.new(rl_ptr)
        r_loader.remove_resource_format_loader(loader) rescue (r_loader.call("remove_resource_format_loader", loader) rescue nil)
      end
      loader.destroy rescue nil if loader.alive?
    end

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def self.resolve_file_path(target_path : String) : String
      return "" if target_path.empty?
      if target_path.starts_with?("res://") || target_path.starts_with?("user://")
        if !Godot::ProjectSettings.singleton_ptr.null?
          ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
          global_path = ps.call_str("globalize_path", target_path).gsub('\\', '/')
          return global_path if !global_path.empty? && File.exists?(global_path)
        end
        stripped = target_path.sub(/^(res|user):\/\//, "")
        return stripped if File.exists?(stripped)
      end
      return target_path if File.exists?(target_path)
      ""
    end

    def self._godot_has_virtual_method(method_name : String) : Bool
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_get_recognized_extensions", "_recognize_path", "_handles_type", "_get_resource_type", "_load"
        true
      else
        false
      end
    end

    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_get_recognized_extensions"
        Bridge.ret_packed_string_array(ret, ["crshader"])
      when "_recognize_path"
        path = Bridge.arg_to_string(args[0])
        ret.as(UInt8*).value = path.downcase.ends_with?(".crshader") ? 1_u8 : 0_u8
      when "_handles_type"
        typename = Bridge.arg_to_string_name(args[0]) rescue ""
        typename = Bridge.arg_to_string(args[0]) rescue "" if typename.empty?
        handles = (typename == "Shader" || typename == "CRShader" || typename == "Resource" || typename.empty?)
        ret.as(UInt8*).value = handles ? 1_u8 : 0_u8
      when "_get_resource_type"
        path = Bridge.arg_to_string(args[0])
        Bridge.ret_string(ret, path.downcase.ends_with?(".crshader") ? "CRShader" : "")
      when "_load"
        path = Bridge.arg_to_string(args[0])
        orig_path = Bridge.arg_to_string(args[1])
        target_path = orig_path.empty? ? path : orig_path

        resolved = ResourceFormatLoaderCRShader.resolve_file_path(target_path)
        source = resolved.empty? ? "" : (File.read(resolved) rescue "")

        shader = Godot.create(CrShader::CRShader)
        if shader
          shader.file_path = target_path
          shader.set_crshader_source(source)
          Bridge.ret_variant_object(ret, shader.pointer)
        else
          Bridge.ret_variant_nil(ret)
        end
      else
        super
      end
    end
  end

  # =============================================================================
  # ResourceFormatSaverCRShader - Transparent Saver for .crshader Files
  # =============================================================================
  @[Tool]
  node ResourceFormatSaverCRShader < ResourceFormatSaver do
    @@instance : ResourceFormatSaverCRShader? = nil
    @@registered : Bool = false

    def self.ensure_registered : Void
      return if @@registered
      rs_ptr = Bridge.get_singleton("ResourceSaver")
      return if rs_ptr.null?

      r_saver = Godot::ResourceSaver.new(rs_ptr)
      if saver = Godot.create(CrShader::ResourceFormatSaverCRShader)
        @@instance = saver
        r_saver.add_resource_format_saver(saver, true) rescue (r_saver.call("add_resource_format_saver", saver, true) rescue nil)
        @@registered = true
        Godot.print("[CRShader] ResourceFormatSaverCRShader registered.")
      end
    end

    def self.unregister : Void
      return unless @@registered
      saver = @@instance
      @@instance = nil
      @@registered = false

      return unless saver && !saver.pointer.null?

      rs_ptr = Bridge.get_singleton("ResourceSaver")
      unless rs_ptr.null?
        r_saver = Godot::ResourceSaver.new(rs_ptr)
        r_saver.remove_resource_format_saver(saver) rescue (r_saver.call("remove_resource_format_saver", saver) rescue nil)
      end
      saver.destroy rescue nil if saver.alive?
    end

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def self._godot_has_virtual_method(method_name : String) : Bool
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_get_recognized_extensions", "_recognize", "_recognize_path", "_save"
        true
      else
        false
      end
    end

    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_get_recognized_extensions"
        Bridge.ret_packed_string_array(ret, ["crshader"])
      when "_recognize"
        res_ptr = args[0]
        if res_ptr && !res_ptr.null?
          obj = CrShader::CRShader.new(res_ptr) rescue nil
          ret.as(UInt8*).value = (obj && obj.alive?) ? 1_u8 : 0_u8
        else
          ret.as(UInt8*).value = 0_u8
        end
      when "_recognize_path"
        path = Bridge.arg_to_string(args[1])
        ret.as(UInt8*).value = path.downcase.ends_with?(".crshader") ? 1_u8 : 0_u8
      when "_save"
        res_ptr = args[0]
        path = Bridge.arg_to_string(args[1])

        if res_ptr && !res_ptr.null? && path.downcase.ends_with?(".crshader")
          shader = CrShader::CRShader.new(res_ptr) rescue nil
          if shader && shader.alive?
            resolved = ResourceFormatLoaderCRShader.resolve_file_path(path)
            resolved = path if resolved.empty?
            File.write(resolved, shader.crshader_source)
            ret.as(Int64*).value = 0_i64 # OK
            return
          end
        end
        ret.as(Int64*).value = 1_i64 # FAILED
      else
        super
      end
    end
  end
end
