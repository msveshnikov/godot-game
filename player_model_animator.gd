extends Node3D
## Drives the procedural walk/run/jump shader on the static main_player mesh
## from the parent CharacterBody3D's velocity, and puts the weapon in the right
## hand: the pistol (tucked at the hip, snapped up to aim when firing), a
## baseball bat (held forward, swung overhead and down), the bazooka (on the right
## shoulder, always pointing at the aim point), or nothing.

const BODY_SHADER: Shader = preload("res://player_body.gdshader")
const PISTOL_SCENE: PackedScene = preload("res://pistol_model.tscn")
const PHASE_PER_METER := 1.43  # ~one full stride cycle per 0.96 s at walk speed, matches footsteps
const WALK_SPEED := 4.5
const RUN_SPEED := 7.5
const MAX_TURN := deg_to_rad(50.0)

# Mirrors player_body.gdshader (mesh space: feet at y = 0, front +Z, right hand on -X).
## Each body's joints for the procedural rig: the right shoulder, the hip height, the
## palm of the A-posed right hand, how much steeper (-) the arm hangs than Max's, and
## the matching player_body.gdshader uniforms (where legs, arms and clothes are).
const BODIES := {
	"male": {
		"shoulder": Vector3(-0.22, 1.43, 0.0), "hip": 0.86, "hand": Vector3(-0.525, 0.855, 0.143), "roll": 0.0,
		"shader": {"hip_height": 0.86, "knee_height": 0.46, "shoulder_height": 1.43, "shoulder_x": 0.22,
			"leg_x_limit": 0.24, "crotch_bottom": 0.72, "crotch_top": 0.95, "arm_inner": 0.2, "arm_outer": 0.3,
			"arm_inner_low": 0.2, "arm_outer_low": 0.3, "arm_split": 1.0,
			"arm_bottom": 0.7, "waist_height": 0.95, "neck_height": 1.56},
	},
	"female": { # measured off her sheet by blender/scripts/alice_sheet.py
		"shoulder": Vector3(-0.173, 1.375, 0.0), "hip": 0.92, "hand": Vector3(-0.34, 0.805, 0.02), "roll": -0.21,
		"shader": {"hip_height": 0.92, "knee_height": 0.49, "shoulder_height": 1.375, "shoulder_x": 0.173,
			"leg_x_limit": 0.22, "crotch_bottom": 0.78, "crotch_top": 1.01, "arm_inner": 0.14, "arm_outer": 0.165,
			"arm_inner_low": 0.2, "arm_outer_low": 0.25, "arm_split": 1.0,
			"arm_bottom": 0.6, "waist_height": 1.0, "neck_height": 1.45},
	},
}
const REST_PITCH := -0.22
const REST_ROLL := 0.36
const AIM_ROLL := 0.5 # brings the outstretched arm in front of the right shoulder
const REST_GUN_DOWN := deg_to_rad(62.0) # barrel angle below horizontal while lowered
const PISTOL_SCALE := 0.5
const PISTOL_GRIP := Vector3(0.11, -0.08, 0.0) # where the palm closes on pistol_model.tscn
const PISTOL_MUZZLE := Vector3(-0.33, 0.1, 0.0)
const FLASH_TIME := 0.05
const RECOIL_KICK := 0.32 # radians the barrel flips up per shot
const RAISE_SPEED := 11.0 # up in ~0.09 s
const LOWER_SPEED := 3.0
const RAISED_HOLD := 0.9 # seconds the arm stays up after the last shot
const SWING_TIME := 0.55
const BAT_TILT := -1.1 # bat angle forward of the forearm line
const BAT_LENGTH := 0.84
const FEMALE_MODEL := "res://female_player.glb"
## The bazooka tube: length behind and ahead of the shoulder, radius.
const TUBE_BACK := 0.5
const TUBE_FRONT := 0.72
const TUBE_RADIUS := 0.075
## Where the cap and the sunglasses sit on each body (mesh space): eye height, the
## front of the face and the back of the head, the head's half width, its top.
const HEADS := {
	"male": {"eyes": 1.737, "front": 0.124, "half_width": 0.1, "top": 1.89, "back": -0.115},
	"female": {"eyes": 1.588, "front": 0.083, "half_width": 0.08, "top": 1.735, "back": -0.12},
}

