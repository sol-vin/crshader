#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const vec2 OUTLINE_DIRS_24[24] = vec2[](vec2(0.0, -1.0), vec2(0.0, 1.0), vec2(-1.0, 0.0), vec2(1.0, 0.0), vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0, 1.0), vec2(0.0, -2.0), vec2(2.0, 0.0), vec2(-2.0, 0.0), vec2(0.0, 2.0), vec2(-1.0, -2.0), vec2(1.0, -2.0), vec2(-1.0, 2.0), vec2(1.0, 2.0), vec2(-2.0, -1.0), vec2(2.0, -1.0), vec2(-2.0, 1.0), vec2(2.0, 1.0), vec2(-2.0, -2.0), vec2(2.0, -2.0), vec2(-2.0, 2.0), vec2(2.0, 2.0));

layout(set = 0, binding = 3, std140) uniform CrShaderSceneData {
	mat4 INV_PROJECTION_MATRIX;
	mat4 PROJECTION_MATRIX;
	mat4 INV_VIEW_MATRIX;
	mat4 VIEW_MATRIX;
	vec2 VIEWPORT_SIZE;
	float TIME;
	float _crshader_scene_pad0;
};

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

layout(set = 0, binding = 1) uniform sampler2D depth_texture;
layout(set = 0, binding = 2) uniform sampler2D normal_roughness_texture;

layout(push_constant, std430) uniform CrShaderParams {
	vec4 outline_color;
	float outline_thickness;
	int sample_directions;
	float depth_threshold;
	float normal_threshold;
	float grazing_scale;
	float boil_amp;
	float boil_freq;
};

float outline_boiling_scale(vec2 uv, float time, float boil_amp, float boil_freq) {
	float boil;
	if ((boil_amp <= 0.0)) {
		return 1.0;
	} else {
		boil = (sin((((uv.x * boil_freq) * 6.2831853) + (time * 12.0))) * cos((((uv.y * boil_freq) * 6.2831853) - (time * 9.0))));
		return max(0.1, (1.0 + (boil * boil_amp)));
	}
}

vec3 reconstruct_view_pos(vec2 uv, float raw_depth, mat4 inv_proj) {
	vec3 ndc = vec3(((uv * 2.0) - 1.0), raw_depth);
	vec4 view_h = (inv_proj * vec4(ndc, 1.0));
	return (view_h.xyz / max(abs(view_h.w), 0.000001));
}

vec3 unpack_view_normal(vec3 encoded_rgb) {
	float len_sq = dot(encoded_rgb, encoded_rgb);
	return (((len_sq < 0.00001)) ? (vec3(0.0, 0.0, 1.0)) : (normalize(((encoded_rgb * 2.0) - 1.0))));

}

vec4 unpack_normal_roughness(vec4 raw) {
	vec3 n = unpack_view_normal(raw.xyz);
	float r = (((raw.w > 0.5)) ? (((1.0 - raw.w) * 2.0)) : ((raw.w * 2.0)));
	return vec4(n, clamp(r, 0.0, 1.0));
}

float grazing_depth_scale(vec3 view_normal, vec3 view_dir, float grazing_strength) {
	float ndotv = clamp(abs(dot(view_normal, view_dir)), 0.0, 1.0);
	return (1.0 + ((1.0 - ndotv) * grazing_strength));
}

float linear_depth_reverse_z(vec2 uv, float raw_depth, mat4 inv_proj) {
	return -reconstruct_view_pos(uv, raw_depth, inv_proj).z;
}

bool is_depth_edge(float z_center, float z_neighbor, float threshold, float grazing_mult) {
	float rel_diff = (abs((z_center - z_neighbor)) / max(min(z_center, z_neighbor), 0.001));
	return (rel_diff > (threshold * grazing_mult));
}

void main() {
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(color_image);
	if (((coord.x >= size.x) || (coord.y >= size.y))) {
		return;
	}
	vec2 uv = ((vec2(float(coord.x), float(coord.y)) + vec2(0.5, 0.5)) / vec2(float(size.x), float(size.y)));
	vec4 color = imageLoad(color_image, coord);
	float raw_d = texelFetch(depth_texture, coord, 0).r;
	float boil;
	float radius_px;
	ivec2 max_c;
	vec2 pixel_uv;
	vec3 view_pos;
	float d_center;
	vec4 nr_center;
	vec3 n_center;
	vec3 view_dir;
	float grazing_mult;
	int tap_count;
	float max_crease;
	bool hit_depth;
	vec3 blended;
	if ((raw_d > 0.00001)) {
		boil = outline_boiling_scale(uv, TIME, boil_amp, boil_freq);
		radius_px = max((outline_thickness * boil), 0.5);
		max_c = (size - ivec2(1, 1));
		pixel_uv = (vec2(1.0, 1.0) / vec2(float(size.x), float(size.y)));
		view_pos = reconstruct_view_pos(uv, raw_d, INV_PROJECTION_MATRIX);
		d_center = -view_pos.z;
		nr_center = unpack_normal_roughness(texelFetch(normal_roughness_texture, coord, 0));
		n_center = nr_center.xyz;
		view_dir = normalize(-view_pos);
		grazing_mult = grazing_depth_scale(n_center, view_dir, grazing_scale);
		tap_count = clamp(sample_directions, 4, 24);
		max_crease = 0.0;
		hit_depth = false;
		for (int i = 0; i < 24; i++) {
			vec2 dir;
			ivec2 offset_px;
			ivec2 n_coord;
			vec2 n_uv;
			float n_raw_d;
			float n_depth;
			vec4 n_nr;
			float crease;
			if ((i < tap_count)) {
				dir = OUTLINE_DIRS_24[i];
				offset_px = ivec2(int(round((dir.x * radius_px))), int(round((dir.y * radius_px))));
				n_coord = clamp((coord + offset_px), ivec2(0, 0), max_c);
				n_uv = clamp((uv + ((dir * pixel_uv) * radius_px)), vec2(0.0005), vec2(0.9995));
				n_raw_d = texelFetch(depth_texture, n_coord, 0).r;
				n_depth = linear_depth_reverse_z(n_uv, n_raw_d, INV_PROJECTION_MATRIX);
				if (is_depth_edge(d_center, n_depth, depth_threshold, grazing_mult)) {
					hit_depth = true;
				}
				n_nr = unpack_normal_roughness(texelFetch(normal_roughness_texture, n_coord, 0));
				crease = (1.0 - clamp(dot(n_center, n_nr.xyz), -1.0, 1.0));
				max_crease = max(max_crease, crease);
			}
		}
		if ((hit_depth || (max_crease > normal_threshold))) {
			blended = mix(color.rgb, outline_color.rgb, outline_color.a);
			color = vec4(blended, color.a);
		}
	}
	imageStore(color_image, coord, color);
}

