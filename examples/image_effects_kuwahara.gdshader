shader_type canvas_item;

render_mode unshaded;

uniform sampler2D screen_texture : filter_linear;
uniform int radius : hint_range(1, 6) = 3;

void fragment() {
	vec2 uv = UV;
	float tex_size = textureSize(screen_texture, 0);
	vec2 step_size = (vec2(1.0) / vec2(float(tex_size.x), float(tex_size.y)));
	vec3 m0 = vec3(0.0);
	vec3 m1 = vec3(0.0);
	vec3 m2 = vec3(0.0);
	vec3 m3 = vec3(0.0);
	vec3 s0 = vec3(0.0);
	vec3 s1 = vec3(0.0);
	vec3 s2 = vec3(0.0);
	vec3 s3 = vec3(0.0);
	float n = float(((radius + 1) * (radius + 1)));
	for (int j = -radius; j <= 0; j++) {
		for (int i = -radius; i <= 0; i++) {
			vec3 col = texture(screen_texture, (uv + (vec2(float(i), float(j)) * step_size))).rgb;
			m0 += col;
			s0 += (col * col);
		}
	}
	for (int j = -radius; j <= 0; j++) {
		for (int i = 0; i <= radius; i++) {
			vec3 col = texture(screen_texture, (uv + (vec2(float(i), float(j)) * step_size))).rgb;
			m1 += col;
			s1 += (col * col);
		}
	}
	for (int j = 0; j <= radius; j++) {
		for (int i = -radius; i <= 0; i++) {
			vec3 col = texture(screen_texture, (uv + (vec2(float(i), float(j)) * step_size))).rgb;
			m2 += col;
			s2 += (col * col);
		}
	}
	for (int j = 0; j <= radius; j++) {
		for (int i = 0; i <= radius; i++) {
			vec3 col = texture(screen_texture, (uv + (vec2(float(i), float(j)) * step_size))).rgb;
			m3 += col;
			s3 += (col * col);
		}
	}
	m0 = (m0 / n);
	m1 = (m1 / n);
	m2 = (m2 / n);
	m3 = (m3 / n);
	vec3 v0 = abs(((s0 / n) - (m0 * m0)));
	vec3 v1 = abs(((s1 / n) - (m1 * m1)));
	vec3 v2 = abs(((s2 / n) - (m2 * m2)));
	vec3 v3 = abs(((s3 / n) - (m3 * m3)));
	float val0 = ((v0.r + v0.g) + v0.b);
	float val1 = ((v1.r + v1.g) + v1.b);
	float val2 = ((v2.r + v2.g) + v2.b);
	float val3 = ((v3.r + v3.g) + v3.b);
	float min_val = val0;
	vec3 result = m0;
	if ((val1 < min_val)) {
		min_val = val1;
		result = m1;
	}
	if ((val2 < min_val)) {
		min_val = val2;
		result = m2;
	}
	if ((val3 < min_val)) {
		min_val = val3;
		result = m3;
	}
	COLOR = vec4(result, 1.0);
}