## World point the gun aims at while raised; set every frame by the owner (camera ray for the
## local player, the shot direction for remote ones). Straight ahead when never set.
var aim_point := Vector3.ZERO
var has_aim_point := false

var _body: CharacterBody3D
var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _phase := 0.0
var _walk_amount := 0.0
var _air_amount := 0.0
var _lean := 0.0
var _yaw := 0.0
var _base_yaw := 0.0
var _aim_amount := 0.0
var _raise_hold := 0.0
var _gun_hand: Node3D
var _muzzle: Marker3D
var _pistol: Node3D
var _bat: Node3D
var _bazooka: Node3D
var _bazooka_muzzle: Marker3D
var _warhead: Node3D
var _weapon := "pistol"
var _swing_t := -1.0 # 0..1 while swinging the bat
var _flash: Node3D
var _flash_light: OmniLight3D
var _flash_time := 0.0
var _recoil := 0.0
var _body_kind := "male"
var _shoulder: Vector3 = BODIES["male"]["shoulder"]
var _hip := Vector3(0.0, 0.86, 0.0)
var _hip_height := 0.86
var _hand: Vector3 = BODIES["male"]["hand"]
var _roll := 0.0
var _tint := Color.WHITE
var _meshes := {} # body kind -> [Mesh, albedo texture, albedo colour]
var _accessories: Array[MeshInstance3D] = []


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if _body == null:
		push_error("Player model animator must be a child of a CharacterBody3D.")
		return
	_base_yaw = rotation.y

	var meshes := find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		push_error("Player model animator could not find the player mesh.")
		return
	var mesh_instance := meshes[0] as MeshInstance3D
	_mesh = mesh_instance

	_material = ShaderMaterial.new()
	_material.shader = BODY_SHADER
	var source := mesh_instance.get_active_material(0) as BaseMaterial3D
	_meshes["male"] = [mesh_instance.mesh, source.albedo_texture if source != null else null, source.albedo_color if source != null else Color.WHITE]
	if source != null:
		_material.set_shader_parameter("albedo_texture", source.albedo_texture)
		_material.set_shader_parameter("albedo_color", source.albedo_color)
		_material.set_shader_parameter("roughness", source.roughness)
	mesh_instance.material_override = _material
	_apply_rig("male")
	_build_gun()


## Gun hand -> pistol (barrel along the hand's -Z, palm on the grip) -> muzzle.
func _build_gun() -> void:
	_gun_hand = Node3D.new()
	_gun_hand.name = "GunHand"
	_gun_hand.top_level = true
	add_child(_gun_hand)
	var pistol := PISTOL_SCENE.instantiate() as Node3D
	pistol.name = "HeldPistol"
	pistol.scale = Vector3.ONE * PISTOL_SCALE
	pistol.rotation.y = -PI / 2.0 # model barrel points -X; turn it to -Z
	pistol.position = -(pistol.basis * PISTOL_GRIP)
	_gun_hand.add_child(pistol)
	_muzzle = Marker3D.new()
	_muzzle.name = "GunMuzzle"
	_muzzle.position = PISTOL_MUZZLE
	pistol.add_child(_muzzle)
	_pistol = pistol
	_build_flash()
	_bat = _build_bat()
	_gun_hand.add_child(_bat)
	_bazooka = _build_bazooka()
	add_child(_bazooka)
	set_weapon(_weapon) # whatever was picked before the model was ready


## Muzzle flash: a hot orange-white blob in front of the barrel and a short burst of light.
func _build_flash() -> void:
	_flash = Node3D.new()
	_flash.name = "MuzzleFlash"
	_muzzle.add_child(_flash)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(1.0, 0.72, 0.3, 0.9)
	for part in [[Vector3(0.1, 0.1, 0.1), Vector3(-0.05, 0, 0)], [Vector3(0.24, 0.06, 0.06), Vector3(-0.12, 0, 0)]]:
		var blob := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 8
		sphere.rings = 4
		blob.mesh = sphere
		blob.material_override = material
		blob.scale = part[0]
		blob.position = part[1]
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flash.add_child(blob)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.75, 0.4)
	_flash_light.light_energy = 3.0
	_flash_light.omni_range = 5.0
	_flash_light.position = Vector3(-0.1, 0, 0)
	_flash.add_child(_flash_light)
	_flash.visible = false


