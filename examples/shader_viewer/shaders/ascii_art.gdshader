shader_type canvas_item;

render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec4 font_color = vec4(0.2, 1.0, 0.4, 1.0);
uniform vec4 background_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform vec2 char_size = vec2(8.0, 12.0);
uniform bool color_mode = false;

float char_pattern(int idx, vec2 p) {
	switch (idx) {
		case 0:
			return 0.0;
		case 1:
			return ((((abs((p.x - 0.5)) < 0.15) && (abs((p.y - 0.8)) < 0.15))) ? (1.0) : (0.0));

		case 2:
			return (((((abs((p.x - 0.5)) < 0.15) && (abs((p.y - 0.35)) < 0.15)) || ((abs((p.x - 0.5)) < 0.15) && (abs((p.y - 0.75)) < 0.15)))) ? (1.0) : (0.0));

		case 3:
			return (((((abs((p.y - 0.5)) < 0.12) && (p.x > 0.2)) && (p.x < 0.8))) ? (1.0) : (0.0));

		case 4:
			return ((((((abs((p.y - 0.5)) < 0.12) && (p.x > 0.2)) && (p.x < 0.8)) || (((abs((p.x - 0.5)) < 0.12) && (p.y > 0.2)) && (p.y < 0.8)))) ? (1.0) : (0.0));

		case 5:
			return ((((((abs((p.y - 0.38)) < 0.1) && (p.x > 0.2)) && (p.x < 0.8)) || (((abs((p.y - 0.62)) < 0.1) && (p.x > 0.2)) && (p.x < 0.8)))) ? (1.0) : (0.0));

		case 6:
			return (((((((abs((p.x - 0.5)) < 0.12) && (p.y > 0.2)) && (p.y < 0.8)) || (((abs((p.y - 0.5)) < 0.12) && (p.x > 0.2)) && (p.x < 0.8))) || (((abs((p.x - p.y)) < 0.12) && (p.x > 0.25)) && (p.x < 0.75)))) ? (1.0) : (0.0));

		case 7:
			return ((((((((abs((p.x - 0.35)) < 0.1) && (p.y > 0.15)) && (p.y < 0.85)) || (((abs((p.x - 0.65)) < 0.1) && (p.y > 0.15)) && (p.y < 0.85))) || (((abs((p.y - 0.35)) < 0.1) && (p.x > 0.15)) && (p.x < 0.85))) || (((abs((p.y - 0.65)) < 0.1) && (p.x > 0.15)) && (p.x < 0.85)))) ? (1.0) : (0.0));

		case 8:
			return ((((((abs((p.x - 0.3)) < 0.15) && (abs((p.y - 0.3)) < 0.15)) || ((abs((p.x - 0.7)) < 0.15) && (abs((p.y - 0.7)) < 0.15))) || (((abs(((p.x + p.y) - 1.0)) < 0.12) && (p.x > 0.2)) && (p.x < 0.8)))) ? (1.0) : (0.0));

		default:
			return ((((((p.x > 0.1) && (p.x < 0.9)) && (p.y > 0.1)) && (p.y < 0.9))) ? (1.0) : (0.0));

	}
}

void fragment() {
	vec2 pixel_coord = FRAGCOORD.xy;
	vec2 cell_idx = floor((pixel_coord / char_size));
	vec2 cell_uv = (((cell_idx * char_size) + (char_size * 0.5)) * SCREEN_PIXEL_SIZE);
	vec2 local_uv = fract((pixel_coord / char_size));
	vec3 scene_color = texture(screen_texture, cell_uv).rgb;
	float luminance = dot(scene_color, vec3(0.299, 0.587, 0.114));
	int glyph_index = clamp(int((luminance * 9.5)), 0, 9);
	float glyph_mask = char_pattern(glyph_index, local_uv);
	vec3 text_col = ((color_mode) ? (scene_color) : (font_color.rgb));
	vec3 out_rgb = mix(background_color.rgb, text_col, glyph_mask);
	COLOR = vec4(out_rgb, 1.0);
}

