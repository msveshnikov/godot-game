shader_type spatial;
// Tree crowns (MultiMesh with per-instance colour): sway in the wind, more at the top,
// each tree out of step with its neighbours; leaves shimmer slightly.

uniform float sway : hint_range(0.0, 0.3) = 0.07;
uniform float gust_speed = 1.3;
uniform bool street_foliage = false;

varying vec3 tint;
varying vec3 canopy_position;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = origin.x * 0.21 + origin.z * 0.17;
	if (street_foliage) {
		vec3 unit_position = VERTEX;
		float lobes = sin(unit_position.x * 13.0 + phase) * sin(unit_position.y * 12.0) * cos(unit_position.z * 11.0);
		VERTEX *= 1.0 + 0.10 * lobes;
		canopy_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
	float gust = 0.6 + 0.4 * sin(TIME * 0.31 + origin.x * 0.02);
	float lift = clamp(VERTEX.y + 1.0, 0.0, 2.0); // 0 at the crown's base, 2 at its top
	VERTEX.x += sin(TIME * gust_speed + phase) * sway * lift * gust;
	VERTEX.z += cos(TIME * gust_speed * 0.8 + phase * 1.3) * sway * 0.6 * lift * gust;
	tint = COLOR.rgb;
}

void fragment() {
	vec3 linear_tint = pow(tint, vec3(2.2));
	if (street_foliage) {
		vec3 grain = canopy_position * 17.0;
		float leaves = sin(grain.x + grain.z * 0.65) * sin(grain.y) * cos(grain.z);
		float clusters = sin(grain.x * 0.15 + grain.y * 0.07) * cos(grain.z * 0.2);
		linear_tint *= 0.89 + 0.24 * leaves + 0.19 * clusters;
		EMISSION = linear_tint * 0.40;
	}
	ALBEDO = linear_tint;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	BACKLIGHT = linear_tint * 0.35;
}
