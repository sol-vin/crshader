shader_type canvas_item;

render_mode unshaded;

const float SOBEL_X[9] = float[](-1.0, 0.0, 1.0, -2.0, 0.0, 2.0, -1.0, 0.0, 1.0);
const float SOBEL_Y[9] = float[](-1.0, -2.0, -1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 1.0);
const vec2 OFFSETS[9] = vec2[](vec2(-1.0, -1.0), vec2(0.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 0.0), vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(-1.0, 1.0), vec2(0.0, 1.0), vec2(1.0, 1.0));

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec4 edge_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float threshold : hint_range(0.01, 1.0) = 0.2;
uniform float thickness : hint_range(0.5, 4.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel_step = (SCREEN_PIXEL_SIZE * thickness);
	float gx = 0.0;
	float gy = 0.0;
	for (int k = 0; k < 9; k++) {
		vec3 sample_col = texture(screen_texture, (uv + (OFFSETS[k] * pixel_step))).rgb;
		float lum = dot(sample_col, vec3(0.299, 0.587, 0.114));
		gx = (gx + (lum * SOBEL_X[k]));
		gy = (gy + (lum * SOBEL_Y[k]));
	}
	float edge = sqrt(((gx * gx) + (gy * gy)));
	vec3 original = texture(screen_texture, uv).rgb;
	if ((edge > threshold)) {
		COLOR = edge_color;
	} else {
		COLOR = vec4(original, 1.0);
	}
}

