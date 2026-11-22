shader_type spatial;

render_mode cull_back, diffuse_toon, specular_toon;

uniform vec4 base_tint : source_color = vec4(0.2196, 0.7412, 0.9725, 1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.35;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.08;
group_uniforms RimFresnel;
uniform vec4 rim_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform float rim_power : hint_range(0.5, 10.0) = 3.0;
uniform float rim_intensity : hint_range(0.0, 5.0) = 1.2;
group_uniforms Dissolve;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_scale : hint_range(1.0, 64.0) = 10.0;
uniform float dissolve_edge_width : hint_range(0.005, 0.3) = 0.06;
uniform vec4 dissolve_edge_color : source_color = vec4(1.0, 0.4157, 0.0627, 1.0);
group_uniforms HitFlash;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float flash_glow : hint_range(0.0, 5.0) = 1.5;
group_uniforms Debug;
/** Live visual variable inspector (stripped automatically in --release) */
uniform int debug_view : hint_enum("Off", "ramp_factor", "surface_albedo", "NaN_Inf_Detector") = 0;
group_uniforms;

vec2 uv_wave(vec2 uv, float freq, float amp, float phase) {
	return vec2((uv.x + (sin(((uv.y * freq) + phase)) * amp)), (uv.y + (cos(((uv.x * freq) + phase)) * amp)));
}

float elevation_curve(float t) {
	float tc = clamp(t, 0.000000, 1.000000);
	float acc = 0.100000;
	acc = mix(acc, 0.650000, smoothstep(0.000000, 0.500000, tc));
	acc = mix(acc, 1.000000, smoothstep(0.500000, 1.000000, tc));
	return acc;
}

vec4 aurora_ramp(float t) {
	float tc = clamp(t, 0.000000, 1.000000);
	vec4 acc = vec4(0.207682, -0.002948, -0.039715, 1.000000);
	acc = mix(acc, vec4(0.546150, -0.026671, -0.213549, 1.000000), smoothstep(0.000000, 0.450000, tc));
	acc = mix(acc, vec4(0.797116, -0.114121, -0.070016, 1.000000), smoothstep(0.450000, 0.800000, tc));
	acc = mix(acc, vec4(0.945102, -0.024867, 0.121791, 1.000000), smoothstep(0.800000, 1.000000, tc));
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

float hash11(float p) {
	vec3 p3 = fract((vec3(p, p, p) * 0.1031));
	p3 += dot(p3, (p3.yzx + 33.33));
	return fract(((p3.x + p3.y) * p3.z));
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = ((f * f) * (3.0 - (2.0 * f)));
	float a = hash11((i.x + (i.y * 57.0)));
	float b = hash11(((i.x + 1.0) + (i.y * 57.0)));
	float c = hash11((i.x + ((i.y + 1.0) * 57.0)));
	float d = hash11(((i.x + 1.0) + ((i.y + 1.0) * 57.0)));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	float _cr_dbg_1 = 0.0;
	vec3 _cr_dbg_2 = vec3(0.0, 0.0, 0.0);
	vec2 warped_uv = uv_wave(fract((UV) * (2.0)), 6.0, 0.03, TIME);
	float ramp_t = elevation_curve(clamp((1.0 - warped_uv.y), 0.0, 1.0));
	_cr_dbg_1 = ramp_t;
	vec3 base_col = (aurora_ramp(ramp_t).rgb * base_tint.rgb);
	_cr_dbg_2 = base_col;
	ALBEDO = base_col;
	ROUGHNESS = roughness_val;
	METALLIC = metallic_val;
	float _rim_fresnel_f0_0_ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float _rim_fresnel_f0_0_rim_mask = pow((1.0 - _rim_fresnel_f0_0_ndotv), rim_power);
	EMISSION = (EMISSION + (rim_color.rgb * (_rim_fresnel_f0_0_rim_mask * rim_intensity)));
	float _dissolve_f1_0_noise_val = value_noise((UV * dissolve_scale));
	if (((dissolve_amount > 0.001) && (_dissolve_f1_0_noise_val < dissolve_amount))) {
		discard;
	}
	float _dissolve_f1_0_edge_mask = (smoothstep((dissolve_amount + dissolve_edge_width), dissolve_amount, _dissolve_f1_0_noise_val) * step(0.001, dissolve_amount));
	EMISSION = (EMISSION + (dissolve_edge_color.rgb * (_dissolve_f1_0_edge_mask * 3.0)));
	float _hit_flash_f2_0_amt = clamp(flash_amount, 0.0, 1.0);
	ALBEDO = mix(ALBEDO, flash_color.rgb, _hit_flash_f2_0_amt);
	EMISSION = (EMISSION + (flash_color.rgb * (_hit_flash_f2_0_amt * flash_glow)));
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
			if ((any(isnan(_cr_dbg_2)) || any(isinf(_cr_dbg_2)))) {
				_cr_dbg_rgb = _cr_chk;
			} else {
				_cr_dbg_rgb = clamp(_cr_dbg_2, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0));
			}
		} else if ((debug_view == 3)) {
			_cr_ref = ALBEDO;
			if ((any(isnan(_cr_ref)) || any(isinf(_cr_ref)))) {
				_cr_dbg_rgb = _cr_chk;
			} else {
				_cr_luma = (dot(clamp(_cr_ref, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0)), vec3(0.2126, 0.7152, 0.0722)) * 0.25);
				_cr_dbg_rgb = vec3(_cr_luma, _cr_luma, _cr_luma);
			}
		}
		ALBEDO = _cr_dbg_rgb;
		EMISSION = (_cr_dbg_rgb * 0.25);
		ROUGHNESS = 1.0;
		METALLIC = 0.0;
	}
}

