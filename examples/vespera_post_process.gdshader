shader_type canvas_item;

render_mode unshaded;

uniform sampler2D screen_texture : filter_linear;
uniform float exposure : hint_range(0.1, 5.0) = 1.1;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.004;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float grain_amount : hint_range(0.0, 0.1) = 0.025;

vec3 aces_tonemap(vec3 x) {
	float a = 2.51;
	float b = 0.03;
	float c = 2.43;
	float d = 0.59;
	float e = 0.14;
	return clamp(((x * ((a * x) + b)) / ((x * ((c * x) + d)) + e)), 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;
	vec2 dir_from_center = (uv - vec2(0.5, 0.5));
	float dist_from_center = length(dir_from_center);
	vec2 offset = ((dir_from_center * chromatic_aberration) * dist_from_center);
	float r = texture(screen_texture, (uv - offset)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, (uv + offset)).b;
	vec3 color = vec3(r, g, b);
	color = (color * exposure);
	color = aces_tonemap(color);
	float vignette = smoothstep(0.8, (0.8 - vignette_intensity), dist_from_center);
	color = (color * vignette);
	float grain_seed = dot((uv + vec2((TIME * 0.1), (TIME * -0.05))), vec2(12.9898, 78.233));
	float grain = ((fract((sin(grain_seed) * 43758.5453)) - 0.5) * grain_amount);
	color = clamp((color + vec3(grain)), 0.0, 1.0);
	COLOR = vec4(color, 1.0);
}

