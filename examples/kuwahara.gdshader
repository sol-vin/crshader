shader_type canvas_item;

render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform int radius : hint_range(1, 8) = 4;
uniform float sharpness : hint_range(0.1, 5.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 tex_size = vec2(textureSize(screen_texture, 0));
	vec2 inv_size = (vec2(1.0, 1.0) / tex_size);
	vec3 m0 = vec3(0.0, 0.0, 0.0);
	vec3 m1 = vec3(0.0, 0.0, 0.0);
	vec3 m2 = vec3(0.0, 0.0, 0.0);
	vec3 m3 = vec3(0.0, 0.0, 0.0);
	vec3 s0 = vec3(0.0, 0.0, 0.0);
	vec3 s1 = vec3(0.0, 0.0, 0.0);
	vec3 s2 = vec3(0.0, 0.0, 0.0);
	vec3 s3 = vec3(0.0, 0.0, 0.0);
	float n = float(((radius + 1) * (radius + 1)));
	for (int j = -radius; j <= 0; j++) {
		for (int i = -radius; i <= 0; i++) {
			vec3 c = texture(screen_texture, (uv + (vec2(float(i), float(j)) * inv_size))).rgb;
			m0 = (m0 + c);
			s0 = (s0 + (c * c));
		}
	}
	for (int j = -radius; j <= 0; j++) {
		for (int i = 0; i <= radius; i++) {
			vec3 c = texture(screen_texture, (uv + (vec2(float(i), float(j)) * inv_size))).rgb;
			m1 = (m1 + c);
			s1 = (s1 + (c * c));
		}
	}
	for (int j = 0; j <= radius; j++) {
		for (int i = -radius; i <= 0; i++) {
			vec3 c = texture(screen_texture, (uv + (vec2(float(i), float(j)) * inv_size))).rgb;
			m2 = (m2 + c);
			s2 = (s2 + (c * c));
		}
	}
	for (int j = 0; j <= radius; j++) {
		for (int i = 0; i <= radius; i++) {
			vec3 c = texture(screen_texture, (uv + (vec2(float(i), float(j)) * inv_size))).rgb;
			m3 = (m3 + c);
			s3 = (s3 + (c * c));
		}
	}
	m0 = (m0 / n);
	s0 = abs(((s0 / n) - (m0 * m0)));
	float v0 = ((s0.x + s0.y) + s0.z);
	m1 = (m1 / n);
	s1 = abs(((s1 / n) - (m1 * m1)));
	float v1 = ((s1.x + s1.y) + s1.z);
	m2 = (m2 / n);
	s2 = abs(((s2 / n) - (m2 * m2)));
	float v2 = ((s2.x + s2.y) + s2.z);
	m3 = (m3 / n);
	s3 = abs(((s3 / n) - (m3 * m3)));
	float v3 = ((s3.x + s3.y) + s3.z);
	float min_val = v0;
	vec3 final_col = m0;
	if ((v1 < min_val)) {
		min_val = v1;
		final_col = m1;
	}
	if ((v2 < min_val)) {
		min_val = v2;
		final_col = m2;
	}
	if ((v3 < min_val)) {
		min_val = v3;
		final_col = m3;
	}
	COLOR = vec4(final_col, 1.0);
}

