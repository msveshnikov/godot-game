shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.12, 0.29, 0.48);
uniform vec3 horizon_color : source_color = vec3(0.91, 0.55, 0.38);
uniform vec3 sun_direction = vec3(-0.4, 0.2, -0.9);
uniform vec3 sun_color : source_color = vec3(1.0, 0.79, 0.52);
uniform vec3 cloud_color : source_color = vec3(0.95, 0.76, 0.62);

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
	for (int octave = 0; octave < 4; octave++) {
		value += noise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float elevation = max(direction.y, 0.0);
	float sky_gradient = smoothstep(0.0, 0.88, elevation);
	vec3 sky_color = mix(horizon_color, zenith_color, sky_gradient);

	float horizon_glow = exp(-elevation * 7.0);
	sky_color += vec3(0.22, 0.12, 0.06) * horizon_glow;

	vec2 cloud_uv = direction.xz / max(direction.y + 0.3, 0.18);
	cloud_uv = cloud_uv * vec2(1.6, 1.15) + vec2(TIME * 0.008, TIME * 0.002);
	float cloud_noise = fbm(cloud_uv);
	float cloud_shape = smoothstep(0.53, 0.69, cloud_noise);
	float cloud_horizon_fade = 1.0 - smoothstep(0.62, 0.96, elevation);
	float cloud_alpha = cloud_shape * cloud_horizon_fade * 0.72;
	sky_color = mix(sky_color, cloud_color, cloud_alpha);

	float sun_alignment = dot(direction, normalize(sun_direction));
	float sun_disk = smoothstep(0.99972, 0.99993, sun_alignment);
	float sun_glow = pow(max(sun_alignment, 0.0), 32.0) * 0.24;
	sky_color += sun_color * (sun_disk + sun_glow);

	COLOR = sky_color;
}
