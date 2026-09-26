shader_type canvas_item;

render_mode unshaded;

const int original_palette_size = 4;
uniform vec4 original_palette[4];
const int target_palette_size = 4;
uniform vec4 target_palette[4];
uniform float threshold : hint_range(0.01, 1.0) = 0.25;

void fragment() {
	float input_color = texture(TEXTURE, UV);
	int best_idx = 0;
	float min_dist = 999.0;
	for (int i = 0; i < original_palette.length(); i++) {
		vec4 orig = original_palette[i];
		float d = distance(input_color.rgb, orig.rgb);
		if ((d < min_dist)) {
			min_dist = d;
			best_idx = i;
		}
	}
	if ((min_dist < threshold)) {
		COLOR = vec4(target_palette[best_idx].rgb, input_color.a);
	} else {
		COLOR = input_color;
	}
}

