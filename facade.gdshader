shader_type spatial;
// Manhattan facades, drawn procedurally so one material covers every building of
// district_nyc.gd and the windows stay crisp at any size.
//   UV   = (metres along the wall, metres above the street)
//   UV2  = (style + seed in the fraction, height of this wall's top)
//   COLOR = wall tint (sRGB); alpha < 0.5 means no shop front at street level
// Styles: 0 brick with punched windows, 1 limestone, 2 glass curtain wall,
// 3 ribbon windows, 4 modern grid, 5 dark glass tower, 6 blank party wall.

// Smashed shop windows (nyc_builder.gd smash_window): one texel per window, at the
// window's middle, 1 m per texel from damage_origin. r: 0.5 cracked, 1 smashed;
// g, b: where the first blow landed (across the shop, height / 4 m); a: a seed.
uniform sampler2D damage_map : filter_nearest, hint_default_black;
uniform vec2 damage_origin = vec2(0.0);
uniform bool damage_on = false;

varying vec3 v_world;
varying vec3 v_wnormal;
varying vec3 v_tint;
varying float v_style;
varying float v_seed;
varying float v_top;
varying float v_shops;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	v_tint = pow(COLOR.rgb, vec3(2.2));
	v_shops = COLOR.a;
	v_style = floor(UV2.x + 0.001);
	v_seed = fract(UV2.x);
	v_top = UV2.y;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

// Soft box mask: 1 inside [lo, hi] on both axes, anti-aliased by the pixel footprint.
float box(vec2 p, vec2 lo, vec2 hi, vec2 fw) {
	vec2 a = smoothstep(lo - fw, lo + fw, p) * (1.0 - smoothstep(hi - fw, hi + fw, p));
	return a.x * a.y;
}

