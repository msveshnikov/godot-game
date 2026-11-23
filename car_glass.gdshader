shader_type spatial;
// Car windows after a bat blow (car_damage.gd): tempered glass crazes into a mesh
// of little cubes round each blow, and where it was hit twice it has crumbled.
// hits[i] = (point in the car's own space, strength: 0 none, 1 crazed, 2 crumbled).

uniform vec4 hits[8];
uniform vec3 tint : source_color = vec3(0.05, 0.07, 0.09);

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

// Distance to the nearest edge between cells of a 3D Voronoi pattern (F2 - F1).
float cell_edge(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int z = -1; z <= 1; z++)
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = hash3(i + g);
		float d = length(g + o - f);
		if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
	}
	return f2 - f1;
}

void fragment() {
	vec3 col = tint;
	float rough = 0.05;
	float craze = 0.0;
	float crumble = 0.0;
	for (int k = 0; k < 8; k++) {
		vec4 h = hits[k];
		if (h.w <= 0.0) continue;
		float d = distance(v_local, h.xyz);
		float reach = 0.3 + 0.28 * h.w;
		craze = max(craze, 1.0 - smoothstep(reach * 0.55, reach, d));
		if (h.w > 1.5) crumble = max(crumble, 1.0 - smoothstep(0.22, 0.34, d));
	}
	if (craze > 0.0) {
		float fine = cell_edge(v_local * 34.0);
		float coarse = cell_edge(v_local * 9.0 + 3.7);
		float lines = max(1.0 - smoothstep(0.0, 0.12, fine), (1.0 - smoothstep(0.0, 0.06, coarse)) * 0.9);
		col = mix(col, vec3(0.78, 0.82, 0.84), lines * craze * 0.8);
		col = mix(col, vec3(0.42, 0.46, 0.48), craze * 0.25);
		rough = mix(rough, 0.45, craze * 0.6);
	}
	if (crumble > 0.0) {
		// Most of it fallen in: dark car interior with a few crumbs still stuck in the frame.
		float crumbs = step(0.62, hash3(floor(v_local * 40.0)).x);
		col = mix(col, mix(vec3(0.015, 0.015, 0.018), vec3(0.6, 0.65, 0.66), crumbs * 0.6), crumble);
		rough = mix(rough, 0.8, crumble);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.3;
	SPECULAR = 0.7;
}
