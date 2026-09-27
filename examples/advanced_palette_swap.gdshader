shader_type canvas_item;

render_mode unshaded;

const int original_palette_size = 16;
uniform vec4 original_palette[16];
const int target_palette_size = 16;
uniform vec4 target_palette[16];
uniform float dither_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform int color_distance_mode : hint_range(0, 10, 1) = 0;
uniform float input_lightness : hint_range(-1.0, 1.0, 0.01) = 0.0;
uniform float input_saturation : hint_range(0.0, 3.0, 0.01) = 1.0;
uniform float input_contrast : hint_range(0.0, 3.0, 0.01) = 1.0;
uniform float input_red : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float input_green : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float input_blue : hint_range(0.0, 2.0, 0.01) = 1.0;

float redmean_dist(vec3 c1, vec3 c2) {
	float rbar = (0.5 * (c1.r + c2.r));
	float dr = (c1.r - c2.r);
	float dg = (c1.g - c2.g);
	float db = (c1.b - c2.b);
	float weight_r = (2.0 + rbar);
	float weight_g = 4.0;
	float weight_b = (3.0 - rbar);
	return sqrt(((((weight_r * dr) * dr) + ((weight_g * dg) * dg)) + ((weight_b * db) * db)));
}

float luminance(vec3 c) {
	return (((0.2126 * c.r) + (0.7152 * c.g)) + (0.0722 * c.b));
}

float bayer4(int x, int y) {
	float m0 = (0.0 / 16.0);
	float m1 = (8.0 / 16.0);
	float m2 = (2.0 / 16.0);
	float m3 = (10.0 / 16.0);
	float m4 = (12.0 / 16.0);
	float m5 = (4.0 / 16.0);
	float m6 = (14.0 / 16.0);
	float m7 = (6.0 / 16.0);
	float m8 = (3.0 / 16.0);
	float m9 = (11.0 / 16.0);
	float m10 = (1.0 / 16.0);
	float m11 = (9.0 / 16.0);
	float m12 = (15.0 / 16.0);
	float m13 = (7.0 / 16.0);
	float m14 = (13.0 / 16.0);
	float m15 = (5.0 / 16.0);
	int idx = (((y % 4) * 4) + (x % 4));
	if ((idx == 0)) {
		return m0;
	} else if ((idx == 1)) {
		return m1;
	} else if ((idx == 2)) {
		return m2;
	} else if ((idx == 3)) {
		return m3;
	} else if ((idx == 4)) {
		return m4;
	} else if ((idx == 5)) {
		return m5;
	} else if ((idx == 6)) {
		return m6;
	} else if ((idx == 7)) {
		return m7;
	} else if ((idx == 8)) {
		return m8;
	} else if ((idx == 9)) {
		return m9;
	} else if ((idx == 10)) {
		return m10;
	} else if ((idx == 11)) {
		return m11;
	} else if ((idx == 12)) {
		return m12;
	} else if ((idx == 13)) {
		return m13;
	} else if ((idx == 14)) {
		return m14;
	} else {
		return m15;
	}
}

float color_dist(vec3 c1, vec3 c2, int mode) {
	float l1;
	float l2;
	float w1;
	float w2;
	if ((mode == 1)) {
		return redmean_dist(c1, c2);
	} else if ((mode == 2)) {
		return distance(c1, c2);
	} else if ((mode == 6)) {
		l1 = luminance(c1);
		l2 = luminance(c2);
		return abs((l1 - l2));
	} else if ((mode == 8)) {
		w1 = (c1.r - c1.b);
		w2 = (c2.r - c2.b);
		return (abs((w1 - w2)) + (0.5 * distance(c1, c2)));
	} else {
		return distance(c1, c2);
	}
}

void fragment() {
	float raw_color = texture(TEXTURE, UV);
	vec3 adj = (raw_color.rgb * vec3(input_red, input_green, input_blue));
	adj = (((adj - vec3(0.5, 0.5, 0.5)) * input_contrast) + vec3(0.5, 0.5, 0.5));
	float lum = luminance(adj);
	adj = mix(vec3(lum, lum, lum), adj, input_saturation);
	adj = clamp((adj + vec3(input_lightness, input_lightness, input_lightness)), 0.0, 1.0);
	int px;
	int py;
	float dither;
	if ((dither_strength > 0.0)) {
		px = int(FRAGCOORD.x);
		py = int(FRAGCOORD.y);
		dither = (((bayer4(px, py) - 0.5) * dither_strength) * 0.25);
		adj = clamp((adj + vec3(dither, dither, dither)), 0.0, 1.0);
	}
	int best_idx = 0;
	float min_dist = 999999.0;
	for (int i = 0; i < original_palette.length(); i++) {
		vec3 orig = original_palette[i].rgb;
		float d = color_dist(adj, orig, color_distance_mode);
		if ((d < min_dist)) {
			min_dist = d;
			best_idx = i;
		}
	}
	vec3 out_color = target_palette[best_idx].rgb;
	COLOR = vec4(out_color, raw_color.a);
}

