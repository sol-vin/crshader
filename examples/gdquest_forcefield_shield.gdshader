shader_type spatial;

render_mode cull_disabled, depth_draw_opaque;

uniform vec4 shield_color : source_color = vec4(0.2, 0.6, 1.0, 0.7);
uniform vec4 rim_color : source_color = vec4(0.6, 0.9, 1.0, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float pulse_speed : hint_range(0.1, 10.0) = 3.0;
uniform float pulse_frequency = 15.0;
uniform float hex_scale = 20.0;
uniform sampler2D depth_texture : hint_depth_texture;

void fragment() {
	float fresnel = pow((1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0)), rim_power);
	float ripple = ((sin(((UV.y * pulse_frequency) - (TIME * pulse_speed))) * 0.5) + 0.5);
	vec2 grid_uv = (UV * hex_scale);
	vec2 hex_coord = abs((fract(grid_uv) - 0.5));
	float hex_line = smoothstep(0.45, 0.50, max(hex_coord.x, hex_coord.y));
	float screen_depth = texture(depth_texture, SCREEN_UV).r;
	float depth_diff = abs((screen_depth - FRAGCOORD.z));
	float intersection_glow = smoothstep(0.02, 0.0, depth_diff);
	float glow_factor = clamp((((fresnel + (hex_line * 0.4)) + (ripple * 0.3)) + (intersection_glow * 0.8)), 0.0, 1.0);
	vec3 final_rgb = mix(shield_color.rgb, rim_color.rgb, glow_factor);
	ALBEDO = final_rgb;
	EMISSION = (final_rgb * (glow_factor * 2.0));
	ALPHA = clamp((shield_color.a * (0.3 + (glow_factor * 0.7))), 0.0, 1.0);
}

