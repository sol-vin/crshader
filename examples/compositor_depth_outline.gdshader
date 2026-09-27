shader_type compute;

uniform vec4 outline_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform int outline_thickness : hint_range(1, 4) = 1;
uniform float depth_threshold : hint_range(0.0001, 0.05, 0.0005) = 0.005;

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID().xy);
	float size = imageSize(color_image());
	if (((pos.x >= size.x) || (pos.y >= size.y))) {
		return;
	}
	float center_depth = imageLoad(depth_image(), pos).r;
	float d_up = imageLoad(depth_image(), (pos + ivec2(0, -outline_thickness))).r;
	float d_down = imageLoad(depth_image(), (pos + ivec2(0, outline_thickness))).r;
	float d_left = imageLoad(depth_image(), (pos + ivec2(-outline_thickness, 0))).r;
	float d_right = imageLoad(depth_image(), (pos + ivec2(outline_thickness, 0))).r;
	float depth_diff = (((abs((center_depth - d_up)) + abs((center_depth - d_down))) + abs((center_depth - d_left))) + abs((center_depth - d_right)));
	float curr_color = imageLoad(color_image(), pos);
	if ((depth_diff > depth_threshold)) {
		imageStore(color_image(), pos, vec4(outline_color.rgb, 1.0));
	} else {
		imageStore(color_image(), pos, curr_color);
	}
}

