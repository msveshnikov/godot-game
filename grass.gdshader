shader_type spatial;

render_mode cull_disabled, fog_disabled;

uniform vec3 grass_dark : source_color = vec3(0.12, 0.31, 0.16);
uniform vec3 grass_mid : source_color = vec3(0.25, 0.47, 0.23);
uniform vec3 grass_light : source_color = vec3(0.46, 0.72, 0.36);

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

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dune = fbm(world_pos.xz * 0.16 + vec2(2.0, 7.0));
	float wobble = sin(world_pos.x * 0.37 + TIME * 0.55) * 0.02;
	wobble += cos(world_pos.z * 0.31 - TIME * 0.42) * 0.02;
	VERTEX.y += (dune - 0.5) * 0.13 + wobble;
}

void fragment() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float field = fbm(world_pos.xz * 0.11 + vec2(5.0, 9.0));
	float patches = smoothstep(0.2, 0.85, field);
	vec3 color = mix(grass_dark, grass_mid, patches);
	color = mix(color, grass_light, smoothstep(0.6, 1.0, field) * 0.6);
	ALBEDO = color;
	ROUGHNESS = 0.96;
	SPECULAR = 0.04;
}
