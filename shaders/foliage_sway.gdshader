shader_type spatial;
// Wind sway for foliage drawn as MultiMesh instances of LowPoly.cross_strip: willow fronds
// hanging from a branch (mesh from y = 0 down to -1) or reeds and grass standing up
// (0 to 1). The free end moves most. Coloured with a pixel texture projected in world
// space, like the rest of the scenery.
render_mode cull_disabled, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tip_color : source_color = vec4(1.0);
uniform float pixels_per_meter = 20.0;
uniform float texture_size = 32.0;
uniform bool hanging = true;
uniform float sway = 0.2; // metres at the free end
uniform float speed = 1.0;

varying vec3 world_pos;
varying float along;

void vertex() {
	along = clamp(hanging ? -VERTEX.y : VERTEX.y, 0.0, 1.0);
	vec3 root = MODEL_MATRIX[3].xyz;
	float t = TIME * speed + root.x * 0.6 + root.z * 0.4;
	vec3 offset = vec3(sin(t), 0.0, cos(t * 0.73) * 0.6) * along * along * sway;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + offset;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset, 0.0)).xyz;
}

void fragment() {
	vec2 uv = vec2(world_pos.x + world_pos.z, world_pos.y) * pixels_per_meter / texture_size;
	vec3 colour = texture(albedo_tex, uv).rgb;
	ALBEDO = mix(colour, colour * tip_color.rgb, along);
	ROUGHNESS = 0.9;
}
