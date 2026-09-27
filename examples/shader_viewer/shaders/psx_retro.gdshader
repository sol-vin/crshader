shader_type spatial;

render_mode cull_disabled;

uniform sampler2D albedo_texture : filter_nearest;
uniform vec2 jitter_resolution = vec2(320.0, 240.0);
uniform float color_depth : hint_range(4.0, 64.0) = 32.0;
uniform bool affine_mapping = true;

varying vec2 v_affine_uv;
varying float v_clip_w;

void vertex() {
	mat4 clip_pos = ((PROJECTION_MATRIX * MODELVIEW_MATRIX) * vec4(VERTEX, 1.0));
	vec2 ndc = (clip_pos.xy / clip_pos.w);
	vec2 snapped_ndc = (floor((ndc * jitter_resolution)) / jitter_resolution);
	clip_pos.xy=((snapped_ndc * clip_pos.w));
	POSITION = clip_pos;
	v_clip_w = clip_pos.w;
	if (affine_mapping) {
		v_affine_uv = (UV * clip_pos.w);
	} else {
		v_affine_uv = UV;
	}
}

void fragment() {
	vec2 uv = ((affine_mapping) ? ((v_affine_uv / v_clip_w)) : (UV));
	float tex_color = texture(albedo_texture, uv);
	vec3 quantized_rgb = (floor((tex_color.rgb * color_depth)) / color_depth);
	ALBEDO = quantized_rgb;
	ALPHA = tex_color.a;
}

