#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer ParticleData {
	vec4 positions[];
	vec4 velocities[];
} particle_data;

layout(push_constant, std430) uniform FlowParams {
	float delta_time;
	uint particle_count;
	float noise_scale;
	float flow_speed;
} flow_params;

void main() {
	float idx = gl_GlobalInvocationID.x;
	if ((idx >= flow_params.particle_count)) {
		return;
	}
	vec3 pos = particle_data.positions[idx].xyz;
	vec3 vel = particle_data.velocities[idx].xyz;
	vec3 p_scaled = (pos * flow_params.noise_scale);
	vec3 flow = vec3(sin((p_scaled.y + p_scaled.z)), cos((p_scaled.z + p_scaled.x)), sin((p_scaled.x + p_scaled.y)));
	vel = mix(vel, (flow * flow_params.flow_speed), 0.1);
	pos = (pos + (vel * flow_params.delta_time));
	if ((length(pos) > 10.0)) {
		pos = (pos * 0.1);
	}
	particle_data.positions[idx] = vec4(pos, 1.0);
	particle_data.velocities[idx] = vec4(vel, 0.0);
}