## A shot just left the barrel: flash and flip the muzzle up a little.
func fire_effects() -> void:
	_flash_time = FLASH_TIME
	_recoil = RECOIL_KICK
	if _flash != null:
		_flash.visible = true
		_flash.rotation.x = randf() * TAU
		_flash.scale = Vector3.ONE * randf_range(0.8, 1.2)


## Wooden bat along the hand's -Z: knob just behind the palm, barrel end forward.
func _build_bat() -> Node3D:
	var bat := Node3D.new()
	bat.name = "HeldBat"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.74, 0.54, 0.32)
	wood.roughness = 0.45
	var tape := StandardMaterial3D.new()
	tape.albedo_color = Color(0.08, 0.08, 0.09)
	tape.roughness = 0.8
	var parts := [
		# [top radius, bottom radius, length, centre along -Z, material]
		[0.043, 0.02, BAT_LENGTH - 0.08, 0.04 + (BAT_LENGTH - 0.08) * 0.5, wood],
		[0.021, 0.019, 0.26, -0.01, tape],
		[0.03, 0.03, 0.025, -0.12, wood],
	]
	for part in parts:
		var mesh := CylinderMesh.new()
		mesh.top_radius = part[0]
		mesh.bottom_radius = part[1]
		mesh.height = part[2]
		mesh.radial_segments = 12
		mesh.material = part[4]
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.rotation.x = -PI / 2.0 # cylinder +Y -> -Z
		instance.position = Vector3(0, 0, -float(part[3]))
		bat.add_child(instance)
	return bat


## Olive tube along its -Z (the muzzle end), flared at both ends, with a grip and
## trigger under it, a sight on the left, and the warhead poking out while loaded.
func _build_bazooka() -> Node3D:
	var root := Node3D.new()
	root.name = "HeldBazooka"
	var olive := StandardMaterial3D.new()
	olive.albedo_color = Color(0.25, 0.29, 0.17)
	olive.roughness = 0.7
	olive.metallic = 0.2
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.06, 0.06)
	dark.roughness = 0.6
	var warhead_paint := StandardMaterial3D.new()
	warhead_paint.albedo_color = Color(0.36, 0.38, 0.3)
	warhead_paint.roughness = 0.5
	warhead_paint.metallic = 0.4
	var tip_paint := StandardMaterial3D.new()
	tip_paint.albedo_color = Color(0.75, 0.12, 0.08)
	var length := TUBE_BACK + TUBE_FRONT
	# [top radius, bottom radius, height, centre along -Z, material]; "top" faces the muzzle.
	var parts := [
		[TUBE_RADIUS, TUBE_RADIUS, length, (TUBE_FRONT - TUBE_BACK) * 0.5, olive],
		[TUBE_RADIUS * 1.45, TUBE_RADIUS * 1.05, 0.16, TUBE_FRONT - 0.08, olive],
		[TUBE_RADIUS * 1.05, TUBE_RADIUS * 1.6, 0.2, -TUBE_BACK + 0.1, olive],
		[TUBE_RADIUS * 1.12, TUBE_RADIUS * 1.12, 0.05, 0.1, dark],
		[TUBE_RADIUS * 1.12, TUBE_RADIUS * 1.12, 0.05, -0.25, dark],
	]
	for part in parts:
		var mesh := CylinderMesh.new()
		mesh.top_radius = part[0]
		mesh.bottom_radius = part[1]
		mesh.height = part[2]
		mesh.radial_segments = 14
		mesh.material = part[4]
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.rotation.x = -PI / 2.0 # cylinder +Y -> -Z
		instance.position = Vector3(0, 0, -float(part[3]))
		root.add_child(instance)
	# Black inside, so the open ends read as a tube.
	for end in [[TUBE_FRONT + 0.001, PI / 2.0], [-TUBE_BACK - 0.001, -PI / 2.0]]:
		var cap := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = TUBE_RADIUS * 0.9
		disc.bottom_radius = TUBE_RADIUS * 0.9
		disc.height = 0.002
		disc.material = dark
		cap.mesh = disc
		cap.rotation.x = -PI / 2.0
		cap.position = Vector3(0, 0, -float(end[0]))
		root.add_child(cap)
	for box in [[Vector3(0.04, 0.16, 0.06), Vector3(0.0, -0.14, -0.3), dark], [Vector3(0.035, 0.13, 0.05), Vector3(0.0, -0.13, 0.05), dark],
			[Vector3(0.03, 0.07, 0.05), Vector3(0.08, 0.05, -0.05), dark]]:
		var mesh := BoxMesh.new()
		mesh.size = box[0]
		mesh.material = box[2]
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.position = box[1]
		root.add_child(instance)
	_warhead = Node3D.new()
	_warhead.position = Vector3(0, 0, -TUBE_FRONT)
	root.add_child(_warhead)
	for cone in [[0.055, 0.065, 0.12, 0.0, warhead_paint], [0.012, 0.055, 0.1, 0.11, tip_paint]]:
		var mesh := CylinderMesh.new()
		mesh.top_radius = cone[0]
		mesh.bottom_radius = cone[1]
		mesh.height = cone[2]
		mesh.radial_segments = 12
		mesh.material = cone[4]
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.rotation.x = -PI / 2.0
		instance.position = Vector3(0, 0, -float(cone[3]) - float(cone[2]) * 0.5)
		_warhead.add_child(instance)
	_bazooka_muzzle = Marker3D.new()
	_bazooka_muzzle.name = "BazookaMuzzle"
	_bazooka_muzzle.position = Vector3(0, 0, -TUBE_FRONT - 0.05)
	root.add_child(_bazooka_muzzle)
	root.visible = false
	return root


