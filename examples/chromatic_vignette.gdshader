shader_type canvas_item;

render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.008;
uniform float barrel_distortion : hint_range(-0.5, 0.5) = 0.12;
uniform float vignette_radius : hint_range(0.1, 1.5) = 0.75;
uniform float vignette_softness : hint_range(0.01, 1.0) = 0.45;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = (uv - vec2(0.5, 0.5));
	float dist_sq = dot(centered, centered);
	float dist = sqrt(dist_sq);
	vec2 distorted_uv = (uv + (centered * (dist_sq * barrel_distortion)));
	vec2 dir = normalize(centered);
	vec2 offset = (dir * (dist * chromatic_aberration));
	float r = texture(screen_texture, (distorted_uv - offset)).r;
	float g = texture(screen_texture, distorted_uv).g;
	float b = texture(screen_texture, (distorted_uv + offset)).b;
	vec3 col = vec3(r, g, b);
	float vig = smoothstep(vignette_radius, (vignette_radius - vignette_softness), dist);
	col = (col * vig);
	COLOR = vec4(col, 1.0);
}

