#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

layout(set = 0, binding = 1) uniform sampler2D depth_texture;

layout(push_constant, std430) uniform CrShaderParams {
	vec4 outline_color;
	int outline_thickness;
	float depth_threshold;
};

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(color_image);
	if (((pos.x >= size.x) || (pos.y >= size.y))) {
		return;
	}
	vec4 curr_color = imageLoad(color_image, pos);
	ivec2 max_coord = (size - ivec2(1, 1));
	float center_depth = texelFetch(depth_texture, pos, 0).r;
	float d_up = texelFetch(depth_texture, clamp((pos + ivec2(0, -outline_thickness)), ivec2(0, 0), max_coord), 0).r;
	float d_down = texelFetch(depth_texture, clamp((pos + ivec2(0, outline_thickness)), ivec2(0, 0), max_coord), 0).r;
	float d_left = texelFetch(depth_texture, clamp((pos + ivec2(-outline_thickness, 0)), ivec2(0, 0), max_coord), 0).r;
	float d_right = texelFetch(depth_texture, clamp((pos + ivec2(outline_thickness, 0)), ivec2(0, 0), max_coord), 0).r;
	float depth_diff = (((abs((center_depth - d_up)) + abs((center_depth - d_down))) + abs((center_depth - d_left))) + abs((center_depth - d_right)));
	if ((depth_diff > depth_threshold)) {
		curr_color = vec4(outline_color.rgb, 1.0);
	}
	imageStore(color_image, pos, curr_color);
}

