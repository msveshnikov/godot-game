extends Node3D
## Drives the procedural walk/run/jump shader on the static main_player mesh
## from the parent CharacterBody3D's velocity, and keeps the foam pistol in the
## right hand: tucked against the body at rest, snapped up to aim when firing.

const BODY_SHADER: Shader = preload("res://player_body.gdshader")
const FOAM_PISTOL_SCENE: PackedScene = preload("res://foam_pistol_model.tscn")
const PHASE_PER_METER := 1.43  # ~one full stride cycle per 0.96 s at walk speed, matches footsteps
const WALK_SPEED := 4.5
const RUN_SPEED := 7.5
const MAX_TURN := deg_to_rad(50.0)

# Mirrors player_body.gdshader (mesh space: feet at y = 0, front +Z, right hand on -X).
const SHOULDER := Vector3(-0.22, 1.43, 0.0)
const HIP := Vector3(0.0, 0.86, 0.0)
const HIP_HEIGHT := 0.86
const HAND := Vector3(-0.525, 0.855, 0.143) # palm of the A-posed right hand
const REST_PITCH := -0.22
const REST_ROLL := 0.36
const AIM_ROLL := 0.5 # brings the outstretched arm in front of the right shoulder
const REST_GUN_DOWN := deg_to_rad(62.0) # barrel angle below horizontal while lowered
const PISTOL_SCALE := 0.5
const PISTOL_GRIP := Vector3(0.13, -0.17, 0.0) # where the palm closes on foam_pistol_model.tscn
const PISTOL_MUZZLE := Vector3(-0.46, 0.12, 0.0)
const RAISE_SPEED := 11.0 # up in ~0.09 s
const LOWER_SPEED := 3.0
const RAISED_HOLD := 0.9 # seconds the arm stays up after the last shot

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
	if source != null:
		_material.set_shader_parameter("albedo_texture", source.albedo_texture)
		_material.set_shader_parameter("albedo_color", source.albedo_color)
		_material.set_shader_parameter("roughness", source.roughness)
	mesh_instance.material_override = _material
	_build_gun()


## Gun hand -> pistol (barrel along the hand's -Z, palm on the grip) -> muzzle.
func _build_gun() -> void:
	_gun_hand = Node3D.new()
	_gun_hand.name = "GunHand"
	_gun_hand.top_level = true
	add_child(_gun_hand)
	var pistol := FOAM_PISTOL_SCENE.instantiate() as Node3D
	pistol.name = "HeldPistol"
	pistol.scale = Vector3.ONE * PISTOL_SCALE
	pistol.rotation.y = -PI / 2.0 # model barrel points -X; turn it to -Z
	pistol.position = -(pistol.basis * PISTOL_GRIP)
	_gun_hand.add_child(pistol)
	_muzzle = Marker3D.new()
	_muzzle.name = "GunMuzzle"
	_muzzle.position = PISTOL_MUZZLE
	pistol.add_child(_muzzle)


## Snap the gun up to aim (or keep it up); it drops back after RAISED_HOLD without shots.
func raise_gun() -> void:
	_raise_hold = RAISED_HOLD


## True once the arm is up far enough for the shot to leave the barrel toward the aim point.
func is_gun_raised() -> bool:
	return _aim_amount >= 0.92


func get_muzzle() -> Marker3D:
	return _muzzle


## Multiplies the model colour, so other players are told apart at a glance.
func set_tint(tint: Color) -> void:
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

	_raise_hold = maxf(_raise_hold - delta, 0.0)
	if _raise_hold > 0.0:
		_aim_amount = move_toward(_aim_amount, 1.0, delta * RAISE_SPEED)
	else:
		_aim_amount = move_toward(_aim_amount, 0.0, delta * LOWER_SPEED)
	var aim_t := smoothstep(0.0, 1.0, _aim_amount)

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

	_material.set_shader_parameter("phase", _phase)
	_material.set_shader_parameter("walk_amount", _walk_amount)
	_material.set_shader_parameter("air_amount", _air_amount)
	_material.set_shader_parameter("leg_swing", lerpf(0.42, 0.62, run_t))
	_material.set_shader_parameter("arm_swing", lerpf(0.45, 0.75, run_t))
	_material.set_shader_parameter("knee_bend", lerpf(0.8, 1.25, run_t))
	_material.set_shader_parameter("lean", _lean)
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
	var shoulder_world := to_mesh * SHOULDER
	var target := _get_aim_point(to_mesh)
	var to_target := target - shoulder_world
	if to_target.length_squared() > 0.01:
		aim_pitch = asin(clampf(to_target.normalized().y, -1.0, 1.0))
	aim_pitch = clampf(aim_pitch, deg_to_rad(-70.0), deg_to_rad(70.0))
	var pitch := lerpf(rest_pitch, -PI / 2.0 - aim_pitch - _lean, aim_t)
	var roll := lerpf(REST_ROLL, AIM_ROLL, aim_t)
	_material.set_shader_parameter("gun_arm_pitch", pitch)
	_material.set_shader_parameter("gun_arm_roll", roll)

	# Same transforms as the shader: shoulder roll + pitch, lean about the hip, planted-foot drop.
	var hand := Basis(Vector3.RIGHT, pitch) * (Basis(Vector3.BACK, roll) * (HAND - SHOULDER)) + SHOULDER
	hand = Basis(Vector3.RIGHT, _lean) * (hand - HIP) + HIP
	var stance := sin(_phase) * lerpf(0.42, 0.62, run_t) * _walk_amount * (1.0 - _air_amount)
	hand.y -= HIP_HEIGHT * (1.0 - cos(stance))
	var hand_world := to_mesh * hand

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
	_gun_hand.global_transform = Transform3D(Basis(rotation_q), hand_world)


func _get_aim_point(to_mesh: Transform3D) -> Vector3:
	if has_aim_point:
		return aim_point
	return to_mesh * (SHOULDER + Vector3(0.0, 0.0, 20.0))
