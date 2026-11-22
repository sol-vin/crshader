require "../ast/types"
require "../ast/shader_ast"

module CrShader
  # =============================================================================
  # VariantCache - Thread-Safe O(1) Shader Permutation & Specialization Cache
  # =============================================================================
  # Maps (source, target, strip_debug_inspects, optimize_names, sorted features)
  # via 64-bit FNV-1a hashing to compiled shader source code (and live
  # Godot::Shader resources when loaded in the Godot / Lapis runtime).
  class VariantCache
    record CachedVariant,
      key : UInt64,
      signature : String,
      code : String,
      target : ShaderTarget

    record CacheStats,
      entries : Int32,
      hits : Int64,
      misses : Int64,
      max_entries : Int32

    FNV_OFFSET_BASIS = 14695981039346656037_u64
    FNV_PRIME        =        1099511628211_u64

    property max_entries : Int32
    getter hits : Int64 = 0_i64
    getter misses : Int64 = 0_i64

    @mutex : ::Mutex = ::Mutex.new
    @entries : Hash(UInt64, CachedVariant) = {} of UInt64 => CachedVariant
    @order : Array(UInt64) = [] of UInt64

    @@global : VariantCache? = nil

    def self.global : VariantCache
      @@global ||= new
    end

    def initialize(@max_entries : Int32 = 256)
    end

    def self.normalize_feature_val(val : FeatureValue) : String
      case val
      when Bool   then val ? "true" : "false"
      when Int32  then val.to_s
      when Symbol then val.to_s
      when String then val.strip
      else             val.to_s
      end
    end

    def self.canonical_feature_signature(features : Hash(String, FeatureValue)?) : String
      return "" unless features && !features.empty?
      keys = features.keys.sort
      String.build do |io|
        keys.each_with_index do |k, idx|
          io << ';' if idx > 0
          io << k << '=' << normalize_feature_val(features[k])
        end
      end
    end

    def self.compute_key(
      source : String,
      target : ShaderTarget?,
      features : Hash(String, FeatureValue)? = nil,
      strip_debug_inspects : Bool = false,
      optimize_names : Bool = false,
    ) : Tuple(UInt64, String)
      sig = canonical_feature_signature(features)
      h = FNV_OFFSET_BASIS
      h = fnv1a_update(h, source)
      h = fnv1a_byte(h, 0x1f_u8)
      h = fnv1a_update(h, target ? target.to_target_keyword : "auto")
      h = fnv1a_byte(h, 0x1f_u8)
      h = fnv1a_byte(h, strip_debug_inspects ? 1_u8 : 0_u8)
      h = fnv1a_byte(h, optimize_names ? 1_u8 : 0_u8)
      h = fnv1a_byte(h, 0x1f_u8)
      h = fnv1a_update(h, sig)
      {h, sig}
    end

    private def self.fnv1a_byte(h : UInt64, byte : UInt8) : UInt64
      (h ^ byte.to_u64) &* FNV_PRIME
    end

    private def self.fnv1a_update(h : UInt64, str : String) : UInt64
      acc = h
      str.each_byte do |b|
        acc = (acc ^ b.to_u64) &* FNV_PRIME
      end
      acc
    end

    def get_or_compile(
      source : String,
      target : ShaderTarget? = nil,
      features : Hash(String, FeatureValue)? = nil,
      strip_debug_inspects : Bool = false,
      optimize_names : Bool = false,
      filename : String? = nil,
    ) : CachedVariant
      key, sig = self.class.compute_key(
        source: source,
        target: target,
        features: features,
        strip_debug_inspects: strip_debug_inspects,
        optimize_names: optimize_names
      )

      @mutex.synchronize do
        if cached = @entries[key]?
          @hits += 1
          return cached
        end
      end

      compiler = Compiler.new(
        target_override: target,
        optimize_names: optimize_names,
        feature_overrides: features ? features.dup : ({} of String => FeatureValue),
        strip_debug_inspects: strip_debug_inspects
      )
      compiled_code = compiler.compile_source(source, filename: filename)
      resolved_target = compiler.last_program.try(&.target) || target || ShaderTarget::GDShader
      entry = CachedVariant.new(key: key, signature: sig, code: compiled_code, target: resolved_target)

      @mutex.synchronize do
        @misses += 1
        unless @entries.has_key?(key)
          while @entries.size >= @max_entries && !@order.empty?
            evict_key = @order.shift
            @entries.delete(evict_key)
            evict_godot_entry(evict_key)
          end
          @order << key
        end
        @entries[key] = entry
      end

      entry
    end

    protected def evict_godot_entry(key : UInt64) : Void
      # Hook overridden when Godot runtime is loaded
    end

    def stats : CacheStats
      @mutex.synchronize do
        CacheStats.new(
          entries: @entries.size,
          hits: @hits,
          misses: @misses,
          max_entries: @max_entries
        )
      end
    end

    def clear! : Void
      @mutex.synchronize do
        @entries.clear
        @order.clear
        @hits = 0_i64
        @misses = 0_i64
        clear_godot_entries
      end
    end

    protected def clear_godot_entries : Void
      # Hook overridden when Godot runtime is loaded
    end
  end
end
