shader_type canvas_item;

uniform vec2 card_size = vec2(0.42, 0.32);
uniform float corner_radius : hint_range(0.0, 0.25) = 0.07;
uniform float border_width : hint_range(0.002, 0.05) = 0.012;
uniform float progress : hint_range(0.0, 1.0) = 0.72;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.65;
group_uniforms Debug;
/** Live visual variable inspector (stripped automatically in --release) */
uniform int debug_view : hint_enum("Off", "sdf_card_dist", "NaN_Inf_Detector") = 0;
group_uniforms;

float sdf2d_rounded_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = ((abs(p) - half_size) + vec2(radius, radius));
	return ((min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0, 0.0)))) - radius);
}

float sdf_fill(float d) {
	float aa = max(fwidth(d), 0.0005);
	return (1.0 - smoothstep(-aa, aa, d));
}

float sdf_stroke(float d, float width) {
	float aa = max(fwidth(d), 0.0005);
	float hw = (width * 0.5);
	return (1.0 - smoothstep((hw - aa), (hw + aa), abs(d)));
}

float sdf_glow(float d, float radius, float falloff) {
	return pow(clamp((1.0 - (max(d, 0.0) / max(radius, 0.0001))), 0.0, 1.0), falloff);
}

vec2 uv_polar(vec2 uv, vec2 center) {
	vec2 d = (uv - center);
	float radius = (length(d) * 2.0);
	float angle = ((atan(d.y, d.x) / 6.2831853) + 0.5);
	return vec2(radius, angle);
}

float osc_sine(float time, float freq) {
	return ((sin(((time * freq) * 6.2831853)) * 0.5) + 0.5);
}

float sdf2d_ring(vec2 p, float radius, float thickness) {
	return (abs((length(p) - radius)) - (thickness * 0.5));
}

vec4 card_bg(float t) {
	float tc = clamp(t, 0.000000, 1.000000);
	vec4 acc = vec4(0.180205, -0.001911, -0.032402, 1.000000);
	acc = mix(acc, vec4(0.279495, -0.006379, -0.036292, 1.000000), clamp(((tc - 0.000000) / 1.000000), 0.0, 1.0));
	float l_ = ((acc.x + (0.39633778 * acc.y)) + (0.21580376 * acc.z));
	float m_ = ((acc.x - (0.10556135 * acc.y)) - (0.06385417 * acc.z));
	float s_ = ((acc.x - (0.08948418 * acc.y)) - (1.29148555 * acc.z));
	float l_c = ((l_ * l_) * l_);
	float m_c = ((m_ * m_) * m_);
	float s_c = ((s_ * s_) * s_);
	float r_lin = (((4.07674166 * l_c) - (3.30771159 * m_c)) + (0.23096993 * s_c));
	float g_lin = (((-1.26843800 * l_c) + (2.60975740 * m_c)) - (0.34131940 * s_c));
	float b_lin = (((-0.00419609 * l_c) - (0.70341861 * m_c)) + (1.70761470 * s_c));
	return vec4(max(vec3(r_lin, g_lin, b_lin), vec3(0.0, 0.0, 0.0)), acc.w);
}

vec4 ring_accent(float t) {
	float tc = clamp(t, 0.000000, 1.000000);
	vec4 acc = vec4(0.753513, -0.084300, -0.110505, 1.000000);
	acc = mix(acc, vec4(0.680113, 0.019114, -0.157144, 1.000000), clamp(((tc - 0.000000) / 0.500000), 0.0, 1.0));
	acc = mix(acc, vec4(0.725266, 0.172437, -0.031148, 1.000000), clamp(((tc - 0.500000) / 0.500000), 0.0, 1.0));
	float l_ = ((acc.x + (0.39633778 * acc.y)) + (0.21580376 * acc.z));
	float m_ = ((acc.x - (0.10556135 * acc.y)) - (0.06385417 * acc.z));
	float s_ = ((acc.x - (0.08948418 * acc.y)) - (1.29148555 * acc.z));
	float l_c = ((l_ * l_) * l_);
	float m_c = ((m_ * m_) * m_);
	float s_c = ((s_ * s_) * s_);
	float r_lin = (((4.07674166 * l_c) - (3.30771159 * m_c)) + (0.23096993 * s_c));
	float g_lin = (((-1.26843800 * l_c) + (2.60975740 * m_c)) - (0.34131940 * s_c));
	float b_lin = (((-0.00419609 * l_c) - (0.70341861 * m_c)) + (1.70761470 * s_c));
	return vec4(max(vec3(r_lin, g_lin, b_lin), vec3(0.0, 0.0, 0.0)), acc.w);
}

