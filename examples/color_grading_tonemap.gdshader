shader_type canvas_item;

render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float exposure : hint_range(0.1, 4.0) = 1.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.15;
uniform float saturation : hint_range(0.0, 2.0) = 1.1;
uniform vec3 lift = vec3(0.0, 0.0, 0.0);
uniform vec3 gamma = vec3(1.0, 1.0, 1.0);
uniform vec3 gain = vec3(1.0, 1.0, 1.0);

vec3 aces_film(vec3 x) {
	float a = 2.51;
	float b = 0.03;
	float c = 2.43;
	float d = 0.59;
	float e = 0.14;
	return clamp(((x * ((x * a) + b)) / ((x * ((x * c) + d)) + e)), 0.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 raw_color = texture(screen_texture, uv).rgb;
	vec3 col = (raw_color * exposure);
	col = (gain * (col + (lift * (vec3(1.0, 1.0, 1.0) - col))));
	col = max(col, vec3(0.0, 0.0, 0.0));
	col = pow(col, (vec3(1.0, 1.0, 1.0) / gamma));
	col = aces_film(col);
	col = (((col - 0.5) * contrast) + 0.5);
	col = clamp(col, 0.0, 1.0);
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(lum, lum, lum), col, saturation);
	col = clamp(col, 0.0, 1.0);
	COLOR = vec4(col, 1.0);
}

