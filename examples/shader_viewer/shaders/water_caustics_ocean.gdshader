shader_type spatial;

render_mode cull_disabled, depth_draw_always;

group_uniforms Water Colors;
uniform vec4 shallow_color : source_color = vec4(0.2, 0.75, 0.85, 0.85);
uniform vec4 deep_color : source_color = vec4(0.05, 0.15, 0.35, 0.95);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
group_uniforms Waves & Motion;
uniform float wave_speed : hint_range(0.1, 5.0, 0.1) = 1.4;
uniform float wave_height : hint_range(0.0, 1.0, 0.05) = 0.25;
uniform float wave_frequency : hint_range(0.5, 6.0, 0.1) = 1.8;
group_uniforms Caustics & Optics;
uniform float caustics_scale : hint_range(1.0, 20.0, 0.5) = 8.0;
uniform float caustics_speed : hint_range(0.1, 3.0, 0.1) = 0.8;
uniform float roughness_val : hint_range(0.0, 1.0, 0.05) = 0.15;

varying vec3 v_world_pos;

vec2 hash22(vec2 p) {
	vec3 p3 = fract((vec3(p.x, p.y, p.x) * vec3(0.1031, 0.1030, 0.0973)));
	p3 += dot(p3, (p3.yzx + 33.33));
	return fract(((p3.xx + p3.yz) * p3.zy));
}

float voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float min_dist = 8.0;
	vec2 diff_0 = (hash22(n) - f);
	min_dist = min(min_dist, length(diff_0));
	vec2 diff_1 = ((hash22((n + vec2(1.0, 0.0))) + vec2(1.0, 0.0)) - f);
	min_dist = min(min_dist, length(diff_1));
	vec2 diff_2 = ((hash22((n + vec2(0.0, 1.0))) + vec2(0.0, 1.0)) - f);
	min_dist = min(min_dist, length(diff_2));
	vec2 diff_3 = ((hash22((n + vec2(1.0, 1.0))) + vec2(1.0, 1.0)) - f);
	min_dist = min(min_dist, length(diff_3));
	return min_dist;
}

float fresnel(float power, vec3 normal, vec3 view) {
	return pow(clamp((1.0 - dot(normal, view)), 0.0, 1.0), power);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = (TIME * wave_speed);
	float wave1 = (sin(((v_world_pos.x * wave_frequency) + t)) * wave_height);
	float wave2 = ((cos((((v_world_pos.z * wave_frequency) * 0.8) + (t * 1.2))) * wave_height) * 0.6);
	VERTEX.y=(((VERTEX.y + wave1) + wave2));
}

void fragment() {
	float t_caustic = (TIME * caustics_speed);
	vec2 uv_c1 = (((v_world_pos.xz * caustics_scale) * 0.1) + vec2((t_caustic * 0.1), (t_caustic * 0.05)));
	vec2 uv_c2 = (((v_world_pos.xz * caustics_scale) * 0.15) - vec2((t_caustic * 0.08), (-t_caustic * 0.12)));
	float c1 = voronoi(uv_c1);
	float c2 = voronoi(uv_c2);
	float caustic_val = min(c1, c2);
	float caustic_intensity = (smoothstep(0.4, 0.1, caustic_val) * 0.4);
	vec3 view_dir = normalize(VIEW);
	float fresnel_term = fresnel(4.0, NORMAL, view_dir);
	vec3 water_col = (mix(deep_color.rgb, shallow_color.rgb, fresnel_term) + vec3(caustic_intensity, caustic_intensity, caustic_intensity));
	ALBEDO = water_col;
	ROUGHNESS = roughness_val;
	METALLIC = 0.1;
	SPECULAR = 0.6;
}

