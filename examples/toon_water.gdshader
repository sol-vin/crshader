shader_type spatial;

render_mode cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.05, 0.25, 0.45, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.2, 0.7, 0.8, 1.0);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform float speed = 1.0;

varying vec3 v_world_pos;

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = ((f * f) * (3.0 - (2.0 * f)));
	float a = hash11((i.x + (i.y * 57.0)));
	float b = hash11(((i.x + 1.0) + (i.y * 57.0)));
	float c = hash11((i.x + ((i.y + 1.0) * 57.0)));
	float d = hash11(((i.x + 1.0) + ((i.y + 1.0) * 57.0)));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float hash11(float p) {
	vec3 p3 = fract((vec3(p, p, p) * 0.1031));
	p3 += dot(p3, (p3.yzx + 33.33));
	return fract(((p3.x + p3.y) * p3.z));
}

float fresnel(float power, vec3 normal, vec3 view) {
	return pow(clamp((1.0 - dot(normal, view)), 0.0, 1.0), power);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 p = (v_world_pos.xz * 0.5);
	float n_val = 0.0;
	n_val += (value_noise(((p * 1.0) + ((TIME * 0.2) * speed))) * (1.0 / 1.0));
	n_val += (value_noise(((p * 2.0) + ((TIME * 0.2) * speed))) * (1.0 / 2.0));
	n_val += (value_noise(((p * 3.0) + ((TIME * 0.2) * speed))) * (1.0 / 3.0));
	VERTEX.y=((VERTEX.y + (n_val * 0.2)));
}

void fragment() {
	float f = fresnel(3.0, NORMAL, VIEW);
	vec3 water_col = mix(deep_color.rgb, shallow_color.rgb, f);
	ALBEDO = water_col;
	ROUGHNESS = 0.1;
	METALLIC = 0.0;
}

