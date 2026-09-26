shader_type canvas_item;

render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int transition_type : hint_range(0, 4) = 4;
uniform vec4 transition_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform vec4 burn_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform float burn_size : hint_range(0.01, 0.2) = 0.05;
uniform sampler2D mask_texture;

void fragment() {
	vec2 uv = UV;
	float cutoff = 0.0;
	switch (transition_type) {
		case 0:
			cutoff = uv.x;
			break;
		case 1:
			cutoff = uv.y;
			break;
		case 2:
			float center_dist = (abs((uv.x - 0.5)) + abs((uv.y - 0.5)));
			cutoff = center_dist;
			break;
		case 3:
			vec2 dir = (uv - vec2(0.5, 0.5));
			float angle = atan(dir.y, dir.x);
			cutoff = ((angle + 3.14159) / (2.0 * 3.14159));
			break;
		default:
			cutoff = texture(mask_texture, uv).r;
			break;
	}
	float is_solid;
	bool is_burn;
	float edge_factor;
	if ((progress <= 0.001)) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else if ((progress >= 0.999)) {
		COLOR = transition_color;
	} else {
		is_solid = (cutoff < progress);
		is_burn = ((cutoff >= progress) && (cutoff < (progress + burn_size)));
		if (is_solid) {
			COLOR = transition_color;
		} else if (is_burn) {
			edge_factor = (1.0 - ((cutoff - progress) / burn_size));
			COLOR = mix(burn_color, transition_color, edge_factor);
		} else {
			COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		}
	}
}

