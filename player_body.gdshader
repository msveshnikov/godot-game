shader_type spatial;
render_mode cull_disabled;

// Procedural walk/run/jump rig for the unskinned main_player mesh.
// All pivots are in the mesh's local space (feet at y = 0, front facing +Z).

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

uniform float phase = 0.0;          // gait cycle, radians
uniform float walk_amount = 0.0;    // 0 idle .. 1 moving
uniform float air_amount = 0.0;     // 0 grounded .. 1 airborne
uniform float leg_swing = 0.45;     // hip swing amplitude, radians
uniform float arm_swing = 0.5;      // shoulder swing amplitude, radians
uniform float knee_bend = 0.9;      // max knee flex during leg recovery
uniform float lean = 0.0;           // upper-body pitch, negative = forward
uniform float breathing = 1.0;

uniform float hip_height = 0.86;
uniform float knee_height = 0.46;
uniform float shoulder_height = 1.43;
uniform float shoulder_x = 0.22;
uniform float leg_x_limit = 0.24;
uniform float crotch_bottom = 0.72;
uniform float crotch_top = 0.95;

// The right arm (mesh -X) holds the pistol: player_model_animator.gd sets these
// two angles directly (and mirrors the same maths to place the gun in the hand).
uniform float gun_arm_pitch = -0.25; // about X at the shoulder; -PI/2 points the arm forward
uniform float gun_arm_roll = 0.35;   // about Z at the shoulder; tucks the A-posed arm against the body

vec3 rotate_x(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x, v.y * c - v.z * s, v.y * s + v.z * c);
}

vec3 rotate_z(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x * c - v.y * s, v.x * s + v.y * c, v.z);
}

vec3 rotate_about(vec3 v, vec3 pivot, float a) {
	return rotate_x(v - pivot, a) + pivot;
}

void vertex() {
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	float side = v.x >= 0.0 ? 1.0 : -1.0;
	float ax = abs(v.x);
	float swing = sin(phase) * side;               // +1: this leg is behind the body
	float recovering = max(0.0, -cos(phase) * side); // leg travelling forward, foot lifted

	// --- Legs (knee first, then hip, so the knee follows the thigh) ---
	float center_fade = mix(1.0, smoothstep(0.0, 0.06, ax), smoothstep(0.62, 0.8, v.y));
	float leg_w = (1.0 - smoothstep(crotch_bottom, crotch_top, v.y))
		* (1.0 - smoothstep(leg_x_limit, leg_x_limit + 0.06, ax))
		* center_fade;
	float knee_w = (1.0 - smoothstep(knee_height - 0.06, knee_height + 0.06, v.y)) * leg_w;

	float air_hip = side > 0.0 ? -0.45 : 0.3;
	float air_knee = side > 0.0 ? 0.35 : 0.75;
	float hip_angle = mix(swing * leg_swing * walk_amount, air_hip, air_amount);
	float knee_angle = mix(recovering * knee_bend * walk_amount, air_knee, air_amount);

	vec3 knee_pivot = vec3(0.0, knee_height, -0.02);
	vec3 hip_pivot = vec3(0.0, hip_height, 0.0);
	v = rotate_about(v, knee_pivot, knee_angle * knee_w);
	n = rotate_x(n, knee_angle * knee_w);
	v = rotate_about(v, hip_pivot, hip_angle * leg_w);
	n = rotate_x(n, hip_angle * leg_w);

	// --- Arms swing opposite to the legs ---
	float arm_w = smoothstep(0.2, 0.3, ax)
		* (1.0 - smoothstep(shoulder_height + 0.04, shoulder_height + 0.12, v.y))
		* smoothstep(0.7, 0.78, VERTEX.y);
	float arm_angle = mix(-swing * arm_swing * walk_amount, -0.5, air_amount);
	vec3 shoulder_pivot = vec3(shoulder_x * side, shoulder_height, 0.0);
	if (side < 0.0) {
		// Gun arm: tuck in, then swing up about the shoulder.
		vec3 local = rotate_z(v - shoulder_pivot, gun_arm_roll * arm_w);
		v = rotate_x(local, gun_arm_pitch * arm_w) + shoulder_pivot;
		n = rotate_x(rotate_z(n, gun_arm_roll * arm_w), gun_arm_pitch * arm_w);
	} else {
		v = rotate_about(v, shoulder_pivot, arm_angle * arm_w);
		n = rotate_x(n, arm_angle * arm_w);
	}

	// --- Upper-body lean and idle breathing (arms lean rigidly with the torso) ---
	float upper_w = max(smoothstep(crotch_bottom, crotch_top, VERTEX.y), arm_w);
	v = rotate_about(v, hip_pivot, lean * upper_w);
	n = rotate_x(n, lean * upper_w);
	float chest_w = smoothstep(1.0, 1.35, VERTEX.y);
	v.y += sin(TIME * 1.7) * 0.006 * chest_w * breathing * (1.0 - walk_amount);

	// --- Keep the planted foot on the ground (legs shorten as they swing) ---
	float stance_angle = swing * leg_swing * walk_amount * (1.0 - air_amount);
	v.y -= hip_height * (1.0 - cos(stance_angle));

	VERTEX = v;
	NORMAL = normalize(n);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = tex.rgb;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
}
