shader_type spatial;

render_mode cull_disabled, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(0.8, 0.2, 0.3, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.4;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float wave_speed = 2.0;
uniform float wave_height = 0.15;

varying vec3 v_world_normal;

void vertex() {
	v_world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float offset = (sin(((TIME * wave_speed) + (VERTEX.x * 2.0))) * wave_height);
	VERTEX.y=((VERTEX.y + offset));
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}

