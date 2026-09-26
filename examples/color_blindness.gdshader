shader_type canvas_item;

render_mode unshaded;

const mat3 PROTANOPIA_MAT = mat3(vec3(0.56667, 0.43333, 0.0), vec3(0.55833, 0.44167, 0.0), vec3(0.0, 0.24167, 0.75833));
const mat3 DEUTERANOPIA_MAT = mat3(vec3(0.625, 0.375, 0.0), vec3(0.70, 0.30, 0.0), vec3(0.0, 0.30, 0.70));
const mat3 TRITANOPIA_MAT = mat3(vec3(0.95, 0.05, 0.0), vec3(0.0, 0.433, 0.567), vec3(0.0, 0.475, 0.525));

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform int mode : hint_range(0, 4) = 1;
uniform float severity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 orig_col = texture(screen_texture, uv).rgb;
	vec3 sim_col = orig_col;
	switch (mode) {
		case 1:
			sim_col = (PROTANOPIA_MAT * orig_col);
			break;
		case 2:
			sim_col = (DEUTERANOPIA_MAT * orig_col);
			break;
		case 3:
			sim_col = (TRITANOPIA_MAT * orig_col);
			break;
		case 4:
			float gray = dot(orig_col, vec3(0.299, 0.587, 0.114));
			sim_col = vec3(gray, gray, gray);
			break;
		default:
			sim_col = orig_col;
			break;
	}
	vec3 final_col = mix(orig_col, sim_col, severity);
	COLOR = vec4(final_col, 1.0);
}

