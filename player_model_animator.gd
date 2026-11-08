extends Node3D
## Drives the procedural walk/run/jump shader on the static main_player mesh
## from the parent CharacterBody3D's velocity.

const BODY_SHADER: Shader = preload("res://player_body.gdshader")
const PHASE_PER_METER := 1.43  # ~one full stride cycle per 0.96 s at walk speed, matches footsteps
const WALK_SPEED := 4.5
const RUN_SPEED := 7.5
const MAX_TURN := deg_to_rad(50.0)

var _body: CharacterBody3D
var _material: ShaderMaterial
var _phase := 0.0
var _walk_amount := 0.0
var _air_amount := 0.0
var _lean := 0.0
var _yaw := 0.0
var _base_yaw := 0.0


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

	_material = ShaderMaterial.new()
	_material.shader = BODY_SHADER
	var source := mesh_instance.get_active_material(0) as BaseMaterial3D
	if source != null:
		_material.set_shader_parameter("albedo_texture", source.albedo_texture)
		_material.set_shader_parameter("albedo_color", source.albedo_color)
		_material.set_shader_parameter("roughness", source.roughness)
	mesh_instance.material_override = _material


func _process(delta: float) -> void:
	if _body == null or _material == null:
		return

	var horizontal := Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	var speed := horizontal.length()
	var local := _body.global_basis.inverse() * horizontal
	var grounded := _body.is_on_floor()
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

	# Turn the body toward strafe direction, mirrored when backpedalling.
	var target_yaw := 0.0
	if speed > 0.15:
		if backwards:
			target_yaw = atan2(local.x, local.z)
		else:
			target_yaw = -atan2(local.x, -local.z)
		target_yaw = clampf(target_yaw, -MAX_TURN, MAX_TURN)
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-10.0 * delta))
	rotation.y = _base_yaw + _yaw

	_material.set_shader_parameter("phase", _phase)
	_material.set_shader_parameter("walk_amount", _walk_amount)
	_material.set_shader_parameter("air_amount", _air_amount)
	_material.set_shader_parameter("leg_swing", lerpf(0.42, 0.62, run_t))
	_material.set_shader_parameter("arm_swing", lerpf(0.45, 0.75, run_t))
	_material.set_shader_parameter("knee_bend", lerpf(0.8, 1.25, run_t))
	_material.set_shader_parameter("lean", _lean)
