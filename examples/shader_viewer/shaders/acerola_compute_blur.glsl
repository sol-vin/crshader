#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba32f, set = 0, binding = 0) uniform image2D input_image;
layout(rgba32f, set = 0, binding = 1) uniform image2D output_image;

layout(set = 1, binding = 0) uniform int blur_radius;
layout(set = 1, binding = 1) uniform float blur_strength;

void main() {
	ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
	float img_size = imageSize(input_image);
	if (((pixel_coord.x >= img_size.x) || (pixel_coord.y >= img_size.y))) {
		return;
	}
	vec4 accum_color = vec4(0.0);
	float total_weight = 0.0;
	for (int ox = -blur_radius; ox <= blur_radius; ox++) {
		for (int oy = -blur_radius; oy <= blur_radius; oy++) {
			ivec2 sample_coord = (pixel_coord + ivec2(ox, oy));
			sample_coord = clamp(sample_coord, ivec2(0, 0), (img_size - ivec2(1, 1)));
			float dist_sq = float(((ox * ox) + (oy * oy)));
			float weight = exp((-dist_sq / (((2.0 * blur_strength) * blur_strength) + 0.0001)));
			float color = imageLoad(input_image, sample_coord);
			accum_color += (color * weight);
			total_weight += weight;
		}
	}
	vec4 final_color = (accum_color / max(total_weight, 0.0001));
	imageStore(output_image, pixel_coord, final_color);
}

