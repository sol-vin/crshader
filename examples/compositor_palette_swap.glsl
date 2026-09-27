#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

const int original_palette_size = 16;
layout(set = 1, binding = 0) uniform vec4 original_palette[16];
const int target_palette_size = 16;
layout(set = 1, binding = 1) uniform vec4 target_palette[16];
layout(set = 1, binding = 2) uniform float dither_strength;

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	float size = imageSize(color_image);
	if (((pos.x >= size.x) || (pos.y >= size.y))) {
		return;
	}
	float curr_color = imageLoad(color_image, pos);
	int best_idx = 0;
	float min_dist = 999999.0;
	for (int i = 0; i < original_palette.length(); i++) {
		vec3 orig = original_palette[i].rgb;
		float d = distance(curr_color.rgb, orig);
		if ((d < min_dist)) {
			min_dist = d;
			best_idx = i;
		}
	}
	vec3 out_rgb = target_palette[best_idx].rgb;
	imageStore(color_image, pos, vec4(out_rgb, curr_color.a));
}

