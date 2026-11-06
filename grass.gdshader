shader_type spatial;

render_mode cull_disabled, fog_disabled;

uniform vec3 grass_dark : source_color = vec3(0.12, 0.31, 0.16);
uniform vec3 grass_mid : source_color = vec3(0.25, 0.47, 0.23);
uniform vec3 grass_light : source_color = vec3(0.46, 0.72, 0.36);

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

	ALBEDO = color;
	ROUGHNESS = 0.96;
	SPECULAR = 0.04;
}
