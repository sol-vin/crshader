#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

layout(set = 0, binding = 1) uniform sampler2D depth_texture;
layout(set = 0, binding = 2) uniform sampler2D normal_roughness_texture;

layout(push_constant, std430) uniform CrShaderParams {
	int preview_mode;
	float z_near;
	float z_far;
};

float fast_linear_depth_reverse_z(float raw_depth, float z_near, float z_far) {
	return ((z_near * z_far) / max((z_near + (raw_depth * (z_far - z_near))), 0.00001));
}

vec3 unpack_view_normal(vec3 encoded_rgb) {
	float len_sq = dot(encoded_rgb, encoded_rgb);
	return (((len_sq < 0.00001)) ? (vec3(0.0, 0.0, 1.0)) : (normalize(((encoded_rgb * 2.0) - 1.0))));

}

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(color_image);
	if (((pos.x >= size.x) || (pos.y >= size.y))) {
		return;
	}
	vec4 curr_color = imageLoad(color_image, pos);
	float depth_val = texelFetch(depth_texture, pos, 0).r;
	float lin;
	float lin_norm;
	float lum;
	vec3 n;
	if ((preview_mode == 1)) {
		curr_color = vec4(depth_val, depth_val, depth_val, 1.0);
	} else if ((preview_mode == 2)) {
		lin = fast_linear_depth_reverse_z(depth_val, z_near, z_far);
		lin_norm = clamp((lin / z_far), 0.0, 1.0);
		curr_color = vec4(lin_norm, lin_norm, lin_norm, 1.0);
	} else if ((preview_mode == 3)) {
		lum = (((0.2126 * curr_color.r) + (0.7152 * curr_color.g)) + (0.0722 * curr_color.b));
		curr_color = vec4(lum, lum, lum, 1.0);
	} else if ((preview_mode == 4)) {
		n = ((unpack_view_normal(texelFetch(normal_roughness_texture, pos, 0).xyz) * 0.5) + vec3(0.5, 0.5, 0.5));
		curr_color = vec4(n, 1.0);
	}
	imageStore(color_image, pos, curr_color);
}

