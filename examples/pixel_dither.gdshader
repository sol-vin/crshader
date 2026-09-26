shader_type canvas_item;

render_mode unshaded;

const float BAYER_4X4[16] = float[]((0.0 / 16.0), (8.0 / 16.0), (2.0 / 16.0), (10.0 / 16.0), (12.0 / 16.0), (4.0 / 16.0), (14.0 / 16.0), (6.0 / 16.0), (3.0 / 16.0), (11.0 / 16.0), (1.0 / 16.0), (9.0 / 16.0), (15.0 / 16.0), (7.0 / 16.0), (13.0 / 16.0), (5.0 / 16.0));

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float pixel_size : hint_range(1.0, 16.0) = 4.0;
uniform float color_depth : hint_range(2.0, 32.0) = 8.0;
uniform float dither_amount : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	vec2 grid = (SCREEN_PIXEL_SIZE * pixel_size);
	vec2 uv = (floor((SCREEN_UV / grid)) * grid);
	vec3 raw_col = texture(screen_texture, uv).rgb;
	int x = (int((FRAGCOORD.x / pixel_size)) % 4);
	int y = (int((FRAGCOORD.y / pixel_size)) % 4);
	float dither_val = ((BAYER_4X4[((y * 4) + x)] - 0.5) * dither_amount);
	vec3 col = (raw_col + vec3(dither_val, dither_val, dither_val));
	col = clamp(col, 0.0, 1.0);
	col = (floor((col * color_depth)) / color_depth);
	COLOR = vec4(col, 1.0);
}

