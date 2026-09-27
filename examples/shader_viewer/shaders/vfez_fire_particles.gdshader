shader_type particles;

uniform float initial_speed : hint_range(1.0, 20.0) = 4.0;
uniform float spread_factor : hint_range(0.0, 5.0) = 1.2;
uniform float buoyancy_accel = 3.5;
uniform float turbulence_strength = 2.0;
uniform vec4 flame_start_color : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform vec4 flame_mid_color : source_color = vec4(0.95, 0.35, 0.05, 1.0);
uniform vec4 smoke_end_color : source_color = vec4(0.15, 0.15, 0.15, 0.0);

void start() {
	float rand_x = ((sin(((float(INDEX) * 12.9898) + SEED)) - 0.5) * spread_factor);
	float rand_z = ((cos(((float(INDEX) * 78.233) + SEED)) - 0.5) * spread_factor);
	float rand_speed = (initial_speed * (0.8 + (0.4 * fract((sin(float(INDEX)) * 43758.5453)))));
	VELOCITY = vec3(rand_x, rand_speed, rand_z);
	COLOR = flame_start_color;
}

void process() {
	float progress = clamp((1.0 - (LIFETIME / max((LIFETIME + DELTA), 0.001))), 0.0, 1.0);
	float swirl_x = (sin(((TIME * 4.0) + float(INDEX))) * turbulence_strength);
	float swirl_z = (cos(((TIME * 4.0) + float(INDEX))) * turbulence_strength);
	VELOCITY.x += (swirl_x * DELTA);
	VELOCITY.y += (buoyancy_accel * DELTA);
	VELOCITY.z += (swirl_z * DELTA);
	float factor;
	if ((progress < 0.4)) {
		factor = (progress / 0.4);
		COLOR = mix(flame_start_color, flame_mid_color, factor);
	} else {
		factor = ((progress - 0.4) / 0.6);
		COLOR = mix(flame_mid_color, smoke_end_color, factor);
	}
}

