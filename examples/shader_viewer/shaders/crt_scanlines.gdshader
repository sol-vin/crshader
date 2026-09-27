shader_type canvas_item;

render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float curvature : hint_range(0.0, 0.2) = 0.04;
uniform float scanline_count : hint_range(50.0, 800.0) = 240.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float scanline_speed : hint_range(0.0, 5.0) = 1.0;
uniform float phosphor_strength : hint_range(0.0, 0.5) = 0.15;

vec2 curve_uv(vec2 uv, float k) {
	vec2 centered = ((uv * 2.0) - vec2(1.0, 1.0));
	vec2 offset = ((centered.yx * centered.yx) * k);
	vec2 curved = (centered + (centered * offset));
	return ((curved * 0.5) + vec2(0.5, 0.5));
}

void fragment() {
	vec2 uv = curve_uv(SCREEN_UV, curvature);
	vec3 col;
	float scanline;
	int px;
	vec3 mask;
	float d;
	float vig;
	if (((((uv.x < 0.0) || (uv.x > 1.0)) || (uv.y < 0.0)) || (uv.y > 1.0))) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		col = texture(screen_texture, uv).rgb;
		scanline = ((sin((((uv.y * scanline_count) * 6.2831853) + (TIME * scanline_speed))) * 0.5) + 0.5);
		col = (col * (1.0 - (scanline * scanline_intensity)));
		px = (int(FRAGCOORD.x) % 3);
		mask = vec3((1.0 - phosphor_strength), (1.0 - phosphor_strength), (1.0 - phosphor_strength));
		if ((px == 0)) {
			mask.r=((1.0 + phosphor_strength));
		} else if ((px == 1)) {
			mask.g=((1.0 + phosphor_strength));
		} else {
			mask.b=((1.0 + phosphor_strength));
		}
		col = (col * mask);
		d = length((uv - vec2(0.5, 0.5)));
		vig = smoothstep(0.75, 0.5, d);
		col = (col * vig);
		COLOR = vec4(col, 1.0);
	}
}