## Whether a rocket sits in the tube (the warhead shows at the muzzle).
func set_loaded(loaded: bool) -> void:
	if _warhead != null:
		_warhead.visible = loaded


## "pistol", "bat", "bazooka" or "none".
func set_weapon(value: String) -> void:
	_weapon = value
	_swing_t = -1.0
	if _pistol != null:
		_pistol.visible = value == "pistol"
	if _bat != null:
		_bat.visible = value == "bat"
	if _bazooka != null:
		_bazooka.visible = value == "bazooka"
	if value != "pistol":
		_raise_hold = 0.0


## Start an overhead bat swing (ignored while one is under way).
func swing() -> void:
	if _weapon == "bat" and _swing_t < 0.0:
		_swing_t = 0.0


## Snap the gun up to aim (or keep it up); it drops back after RAISED_HOLD without shots.
func raise_gun() -> void:
	_raise_hold = RAISED_HOLD


## True once the arm is up far enough for the shot to leave the barrel toward the aim point.
func is_gun_raised() -> bool:
	return _aim_amount >= 0.92


func get_muzzle() -> Marker3D:
	return _bazooka_muzzle if _weapon == "bazooka" and _bazooka_muzzle != null else _muzzle


## Dress the model as game_state.gd describes (slot -> item id): which body, the
## T-shirt and jeans colours, a cap, sunglasses.
func apply_look(look: Dictionary) -> void:
	if _material == null:
		return
	_set_body(str(look.get("body", "male")))
	var game := get_tree().root.get_node_or_null("Game")
	if game == null:
		return
	var shirt: Variant = game.call("item_color", "shirt", str(look.get("shirt", "")))
	var pants: Variant = game.call("item_color", "pants", str(look.get("pants", "")))
	_material.set_shader_parameter("shirt_tint", Color(shirt.r, shirt.g, shirt.b, 1.0) if shirt is Color else Color(0, 0, 0, 0))
	_material.set_shader_parameter("pants_tint", Color(pants.r, pants.g, pants.b, 1.0) if pants is Color else Color(0, 0, 0, 0))
	for part in _accessories:
		part.queue_free()
	_accessories.clear()
	var head: Dictionary = HEADS.get(_body_kind, HEADS["male"])
	var hat: Variant = game.call("item_color", "hat", str(look.get("hat", "none")))
	if hat is Color:
		_add_cap(head, hat)
	var shades: Variant = game.call("item_color", "glasses", str(look.get("glasses", "none")))
	if shades is Color:
		_add_sunglasses(head, shades, str(look.get("glasses", "")) == "gold")


## "male" or "female" (falls back to male while her model isn't in the game).
func _set_body(kind: String) -> void:
	if kind == "female" and not _meshes.has("female"):
		if not ResourceLoader.exists(FEMALE_MODEL):
			kind = "male"
		else:
			var scene := (load(FEMALE_MODEL) as PackedScene).instantiate()
			var found := scene.find_children("*", "MeshInstance3D", true, false)
			if found.is_empty():
				kind = "male"
			else:
				var mi := found[0] as MeshInstance3D
				var source := mi.get_active_material(0) as BaseMaterial3D
				_meshes["female"] = [mi.mesh, source.albedo_texture if source != null else null, source.albedo_color if source != null else Color.WHITE]
			scene.free()
	if kind == _body_kind:
		return
	_body_kind = kind
	_apply_rig(kind)
	var entry: Array = _meshes[kind]
	_mesh.mesh = entry[0]
	_material.set_shader_parameter("albedo_texture", entry[1])
	_material.set_shader_parameter("albedo_color", (entry[2] as Color) * _tint)


