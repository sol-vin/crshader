shader_type canvas_item;

render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.06;
uniform float grain_speed : hint_range(1.0, 30.0) = 12.0;
uniform float grain_size : hint_range(1.0, 5.0) = 1.5;
uniform bool colored_noise = false;

float hash21(vec2 p) {
	vec3 p3 = fract((vec3(p.x, p.y, p.x) * 0.1031));
	p3 = (p3 + dot(p3, (p3.yzx + 33.33)));
	return fract(((p3.x + p3.y) * p3.z));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 scene_color = texture(screen_texture, uv).rgb;
	float t = floor((TIME * grain_speed));
	vec2 grain_uv = ((FRAGCOORD.xy / grain_size) + vec2((t * 17.13), (t * 43.71)));
	float n_r = (hash21(grain_uv) - 0.5);
	float n_g;
	float n_b;
	vec3 noise_vec;
	if (colored_noise) {
		n_g = (hash21((grain_uv + vec2(13.5, 47.2))) - 0.5);
		n_b = (hash21((grain_uv + vec2(71.9, 93.1))) - 0.5);
		noise_vec = vec3(n_r, n_g, n_b);
	} else {
		noise_vec = vec3(n_r, n_r, n_r);
	}
	float lum = dot(scene_color, vec3(0.299, 0.587, 0.114));
	float response = (1.0 - (abs((lum - 0.5)) * 1.5));
	response = clamp(response, 0.2, 1.0);
	vec3 final_color = (scene_color + (noise_vec * (grain_amount * response)));
	final_color = clamp(final_color, 0.0, 1.0);
	COLOR = vec4(final_color, 1.0);
}

