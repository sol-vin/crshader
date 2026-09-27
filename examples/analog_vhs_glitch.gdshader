shader_type canvas_item;

render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
group_uniforms Tracking & Jitter;
uniform float tracking_jitter : hint_range(0.0, 0.1, 0.005) = 0.015;
uniform float tape_crease_speed : hint_range(0.1, 3.0, 0.1) = 0.5;
group_uniforms Color Aberration;
uniform float rgb_shift : hint_range(0.0, 0.03, 0.001) = 0.006;
uniform float color_bleed : hint_range(0.0, 2.0, 0.1) = 0.8;
group_uniforms Curvature & Tube;
uniform float tube_curvature : hint_range(0.0, 0.5, 0.02) = 0.12;
uniform float vignette_strength : hint_range(0.0, 1.0, 0.05) = 0.35;

vec2 barrel_distortion(vec2 uv, float distortion) {
	vec2 d = (uv - vec2(0.5, 0.5));
	return (uv + ((d * dot(d, d)) * distortion));
}

vec2 scanline_jitter(vec2 uv, float time, float intensity) {
	float j = fract((sin(dot(vec2(floor((uv.y * 240.0)), time), vec2(12.9898, 78.233))) * 43758.5453));
	float offset = (((j - 0.5) * intensity) * step(0.92, j));
	return vec2((uv.x + offset), uv.y);
}

float rand() {
	return fract((sin(dot(vec2(0.123, 0.456), vec2(12.9898, 78.233))) * 43758.5453123));
}

float vignette(vec2 uv, float radius, float softness) {
	float d = length((uv - vec2(0.5, 0.5)));
	return smoothstep(radius, (radius - softness), d);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	uv = barrel_distortion(uv, tube_curvature);
	vec2 jittered_uv = scanline_jitter(uv, TIME, tracking_jitter);
	float noise_bar_y = fract((TIME * tape_crease_speed));
	float dist_to_bar = abs((uv.y - noise_bar_y));
	float noise_factor = (smoothstep(0.05, 0.0, dist_to_bar) * 0.15);
	jittered_uv.x=((jittered_uv.x + (noise_factor * rand(vec2(uv.y, TIME)))));
	float col_r = texture(screen_tex, (jittered_uv + vec2(rgb_shift, 0.0))).r;
	float col_g = texture(screen_tex, jittered_uv).g;
	float col_b = texture(screen_tex, (jittered_uv - vec2(rgb_shift, 0.0))).b;
	vec3 col = vec3(col_r, col_g, col_b);
	float vig = vignette(uv, 0.75, vignette_strength);
	COLOR = vec4((col * vig), 1.0);
}

