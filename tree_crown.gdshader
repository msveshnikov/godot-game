shader_type spatial;
// Tree crowns (MultiMesh with per-instance colour): sway in the wind, more at the top,
// each tree out of step with its neighbours; leaves shimmer slightly.

uniform float sway : hint_range(0.0, 0.3) = 0.07;
uniform float gust_speed = 1.3;

varying vec3 tint;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = origin.x * 0.21 + origin.z * 0.17;
	float gust = 0.6 + 0.4 * sin(TIME * 0.31 + origin.x * 0.02);
	float lift = clamp(VERTEX.y + 1.0, 0.0, 2.0); // 0 at the crown's base, 2 at its top
	VERTEX.x += sin(TIME * gust_speed + phase) * sway * lift * gust;
	VERTEX.z += cos(TIME * gust_speed * 0.8 + phase * 1.3) * sway * 0.6 * lift * gust;
	tint = COLOR.rgb;
}

void fragment() {
	vec3 linear_tint = pow(tint, vec3(2.2));
	ALBEDO = linear_tint;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	BACKLIGHT = linear_tint * 0.35;
}
