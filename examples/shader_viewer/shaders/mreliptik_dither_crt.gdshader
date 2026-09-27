shader_type canvas_item;

render_mode unshaded;

const float bayer_matrix[16] = float[]((0.0 / 16.0), (8.0 / 16.0), (2.0 / 16.0), (10.0 / 16.0), (12.0 / 16.0), (4.0 / 16.0), (14.0 / 16.0), (6.0 / 16.0), (3.0 / 16.0), (11.0 / 16.0), (1.0 / 16.0), (9.0 / 16.0), (15.0 / 16.0), (7.0 / 16.0), (13.0 / 16.0), (5.0 / 16.0));

uniform sampler2D screen_texture : filter_nearest;
uniform float curvature : hint_range(0.0, 0.2) = 0.05;
uniform float scanline_count = 240.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.25;
uniform float dither_strength : hint_range(0.0, 0.5) = 0.08;

vec2 curve_uv(vec2 uv, float k) {
	vec2 centered = (uv - vec2(0.5, 0.5));
	float r2 = dot(centered, centered);
	vec2 curved = (centered * (1.0 + (k * r2)));
	return (curved + vec2(0.5, 0.5));
}

void fragment() {
	vec2 uv = curve_uv(UV, curvature);
	vec3 color;
	float scanline;
	int px;
	int py;
	float bayer_idx;
	float dither_threshold;
	if (((((uv.x < 0.0) || (uv.x > 1.0)) || (uv.y < 0.0)) || (uv.y > 1.0))) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		color = texture(screen_texture, uv).rgb;
		scanline = ((sin(((uv.y * scanline_count) * 3.14159)) * 0.5) + 0.5);
		color = (color * (1.0 - (scanline * scanline_strength)));
		px = (int(FRAGCOORD.x) % 4);
		py = (int(FRAGCOORD.y) % 4);
		bayer_idx = ((py * 4) + px);
		dither_threshold = (bayer_matrix[bayer_idx] - 0.5);
		color = (color + vec3((dither_threshold * dither_strength)));
		color = clamp(color, 0.0, 1.0);
		COLOR = vec4(color, 1.0);
	}
}

