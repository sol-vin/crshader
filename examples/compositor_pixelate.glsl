#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

layout(set = 1, binding = 0) uniform int pixel_size;
layout(set = 1, binding = 1) uniform float grid_strength;

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	float size = imageSize(color_image);
	if (((pos.x >= size.x) || (pos.y >= size.y))) {
		return;
	}
	ivec2 block_origin = ((pos / pixel_size) * pixel_size);
	ivec2 center_pos = (block_origin + ivec2((pixel_size / 2), (pixel_size / 2)));
	center_pos = clamp(center_pos, ivec2(0, 0), (size - ivec2(1, 1)));
	float sampled = imageLoad(color_image, center_pos);
	bool is_border = (((pos.x % pixel_size) == 0) || ((pos.y % pixel_size) == 0));
	vec3 darkened;
	if ((is_border && (grid_strength > 0.0))) {
		darkened = (sampled.rgb * (1.0 - (grid_strength * 0.4)));
		imageStore(color_image, pos, vec4(darkened, sampled.a));
	} else {
		imageStore(color_image, pos, sampled);
	}
}

