shader_type spatial;
// Dresses the Cogito mannequin: skin, T-shirt, shorts or jeans, shoes, hair and
// a simple face. Regions are picked from the vertex's rest-pose (T-pose)
// position, stored in CUSTOM0 by villager_outfit.gd, so clothes stay put while
// the skeleton animates.

uniform vec3 skin_color : source_color = vec3(0.86, 0.66, 0.52);
uniform vec3 hair_color : source_color = vec3(0.2, 0.13, 0.08);
uniform vec3 shirt_color : source_color = vec3(0.8, 0.2, 0.2);
uniform vec3 stripe_color : source_color = vec3(1.0);
uniform vec3 pants_color : source_color = vec3(0.2, 0.3, 0.5);
uniform vec3 shoe_color : source_color = vec3(0.95);
uniform float stripes = 0.0;       // 1 = horizontally striped shirt
uniform float hem_height = 0.62;   // trouser hem; ~0.13 = long trousers
uniform float sleeve_end = 0.33;   // |x| where sleeves stop; ~0.7 = long sleeves
uniform float long_hair = 0.0;
uniform float denim = 0.0;         // twill weave on the trousers

varying vec3 rest;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	rest = CUSTOM0.xyz;
}

void fragment() {
	vec3 p = rest;
	float ax = abs(p.x);
	vec3 color = skin_color;
	float rough = 0.6;
	float cloth = 0.0;

	bool arm = ax > 0.19 && p.y > 1.28 && p.y < 1.56;
	bool head = p.y > 1.535 && ax < 0.11;

	if (p.y < 0.118) {
		// Shoes, with a pale sole.
		color = p.y < 0.025 ? vec3(0.92, 0.9, 0.86) : shoe_color;
		rough = 0.45;
	} else if (arm) {
		if (ax < sleeve_end) {
			color = shirt_color;
			cloth = 1.0;
		}
	} else if (head) {
		bool hair = p.y > 1.755 - 0.03 * smoothstep(0.0, -0.1, p.z)
			|| (p.z < -0.035 && p.y > 1.6)
			|| (ax > 0.075 && p.y > 1.69 && p.z < 0.05);
		if (long_hair > 0.5 && p.z < -0.02 && p.y > 1.5) {
			hair = true;
		}
		if (hair) {
			color = hair_color * (0.85 + 0.3 * noise(p * vec3(160.0, 30.0, 160.0)));
			rough = 0.8;
		} else if (p.z > 0.05) {
			// Face: eyes, brows and mouth.
			vec2 eye = vec2(ax - 0.034, (p.y - 1.705) * 1.25);
			float eye_distance = length(eye);
			if (eye_distance < 0.0075) {
				color = vec3(0.04);
				rough = 0.2;
			} else if (eye_distance < 0.0135) {
				color = vec3(0.93, 0.92, 0.9);
				rough = 0.25;
			} else if (abs(ax - 0.036) < 0.018 && abs(p.y - 1.728) < 0.0045) {
				color = hair_color * 0.8;
			} else if (ax < 0.022 && abs(p.y - 1.632) < 0.004) {
				color = skin_color * vec3(0.7, 0.42, 0.42);
			}
		}
	} else if (long_hair > 0.5 && p.z < -0.05 && ax < 0.1 - 0.9 * max(1.53 - p.y, 0.0) && p.y > 1.43) {
		color = hair_color;
		rough = 0.8;
	} else if (p.y < 0.995) {
		if (p.y > hem_height) {
			color = pants_color;
			cloth = 2.0;
			if (p.y > 0.955) {
				color = mix(pants_color, vec3(0.1), 0.6); // belt
			}
		}
	} else if (p.y < 1.49 || (ax > 0.085 && p.y < 1.535)) {
		color = shirt_color;
		cloth = 1.0;
		if (stripes > 0.5 && fract(p.y * 11.0) < 0.42) {
			color = stripe_color;
		}
	}

	if (cloth > 0.5) {
		// Woven fabric: fine grain plus soft wrinkles.
		float grain = noise(p * 260.0);
		float wrinkle = noise(p * vec3(14.0, 40.0, 14.0));
		float shade = 0.9 + 0.12 * grain + 0.1 * wrinkle;
		if (cloth > 1.5 && denim > 0.5) {
			shade *= 0.88 + 0.16 * step(0.5, fract((p.y + ax) * 150.0));
		}
		color *= shade;
		rough = 0.9;
	}

	ALBEDO = color;
	ROUGHNESS = rough;
}
