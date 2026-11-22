shader_type spatial;

render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled;

const vec2 OUTLINE_DIRS_24[24] = vec2[](vec2(0.0, -1.0), vec2(0.0, 1.0), vec2(-1.0, 0.0), vec2(1.0, 0.0), vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0, 1.0), vec2(0.0, -2.0), vec2(2.0, 0.0), vec2(-2.0, 0.0), vec2(0.0, 2.0), vec2(-1.0, -2.0), vec2(1.0, -2.0), vec2(-1.0, 2.0), vec2(1.0, 2.0), vec2(-2.0, -1.0), vec2(2.0, -1.0), vec2(-2.0, 1.0), vec2(2.0, 1.0), vec2(-2.0, -2.0), vec2(2.0, -2.0), vec2(-2.0, 2.0), vec2(2.0, 2.0));
const uint OUTLINE_ID_TAG_MASK = 1660944384u;
const uint OUTLINE_ID_TAG_BITS = 1090519040u;

struct PixelOutlineSample {
	vec3 rgb;
	uint surface_id;
	uint group_id;
	bool valid;
};

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
group_uniforms Outline;
/** Outline stroke thickness in pixels */
uniform float outline_width : hint_range(0.5, 8.0, 0.5) = 1.5;
/** Linear view-space depth edge threshold */
uniform float depth_threshold : hint_range(0.005, 1.0, 0.005) = 0.08;
/** Base outline RGBA color */
uniform vec4 outline_color : source_color = vec4(0.05, 0.04, 0.08, 1.0);
group_uniforms Outline.RetroFX;
/** Win98 directional bevel highlight strength */
uniform float bevel_highlight : hint_range(0.0, 1.0, 0.05) = 0.2;
/** Win98 directional bevel shadow strength */
uniform float bevel_shadow : hint_range(0.0, 1.0, 0.05) = 0.25;
/** Stepped Squigglevision boil amplitude in pixels (0 disables) */
uniform float boil_amplitude : hint_range(0.0, 4.0, 0.25) = 0.0;
/** Boil animation frame rate */
uniform float boil_fps : hint_range(1.0, 24.0, 1.0) = 8.0;
group_uniforms;

vec2 apply_line_boil(vec2 uv, vec2 texel_size, float time, float fps, float amp_px, float freq) {
	float q_time;
	vec2 phase;
	vec2 jitter;
	if ((amp_px <= 0.0)) {
		return uv;
	} else {
		q_time = (floor((time * max(fps, 1.0))) / max(fps, 1.0));
		phase = (((uv * freq) * 18.8495559) + vec2((q_time * 17.3), (-q_time * 13.7)));
		jitter = vec2(sin((phase.x + cos(phase.y))), cos((phase.y - sin(phase.x))));
		return (uv + ((jitter * texel_size) * amp_px));
	}
}

uint float_to_bits_u32(float v) {
	return floatBitsToUint(v);
}

PixelOutlineSample decode_outline_pixel(vec4 rgba) {
	uint bits = float_to_bits_u32(rgba.a);
	bool is_tagged = ((bits & OUTLINE_ID_TAG_MASK) == OUTLINE_ID_TAG_BITS);
	uint surf = ((is_tagged) ? (((bits >> 8u) & 16383u)) : (0u));
	uint grp = ((is_tagged) ? ((bits & 255u)) : (0u));
	return PixelOutlineSample(rgba.rgb, surf, grp, is_tagged);
}

vec3 reconstruct_view_pos(vec2 uv, float raw_depth, mat4 inv_proj) {
	vec3 ndc = vec3(((uv * 2.0) - 1.0), raw_depth);
	vec4 view_h = (inv_proj * vec4(ndc, 1.0));
	return (view_h.xyz / max(abs(view_h.w), 0.000001));
}

float linear_view_depth(vec2 uv, float raw_depth, mat4 inv_proj) {
	return -reconstruct_view_pos(uv, raw_depth, inv_proj).z;
}

bool is_depth_edge(float z_center, float z_neighbor, float threshold, float grazing_mult) {
	float rel_diff = (abs((z_center - z_neighbor)) / max(min(z_center, z_neighbor), 0.001));
	return (rel_diff > (threshold * grazing_mult));
}

vec3 apply_win98_bevel(vec3 base_rgb, vec2 edge_dir, float highlight_strength, float shadow_strength) {
	vec2 light_axis = normalize(vec2(-0.70710678, -0.70710678));
	vec2 n_dir = (((dot(edge_dir, edge_dir) > 0.00001)) ? (normalize(edge_dir)) : (vec2(0.0, -1.0)));
	float facing = dot(n_dir, light_axis);
	return (((facing >= 0.0)) ? (mix(base_rgb, vec3(1.0, 1.0, 1.0), clamp((facing * highlight_strength), 0.0, 1.0))) : (mix(base_rgb, vec3(0.0, 0.0, 0.0), clamp((-facing * shadow_strength), 0.0, 1.0))));

}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 texel = (vec2(1.0) / VIEWPORT_SIZE);
	vec2 uv = apply_line_boil(SCREEN_UV, texel, TIME, boil_fps, boil_amplitude, 2.0);
	vec4 center_raw = texture(screen_texture, uv);
	PixelOutlineSample center_id = decode_outline_pixel(center_raw);
	float center_z = linear_view_depth(uv, texture(depth_texture, uv).r, INV_PROJECTION_MATRIX);
	float best_z = 1000000.0;
	vec2 best_dir = vec2(0.0, -1.0);
	bool edge_hit = false;
	for (int i = 0; i < 24; i++) {
		vec2 dir = OUTLINE_DIRS_24[i];
		vec2 s_uv = clamp((uv + ((dir * texel) * outline_width)), vec2(0.0005), vec2(0.9995));
		PixelOutlineSample n_id = decode_outline_pixel(texture(screen_texture, s_uv));
		float n_z = linear_view_depth(s_uv, texture(depth_texture, s_uv).r, INV_PROJECTION_MATRIX);
		bool id_edge = ((center_id.valid && n_id.valid) && (center_id.surface_id != n_id.surface_id));
		bool d_edge = is_depth_edge(center_z, n_z, depth_threshold, 1.0);
		if (((id_edge || d_edge) && (n_z < best_z))) {
			best_z = n_z;
			best_dir = dir;
			edge_hit = true;
		}
	}
	vec3 beveled = apply_win98_bevel(outline_color.rgb, best_dir, bevel_highlight, bevel_shadow);
	ALBEDO = ((edge_hit) ? (beveled) : (center_raw.rgb));
	ALPHA = ((edge_hit) ? (outline_color.a) : (0.0));
}