func _accessory(mesh: Mesh, at: Vector3, color: Color, rough := 0.6, scale_by := Vector3.ONE, rotation_by := Vector3.ZERO) -> void:
	var material := ShaderMaterial.new()
	material.shader = BODY_SHADER
	material.set_shader_parameter("plain", true)
	material.set_shader_parameter("albedo_color", color)
	material.set_shader_parameter("roughness", rough)
	material.set_shader_parameter("breathing", 0.0)
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.scale = scale_by
	part.rotation = rotation_by
	_mesh.add_child(part)
	_accessories.append(part)


## A baseball cap: a dome over the top of the head and a peak out front.
func _add_cap(head: Dictionary, color: Color) -> void:
	var top: float = head["top"]
	var half: float = head["half_width"]
	var radius := half + 0.02
	var centre_z := (float(head["front"]) + float(head["back"])) * 0.5
	var depth := (float(head["front"]) - float(head["back"])) * 0.5 + 0.02
	var base_y := top - radius * 0.7
	var dome := SphereMesh.new()
	dome.radius = radius
	dome.height = radius
	dome.is_hemisphere = true
	dome.radial_segments = 20
	dome.rings = 6
	_accessory(dome, Vector3(0.0, base_y, centre_z), color, 0.8, Vector3(1.0, 1.12, depth / radius))
	var band := CylinderMesh.new()
	band.top_radius = radius + 0.002
	band.bottom_radius = radius + 0.002
	band.height = 0.03
	band.radial_segments = 20
	_accessory(band, Vector3(0.0, base_y, centre_z), color.darkened(0.15), 0.8, Vector3(1.0, 1.0, depth / radius))
	var peak := CylinderMesh.new()
	peak.top_radius = 0.095
	peak.bottom_radius = 0.095
	peak.height = 0.012
	peak.radial_segments = 16
	_accessory(peak, Vector3(0.0, base_y - 0.01, float(head["front"]) + 0.06), color.darkened(0.25), 0.8, Vector3(1.0, 1.0, 0.85), Vector3(0.12, 0.0, 0.0))


## Sunglasses: two dark lenses, a bridge and the arms back to the ears.
func _add_sunglasses(head: Dictionary, color: Color, aviator: bool) -> void:
	var eyes: float = head["eyes"]
	var front: float = float(head["front"]) + 0.006
	var half: float = head["half_width"]
	var lens := BoxMesh.new()
	lens.size = Vector3(0.058, 0.038 if aviator else 0.032, 0.008)
	var frame_color := Color(0.75, 0.6, 0.25) if aviator else Color(0.03, 0.03, 0.03)
	for side in [-1.0, 1.0]:
		_accessory(lens, Vector3(side * 0.036, eyes, front), color, 0.08, Vector3.ONE, Vector3(0.0, side * 0.12, 0.0))
	var bridge := BoxMesh.new()
	bridge.size = Vector3(0.022, 0.006, 0.008)
	_accessory(bridge, Vector3(0.0, eyes + 0.008, front + 0.002), frame_color, 0.3)
	var arm := BoxMesh.new()
	var back := float(head["back"]) * 0.2
	arm.size = Vector3(0.006, 0.006, front - back)
	for side in [-1.0, 1.0]:
		_accessory(arm, Vector3(side * (half + 0.004), eyes + 0.006, (front + back) * 0.5), frame_color, 0.3)


## Joints and shader regions for a body.
func _apply_rig(kind: String) -> void:
	var body: Dictionary = BODIES.get(kind, BODIES["male"])
	_shoulder = body["shoulder"]
	_hip_height = body["hip"]
	_hip = Vector3(0.0, _hip_height, 0.0)
	_hand = body["hand"]
	_roll = body["roll"]
	for key in body["shader"]:
		_material.set_shader_parameter(key, body["shader"][key])


