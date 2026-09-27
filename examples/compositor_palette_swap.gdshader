shader_type compute;

const int original_palette_size = 16;
uniform vec4 original_palette[16];
const int target_palette_size = 16;
uniform vec4 target_palette[16];
uniform float dither_strength : hint_range(0.0, 1.0, 0.01) = 0.0;

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID().xy);
	float size = imageSize(color_image());
	if (((pos.x >= size.x) || (pos.y >= size.y))) {
		return;
	}
	float curr_color = imageLoad(color_image(), pos);
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
	imageStore(color_image(), pos, vec4(out_rgb, curr_color.a));
}