void fragment() {
	vec2 m = UV;
	vec2 fw = max(fwidth(m), vec2(0.002));
	float seed = v_seed;
	vec3 wall = v_tint;
	vec3 col = wall;
	float rough = 0.85;
	float metal = 0.0;
	float glow = 0.0;

	// Floor height and window bay width vary by building.
	float floor_h = 3.3 + seed * 0.6;
	float bay = 1.9 + fract(seed * 7.3) * 1.0;
	float storey_base = (v_shops > 0.5) ? 4.8 : 0.0;
	vec2 cell = vec2(m.x / bay, (m.y - storey_base) / floor_h);
	vec2 id = floor(cell);
	vec2 f = fract(cell) * vec2(bay, floor_h);
	float rnd = hash(id + seed * 31.0);
	float rnd2 = hash(id.yx * 1.7 + seed * 13.0);

	// Window glass: blue-grey sky reflection, blinds in some, a few warm lit rooms.
	vec3 glass = mix(vec3(0.05, 0.07, 0.09), vec3(0.2, 0.27, 0.33), smoothstep(0.0, 1.0, f.y / floor_h + rnd * 0.3));
	if (rnd2 > 0.72) glass = mix(glass, vec3(0.72, 0.7, 0.62), 0.55); // blinds down
	if (rnd2 < 0.05) { glass = vec3(0.9, 0.72, 0.45); glow = 0.35; }

	// Far away, fade the window pattern into its average so it doesn't shimmer.
	float detail = 1.0 - smoothstep(0.35, 0.9, max(fw.x / bay, fw.y / floor_h) * 6.0);
	int style = int(v_style);

	if (style == 0 || style == 1) {
		// Masonry with punched windows, a sill and a lintel.
		if (style == 0) {
			// Brick courses.
			float course = fract(m.y / 0.075);
			float joint = fract(m.x / 0.21 + floor(m.y / 0.075) * 0.5);
			float mortar = max(step(0.86, course), step(0.94, joint));
			float fine = 1.0 - smoothstep(0.15, 0.45, max(fw.x / 0.21, fw.y / 0.075));
			col = mix(wall * (0.9 + hash(floor(vec2(m.x / 0.21, m.y / 0.075))) * 0.2 * fine), wall * 1.35 + 0.05, mortar * fine * 0.6);
			col = mix(wall * 1.04, col, fine);
		} else {
			float block = step(0.97, fract(m.y / 0.6)) + step(0.985, fract(m.x / 1.2 + floor(m.y / 0.6) * 0.5));
			col = wall * (1.0 - min(block, 1.0) * 0.12 * detail);
		}
		float win = box(f, vec2(bay * 0.24, 0.85), vec2(bay * 0.76, 2.55), fw);
		float sill = box(f, vec2(bay * 0.2, 0.72), vec2(bay * 0.8, 0.85), fw);
		float lintel = box(f, vec2(bay * 0.2, 2.55), vec2(bay * 0.8, 2.78), fw);
		col = mix(col, wall * 1.25 + 0.06, max(sill, lintel) * detail);
		// Two sashes.
		float mull = box(f, vec2(bay * 0.5 - 0.04, 0.85), vec2(bay * 0.5 + 0.04, 2.55), fw) + box(f, vec2(bay * 0.24, 1.66), vec2(bay * 0.76, 1.72), fw);
		vec3 w = mix(glass, vec3(0.85, 0.84, 0.8), min(mull, 1.0) * detail);
		col = mix(col, w, win * mix(0.55, 1.0, detail));
		if (detail < 1.0) col = mix(mix(wall, glass, 0.32), col, detail);
	} else if (style == 2 || style == 5) {
		// Curtain wall: glass between thin mullions, a spandrel at each floor slab.
		vec3 tint = (style == 2) ? mix(vec3(0.16, 0.26, 0.3), wall, 0.35) : mix(vec3(0.05, 0.07, 0.09), wall, 0.25);
		float pane = 1.5;
		vec2 g = vec2(fract(m.x / pane) * pane, f.y);
		float mullion = 1.0 - box(g, vec2(0.05, 0.0), vec2(pane - 0.05, floor_h), fw);
		float spandrel = 1.0 - box(g, vec2(-1.0, 0.9), vec2(pane + 1.0, floor_h - 0.05), fw);
		float shade = hash(vec2(floor(m.x / pane), id.y) + seed) * 0.08;
		col = tint * (0.85 + shade * 2.0 + f.y / floor_h * 0.25);
		if (rnd2 < 0.04) { col = mix(col, vec3(0.9, 0.82, 0.6), 0.5); glow = 0.2; }
		col = mix(col, mix(tint * 0.6, vec3(0.55, 0.57, 0.6), 0.5), max(mullion, spandrel * 0.8) * detail);
		rough = 0.08;
		metal = 0.6;
	} else if (style == 3) {
		// Ribbon windows: horizontal bands of glass and light spandrels.
		float band = box(vec2(1.0, f.y), vec2(0.0, 1.05), vec2(2.0, floor_h - 0.15), fw);
		float mull = 1.0 - box(vec2(fract(m.x / 1.6) * 1.6, 0.5), vec2(0.04, 0.0), vec2(1.56, 1.0), fw);
		vec3 g = mix(vec3(0.1, 0.14, 0.18), vec3(0.3, 0.38, 0.44), f.y / floor_h);
		col = mix(wall, mix(g, wall * 0.7, mull * detail * 0.7), band);
		rough = mix(0.8, 0.15, band);
		metal = band * 0.4;
	} else if (style == 4) {
		// Modern grid: deep square windows in light panels.
		float win = box(f, vec2(0.3, 0.6), vec2(bay - 0.3, floor_h - 0.5), fw);
		col = mix(wall, glass, win);
		col = mix(col, wall * 0.75, box(f, vec2(0.3, 0.45), vec2(bay - 0.3, 0.6), fw) * detail);
		rough = mix(0.8, 0.2, win);
	} else if (style == 7) {
		// Granite sea wall: big blocks, wet and green-stained low down.
		vec2 q = m / vec2(1.6, 0.8);
		vec2 bid = floor(vec2(q.x + floor(q.y) * 0.5, q.y));
		col = wall * (0.82 + hash(bid + seed) * 0.3);
		float joint = max(step(0.95, fract(q.y)), step(0.97, fract(q.x + floor(q.y) * 0.5)));
		col = mix(col, col * 0.5, joint * detail);
		float wet = 1.0 - smoothstep(-2.6, -1.2, m.y);
		col = mix(col, col * vec3(0.45, 0.55, 0.45), wet);
		rough = mix(0.85, 0.35, wet);
	} else {
		// Blank party wall (sides that will be built against): plain with stains.
		col = wall * (0.9 + 0.1 * hash(floor(m / 3.0) + seed));
	}

	// Street level: shop fronts with big windows, a door now and then, a sign band.
	if (v_shops > 0.5 && m.y < 4.8 && style != 6) {
		float unit = 7.0 + fract(seed * 3.1) * 3.0;
		float x = fract(m.x / unit) * unit;
		float sid = hash(vec2(floor(m.x / unit), seed * 5.0));
		vec3 frame = mix(vec3(0.08, 0.08, 0.09), vec3(0.75, 0.73, 0.68), step(0.6, sid));
		vec3 sign_col = vec3(0.6 + 0.4 * sin(sid * 40.0), 0.3 + 0.5 * sin(sid * 23.0 + 1.0), 0.25 + 0.6 * sin(sid * 11.0 + 2.0));
		sign_col = clamp(sign_col, 0.04, 1.0);
		float window = box(vec2(x, m.y), vec2(0.2, 0.45), vec2(unit - 0.2, 3.5), fw);
		float door = box(vec2(x, m.y), vec2(unit * 0.62, 0.0), vec2(unit * 0.62 + 1.6, 2.6), fw);
		float sign_band = box(vec2(x, m.y), vec2(0.15, 3.65), vec2(unit - 0.15, 4.55), fw);
		vec3 inside = mix(vec3(0.05, 0.05, 0.05), vec3(0.32, 0.28, 0.22), smoothstep(0.4, 3.0, m.y) * (0.3 + sid * 0.7));
		// Sky reflected in the upper part of the shop window, goods lit warm low down.
		inside = mix(inside, vec3(0.38, 0.44, 0.5), smoothstep(2.2, 3.4, m.y) * 0.6);
		inside += vec3(0.25, 0.18, 0.1) * (1.0 - smoothstep(0.5, 1.8, m.y)) * step(0.4, sid);
		vec3 shop = frame;
		shop = mix(shop, inside, window);
		shop = mix(shop, vec3(0.05, 0.05, 0.06), door * 0.8);
		float pane = max(window, door);
		if (damage_on && pane > 0.001) {
			// Which window this is: its middle on the wall, looked up in the damage map.
			vec2 along = normalize(vec2(-v_wnormal.z, v_wnormal.x));
			float shop_id = floor(m.x / unit);
			vec2 middle = v_world.xz + along * ((shop_id + 0.5) * unit - m.x);
			ivec2 texel = ivec2(floor(middle - damage_origin));
			ivec2 size = textureSize(damage_map, 0);
			if (texel.x >= 0 && texel.y >= 0 && texel.x < size.x && texel.y < size.y) {
				vec4 dmg = texelFetch(damage_map, texel, 0);
				if (dmg.r > 0.25) {
					vec2 q = vec2(x, m.y) - vec2(dmg.g * unit, dmg.b * 4.0);
					float r = length(q);
					float ang = atan(q.y, q.x) + 3.14159265;
					float spokes = 15.0;
					float wedge = 6.2831853 / spokes;
					float ci = floor(ang / wedge);
					float cw = fw.x * 1.2 + 0.008;
					// Radial cracks from the blow, each a little off its wedge's middle,
					// fading out at their own length; rings of short cracks between them.
					float web = 0.0;
					for (int k = 0; k < 2; k++) {
						float c = ci + float(k);
						float h = hash(vec2(mod(c, spokes), dmg.a * 97.0));
						float spoke = (c + 0.5 + (h - 0.5) * 0.8) * wedge;
						float dist = abs(sin(ang - spoke)) * r;
						float reach = 0.9 + h * 2.6;
						web = max(web, (1.0 - smoothstep(0.0, cw, dist)) * (1.0 - smoothstep(reach * 0.6, reach, r)));
					}
					float ring_step = 0.22;
					float rc = floor(r / ring_step);
					float rh = hash(vec2(rc, ci + dmg.a * 31.0));
					float ring_r = (rc + 0.3 + rh * 0.4) * ring_step;
					float ring = (1.0 - smoothstep(0.0, cw, abs(r - ring_r))) * step(0.3, rh) * (1.0 - smoothstep(0.5, 1.3, r));
					web = max(web, ring);
					float crush = 1.0 - smoothstep(0.05, 0.16, r);
					vec3 cracked = mix(shop, vec3(0.86, 0.9, 0.92), max(web * 0.85, crush * 0.7));
					if (dmg.r > 0.75) {
						// Smashed out: a hole into the shop, jagged teeth of glass left in the frame.
						// Distance in from the edge of the opening (window and door together).
						float in_window = min(min(x - 0.2, unit - 0.2 - x), min(m.y - 0.45, 3.5 - m.y));
						float in_door = min(min(x - unit * 0.62, unit * 0.62 + 1.6 - x), min(m.y, 2.6 - m.y));
						float edge = max(in_window, in_door);
						// Teeth: triangular spikes pointing in at the blow, a few long, most short.
						float ta = ang * 4.0 + dmg.a * 7.0;
						float tooth = pow(hash(vec2(floor(ta), dmg.a * 53.0)), 2.5);
						float spike = 1.0 - abs(fract(ta) * 2.0 - 1.0);
						float tb = ang * 11.0 + dmg.a * 3.0;
						float small = hash(vec2(floor(tb), dmg.a * 17.0)) * (1.0 - abs(fract(tb) * 2.0 - 1.0));
						float teeth = 0.025 + (tooth * spike * 0.75 + small * 0.12) * (0.4 + 0.6 * smoothstep(0.3, 1.5, r));
						float keep = 1.0 - smoothstep(teeth - fw.x, teeth + fw.x, edge);
						vec3 hole = mix(vec3(0.02, 0.02, 0.02), vec3(0.2, 0.16, 0.11), smoothstep(0.3, 2.8, m.y) * (0.3 + sid * 0.7));
						hole += vec3(0.22, 0.15, 0.08) * (1.0 - smoothstep(0.4, 1.6, m.y)) * step(0.4, sid);
						float rim = keep * (1.0 - smoothstep(0.0, 0.03 + fw.x, teeth - edge));
						vec3 teeth_col = mix(inside, vec3(0.8, 0.86, 0.9), 0.35 + web * 0.4);
						cracked = mix(hole, mix(teeth_col, vec3(0.92, 0.95, 0.97), rim * 0.7), keep);
					}
					shop = mix(shop, cracked, pane);
				}
			}
		}
		shop = mix(shop, sign_col, sign_band);
		col = shop;
		glow = max(glow, sign_band * 0.45 + window * 0.12);
		rough = mix(0.5, 0.1, window);
		metal = 0.0;
	}

	// Cornice band at the top of the wall and a darker base course.
	float cornice = smoothstep(v_top - 1.2 - fw.y, v_top - 1.2 + fw.y, m.y) * step(m.y, v_top - 0.05);
	if (style != 2 && style != 5) col = mix(col, wall * 1.15 + 0.04, cornice * 0.8);

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;
	EMISSION = col * glow;
}