## Pose uniforms go to the body and to whatever it wears.
func _set_param(param: String, value: Variant) -> void:
	_material.set_shader_parameter(param, value)
	for part in _accessories:
		(part.material_override as ShaderMaterial).set_shader_parameter(param, value)


## Multiplies the model colour, so other players are told apart at a glance.
func set_tint(tint: Color) -> void:
	_tint = tint
	if _material != null:
		var base: Variant = _material.get_shader_parameter("albedo_color")
		_material.set_shader_parameter("albedo_color", (base if base is Color else Color.WHITE) * tint)


func _process(delta: float) -> void:
	if _body == null or _material == null:
		return

	var horizontal := Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	var speed := horizontal.length()
	var local := _body.global_basis.inverse() * horizontal
	var grounded: bool = _body.call("net_grounded") if _body.has_method("net_grounded") else _body.is_on_floor()
	var moving := speed > 0.15 and grounded
	var backwards := local.z > 0.05
	var run_t := clampf((speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0.0, 1.0)

	_phase = fmod(_phase + delta * speed * PHASE_PER_METER * (-1.0 if backwards else 1.0), TAU)
	_walk_amount = move_toward(_walk_amount, 1.0 if moving else 0.0, delta * 6.0)
	_air_amount = move_toward(_air_amount, 0.0 if grounded else 1.0, delta * 5.0)
	if not moving and _walk_amount == 0.0:
		_phase = 0.0

	var target_lean := 0.0
	if moving:
		target_lean = 0.08 if backwards else -(0.05 + 0.12 * run_t)
	_lean = lerpf(_lean, target_lean, 1.0 - exp(-8.0 * delta))

	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0 and _flash != null:
			_flash.visible = false
	_recoil = move_toward(_recoil, 0.0, delta * 3.0)
	_raise_hold = maxf(_raise_hold - delta, 0.0)
	if _raise_hold > 0.0 or _weapon == "bazooka":
		_aim_amount = move_toward(_aim_amount, 1.0, delta * RAISE_SPEED)
	else:
		_aim_amount = move_toward(_aim_amount, 0.0, delta * LOWER_SPEED)
	var aim_t := smoothstep(0.0, 1.0, _aim_amount)
	if _swing_t >= 0.0:
		_swing_t += delta / SWING_TIME
		if _swing_t >= 1.0:
			_swing_t = -1.0
	var square_up := maxf(aim_t, 1.0 if _swing_t >= 0.0 else 0.0)

	# Turn the body toward strafe direction, mirrored when backpedalling; square up while aiming.
	var target_yaw := 0.0
	if speed > 0.15:
		if backwards:
			target_yaw = atan2(local.x, local.z)
		else:
			target_yaw = -atan2(local.x, -local.z)
		target_yaw = clampf(target_yaw, -MAX_TURN, MAX_TURN) * (1.0 - aim_t)
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-(10.0 + 20.0 * aim_t) * delta))
	rotation.y = _base_yaw + _yaw

	_set_param("phase", _phase)
	_set_param("walk_amount", _walk_amount)
	_set_param("air_amount", _air_amount)
	_set_param("leg_swing", lerpf(0.42, 0.62, run_t))
	_set_param("arm_swing", lerpf(0.45, 0.75, run_t))
	_set_param("knee_bend", lerpf(0.8, 1.25, run_t))
	_set_param("lean", _lean)
	_update_gun_arm(aim_t, run_t)


