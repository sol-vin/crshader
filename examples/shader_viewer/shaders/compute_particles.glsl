#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer ParticleBuffer {
	vec4 positions[];
	vec4 velocities[];
} particle_buffer;

layout(push_constant, std430) uniform Params {
	float delta_time;
	uint particle_count;
	vec3 gravity;
} params;

void main() {
	float idx = gl_GlobalInvocationID.x;
	if ((idx >= params.particle_count)) {
		return;
	}
	vec3 pos = particle_buffer.positions[idx].xyz;
	vec3 vel = particle_buffer.velocities[idx].xyz;
	vel = (vel + (params.gravity * params.delta_time));
	pos = (pos + (vel * params.delta_time));
	if ((pos.y < 0.0)) {
		pos.y=(0.0);
		vel.y=((-vel.y * 0.7));
	}
	particle_buffer.positions[idx] = vec4(pos, 1.0);
	particle_buffer.velocities[idx] = vec4(vel, 0.0);
}

