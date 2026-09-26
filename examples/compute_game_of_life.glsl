#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba32f, set = 0, binding = 0) uniform image2D state_in;
layout(rgba32f, set = 0, binding = 1) uniform image2D state_out;

void main() {
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
	float size = imageSize(state_in);
	if (((coord.x >= size.x) || (coord.y >= size.y))) {
		return;
	}
	int live_neighbors = 0;
	for (int dx = -1; dx <= 1; dx++) {
		for (int dy = -1; dy <= 1; dy++) {
			ivec2 neighbor_coord;
			float cell;
			if (((dx != 0) || (dy != 0))) {
				neighbor_coord = (((coord + ivec2(dx, dy)) + size) % size);
				cell = imageLoad(state_in, neighbor_coord);
				if ((cell.r > 0.5)) {
					live_neighbors += 1;
				}
			}
		}
	}
	float current_cell = imageLoad(state_in, coord);
	float currently_alive = (current_cell.r > 0.5);
	bool next_alive = false;
	if (currently_alive) {
		if (((live_neighbors == 2) || (live_neighbors == 3))) {
			next_alive = true;
		}
	} else if ((live_neighbors == 3)) {
		next_alive = true;
	}
	vec4 out_col = ((next_alive) ? (vec4(1.0, 1.0, 1.0, 1.0)) : (vec4(0.0, 0.0, 0.0, 1.0)));
	imageStore(state_out, coord, out_col);
}

