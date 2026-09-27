shader_type spatial;

render_mode cull_disabled, depth_draw_opaque;

group_uniforms Base Appearance;
uniform vec4 albedo_color : source_color = vec4(0.15, 0.45, 0.85, 1.0);
uniform float roughness_val : hint_range(0.0, 1.0, 0.05) = 0.35;
group_uniforms Dissolve Burn;
uniform float dissolve_amount : hint_range(0.0, 1.0, 0.02) = 0.35;
uniform float noise_scale : hint_range(1.0, 16.0, 0.5) = 4.0;
uniform float burn_width : hint_range(0.01, 0.2, 0.01) = 0.08;
uniform vec4 burn_color : source_color = vec4(1.0, 0.45, 0.05, 1.0);
group_uniforms Hologram Scanlines;
uniform float holo_speed : hint_range(0.5, 10.0, 0.5) = 3.0;
uniform float holo_density : hint_range(5.0, 60.0, 1.0) = 30.0;
uniform float holo_intensity : hint_range(0.0, 1.0, 0.05) = 0.5;

varying vec3 v_world_pos;

float hash11(float p) {
	vec3 p3 = fract((vec3(p, p, p) * 0.1031));
	p3 += dot(p3, (p3.yzx + 33.33));
	return fract(((p3.x + p3.y) * p3.z));
}

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

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = value_noise((v_world_pos.xz * noise_scale));
	if ((n < dissolve_amount)) {
		discard;
	}
	float burn_factor = smoothstep(dissolve_amount, (dissolve_amount + burn_width), n);
	float edge_glow = ((1.0 - burn_factor) * 5.0);
	float scanline = ((sin(((v_world_pos.y * holo_density) + (TIME * holo_speed))) * 0.5) + 0.5);
	float holo_effect = (scanline * holo_intensity);
	vec3 base_rgb = (albedo_color.rgb + (vec3(holo_effect, holo_effect, holo_effect) * 0.3));
	vec3 emissive_rgb = (burn_color.rgb * edge_glow);
	ALBEDO = base_rgb;
	EMISSION = emissive_rgb;
	ROUGHNESS = roughness_val;
	METALLIC = 0.2;
}

