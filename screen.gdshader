shader_type spatial;
// The LED billboards of Times Square, all in one mesh (district_nyc.gd).
// The ads are painted once into an atlas (nyc_ads.gd); each screen flips between
// two of them with a slide, a slow zoom and a shine sweeping across, and shows
// its LED dots up close. Tickers scroll a text strip along the facade.
//   UV    screens: 0..1 across the panel (y down); tickers: (metres along, 0..1 down)
//   UV2   (ad A, ad B) atlas indices, or (strip index, -1) for a ticker
//   COLOR r = phase, g = 1 for a ticker, b = panel width / height / 8, a = brightness

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 atlas_px = vec2(2048.0, 2304.0);
uniform float period = 16.0;
uniform bool lightweight = false;

varying vec4 v_info;
varying vec2 v_ads;

void vertex() {
	v_info = COLOR;
	v_ads = UV2;
}

// Atlas rect (pixels) of ad `i`: 0-15 wide 512x256, 16-31 tall 256x512, 32-35 ticker strips 2048x64.
vec4 ad_rect(float i) {
	if (i < 15.5) {
		return vec4(mod(i, 4.0) * 512.0, floor(i / 4.0) * 256.0, 512.0, 256.0);
	} else if (i < 31.5) {
		float j = i - 16.0;
		return vec4(mod(j, 8.0) * 256.0, 1024.0 + floor(j / 8.0) * 512.0, 256.0, 512.0);
	}
	return vec4(0.0, 2048.0 + (i - 32.0) * 64.0, 2048.0, 64.0);
}

vec3 sample_ad(float i, vec2 uv, float aspect, float zoom) {
	vec4 r = ad_rect(i);
	float ad_aspect = r.z / r.w;
	vec2 q = uv - 0.5;
	// Cover the panel: crop the ad to the panel's shape instead of stretching it.
	if (aspect > ad_aspect) q.y *= ad_aspect / aspect; else q.x *= aspect / ad_aspect;
	q /= zoom;
	vec2 px = r.xy + (q + 0.5) * r.zw;
	px = clamp(px, r.xy + 1.0, r.xy + r.zw - 1.0);
	return texture(atlas, px / atlas_px).rgb;
}

void fragment() {
	float brightness = v_info.a;
	vec3 col;
	if (v_info.g > 0.5) {
		// Ticker: the strip scrolls right to left, 64 px of strip per metre of height.
		float strip = v_ads.x;
		vec4 r = ad_rect(strip);
		float x = fract(UV.x / (r.z / r.w) - TIME * 0.035 + v_info.r);
		vec2 px = r.xy + vec2(x, clamp(UV.y, 0.02, 0.98)) * r.zw;
		col = texture(atlas, px / atlas_px).rgb;
	} else if (lightweight) {
		float aspect = max(v_info.b * 8.0, 0.05);
		float ad = fract(TIME / period + v_info.r) < 0.5 ? v_ads.x : v_ads.y;
		col = sample_ad(ad, UV, aspect, 1.0);
	} else {
		float aspect = max(v_info.b * 8.0, 0.05);
		float t = TIME / period + v_info.r;
		float cycle = fract(t);
		// Ad A for the first half of the cycle, B for the second; the next one slides in.
		float half_cycle = fract(cycle * 2.0);
		bool first = cycle < 0.5;
		float now_ad = first ? v_ads.x : v_ads.y;
		float next_ad = first ? v_ads.y : v_ads.x;
		float slide = smoothstep(0.93, 1.0, half_cycle);
		float zoom = 1.0 + 0.05 * half_cycle;
		if (UV.x + slide < 1.0) {
			col = sample_ad(now_ad, UV + vec2(slide, 0.0), aspect, zoom);
		} else {
			col = sample_ad(next_ad, UV + vec2(slide - 1.0, 0.0), aspect, 1.0);
		}
		// A shine sweeping across now and then.
		float sweep = fract(t * 2.0 + 0.3);
		col += vec3(0.25) * (1.0 - smoothstep(0.0, 0.06, abs(UV.x - UV.y * 0.3 - sweep * 1.6 + 0.3)));
	}
	// LED dots, visible only up close.
	if (!lightweight) {
		vec2 fw = fwidth(UV);
		float led_size = 0.012;
		vec2 cell = fract(UV / vec2(led_size * 0.5, led_size));
		float dots = smoothstep(0.95, 0.6, length(cell - 0.5) * 1.4);
		float close = 1.0 - smoothstep(0.004, 0.012, max(fw.x, fw.y));
		col *= mix(1.0, 0.55 + 0.6 * dots, close);
	}

	ALBEDO = col * 0.12;
	ROUGHNESS = 0.35;
	SPECULAR = 0.3;
	EMISSION = col * brightness;
}
