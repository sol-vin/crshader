shader_type canvas_item;

render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
group_uniforms Fog Properties;
uniform float fog_density : hint_range(0.001, 0.2, 0.005) = 0.04;
uniform vec4 fog_color : source_color = vec4(0.65, 0.75, 0.9, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform vec3 sun_direction = vec3(0.5, 0.6, -0.6);
group_uniforms Raymarching;
uniform int ray_steps : hint_range(8, 64, 4) = 24;
uniform float scattering_g : hint_range(-0.9, 0.9, 0.05) = 0.45;
uniform float max_distance : hint_range(5.0, 100.0, 5.0) = 40.0;

float hg_phase(float cos_theta, float g) {
	float g2 = (g * g);
	float num = (1.0 - g2);
	float denom = ((4.0 * 3.14159265) * pow(((1.0 + g2) - ((2.0 * g) * cos_theta)), 1.5));
	return (num / max(denom, 0.0001));
}

void fragment() {
	float scene_color = texture(screen_tex, SCREEN_UV);
	float depth_val = texture(depth_tex, SCREEN_UV).x;
	vec3 ray_dir = normalize(vec3(((SCREEN_UV.x - 0.5) * 1.6), ((0.5 - SCREEN_UV.y) * 1.2), -1.0));
	vec3 sun_dir = normalize(sun_direction);
	float cos_theta = dot(ray_dir, sun_dir);
	float phase = hg_phase(cos_theta, scattering_g);
	float step_len = (max_distance / float(ray_steps));
	float accum_density = 0.0;
	vec3 accum_light = vec3(0.0, 0.0, 0.0);
	for (int i = 0; i <= 23; i++) {
		float dist = (float(i) * step_len);
		float sample_density = (fog_density * exp((-dist * 0.03)));
		accum_density = (accum_density + (sample_density * step_len));
		accum_light = (accum_light + (((sun_color.rgb * phase) * sample_density) * step_len));
	}
	float transmittance = clamp(exp(-accum_density), 0.0, 1.0);
	vec3 final_rgb = ((scene_color.rgb * transmittance) + ((fog_color.rgb * (1.0 - transmittance)) + accum_light));
	COLOR = vec4(final_rgb, 1.0);
}

