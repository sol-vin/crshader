module CrShader
  CRYSTAL_STUBS = <<-CRYSTAL
    # Stubs for CRShader compilation
    struct Vec2
      property x : Float32, y : Float32
      def initialize(@x = 0.0f32, @y = 0.0f32); end
      def self.new(x : Number, y : Number); new(x.to_f32, y.to_f32); end
    end

    struct Vec3
      property x : Float32, y : Float32, z : Float32
      def initialize(@x = 0.0f32, @y = 0.0f32, @z = 0.0f32); end
      def self.new(x : Number, y : Number, z : Number); new(x.to_f32, y.to_f32, z.to_f32); end
    end

    struct Vec4
      property x : Float32, y : Float32, z : Float32, w : Float32
      def initialize(@x = 0.0f32, @y = 0.0f32, @z = 0.0f32, @w = 1.0f32); end
      def self.new(x : Number, y : Number, z : Number, w : Number = 1.0); new(x.to_f32, y.to_f32, z.to_f32, w.to_f32); end
    end

    struct Color
      property r : Float32, g : Float32, b : Float32, a : Float32
      def initialize(@r = 1.0f32, @g = 1.0f32, @b = 1.0f32, @a = 1.0f32); end
      def self.new(r : Number, g : Number, b : Number, a : Number = 1.0); new(r.to_f32, g.to_f32, b.to_f32, a.to_f32); end
    end

    struct InOut(T)
    end

    struct Out(T)
    end

    def shader_type(*args); end
    def render_mode(*args); end
    def setup_gdshader; end
    def setup_gdshader(); end
    def uniform(*args, **kwargs); end
    def instance_uniform(*args, **kwargs); end
    def global_uniform(*args, **kwargs); end
    def varying(*args, **kwargs); end
    def const(*args, **kwargs); end
    def buffer(*args, **kwargs, &block); end
    def push_constant(*args, **kwargs, &block); end
    def shared(*args, **kwargs); end
    def image2d(*args, **kwargs); end
    def shader(*args, **kwargs, &block); end
    def vertex(&block); end
    def fragment(&block); end
    def light(&block); end
    def start(&block); end
    def process(&block); end
    def sky(&block); end
    def fog(&block); end
  CRYSTAL
end
