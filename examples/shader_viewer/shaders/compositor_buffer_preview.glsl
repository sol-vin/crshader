#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(r32f, set = 0, binding = 1) uniform image2D depth_image;

layout(set = 1, binding = 0) uniform int preview_mode;
layout(set = 1, binding = 1) uniform float z_near;
layout(set = 1, binding = 2) uniform float z_far;

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	float size = imageSize(color_image);
	if (((pos.x >= size.x) || (pos.y >= size.y))) {
		return;
	}
	float curr_color = imageLoad(color_image, pos);
	float depth_val = imageLoad(depth_image, pos).r;
	float lin;
	float lin_norm;
	float lum;
	if ((preview_mode == 1)) {
		imageStore(color_image, pos, vec4(depth_val, depth_val, depth_val, 1.0));
	} else if ((preview_mode == 2)) {
		lin = ((z_near * z_far) / (z_far + (depth_val * (z_near - z_far))));
		lin_norm = clamp((lin / z_far), 0.0, 1.0);
		imageStore(color_image, pos, vec4(lin_norm, lin_norm, lin_norm, 1.0));
	} else if ((preview_mode == 3)) {
		lum = (((0.2126 * curr_color.r) + (0.7152 * curr_color.g)) + (0.0722 * curr_color.b));
		imageStore(color_image, pos, vec4(lum, lum, lum, 1.0));
	} else {
		imageStore(color_image, pos, curr_color);
	}
}

