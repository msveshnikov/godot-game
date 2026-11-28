shader_type sky;

// A static sky lets the renderer reuse its radiance map.
uniform vec3 zenith_color : source_color;
uniform vec3 horizon_color : source_color;
uniform vec3 sun_direction;
uniform vec3 sun_color : source_color;
uniform vec3 cloud_color : source_color;
uniform vec3 cloud_shadow_color : source_color;
uniform float cloud_cover;
uniform vec3 ground_color : source_color;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), f.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), f.x), f.y);
}

void sky() {
	float elevation = EYEDIR.y;
	if (elevation < 0.0) {
		COLOR = mix(horizon_color, ground_color, smoothstep(0.0, 0.25, -elevation));
	} else {
		vec3 sky_color = mix(horizon_color, zenith_color, smoothstep(0.0, 1.0, sqrt(elevation)));
		vec2 uv = EYEDIR.xz / (elevation + 0.12);
		float density = noise(uv * 1.3) * 0.7 + noise(uv * 3.4 + 17.0) * 0.3;
		float cloud = smoothstep(1.0 - cloud_cover, 1.18 - cloud_cover, density);
		vec3 cloud_rgb = mix(cloud_shadow_color, cloud_color, cloud);
		sky_color = mix(sky_color, cloud_rgb, cloud * 0.85 * smoothstep(0.0, 0.12, elevation));
		float alignment = max(dot(EYEDIR, normalize(sun_direction)), 0.0);
		float disc = smoothstep(0.99955, 0.9998, alignment);
		COLOR = sky_color + sun_color * (disc * 6.0 + pow(alignment, 24.0) * 0.18) * (1.0 - cloud * 0.85);
	}
}