## Pose the gun arm (shader angles) and put the pistol in the resulting hand.
func _update_gun_arm(aim_t: float, run_t: float) -> void:
	if _gun_hand == null:
		return
	var to_mesh := _mesh.global_transform
	var swing := sin(_phase) * -1.0 # right side, as in the shader
	var rest_pitch := REST_PITCH - swing * lerpf(0.45, 0.75, run_t) * _walk_amount * 0.3
	rest_pitch = lerpf(rest_pitch, -0.45, _air_amount)

	# Aim pitch from the shoulder to the aim point, minus the body lean the shader adds on top.
	var aim_pitch := 0.0
	var shoulder_world := to_mesh * _shoulder
	var target := _get_aim_point(to_mesh)
	var to_target := target - shoulder_world
	if to_target.length_squared() > 0.01:
		aim_pitch = asin(clampf(to_target.normalized().y, -1.0, 1.0))
	aim_pitch = clampf(aim_pitch, deg_to_rad(-70.0), deg_to_rad(70.0))
	var pitch := lerpf(rest_pitch, -PI / 2.0 - aim_pitch - _lean, aim_t)
	var roll := lerpf(REST_ROLL + _roll, AIM_ROLL + _roll, aim_t)
	if _weapon != "pistol" and _weapon != "bazooka":
		pitch = rest_pitch
		roll = REST_ROLL + _roll
		if _weapon == "bat" and _swing_t >= 0.0:
			pitch = _swing_pitch(_swing_t, rest_pitch)
			roll = lerpf(REST_ROLL + _roll, AIM_ROLL + _roll, sin(_swing_t * PI))
	_set_param("gun_arm_pitch", pitch)
	_set_param("gun_arm_roll", roll)

	# Same transforms as the shader: shoulder roll + pitch, lean about the hip, planted-foot drop.
	var hand := Basis(Vector3.RIGHT, pitch) * (Basis(Vector3.BACK, roll) * (_hand - _shoulder)) + _shoulder
	hand = Basis(Vector3.RIGHT, _lean) * (hand - _hip) + _hip
	var stance := sin(_phase) * lerpf(0.42, 0.62, run_t) * _walk_amount * (1.0 - _air_amount)
	hand.y -= _hip_height * (1.0 - cos(stance))
	var hand_world := to_mesh * hand

	if _weapon == "bazooka":
		# The tube lies on the right shoulder and points at the aim point; the hand holds the grip.
		var on_shoulder := to_mesh * (Basis(Vector3.RIGHT, _lean) * (_shoulder + Vector3(0.03, 0.13, 0.0) - _hip) + _hip)
		var tube_dir := target - on_shoulder
		if tube_dir.length_squared() < 0.25:
			tube_dir = to_mesh.basis.z
		_bazooka.global_transform = Transform3D(Basis.looking_at(tube_dir.normalized(), to_mesh.basis.y.normalized()) * Basis(Vector3.RIGHT, _recoil * 0.5), on_shoulder)
		_gun_hand.global_transform = Transform3D(_bazooka.global_basis, hand_world)
		return

	if _weapon == "bat":
		# The bat continues the forearm, tilted forward.
		var arm := Basis(Vector3.RIGHT, pitch) * (Basis(Vector3.BACK, roll) * (_hand - _shoulder))
		var bat_dir := to_mesh.basis * Basis(Vector3.RIGHT, _lean) * (Basis(Vector3.RIGHT, BAT_TILT) * arm.normalized())
		var side := to_mesh.basis.x.normalized()
		if absf(bat_dir.normalized().dot(side)) > 0.95:
			side = to_mesh.basis.y.normalized()
		_gun_hand.global_transform = Transform3D(Basis.looking_at(bat_dir.normalized(), side), hand_world)
		return

	# Lowered: barrel forward-and-down along the leg. Raised: straight at the aim point.
	var down := REST_GUN_DOWN - (rest_pitch - REST_PITCH)
	var rest_dir := to_mesh.basis * Basis(Vector3.RIGHT, _lean) * Vector3(0.0, -sin(down), cos(down))
	var up := to_mesh.basis.y.normalized()
	var rest_basis := Basis.looking_at(rest_dir.normalized(), up)
	var aim_dir := target - hand_world
	if aim_dir.length_squared() < 0.04:
		aim_dir = to_mesh.basis.z
	var aim_basis := Basis.looking_at(aim_dir.normalized(), up)
	var rotation_q := Quaternion(rest_basis).slerp(Quaternion(aim_basis), aim_t)
	_gun_hand.global_transform = Transform3D(Basis(rotation_q) * Basis(Vector3.RIGHT, _recoil), hand_world)


## Arm pitch through a swing: wind up overhead and back, chop down in front, recover.
func _swing_pitch(t: float, rest: float) -> float:
	const WOUND := -3.3
	const STRUCK := -0.85
	if t < 0.38:
		return lerpf(rest, WOUND, smoothstep(0.0, 1.0, t / 0.38))
	if t < 0.58:
		var k := (t - 0.38) / 0.2
		return lerpf(WOUND, STRUCK, k * k * (3.0 - 2.0 * k))
	return lerpf(STRUCK, rest, smoothstep(0.0, 1.0, (t - 0.58) / 0.42))


func _get_aim_point(to_mesh: Transform3D) -> Vector3:
	if has_aim_point:
		return aim_point
	return to_mesh * (_shoulder + Vector3(0.0, 0.0, 20.0))
