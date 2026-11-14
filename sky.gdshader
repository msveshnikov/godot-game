shader_type sky;
// Autumn afternoon sky: deep blue zenith, pale hazy horizon, drifting cumulus lit
// from the sun side with grey undersides, thin high cirrus, sun disc with halo.

uniform vec3 zenith_color : source_color = vec3(0.2, 0.42, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.8, 0.86, 0.93);
uniform vec3 sun_direction = vec3(0.2, 0.64, -0.74);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.78);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.99, 0.97);
uniform vec3 cloud_shadow_color : source_color = vec3(0.56, 0.6, 0.68);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.48;
uniform vec3 ground_color : source_color = vec3(0.36, 0.38, 0.33);

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
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

float cumulus(vec2 uv) {
	vec2 warp = vec2(fbm(uv * 0.7 + vec2(3.1, 1.7)), fbm(uv * 0.7 + vec2(8.3, 2.8))) - 0.5;
	float n = fbm(uv + warp * 0.9);
	return smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.22, n);
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	vec3 sun = normalize(sun_direction);
	float elevation = direction.y;

	if (elevation < 0.0) {
		// Below the horizon: hazy ground colour fading into the horizon haze.
		COLOR = mix(horizon_color, ground_color, smoothstep(0.0, 0.25, -elevation));
	} else {
		float up = pow(elevation, 0.55);
		vec3 sky_color = mix(horizon_color, zenith_color, smoothstep(0.0, 1.0, up));
		// Warm glow in the sun's half of the sky, and a bright haze band at the horizon.
		float sun_side = max(dot(normalize(vec3(direction.x, 0.0, direction.z)), normalize(vec3(sun.x, 0.0, sun.z))), 0.0);
		sky_color += vec3(0.16, 0.1, 0.03) * pow(sun_side, 3.0) * exp(-elevation * 3.0);
		sky_color = mix(sky_color, horizon_color * 1.05, exp(-elevation * 18.0) * 0.6);

		// Cumulus layer projected onto a dome, drifting slowly.
		vec2 uv = direction.xz / (elevation + 0.12) * 0.9 + vec2(TIME * 0.006, TIME * 0.0025);
		float cloud = cumulus(uv);
		// Lit from the sun: sample the density a little towards the sun for self-shadowing.
		float towards_sun = cumulus(uv + normalize(sun.xz + vec2(0.0001)) * 0.06);
		float lit = clamp(1.0 - (towards_sun - cloud) * 2.5 - towards_sun * 0.35, 0.0, 1.0);
		vec3 cloud_rgb = mix(cloud_shadow_color, cloud_color, lit);
		cloud_rgb += sun_color * pow(max(dot(direction, sun), 0.0), 8.0) * 0.35 * (1.0 - cloud);
		float fade = smoothstep(0.0, 0.12, elevation);
		sky_color = mix(sky_color, cloud_rgb, cloud * 0.92 * fade);

		// Thin cirrus streaks high up.
		vec2 cirrus_uv = direction.xz / (elevation + 0.35) * vec2(0.6, 2.6) + vec2(TIME * 0.003, 0.0);
		float cirrus = smoothstep(0.55, 0.85, fbm(cirrus_uv * 1.5)) * 0.35 * smoothstep(0.1, 0.4, elevation);
		sky_color = mix(sky_color, vec3(1.0), cirrus * (1.0 - cloud));

		// Sun disc, halo and wide glow (dimmed behind clouds).
		float alignment = dot(direction, sun);
		float disc = smoothstep(0.99955, 0.9998, alignment);
		float halo = pow(max(alignment, 0.0), 220.0) * 0.6 + pow(max(alignment, 0.0), 24.0) * 0.18;
		sky_color += sun_color * (disc * 6.0 + halo) * (1.0 - cloud * 0.85);
		COLOR = sky_color;
	}
}
