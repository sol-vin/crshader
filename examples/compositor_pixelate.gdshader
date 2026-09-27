shader_type compute;

uniform int pixel_size : hint_range(1, 32) = 6;
uniform float grid_strength : hint_range(0.0, 1.0, 0.05) = 0.15;

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID().xy);
	float size = imageSize(color_image());
	if (((pos.x >= size.x) || (pos.y >= size.y))) {
		return;
	}
	ivec2 block_origin = ((pos / pixel_size) * pixel_size);
	ivec2 center_pos = (block_origin + ivec2((pixel_size / 2), (pixel_size / 2)));
	center_pos = clamp(center_pos, ivec2(0, 0), (size - ivec2(1, 1)));
	float sampled = imageLoad(color_image(), center_pos);
	bool is_border = (((pos.x % pixel_size) == 0) || ((pos.y % pixel_size) == 0));
	vec3 darkened;
	if ((is_border && (grid_strength > 0.0))) {
		darkened = (sampled.rgb * (1.0 - (grid_strength * 0.4)));
		imageStore(color_image(), pos, vec4(darkened, sampled.a));
	} else {
		imageStore(color_image(), pos, sampled);
	}
}

