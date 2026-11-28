shader_type spatial;
render_mode cull_back;
// The open sea round the Times Square island: rolling swell, small chop, sky
// reflection by Fresnel, and a band of foam where the waves slap the sea wall.

uniform vec3 deep_color : source_color = vec3(0.03, 0.12, 0.17);
uniform vec3 shallow_color : source_color = vec3(0.07, 0.25, 0.3);
uniform vec3 sky_color : source_color = vec3(0.62, 0.74, 0.86);
uniform vec2 island_centre = vec2(0.0, 0.0);
uniform vec2 island_half = vec2(300.0, 300.0);
uniform float island_corner = 24.0;
uniform bool lightweight = false;

varying vec3 world_pos;
varying vec2 wave_slope;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// Swell: a few long sine waves; returns height and its slope.
vec3 swell(vec2 p, float t) {
	vec3 r = vec3(0.0);
	vec2 dirs[4] = vec2[](vec2(0.8, 0.6), vec2(-0.3, 0.95), vec2(0.97, -0.24), vec2(-0.7, -0.7));
	float lens[4] = float[](38.0, 23.0, 15.0, 9.0);
	float amps[4] = float[](0.32, 0.18, 0.1, 0.05);
	for (int i = 0; i < 4; i++) {
		float k = 6.2831 / lens[i];
		float ph = dot(dirs[i], p) * k + t * sqrt(9.8 * k);
		r.x += amps[i] * sin(ph);
		r.yz += amps[i] * k * cos(ph) * dirs[i];
	}
	return r;
}

float wall_distance(vec2 p) {
	vec2 q = abs(p - island_centre) - (island_half - vec2(island_corner));
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - island_corner;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float calm = smoothstep(2.0, 30.0, wall_distance(w.xz));
	vec3 s = swell(w.xz, TIME);
	VERTEX.y += s.x * (0.35 + 0.65 * calm);
	world_pos = w;
	wave_slope = s.yz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = TIME;
	float d = wall_distance(p);
	vec2 slope;
	float foam;
	if (lightweight) {
		slope = wave_slope + sin(p.yx * vec2(0.43, 0.65) + t * vec2(1.5, -1.2)) * 0.075;
		float edge = d + 0.4 * sin(dot(p, vec2(1.5, 0.7)) - t * 2.0);
		foam = (1.0 - smoothstep(0.0, 2.2, edge)) * step(-0.5, d) * 0.7;
	} else {
		vec3 s = swell(p, t);
		// Chop: two scrolling noise layers for small ripples.
		float e = 0.6;
		vec2 q1 = p * 0.35 + vec2(t * 0.35, t * 0.2);
		vec2 q2 = p * 0.9 - vec2(t * 0.25, -t * 0.4);
		float n0 = noise(q1) + 0.5 * noise(q2);
		float nx = noise(q1 + vec2(e, 0.0)) + 0.5 * noise(q2 + vec2(e, 0.0));
		float nz = noise(q1 + vec2(0.0, e)) + 0.5 * noise(q2 + vec2(0.0, e));
		slope = s.yz + vec2(nx - n0, nz - n0) * 0.55;
		// Foam against the sea wall and on crests.
		float lace = noise(p * 1.7 + vec2(t * 0.8, -t * 0.4));
		float foam_line = (1.0 - smoothstep(0.0, 2.2, d + noise(p * 0.6 + t * 0.5) * 1.5)) * step(-0.5, d) * (0.55 + 0.45 * lace);
		float crest = smoothstep(0.55, 0.7, s.x + n0 * 0.1) * smoothstep(0.55, 0.8, noise(p * 0.21 + t * 0.05)) * 0.5;
		foam = clamp(foam_line + crest * lace, 0.0, 1.0);
	}
	vec3 n_world = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fres = pow(1.0 - clamp(dot(view_dir, n_world), 0.0, 1.0), 4.0);
	vec3 water = mix(shallow_color, deep_color, smoothstep(0.0, 60.0, d));
	water = mix(water, sky_color, clamp(fres * 0.9, 0.0, 0.85));
	water = mix(water, vec3(0.88, 0.92, 0.94), foam);

	ALBEDO = water;
	ROUGHNESS = mix(0.06, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
