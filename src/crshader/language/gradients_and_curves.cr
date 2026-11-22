require "compiler/crystal/syntax"
require "../ast/shader_ast"

module CrShader
  module GradientsAndCurves
    extend self

    # Parses `gradient :name, {0.0 => Color.hex("#..."), ...}, space: :oklab, interp: :smooth`
    # or `gradient :name, [{0.0, "#..."}, ...]`
    def parse_gradient_call(call : Crystal::Call) : GradientDecl?
      return nil if call.args.size < 2
      name = extract_ident(call.args[0])
      return nil if name.empty?

      space = "srgb"
      interp = "linear"
      call.named_args.try &.each do |narg|
        case narg.name
        when "space", "color_space"
          space = extract_ident(narg.value).downcase
        when "interp", "interpolation", "mode"
          interp = extract_ident(narg.value).downcase
        end
      end

      stops = extract_gradient_stops(call.args[1])
      return nil if stops.empty?
      stops.sort_by!(&.pos)

      GradientDecl.new(name: name, stops: stops, space: space, interp: interp)
    end

    # Parses `curve :name, {0.0 => 0.0, 0.5 => 1.0, 1.0 => 0.0}, interp: :smooth`
    # or `curve :name, [{0.0, 0.0}, {0.5, 1.0}]`
    def parse_curve_call(call : Crystal::Call) : CurveDecl?
      return nil if call.args.size < 2
      name = extract_ident(call.args[0])
      return nil if name.empty?

      interp = "linear"
      call.named_args.try &.each do |narg|
        case narg.name
        when "interp", "interpolation", "mode"
          interp = extract_ident(narg.value).downcase
        end
      end

      points = extract_curve_points(call.args[1])
      return nil if points.empty?
      points.sort_by!(&.pos)

      CurveDecl.new(name: name, points: points, interp: interp)
    end

    # Synthesizes a callable `def <name>(t : Float32) : Vec4` AST node for ShaderProgram
    def synthesize_gradient_def(decl : GradientDecl) : Crystal::Def
      sorted = decl.stops.sort_by(&.pos)
      converted = sorted.map { |s| convert_stop_for_space(s, decl.space) }

      lines = [] of String
      lines << "def #{decl.name}(t : Float32) : Vec4"
      if converted.size == 1
        c0 = converted[0]
        if decl.space == "oklab"
          rgb = oklab_to_linear_rgb(c0[0], c0[1], c0[2])
          lines << "  vec4(#{fmt(rgb[0])}, #{fmt(rgb[1])}, #{fmt(rgb[2])}, #{fmt(c0[3])})"
        else
          lines << "  vec4(#{fmt(c0[0])}, #{fmt(c0[1])}, #{fmt(c0[2])}, #{fmt(c0[3])})"
        end
      else
        first_p = fmt(sorted.first.pos)
        last_p = fmt(sorted.last.pos)
        lines << "  tc = clamp(t, #{first_p}, #{last_p})"
        c0 = converted[0]
        lines << "  acc = vec4(#{fmt(c0[0])}, #{fmt(c0[1])}, #{fmt(c0[2])}, #{fmt(c0[3])})"

        (1...sorted.size).each do |i|
          p0 = sorted[i - 1].pos
          p1 = sorted[i].pos
          span = Math.max(p1 - p0, 0.000001_f32)
          ci = converted[i]
          target_vec = "vec4(#{fmt(ci[0])}, #{fmt(ci[1])}, #{fmt(ci[2])}, #{fmt(ci[3])})"
          w_expr = case decl.interp
                   when "smooth", "smoothstep", "cubic"
                     "smoothstep(#{fmt(p0)}, #{fmt(p0 + span)}, tc)"
                   when "step", "constant", "nearest"
                     "step(#{fmt(p1)}, tc)"
                   else
                     "clamp((tc - #{fmt(p0)}) / #{fmt(span)}, 0.0, 1.0)"
                   end
          lines << "  acc = mix(acc, #{target_vec}, #{w_expr})"
        end

        if decl.space == "oklab"
          lines << "  l_ = acc.x + 0.39633778 * acc.y + 0.21580376 * acc.z"
          lines << "  m_ = acc.x - 0.10556135 * acc.y - 0.06385417 * acc.z"
          lines << "  s_ = acc.x - 0.08948418 * acc.y - 1.29148555 * acc.z"
          lines << "  l_c = l_ * l_ * l_"
          lines << "  m_c = m_ * m_ * m_"
          lines << "  s_c = s_ * s_ * s_"
          lines << "  r_lin = 4.07674166 * l_c - 3.30771159 * m_c + 0.23096993 * s_c"
          lines << "  g_lin = -1.26843800 * l_c + 2.60975740 * m_c - 0.34131940 * s_c"
          lines << "  b_lin = -0.00419609 * l_c - 0.70341861 * m_c + 1.70761470 * s_c"
          lines << "  vec4(max(vec3(r_lin, g_lin, b_lin), vec3(0.0, 0.0, 0.0)), acc.w)"
        else
          lines << "  acc"
        end
      end
      lines << "end"

      Crystal::Parser.new(lines.join("\n")).parse.as(Crystal::Def)
    end

    # Synthesizes a callable `def <name>(t : Float32) : Float32` AST node for ShaderProgram
    def synthesize_curve_def(decl : CurveDecl) : Crystal::Def
      sorted = decl.points.sort_by(&.pos)
      lines = [] of String
      lines << "def #{decl.name}(t : Float32) : Float32"
      if sorted.size == 1
        lines << "  #{fmt(sorted[0].value)}"
      else
        first_p = fmt(sorted.first.pos)
        last_p = fmt(sorted.last.pos)
        lines << "  tc = clamp(t, #{first_p}, #{last_p})"
        lines << "  acc = #{fmt(sorted[0].value)}"

        (1...sorted.size).each do |i|
          p0 = sorted[i - 1].pos
          p1 = sorted[i].pos
          span = Math.max(p1 - p0, 0.000001_f32)
          v1 = fmt(sorted[i].value)
          w_expr = case decl.interp
                   when "smooth", "smoothstep", "cubic"
                     "smoothstep(#{fmt(p0)}, #{fmt(p0 + span)}, tc)"
                   when "step", "constant", "nearest"
                     "step(#{fmt(p1)}, tc)"
                   else
                     "clamp((tc - #{fmt(p0)}) / #{fmt(span)}, 0.0, 1.0)"
                   end
          lines << "  acc = mix(acc, #{v1}, #{w_expr})"
        end
        lines << "  acc"
      end
      lines << "end"

      Crystal::Parser.new(lines.join("\n")).parse.as(Crystal::Def)
    end

    def srgb_to_linear_channel(c : Float64) : Float64
      v = c.clamp(0.0, 1.0)
      v <= 0.04045 ? (v / 12.92) : (((v + 0.055) / 1.055) ** 2.4)
    end

    def linear_to_srgb_channel(c : Float64) : Float64
      v = Math.max(c, 0.0)
      out = v <= 0.0031308 ? (v * 12.92) : (1.055 * (v ** (1.0 / 2.4)) - 0.055)
      out.clamp(0.0, 1.0)
    end

    def linear_rgb_to_oklab(r : Float64, g : Float64, b : Float64) : Tuple(Float32, Float32, Float32)
      l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
      m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
      s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
      l_ = Math.cbrt(Math.max(l, 0.0))
      m_ = Math.cbrt(Math.max(m, 0.0))
      s_ = Math.cbrt(Math.max(s, 0.0))
      l_out = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
      a_out = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
      b_out = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
      {l_out.to_f32, a_out.to_f32, b_out.to_f32}
    end

    def oklab_to_linear_rgb(l_in : Float32, a_in : Float32, b_in : Float32) : Tuple(Float32, Float32, Float32)
      l_ = l_in.to_f64 + 0.3963377774 * a_in.to_f64 + 0.2158037573 * b_in.to_f64
      m_ = l_in.to_f64 - 0.1055613458 * a_in.to_f64 - 0.0638541728 * b_in.to_f64
      s_ = l_in.to_f64 - 0.0894841775 * a_in.to_f64 - 1.2914855480 * b_in.to_f64
      l = l_ * l_ * l_
      m = m_ * m_ * m_
      s = s_ * s_ * s_
      r = Math.max(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, 0.0)
      g = Math.max(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, 0.0)
      b = Math.max(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s, 0.0)
      {r.to_f32, g.to_f32, b.to_f32}
    end

    def parse_hex_rgba(hex_str : String) : Tuple(Float32, Float32, Float32, Float32)?
      clean = hex_str.strip.sub(/^#/, "").sub(/^0x/i, "")
      case clean.size
      when 6
        r = clean[0..1].to_i(16) / 255.0_f32
        g = clean[2..3].to_i(16) / 255.0_f32
        b = clean[4..5].to_i(16) / 255.0_f32
        {r, g, b, 1.0_f32}
      when 8
        r = clean[0..1].to_i(16) / 255.0_f32
        g = clean[2..3].to_i(16) / 255.0_f32
        b = clean[4..5].to_i(16) / 255.0_f32
        a = clean[6..7].to_i(16) / 255.0_f32
        {r, g, b, a}
      else
        nil
      end
    rescue
      nil
    end

    private def convert_stop_for_space(stop : GradientStop, space : String) : Tuple(Float32, Float32, Float32, Float32)
      case space
      when "linear"
        {
          srgb_to_linear_channel(stop.r.to_f64).to_f32,
          srgb_to_linear_channel(stop.g.to_f64).to_f32,
          srgb_to_linear_channel(stop.b.to_f64).to_f32,
          stop.a,
        }
      when "oklab"
        lr = srgb_to_linear_channel(stop.r.to_f64)
        lg = srgb_to_linear_channel(stop.g.to_f64)
        lb = srgb_to_linear_channel(stop.b.to_f64)
        lab = linear_rgb_to_oklab(lr, lg, lb)
        {lab[0], lab[1], lab[2], stop.a}
      else
        {stop.r, stop.g, stop.b, stop.a}
      end
    end

    private def fmt(v : Float32 | Float64) : String
      sprintf("%.6f", v)
    end

    private def extract_ident(node : Crystal::ASTNode) : String
      case node
      when Crystal::SymbolLiteral, Crystal::StringLiteral
        node.value
      when Crystal::Var
        node.name
      when Crystal::Path
        node.names.join("::")
      else
        node.to_s
      end
    end

    private def extract_float(node : Crystal::ASTNode) : Float32?
      case node
      when Crystal::NumberLiteral
        node.value.gsub(/_f32|_f64|_i32|_u32/, "").to_f32?
      when Crystal::Call
        if node.name == "-" && (obj = node.obj) && node.args.empty?
          extract_float(obj).try { |v| -v }
        else
          nil
        end
      else
        node.to_s.gsub(/_f32|_f64|_i32|_u32/, "").to_f32?
      end
    end

    private def extract_color_rgba(node : Crystal::ASTNode) : Tuple(Float32, Float32, Float32, Float32)?
      case node
      when Crystal::StringLiteral
        parse_hex_rgba(node.value)
      when Crystal::TupleLiteral
        if node.elements.size >= 3
          r = extract_float(node.elements[0]) || 0.0_f32
          g = extract_float(node.elements[1]) || 0.0_f32
          b = extract_float(node.elements[2]) || 0.0_f32
          a = node.elements[3]?.try { |e| extract_float(e) } || 1.0_f32
          {r, g, b, a}
        else
          nil
        end
      when Crystal::Call
        if (node.name == "hex" || node.name == "from_hex") && (arg = node.args.first?)
          if arg.is_a?(Crystal::StringLiteral)
            return parse_hex_rgba(arg.value)
          end
        elsif ["new", "vec4", "vec3", "color", "Color"].includes?(node.name)
          if node.args.size >= 3
            r = extract_float(node.args[0]) || 0.0_f32
            g = extract_float(node.args[1]) || 0.0_f32
            b = extract_float(node.args[2]) || 0.0_f32
            a = node.args[3]?.try { |e| extract_float(e) } || 1.0_f32
            return {r, g, b, a}
          elsif node.args.size == 1 && node.args[0].is_a?(Crystal::StringLiteral)
            return parse_hex_rgba(node.args[0].as(Crystal::StringLiteral).value)
          end
        end
        nil
      else
        nil
      end
    end

    private def extract_gradient_stops(node : Crystal::ASTNode) : Array(GradientStop)
      stops = [] of GradientStop
      case node
      when Crystal::HashLiteral
        node.entries.each do |entry|
          pos = extract_float(entry.key)
          rgba = extract_color_rgba(entry.value)
          if pos && rgba
            stops << GradientStop.new(pos, rgba[0], rgba[1], rgba[2], rgba[3])
          end
        end
      when Crystal::ArrayLiteral
        node.elements.each do |el|
          if el.is_a?(Crystal::TupleLiteral) && el.elements.size >= 2
            pos = extract_float(el.elements[0])
            rgba = extract_color_rgba(el.elements[1])
            if pos && rgba
              stops << GradientStop.new(pos, rgba[0], rgba[1], rgba[2], rgba[3])
            end
          end
        end
      end
      stops
    end

    private def extract_curve_points(node : Crystal::ASTNode) : Array(CurvePoint)
      pts = [] of CurvePoint
      case node
      when Crystal::HashLiteral
        node.entries.each do |entry|
          pos = extract_float(entry.key)
          val = extract_float(entry.value)
          if pos && val
            pts << CurvePoint.new(pos, val)
          end
        end
      when Crystal::ArrayLiteral
        node.elements.each do |el|
          if el.is_a?(Crystal::TupleLiteral) && el.elements.size >= 2
            pos = extract_float(el.elements[0])
            val = extract_float(el.elements[1])
            if pos && val
              pts << CurvePoint.new(pos, val)
            end
          end
        end
      end
      pts
    end
  end

  # =============================================================================
  # ProceduralLUT - Runtime 1D Gradient & Curve Baker (CPU Evaluator + RGBA8 LUT)
  # =============================================================================
  module ProceduralLUT
    extend self

    def normalize_stops(
      stops : Array(GradientStop) | Array(Tuple(Float32, String)) | Hash(Float64, String) | Hash(Float32, String),
    ) : Array(GradientStop)
      result = [] of GradientStop
      case stops
      when Array(GradientStop)
        result.concat(stops)
      when Array(Tuple(Float32, String))
        stops.each do |pos, hex|
          if rgba = GradientsAndCurves.parse_hex_rgba(hex)
            result << GradientStop.new(pos, rgba[0], rgba[1], rgba[2], rgba[3])
          end
        end
      when Hash(Float64, String)
        stops.each do |pos, hex|
          if rgba = GradientsAndCurves.parse_hex_rgba(hex)
            result << GradientStop.new(pos.to_f32, rgba[0], rgba[1], rgba[2], rgba[3])
          end
        end
      when Hash(Float32, String)
        stops.each do |pos, hex|
          if rgba = GradientsAndCurves.parse_hex_rgba(hex)
            result << GradientStop.new(pos, rgba[0], rgba[1], rgba[2], rgba[3])
          end
        end
      end
      result.sort_by!(&.pos)
      result
    end

    def normalize_points(
      points : Array(CurvePoint) | Array(Tuple(Float32, Float32)) | Hash(Float64, Float64) | Hash(Float32, Float32),
    ) : Array(CurvePoint)
      result = [] of CurvePoint
      case points
      when Array(CurvePoint)
        result.concat(points)
      when Array(Tuple(Float32, Float32))
        points.each { |p, v| result << CurvePoint.new(p, v) }
      when Hash(Float64, Float64)
        points.each { |p, v| result << CurvePoint.new(p.to_f32, v.to_f32) }
      when Hash(Float32, Float32)
        points.each { |p, v| result << CurvePoint.new(p, v) }
      end
      result.sort_by!(&.pos)
      result
    end

    # Evaluates gradient at t in [0..1], returning sRGB RGBA in [0..1]
    def evaluate_gradient(
      stops : Array(GradientStop),
      t : Float32,
      space : Symbol | String = :oklab,
      interp : Symbol | String = :linear,
    ) : Tuple(Float32, Float32, Float32, Float32)
      return {0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32} if stops.empty?
      sorted = stops.sort_by(&.pos)
      return {sorted[0].r, sorted[0].g, sorted[0].b, sorted[0].a} if sorted.size == 1

      sp = space.to_s.downcase
      im = interp.to_s.downcase
      tc = t.clamp(sorted.first.pos, sorted.last.pos)

      conv = sorted.map do |s|
        case sp
        when "linear"
          {
            GradientsAndCurves.srgb_to_linear_channel(s.r.to_f64).to_f32,
            GradientsAndCurves.srgb_to_linear_channel(s.g.to_f64).to_f32,
            GradientsAndCurves.srgb_to_linear_channel(s.b.to_f64).to_f32,
            s.a,
          }
        when "oklab"
          lr = GradientsAndCurves.srgb_to_linear_channel(s.r.to_f64)
          lg = GradientsAndCurves.srgb_to_linear_channel(s.g.to_f64)
          lb = GradientsAndCurves.srgb_to_linear_channel(s.b.to_f64)
          lab = GradientsAndCurves.linear_rgb_to_oklab(lr, lg, lb)
          {lab[0], lab[1], lab[2], s.a}
        else
          {s.r, s.g, s.b, s.a}
        end
      end

      acc = conv[0]
      (1...sorted.size).each do |i|
        p0 = sorted[i - 1].pos
        p1 = sorted[i].pos
        span = Math.max(p1 - p0, 0.000001_f32)
        w = weight_for(tc, p0, p1, span, im)
        ci = conv[i]
        acc = {
          acc[0] + (ci[0] - acc[0]) * w,
          acc[1] + (ci[1] - acc[1]) * w,
          acc[2] + (ci[2] - acc[2]) * w,
          acc[3] + (ci[3] - acc[3]) * w,
        }
      end

      case sp
      when "linear"
        {
          GradientsAndCurves.linear_to_srgb_channel(acc[0].to_f64).to_f32,
          GradientsAndCurves.linear_to_srgb_channel(acc[1].to_f64).to_f32,
          GradientsAndCurves.linear_to_srgb_channel(acc[2].to_f64).to_f32,
          acc[3].clamp(0.0_f32, 1.0_f32),
        }
      when "oklab"
        lin = GradientsAndCurves.oklab_to_linear_rgb(acc[0], acc[1], acc[2])
        {
          GradientsAndCurves.linear_to_srgb_channel(lin[0].to_f64).to_f32,
          GradientsAndCurves.linear_to_srgb_channel(lin[1].to_f64).to_f32,
          GradientsAndCurves.linear_to_srgb_channel(lin[2].to_f64).to_f32,
          acc[3].clamp(0.0_f32, 1.0_f32),
        }
      else
        {
          acc[0].clamp(0.0_f32, 1.0_f32),
          acc[1].clamp(0.0_f32, 1.0_f32),
          acc[2].clamp(0.0_f32, 1.0_f32),
          acc[3].clamp(0.0_f32, 1.0_f32),
        }
      end
    end

    def evaluate_curve(
      points : Array(CurvePoint),
      t : Float32,
      interp : Symbol | String = :linear,
    ) : Float32
      return 0.0_f32 if points.empty?
      sorted = points.sort_by(&.pos)
      return sorted[0].value if sorted.size == 1

      im = interp.to_s.downcase
      tc = t.clamp(sorted.first.pos, sorted.last.pos)
      acc = sorted[0].value
      (1...sorted.size).each do |i|
        p0 = sorted[i - 1].pos
        p1 = sorted[i].pos
        span = Math.max(p1 - p0, 0.000001_f32)
        w = weight_for(tc, p0, p1, span, im)
        acc = acc + (sorted[i].value - acc) * w
      end
      acc
    end

    def sample_gradient_bytes(
      stops,
      width : Int32 = 256,
      space : Symbol | String = :oklab,
      interp : Symbol | String = :linear,
    ) : Bytes
      w = Math.max(width, 2)
      norm = normalize_stops(stops)
      buf = Bytes.new(w * 4, 0_u8)
      denom = (w - 1).to_f32
      w.times do |x|
        t = x.to_f32 / denom
        rgba = evaluate_gradient(norm, t, space: space, interp: interp)
        base = x * 4
        buf[base + 0] = (rgba[0].clamp(0.0_f32, 1.0_f32) * 255.0_f32).round.to_u8
        buf[base + 1] = (rgba[1].clamp(0.0_f32, 1.0_f32) * 255.0_f32).round.to_u8
        buf[base + 2] = (rgba[2].clamp(0.0_f32, 1.0_f32) * 255.0_f32).round.to_u8
        buf[base + 3] = (rgba[3].clamp(0.0_f32, 1.0_f32) * 255.0_f32).round.to_u8
      end
      buf
    end

    def sample_curve_floats(
      points,
      width : Int32 = 256,
      interp : Symbol | String = :smooth,
    ) : Array(Float32)
      w = Math.max(width, 2)
      norm = normalize_points(points)
      denom = (w - 1).to_f32
      Array(Float32).new(w) do |x|
        evaluate_curve(norm, x.to_f32 / denom, interp: interp)
      end
    end

    def sample_curve_bytes(
      points,
      width : Int32 = 256,
      interp : Symbol | String = :smooth,
    ) : Bytes
      vals = sample_curve_floats(points, width: width, interp: interp)
      buf = Bytes.new(vals.size * 4, 0_u8)
      vals.each_with_index do |v, idx|
        byte = (v.clamp(0.0_f32, 1.0_f32) * 255.0_f32).round.to_u8
        base = idx * 4
        buf[base + 0] = byte
        buf[base + 1] = byte
        buf[base + 2] = byte
        buf[base + 3] = 255_u8
      end
      buf
    end

    private def weight_for(tc : Float32, p0 : Float32, p1 : Float32, span : Float32, interp : String) : Float32
      case interp
      when "smooth", "smoothstep", "cubic"
        x = ((tc - p0) / span).clamp(0.0_f32, 1.0_f32)
        x * x * (3.0_f32 - 2.0_f32 * x)
      when "step", "constant", "nearest"
        tc >= p1 ? 1.0_f32 : 0.0_f32
      else
        ((tc - p0) / span).clamp(0.0_f32, 1.0_f32)
      end
    end
  end
end
