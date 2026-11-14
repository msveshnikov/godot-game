shader_type spatial;

render_mode cull_disabled;

uniform vec3 grass_dark : source_color = vec3(0.12, 0.31, 0.16);
uniform vec3 grass_mid : source_color = vec3(0.25, 0.47, 0.23);
uniform vec3 grass_light : source_color = vec3(0.46, 0.72, 0.36);
uniform vec2 grass_exclusion_center = vec2(0.0);
uniform vec2 grass_exclusion_half_extents = vec2(7.1);
// Autumn: fallen leaves scattered over the grass, thicker in drifts.
uniform float leaf_density : hint_range(0.0, 1.0) = 0.55;
uniform vec3 autumn_tint : source_color = vec3(0.62, 0.58, 0.3);
uniform float autumn_amount : hint_range(0.0, 1.0) = 0.28;

varying vec3 world_position;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 5; octave++) {
		value += noise(p) * amplitude;
		p = p * 2.06 + vec2(16.7, 10.4);
		amplitude *= 0.5;
	}
	return value;
}

float blade_shape(vec2 local, vec2 origin, float angle, float length, float width) {
	vec2 direction = vec2(cos(angle), sin(angle));
	vec2 offset = local - origin;
	float along = dot(offset, direction);
	float side = abs(dot(offset, vec2(-direction.y, direction.x)));
	float taper = mix(width, width * 0.12, clamp(along / length, 0.0, 1.0));
	float edge = max(fwidth(side), 0.002);
	float blade = 1.0 - smoothstep(taper - edge, taper + edge, side);
	float ends = smoothstep(0.0, edge * 2.0, along)
		* (1.0 - smoothstep(length - edge * 2.0, length, along));
	return blade * ends;
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dune = fbm(world_pos.xz * 0.16 + vec2(2.0, 7.0));
	VERTEX.y += (dune - 0.5) * 0.08;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 room_offset = abs(world_position.xz - grass_exclusion_center);
	if (room_offset.x < grass_exclusion_half_extents.x
		&& room_offset.y < grass_exclusion_half_extents.y) {
		discard;
	}

	float field = fbm(world_position.xz * 0.24 + vec2(5.0, 9.0));
	float fine_variation = noise(world_position.xz * 2.2);
	float patches = smoothstep(0.2, 0.85, field);
	vec3 color = mix(grass_dark, grass_mid, patches);
	color = mix(color, grass_light, smoothstep(0.6, 1.0, field) * 0.45);
	color *= mix(0.78, 1.12, fine_variation);

	vec2 blade_grid = world_position.xz * 8.0;
	vec2 blade_cell = floor(blade_grid);
	vec2 blade_local = fract(blade_grid);
	for (int i = 0; i < 3; i++) {
		vec2 seed = blade_cell + vec2(float(i) * 17.13, float(i) * 31.71);
		vec2 origin = vec2(hash(seed), hash(seed + vec2(7.1, 3.7))) * 0.72 + 0.14;
		float angle = hash(seed + vec2(11.4, 8.2)) * 6.2831853;
		float blade_length = mix(0.38, 0.78, hash(seed + vec2(2.3, 5.9)));
		float blade_width = mix(0.018, 0.032, hash(seed + vec2(4.8, 1.6)));
		float blade = blade_shape(blade_local, origin, angle, blade_length, blade_width);
		vec3 blade_color = mix(grass_mid, grass_light, hash(seed + vec2(9.2, 6.4)) * 0.75);
		color = mix(color, blade_color, blade * 0.9);
	}

	// Autumn: sun-dried patches of grass.
	float dry = smoothstep(0.35, 0.75, fbm(world_position.xz * 0.05 + vec2(31.0, 7.0)));
	color = mix(color, color * 0.55 + autumn_tint * 0.45, dry * autumn_amount);

	// Fallen leaves: one candidate leaf per 0.4 m cell, two layers; more where the drift noise is high.
	float drift = smoothstep(0.25, 0.8, fbm(world_position.xz * 0.11 + vec2(3.0, 41.0)));
	float chance = leaf_density * mix(0.18, 0.85, drift);
	for (int layer = 0; layer < 2; layer++) {
		vec2 grid = world_position.xz * 2.5 + vec2(float(layer) * 0.37, float(layer) * 0.61);
		vec2 cell = floor(grid);
		vec2 local = fract(grid) - 0.5;
		vec2 seed = cell + vec2(float(layer) * 13.7, 5.3);
		if (hash(seed + vec2(2.1, 9.7)) < chance) {
			vec2 centre = (vec2(hash(seed), hash(seed + vec2(3.3, 1.1))) - 0.5) * 0.5;
			float angle = hash(seed + vec2(8.8, 4.4)) * 6.2831853;
			vec2 axis = vec2(cos(angle), sin(angle));
			vec2 p = local - centre;
			vec2 q = vec2(dot(p, axis), dot(p, vec2(-axis.y, axis.x)));
			float size = mix(0.13, 0.22, hash(seed + vec2(6.1, 2.7)));
			// Pointed leaf: ellipse narrowing towards both tips.
			float width = size * 0.42 * (1.0 - pow(abs(q.x) / size, 2.0));
			float edge = max(fwidth(q.y), 0.003);
			float leaf = (1.0 - smoothstep(width - edge, width + edge, abs(q.y))) * step(abs(q.x), size);
			float pick = hash(seed + vec2(1.9, 7.3));
			vec3 leaf_color = pick < 0.4 ? vec3(0.86, 0.66, 0.12)
				: pick < 0.68 ? vec3(0.82, 0.4, 0.08)
				: pick < 0.88 ? vec3(0.48, 0.3, 0.12)
				: vec3(0.66, 0.16, 0.07);
			leaf_color *= mix(0.75, 1.1, hash(seed + vec2(4.2, 3.9)));
			float vein = 1.0 - (1.0 - smoothstep(0.0, edge * 1.5, abs(q.y))) * 0.25; // darker midrib
			color = mix(color, leaf_color * vein, leaf);
		}
	}

	ALBEDO = color;
	ROUGHNESS = 0.96;
	SPECULAR = 0.04;
}
