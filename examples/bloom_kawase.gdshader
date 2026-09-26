shader_type canvas_item;

render_mode unshaded;

const vec2 OFFSETS[4] = vec2[](vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0, 1.0));

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float bloom_threshold : hint_range(0.0, 2.0) = 0.8;
uniform float bloom_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float blur_radius : hint_range(0.5, 10.0) = 2.5;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel_step = (SCREEN_PIXEL_SIZE * blur_radius);
	vec3 base_color = texture(screen_texture, uv).rgb;
	vec3 bloom_sum = vec3(0.0, 0.0, 0.0);
	for (int i = 0; i < 4; i++) {
		vec2 tap_uv = (uv + (OFFSETS[i] * pixel_step));
		vec3 sample_col = textureLod(screen_texture, tap_uv, 1.0).rgb;
		float brightness = max(sample_col.r, max(sample_col.g, sample_col.b));
		float soft_factor = clamp((brightness - bloom_threshold), 0.0, 1.0);
		bloom_sum = (bloom_sum + (sample_col * soft_factor));
	}
	vec3 bloom = ((bloom_sum * 0.25) * bloom_intensity);
	vec3 final_rgb = (base_color + bloom);
	COLOR = vec4(final_rgb, 1.0);
}

