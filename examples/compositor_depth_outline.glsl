#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(r32f, set = 0, binding = 1) uniform image2D depth_image;

layout(set = 1, binding = 0) uniform vec4 outline_color;
layout(set = 1, binding = 1) uniform int outline_thickness;
layout(set = 1, binding = 2) uniform float depth_threshold;

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	float size = imageSize(color_image);
	if (((pos.x >= size.x) || (pos.y >= size.y))) {
		return;
	}
	float center_depth = imageLoad(depth_image, pos).r;
	float d_up = imageLoad(depth_image, (pos + ivec2(0, -outline_thickness))).r;
	float d_down = imageLoad(depth_image, (pos + ivec2(0, outline_thickness))).r;
	float d_left = imageLoad(depth_image, (pos + ivec2(-outline_thickness, 0))).r;
	float d_right = imageLoad(depth_image, (pos + ivec2(outline_thickness, 0))).r;
	float depth_diff = (((abs((center_depth - d_up)) + abs((center_depth - d_down))) + abs((center_depth - d_left))) + abs((center_depth - d_right)));
	float curr_color = imageLoad(color_image, pos);
	if ((depth_diff > depth_threshold)) {
		imageStore(color_image, pos, vec4(outline_color.rgb, 1.0));
	} else {
		imageStore(color_image, pos, curr_color);
	}
}