void fragment() {
	float _cr_dbg_1 = 0.0;
	vec2 uv = UV;
	float __duv_x = length(vec2(dFdx(uv.x), dFdy(uv.x)));
	float __duv_y = length(vec2(dFdx(uv.y), dFdy(uv.y)));
	float __ui_aspect = ((((__duv_x > 0.000001) && (__duv_y > 0.000001))) ? ((__duv_y / __duv_x)) : (1.0));
	vec2 centered_uv = ((uv - vec2(0.5, 0.5)) * vec2(__ui_aspect, 1.0));
	vec4 color = (texture(TEXTURE, uv) * COLOR);
	float card_d = sdf2d_rounded_box(centered_uv, card_size, corner_radius);
	float card_mask = sdf_fill(card_d);
	float border_mask = sdf_stroke(card_d, border_width);
	float outer_glow = (sdf_glow(card_d, 0.08, 2.2) * glow_strength);
	vec2 polar_coords = uv_polar(uv, vec2(0.5, 0.5));
	float anim_prog = clamp(((progress * 0.85) + (osc_sine(TIME, 0.35) * 0.15)), 0.0, 1.0);
	float arc_mask = smoothstep((anim_prog + 0.01), (anim_prog - 0.01), polar_coords.y);
	float ring_d = sdf2d_ring(centered_uv, 0.16, 0.028);
	float ring_track = sdf_fill(ring_d);
	float ring_active = (ring_track * arc_mask);
	_cr_dbg_1 = card_d;
	vec3 bg_rgb = card_bg(uv.y).rgb;
	vec3 accent_rgb = ring_accent(polar_coords.y).rgb;
	vec3 composed = (bg_rgb * card_mask);
	composed = mix(composed, (bg_rgb * 1.8), (ring_track * 0.45));
	composed = mix(composed, accent_rgb, ring_active);
	composed = (composed + (accent_rgb * ((border_mask * 0.85) + (outer_glow * 0.45))));
	float alpha_out = (clamp(((card_mask + border_mask) + (outer_glow * 0.5)), 0.0, 1.0) * color.a);
	color = vec4(composed, alpha_out);
	COLOR = color;
	vec2 _cr_px;
	vec3 _cr_chk;
	vec3 _cr_dbg_rgb;
	vec3 _cr_ref;
	float _cr_luma;
	if ((debug_view > 0)) {
		_cr_px = FRAGCOORD.xy;
		_cr_chk = (((mod((floor((_cr_px.x * 0.125)) + floor((_cr_px.y * 0.125))), 2.0) < 0.5)) ? (vec3(1.0, 0.0, 1.0)) : (vec3(0.12, 0.0, 0.12)));
		_cr_dbg_rgb = vec3(0.0, 0.0, 0.0);
		if ((debug_view == 1)) {
			if ((isnan(_cr_dbg_1) || isinf(_cr_dbg_1))) {
				_cr_dbg_rgb = _cr_chk;
			} else if ((_cr_dbg_1 < 0.0)) {
				_cr_dbg_rgb = mix(vec3(0.05, 0.18, 0.48), vec3(0.0, 0.72, 1.0), clamp(-_cr_dbg_1, 0.0, 1.0));
			} else if ((_cr_dbg_1 > 1.0)) {
				_cr_dbg_rgb = mix(vec3(1.0, 0.85, 0.2), vec3(1.0, 0.22, 0.0), clamp(((_cr_dbg_1 - 1.0) * 0.25), 0.0, 1.0));
			} else {
				_cr_dbg_rgb = vec3(_cr_dbg_1, _cr_dbg_1, _cr_dbg_1);
			}
		} else if ((debug_view == 2)) {
			_cr_ref = COLOR.rgb;
			if ((any(isnan(_cr_ref)) || any(isinf(_cr_ref)))) {
				_cr_dbg_rgb = _cr_chk;
			} else {
				_cr_luma = (dot(clamp(_cr_ref, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0)), vec3(0.2126, 0.7152, 0.0722)) * 0.25);
				_cr_dbg_rgb = vec3(_cr_luma, _cr_luma, _cr_luma);
			}
		}
		COLOR = vec4(_cr_dbg_rgb, 1.0);
	}
}

