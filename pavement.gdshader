shader_type spatial;
// Street surfaces of the Times Square island (district_nyc.gd), patterned in
// world space so pieces line up:
//   COLOR.rgb  base colour (sRGB)
//   COLOR.a    surface: 0.0 sidewalk flags, 0.1 plaza pavers with steel discs,
//              0.2 asphalt, 0.3 hexagonal pavers, 0.4 granite, 0.5 road paint,
//              0.6 granite setts, 0.7 lawn

uniform bool lightweight = false;

varying vec3 world_pos;
varying vec3 v_tint;
varying float v_kind;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_tint = pow(COLOR.rgb, vec3(2.2));
	v_kind = COLOR.a * 10.0;
}

float line_mask(float x, float width, float fw) {
	float d = abs(fract(x) - 0.5) * 2.0;
	return smoothstep(1.0 - width - fw, 1.0 - width + fw, d);
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 fw = max(fwidth(p), vec2(0.001));
	float far_fade = 1.0 - smoothstep(0.08, 0.35, max(fw.x, fw.y));
	vec3 col = v_tint;
	float rough = 0.9;
	int kind = int(v_kind + 0.5);
	float grime = 0.25;
	if (!lightweight) {
		grime = noise(p * 0.35) * 0.5 + noise(p * 2.1) * 0.25;
	}

	if (kind == 0) {
		// Concrete sidewalk flags, 1.5 m, with dark joints and the odd darker slab.
		vec2 cell = floor(p / 1.5);
		col *= 0.9 + hash(cell) * 0.16 - grime * 0.1;
		float joint = max(line_mask(p.x / 1.5 + 0.5, 0.025, fw.x / 1.5), line_mask(p.y / 1.5 + 0.5, 0.025, fw.y / 1.5));
		col = mix(col, col * 0.55, joint * far_fade);
		// Flattened chewing gum.
		if (!lightweight) {
			float gum = step(0.985, hash(floor(p / 0.22))) * far_fade;
			col = mix(col, col * 0.6, gum * 0.6);
		}
	} else if (kind == 1) {
		// Times Square plaza: dark pre-cast pavers set with little steel discs.
		vec2 q = p / vec2(0.6, 1.2);
		vec2 cell = floor(q + vec2(floor(q.y) * 0.5, 0.0));
		col *= 0.85 + hash(cell) * 0.25 - grime * 0.08;
		float joint = max(line_mask(q.x + floor(q.y) * 0.5 + 0.5, 0.04, fw.x / 0.6), line_mask(q.y + 0.5, 0.03, fw.y / 1.2));
		col = mix(col, col * 0.6, joint * far_fade);
		rough = 0.85;
		if (!lightweight) {
			vec2 dp = fract(p / 1.8) - 0.5;
			float disc = (1.0 - smoothstep(0.03, 0.04, length(dp))) * step(0.7, hash(floor(p / 1.8))) * far_fade;
			col = mix(col, vec3(0.75, 0.76, 0.78), disc);
			rough = mix(0.85, 0.25, disc);
		}
	} else if (kind == 2) {
		// Asphalt: speckled, patched, darker in the wheel tracks.
		if (lightweight) {
			col *= 0.88 + noise(p * 0.35) * 0.18;
		} else {
			col *= 0.82 + noise(p * 6.0) * 0.18 + grime * 0.25;
			float patch = smoothstep(0.62, 0.64, noise(p * 0.12 + 7.0));
			col = mix(col, col * 0.75, patch);
		}
		rough = 0.92;
	} else if (kind == 3) {
		// Hexagonal pavers of the waterfront promenade.
		vec2 q = p / 0.5;
		vec2 r = vec2(1.0, 1.732);
		vec2 h = r * 0.5;
		vec2 a = mod(q, r) - h;
		vec2 b = mod(q - h, r) - h;
		vec2 g = dot(a, a) < dot(b, b) ? a : b;
		vec2 gid = q - g;
		col *= 0.85 + hash(floor(gid * 2.0)) * 0.2 - grime * 0.1;
		vec2 g2 = abs(g);
		float edge = max(dot(g2, normalize(vec2(1.0, 1.732))), g2.x);
		col = mix(col, col * 0.55, smoothstep(0.44, 0.48, edge) * far_fade);
	} else if (kind == 4) {
		col *= 0.92 + hash(floor(p / 0.9)) * 0.12;
		rough = 0.7;
	} else if (kind == 6) {
		vec2 q = p / vec2(0.62, 0.36);
		q.x += mod(floor(q.y), 2.0) * 0.5;
		col *= 0.84 + hash(floor(q)) * 0.23;
		float joint = max(line_mask(q.x + 0.5, 0.045, fw.x / 0.62), line_mask(q.y + 0.5, 0.05, fw.y / 0.36));
		col = mix(col, col * 0.58, joint * far_fade);
	} else if (kind == 7) {
		col *= 0.74 + noise(p * 0.55) * 0.22 + hash(floor(p * 18.0)) * 0.15;
	} else {
		col *= 0.92 + noise(p * 9.0) * 0.1;
		rough = 0.7;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
