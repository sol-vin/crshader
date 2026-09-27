shader_type spatial;

render_mode cull_back, diffuse_toon, specular_toon;

group_uniforms Base Material;
uniform vec4 base_color : source_color = vec4(0.85, 0.45, 0.65, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.35, 0.25, 0.5, 1.0);
uniform float roughness_val : hint_range(0.0, 1.0, 0.05) = 0.4;
group_uniforms Toon Ramping;
uniform float diffuse_steps : hint_range(1.0, 5.0, 1.0) = 3.0;
uniform float shadow_threshold : hint_range(0.0, 1.0, 0.05) = 0.45;
uniform float shadow_softness : hint_range(0.01, 0.5, 0.01) = 0.08;
group_uniforms Specular & Rim;
uniform float specular_size : hint_range(0.01, 0.5, 0.01) = 0.15;
uniform float specular_gloss : hint_range(4.0, 64.0, 2.0) = 32.0;
uniform float rim_power : hint_range(0.5, 8.0, 0.5) = 3.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);

float fresnel(float power, vec3 normal, vec3 view) {
	return pow(clamp((1.0 - dot(normal, view)), 0.0, 1.0), power);
}

float cel_shade(float n_dot_l, float steps) {
	return (floor((clamp(n_dot_l, 0.0, 1.0) * steps)) / steps);
}

float blinn_phong(vec3 normal, vec3 light_dir, vec3 view_dir, float shininess) {
	vec3 half_dir = normalize((light_dir + view_dir));
	return pow(clamp(dot(normal, half_dir), 0.0, 1.0), shininess);
}

void fragment() {
	vec3 view_dir = normalize(VIEW);
	float fresnel_term = fresnel(rim_power, NORMAL, view_dir);
	ALBEDO = (base_color.rgb + ((rim_color.rgb * fresnel_term) * 0.5));
	ROUGHNESS = roughness_val;
	SPECULAR = 0.2;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	float ramp = smoothstep((shadow_threshold - shadow_softness), (shadow_threshold + shadow_softness), n_dot_l);
	float stepped_ramp = cel_shade(ramp, diffuse_steps);
	vec3 diffuse_col = mix(shadow_tint.rgb, LIGHT_COLOR, stepped_ramp);
	float spec = blinn_phong(NORMAL, LIGHT, VIEW, specular_gloss);
	float spec_stepped = step((1.0 - specular_size), spec);
	DIFFUSE_LIGHT = (diffuse_col * ATTENUATION);
	SPECULAR_LIGHT = ((spec_stepped * LIGHT_COLOR) * ATTENUATION);
}

