shader_type canvas_item;

render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
group_uniforms ChromaticAberration;
uniform float aberration_amount : hint_range(0.0, 0.05) = 0.004;
group_uniforms ColorGrade;
uniform float grade_exposure : hint_range(0.1, 4.0) = 1.0;
uniform float grade_contrast : hint_range(0.2, 2.5) = 1.08;
uniform float grade_saturation : hint_range(0.0, 2.5) = 1.12;
uniform vec4 grade_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
group_uniforms Vignette;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.45;
uniform float vignette_radius : hint_range(0.1, 1.5) = 0.82;
uniform float vignette_softness : hint_range(0.02, 1.0) = 0.45;
uniform vec4 vignette_color : source_color = vec4(0.0235, 0.0353, 0.0745, 1.0);
group_uniforms FilmGrain;
uniform float grain_amount : hint_range(0.0, 0.25) = 0.035;
uniform float grain_speed : hint_range(0.0, 60.0) = 12.0;
group_uniforms Debug;
/** Live visual variable inspector (stripped automatically in --release) */
uniform int debug_view : hint_enum("Off", "input_luma", "NaN_Inf_Detector") = 0;
group_uniforms;

void fragment() {
	float _cr_dbg_1 = 0.0;
	vec2 uv = SCREEN_UV;
	vec4 color = texture(screen_texture, uv);
	_cr_dbg_1 = dot((color).rgb, vec3(0.2126, 0.7152, 0.0722));
	color;
	vec2 _chromatic_aberration_p0_0_dir = (uv - vec2(0.5, 0.5));
	vec2 _chromatic_aberration_p0_0_uv_r = clamp((uv + (_chromatic_aberration_p0_0_dir * aberration_amount)), vec2(0.0, 0.0), vec2(1.0, 1.0));
	vec2 _chromatic_aberration_p0_0_uv_b = clamp((uv - (_chromatic_aberration_p0_0_dir * aberration_amount)), vec2(0.0, 0.0), vec2(1.0, 1.0));
	float _chromatic_aberration_p0_0_r_ch = texture(screen_texture, _chromatic_aberration_p0_0_uv_r).r;
	float _chromatic_aberration_p0_0_b_ch = texture(screen_texture, _chromatic_aberration_p0_0_uv_b).b;
	color = vec4(_chromatic_aberration_p0_0_r_ch, color.g, _chromatic_aberration_p0_0_b_ch, color.a);
	vec3 _color_grade_p1_0_exposed = ((color.rgb * grade_exposure) * grade_tint.rgb);
	vec3 _color_grade_p1_0_contrasted = (((_color_grade_p1_0_exposed - vec3(0.5, 0.5, 0.5)) * grade_contrast) + vec3(0.5, 0.5, 0.5));
	float _color_grade_p1_0_luma = dot(_color_grade_p1_0_contrasted, vec3(0.2126, 0.7152, 0.0722));
	vec3 _color_grade_p1_0_graded = max(mix(vec3(_color_grade_p1_0_luma, _color_grade_p1_0_luma, _color_grade_p1_0_luma), _color_grade_p1_0_contrasted, grade_saturation), vec3(0.0, 0.0, 0.0));
	color = vec4(_color_grade_p1_0_graded, color.a);
	float _vignette_p2_0_dist = length((uv - vec2(0.5, 0.5)));
	float _vignette_p2_0_vig = smoothstep(vignette_radius, (vignette_radius - vignette_softness), _vignette_p2_0_dist);
	vec3 _vignette_p2_0_out_rgb = mix(color.rgb, vignette_color.rgb, ((1.0 - _vignette_p2_0_vig) * vignette_intensity));
	color = vec4(_vignette_p2_0_out_rgb, color.a);
	vec2 _film_grain_p3_0_seed_uv = ((uv * vec2(512.0, 512.0)) + vec2((floor((TIME * grain_speed)) * 17.3), (floor((TIME * grain_speed)) * 31.7)));
	float _film_grain_p3_0_n = (fract((sin(dot(_film_grain_p3_0_seed_uv, vec2(12.9898, 78.233))) * 43758.5453)) - 0.5);
	color = vec4(max((color.rgb + (vec3(_film_grain_p3_0_n, _film_grain_p3_0_n, _film_grain_p3_0_n) * grain_amount)), vec3(0.0, 0.0, 0.0)), color.a);
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

