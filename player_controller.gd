extends CharacterBody3D

const SHOT_SOUND: AudioStream = preload("res://audio/pistol_shot.ogg")
const MOBILE_CONTROLS_SCRIPT = preload("res://mobile_controls.gd")
const BAT_HIT_SOUND: AudioStream = preload("res://audio/bat_hit.ogg")
const BAT_WOOSH_SOUND: AudioStream = preload("res://audio/bat_woosh.ogg")
const BAT_RANGE := 2.6
const BAT_HIT_DELAY := 0.24 # from the start of the swing to the moment the bat comes down
const BAT_COOLDOWN := 0.62
const WEAPONS := ["pistol", "bat", "none"]
const WEAPON_NAMES := {"pistol": "Pistol", "bat": "Baseball bat", "none": "Hands"}
const MAX_HEALTH := 100
const FIRE_INTERVAL := 0.22
const SHOT_RANGE := 150.0
const CAMERA_KICK := 0.014 # radians the view jumps up per shot
## Where a round lands on a standing person, in metres above the feet.
const HEAD_HEIGHT := 1.5
const CHEST_HEIGHT := 1.12
const BELLY_HEIGHT := 0.86
const BODY_RADIUS := 0.32
const BAT_PLAYER_DAMAGE := 30
const SPAWN_PROTECTION := 2.0
## Camera pitch that puts the crosshair on a standing person's chest ~10 m ahead.
const LEVEL_PITCH := -0.08
## Touch auto-camera: how fast the view turns toward the stick direction (per radian off-axis).
const AUTO_YAW_RATE := 0.9
const AUTO_YAW_RUN_RATE := 1.2
const AUTO_YAW_MAX_ANGLE := 2.0 # ~115°: further back counts as backing up, no turning
const AUTO_PITCH_RATE := 2.5
const RUN_FOOTSTEP_SOUNDS: Array[AudioStream] = [
	preload("res://addons/cogito/Assets/Audio/Kenney/Footsteps/footstep00.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Footsteps/footstep01.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Footsteps/footstep02.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Footsteps/footstep03.ogg"),
	preload("res://addons/cogito/Assets/Audio/Kenney/Footsteps/footstep04.ogg"),
]
const WALK_FOOTSTEP_INTERVAL := 0.48
const RUN_FOOTSTEP_INTERVAL := 0.3
@export var walk_speed := 4.5
@export var run_speed := 7.5
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.0025
@export var invert_mouse_y := false

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var interact_ray: RayCast3D = $CameraPivot/SpringArm3D/Camera3D/InteractRay
@onready var model: Node3D = $MainPlayerModel # player_model_animator.gd: holds the pistol
@onready var hud: CanvasLayer = $HUD

var has_gun := true
## Held weapon: "pistol", "bat" or "none" (hands empty: people stop running away).
var weapon := "pistol"
var health := MAX_HEALTH
var _can_fire := true
var _shot_pending := false
var _aim_target := Vector3.ZERO
var _game_started := false
var _game_over := false
var _fire_sound: AudioStreamPlayer
var _footstep_sound: AudioStreamPlayer
var _footstep_timer := 0.0
var _mobile_controls: MobileControls
var _health_label: Label
var _weapon_label: Label
var _bat_sound: AudioStreamPlayer
var _woosh_sound: AudioStreamPlayer
var _start_screen: Control
var _game_over_screen: Control
var _name_edit: LineEdit
var _crosshair: Crosshair
var _damage_flash: ColorRect
var _protection := 0.0
var _auto_yaw_speed := 0.0


func _ready() -> void:
	add_to_group("player")
	_move_to_random_spawn()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _is_touch_device():
		_mobile_controls = MOBILE_CONTROLS_SCRIPT.new()
		add_child(_mobile_controls)
		_mobile_controls.visible = false
		_mobile_controls.swap_pressed.connect(func() -> void: _cycle_weapon(1))
		_mobile_controls.look_delta.connect(_apply_look_delta)
	_fire_sound = AudioStreamPlayer.new()
	_fire_sound.name = "PistolShotSound"
	_fire_sound.stream = SHOT_SOUND
	_fire_sound.volume_db = -3.0
	_fire_sound.max_polyphony = 3
	add_child(_fire_sound)
	_bat_sound = AudioStreamPlayer.new()
	_bat_sound.name = "BatHitSound"
	_bat_sound.stream = BAT_HIT_SOUND
	add_child(_bat_sound)
	_woosh_sound = AudioStreamPlayer.new()
	_woosh_sound.name = "BatWoosh"
	_woosh_sound.stream = BAT_WOOSH_SOUND
	_woosh_sound.volume_db = -4.0
	add_child(_woosh_sound)
	_add_falling_leaves()
	_footstep_sound = AudioStreamPlayer.new()
	_footstep_sound.name = "RunFootsteps"
	_footstep_sound.volume_db = -2.0
	add_child(_footstep_sound)
	_setup_game_ui()
	_update_health_ui()


## Autumn leaves drifting down around the player, wherever they go.
func _add_falling_leaves() -> void:
	var leaves := CPUParticles3D.new()
	leaves.name = "FallingLeaves"
	leaves.amount = 160
	leaves.lifetime = 12.0
	leaves.preprocess = 12.0
	leaves.local_coords = false
	leaves.position = Vector3(0, 9.0, 0)
	leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	leaves.emission_box_extents = Vector3(22.0, 4.0, 22.0)
	leaves.direction = Vector3(0.3, -1.0, 0.2)
	leaves.spread = 25.0
	leaves.initial_velocity_min = 0.3
	leaves.initial_velocity_max = 0.8
	leaves.gravity = Vector3(0.35, -0.55, 0.15)
	leaves.angular_velocity_min = -180.0
	leaves.angular_velocity_max = 180.0
	leaves.angle_min = 0.0
	leaves.angle_max = 360.0
	leaves.scale_amount_min = 0.7
	leaves.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.9, 0.68, 0.12))
	ramp.set_color(1, Color(0.62, 0.18, 0.07))
	ramp.add_point(0.4, Color(0.85, 0.42, 0.08))
	ramp.add_point(0.7, Color(0.5, 0.31, 0.12))
	leaves.color_initial_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.13, 0.09)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	quad.material = material
	leaves.mesh = quad
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(leaves)


## True while this player is in the world and can be targeted (not on the start or game-over screen).
func is_playing() -> bool:
	return _game_started and not _game_over


## People run away from a player holding a pistol or a bat.
func is_armed() -> bool:
	return weapon != "none"


func set_weapon(value: String) -> void:
	if not WEAPONS.has(value) or value == weapon:
		return
	weapon = value
	_shot_pending = false
	model.call("set_weapon", weapon)
	_update_weapon_ui()


func _cycle_weapon(step: int) -> void:
	set_weapon(WEAPONS[(WEAPONS.find(weapon) + step + WEAPONS.size()) % WEAPONS.size()])


func _is_touch_device() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return OS.has_feature("web") and DisplayServer.is_touchscreen_available()


func _process(delta: float) -> void:
	_protection = maxf(_protection - delta, 0.0)
	_aim_target = _get_aim_target()
	model.set("aim_point", _aim_target)
	model.set("has_aim_point", true)
	if _crosshair != null:
		_crosshair.visible = is_playing() and weapon == "pistol"
	if _mobile_controls != null:
		_mobile_controls.visible = is_playing()
		if _mobile_controls.fire_held:
			_attack()
		_auto_camera(delta)
	# The trigger snaps the arm up first; the round leaves the barrel once it points at the target.
	if _shot_pending and model.call("is_gun_raised"):
		_shot_pending = false
		_fire_shot()


func _input(event: InputEvent) -> void:
	if not _game_started or _game_over:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_attack()
			KEY_1:
				set_weapon("pistol")
			KEY_2:
				set_weapon("bat")
			KEY_3:
				set_weapon("none")
	elif _mobile_controls == null and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_attack()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_weapon(1)


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look_delta(event.relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()


func _apply_look_delta(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	var vertical_mouse_direction := 1.0 if invert_mouse_y else -1.0
	camera_pivot.rotate_x(relative.y * mouse_sensitivity * vertical_mouse_direction)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(-60.0), deg_to_rad(35.0))


## Touch screens: aiming with the second thumb is hard, so while the stick is moving the
## player the camera swings round to the way they walk and levels out at chest height.
## It keeps its hands off while a finger is turning the camera, and when walking backwards.
func _auto_camera(delta: float) -> void:
	if not is_playing() or _mobile_controls.is_looking():
		_auto_yaw_speed = 0.0
		return
	var stick := _mobile_controls.movement_direction
	if stick == Vector2.ZERO:
		_auto_yaw_speed = 0.0
		return
	var heading := atan2(stick.x, -stick.y) # 0 = straight ahead, + = to the right
	var target_speed := 0.0
	if absf(heading) < AUTO_YAW_MAX_ANGLE:
		var rate := AUTO_YAW_RUN_RATE if _mobile_controls.run_pressed else AUTO_YAW_RATE
		target_speed = heading * rate * stick.length()
	_auto_yaw_speed = lerpf(_auto_yaw_speed, target_speed, 1.0 - exp(-6.0 * delta))
	rotate_y(-_auto_yaw_speed * delta)
	camera_pivot.rotation.x = lerp_angle(camera_pivot.rotation.x, LEVEL_PITCH, 1.0 - exp(-AUTO_PITCH_RATE * delta))


func _interact() -> void:
	if not interact_ray.is_colliding():
		return

	var target := interact_ray.get_collider()
	if not target.has_method("interact"):
		return

	target.call("interact")


## Drop the player at a random open spot in the estate, facing the home block.
## The small jitter keeps two players spawning together from standing inside each other.
func _move_to_random_spawn() -> void:
	var district := get_node_or_null("../Diorama/District")
	var spots: Array = district.call("spawn_points") if district != null and district.has_method("spawn_points") else [Vector2.ZERO]
	var spot: Vector2 = spots[randi() % spots.size()]
	var yaw: float = district.call("spawn_yaw") if district != null and district.has_method("spawn_yaw") else PI
	var jitter := Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0))
	global_transform = Transform3D(
		Basis(Vector3.UP, yaw),
		Vector3(spot.x + jitter.x, 0.9, spot.y + jitter.y)
	)
	camera_pivot.rotation.x = LEVEL_PITCH


## Fire the pistol or swing the bat, whichever is in hand.
func _attack() -> void:
	match weapon:
		"pistol":
			_pull_trigger()
		"bat":
			_swing_bat()


func _swing_bat() -> void:
	if not is_playing() or not _can_fire:
		return
	_can_fire = false
	model.call("swing")
	_woosh_sound.pitch_scale = randf_range(0.9, 1.15)
	_woosh_sound.play()
	var net_world := get_tree().current_scene.get_node_or_null("NetWorld")
	if net_world != null:
		net_world.call("broadcast_swing")
	await get_tree().create_timer(BAT_HIT_DELAY).timeout
	_bat_hit()
	await get_tree().create_timer(BAT_COOLDOWN - BAT_HIT_DELAY).timeout
	_can_fire = true


## Knock down every villager within reach in front of the player.
func _bat_hit() -> void:
	if not is_playing():
		return
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var hit_any := false
	for villager in get_tree().get_nodes_in_group("villagers"):
		var body := villager as Node3D
		if not body.call("can_be_hit"):
			continue
		var to_body := body.global_position - global_position
		to_body.y = 0.0
		if to_body.length() > BAT_RANGE:
			continue
		if to_body.length() > 0.4 and forward.dot(to_body.normalized()) < 0.45:
			continue
		body.call("receive_hit", "bat")
		hit_any = true
	var net_world := get_tree().current_scene.get_node_or_null("NetWorld")
	for remote in get_tree().get_nodes_in_group("remote_players"):
		var other := remote as Node3D
		if net_world == null or not other.get("active") or not other.visible:
			continue
		var to_other := other.global_position - global_position
		to_other.y = 0.0
		if to_other.length() > BAT_RANGE:
			continue
		if to_other.length() > 0.4 and forward.dot(to_other.normalized()) < 0.45:
			continue
		net_world.call("send_damage", int(other.get("peer_id")), BAT_PLAYER_DAMAGE, "bat")
		ShotFx.blood(get_tree().current_scene, other.global_position + Vector3.UP * 0.6, forward)
		hit_any = true
	if hit_any:
		_bat_sound.pitch_scale = randf_range(0.9, 1.1)
		_bat_sound.play()


func _pull_trigger() -> void:
	if not is_playing() or weapon != "pistol" or not _can_fire:
		return

	_can_fire = false
	_shot_pending = true
	model.call("raise_gun")
	await get_tree().create_timer(FIRE_INTERVAL).timeout
	_can_fire = true


## One round, hitscan: it goes where the crosshair points (the camera ray), and the
## tracer is drawn from the muzzle. Villagers die from any hit; other players take
## damage by where they were hit (pistol_damage) and are told over the network.
func _fire_shot() -> void:
	if not is_playing():
		return
	var scene := get_tree().current_scene
	var muzzle := (model.call("get_muzzle") as Marker3D).global_position
	var hit := _shoot_ray()
	var end: Vector3 = hit.get("position", camera.global_position - camera.global_basis.z * SHOT_RANGE)
	var target := _shot_target(hit.get("collider"))
	var flesh := false
	var net_world := scene.get_node_or_null("NetWorld")
	if target != null and target.is_in_group("villagers"):
		target.call("receive_hit", "pistol")
		flesh = true
	elif target != null and target.is_in_group("remote_players"):
		var damage := pistol_damage((target as Node3D).global_position - Vector3.UP * 0.9, end, muzzle.direction_to(end))
		if net_world != null:
			net_world.call("send_damage", int(target.get("peer_id")), damage[0], damage[1])
		_crosshair.show_hit(damage[1] == "head")
		flesh = true
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	if target == null and not hit.is_empty():
		_shoot_car(hit, net_world)
	if flesh:
		ShotFx.blood(scene, end, muzzle.direction_to(end))
	elif not hit.is_empty():
		ShotFx.impact(scene, end, normal)
	ShotFx.tracer(scene, muzzle, end)
	model.call("fire_effects")
	_crosshair.kick()
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x + CAMERA_KICK, deg_to_rad(-60.0), deg_to_rad(35.0))
	if net_world != null:
		net_world.call("broadcast_shot", muzzle, end, flesh, normal)
	_fire_sound.pitch_scale = randf_range(0.96, 1.04)
	_fire_sound.play()


## A round into a car (parked: the district; driving: the traffic) blows it up,
## here and, through NetWorld, on everyone else's screen.
func _shoot_car(hit: Dictionary, net_world: Node) -> void:
	var cars := (hit["collider"] as Node).get_parent()
	if cars == null or not cars.has_method("car_index_at"):
		return
	var index: int = cars.call("car_index_at", hit)
	if index < 0:
		return
	var s: float = cars.call("car_progress", index)
	if cars.call("blow_up_car", index, s, Net.my_id) and net_world != null:
		net_world.call("broadcast_car", "traffic" if cars.name == "Traffic" else "parked", index, s)


## Camera ray from level with the player (so nothing between the camera and the
## player's back gets hit) out to SHOT_RANGE. Goes through: ourselves, civilians
## (bullets are not for them), players who are not in the game, and the empty
## corners of a player's capsule beside the head.
func _shoot_ray() -> Dictionary:
	var forward := -camera.global_basis.z
	var from := camera.global_position
	from += forward * maxf((global_position - from).dot(forward), 0.0)
	var to := from + forward * SHOT_RANGE
	var exclude: Array[RID] = [get_rid()]
	var space := get_world_3d().direct_space_state
	for attempt in 6:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return hit
		var target := _shot_target(hit.get("collider"))
		var pass_through := false
		if target != null and target.is_in_group("civilians"):
			pass_through = true
		elif target != null and target.is_in_group("remote_players"):
			var feet := (target as Node3D).global_position - Vector3.UP * 0.9
			var point: Vector3 = hit["position"]
			var off_centre := off_centre_of(feet, point, forward)
			var beside_head := point.y - feet.y >= HEAD_HEIGHT - 0.02 and off_centre > 0.6
			pass_through = not target.get("active") or not (target as Node3D).visible or beside_head
		if not pass_through:
			return hit
		exclude.append((hit["collider"] as CollisionObject3D).get_rid())
	return {}


## The person (villager, civilian, other player) a collider belongs to, or null.
func _shot_target(collider: Variant) -> Node:
	var node := collider as Node
	while node != null and node != get_tree().current_scene:
		if node.is_in_group("villagers") or node.is_in_group("civilians") or node.is_in_group("remote_players"):
			return node
		node = node.get_parent()
	return null


## How far from the middle of the body a round passes, 0 (dead centre) .. 1 (the edge):
## the round's line seen from above against the body's vertical axis. The hit point
## itself always lies on the capsule's surface, so its own distance says nothing.
static func off_centre_of(feet: Vector3, point: Vector3, direction: Vector3) -> float:
	var to_axis := Vector2(feet.x - point.x, feet.z - point.z)
	var flat := Vector2(direction.x, direction.z)
	if flat.length_squared() < 0.0001:
		return to_axis.length() / BODY_RADIUS
	return absf(flat.normalized().cross(to_axis)) / BODY_RADIUS


## [damage, zone] of one round landing at `point` on a standing person whose feet are
## at `feet`. Head: dead. Chest (heart, lungs) hurts most, the belly less, legs least;
## the nearer the middle of the body, the more (34 at the heart, ~24 at the side).
static func pistol_damage(feet: Vector3, point: Vector3, direction := Vector3.ZERO) -> Array:
	var height := point.y - feet.y
	var off_centre := clampf(off_centre_of(feet, point, direction), 0.0, 1.0)
	if height >= HEAD_HEIGHT:
		return [MAX_HEALTH, "head"]
	if height >= CHEST_HEIGHT:
		return [roundi(lerpf(34.0, 24.0, off_centre)), "chest"]
	if height >= BELLY_HEIGHT:
		return [roundi(lerpf(28.0, 20.0, off_centre)), "belly"]
	return [roundi(lerpf(20.0, 15.0, off_centre)), "legs"]


## Hurt by a villager's foam (attacker 0) or by another player (their peer id and the
## body zone, or "bat"). Freshly respawned players are safe for a moment.
func receive_damage(amount: float, attacker := 0, zone := "") -> void:
	if not is_playing() or amount <= 0.0 or _protection > 0.0:
		return

	health = maxi(health - roundi(amount), 0)
	_update_health_ui()
	_flash_damage(0.55 if zone == "head" else 0.35)
	if health > 0:
		return
	var net_world := get_tree().current_scene.get_node_or_null("NetWorld")
	var killer := ""
	if attacker != 0 and attacker != Net.my_id and net_world != null:
		killer = net_world.call("peer_name", attacker)
		net_world.call("report_death", attacker, zone)
	var how: String = {"head": " with a headshot", "bat": " with a bat", "blast": " with an exploding car"}.get(zone, "")
	var text := "The villagers got you."
	if zone == "blast" and (killer.is_empty() or attacker == Net.my_id):
		text = "You were too close to an exploding car."
	elif not killer.is_empty():
		text = "Killed by %s%s." % [killer, how]
	_set_game_over_text(text)
	_end_game()


func _flash_damage(strength: float) -> void:
	if _damage_flash == null:
		return
	_damage_flash.color.a = strength
	var tween := _damage_flash.create_tween()
	tween.tween_property(_damage_flash, "color:a", 0.0, 0.5)


func _set_game_over_text(text: String) -> void:
	var label := _game_over_screen.get_meta("description", null) as Label
	if label != null:
		label.text = text


## What the screen centre points at: the first thing the camera ray hits past the player, else far away.
func _get_aim_target() -> Vector3:
	var from := camera.global_position
	var forward := -camera.global_basis.z
	var far_point := from + forward * 120.0
	var query := PhysicsRayQueryParameters3D.create(from, far_point)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or from.distance_to(hit.position) < 4.0:
		return far_point
	return hit.position


func _physics_process(delta: float) -> void:
	if not _game_started or _game_over:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_physical_key_pressed(KEY_SPACE) or (_mobile_controls != null and _mobile_controls.jump_pressed):
		velocity.y = jump_velocity

	var input_direction := Vector2.ZERO
	input_direction.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	input_direction.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	if _mobile_controls != null:
		input_direction += _mobile_controls.movement_direction
	input_direction = input_direction.limit_length(1.0)

	var direction := transform.basis * Vector3(input_direction.x, 0.0, input_direction.y)
	direction.y = 0.0
	direction = direction.normalized()
	var is_running := Input.is_physical_key_pressed(KEY_SHIFT) or (_mobile_controls != null and _mobile_controls.run_pressed)
	var speed := run_speed if is_running else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()
	_update_footsteps(delta, input_direction.length_squared() > 0.0, is_running)


func _update_footsteps(delta: float, has_movement_input: bool, is_running: bool) -> void:
	if not has_movement_input or not is_on_floor() or Vector2(velocity.x, velocity.z).length_squared() < 0.01:
		_footstep_timer = 0.0
		return

	_footstep_timer -= delta
	if _footstep_timer > 0.0:
		return

	_footstep_sound.stream = RUN_FOOTSTEP_SOUNDS[randi_range(0, RUN_FOOTSTEP_SOUNDS.size() - 1)]
	_footstep_sound.pitch_scale = randf_range(0.94, 1.06)
	_footstep_sound.play()
	_footstep_timer = RUN_FOOTSTEP_INTERVAL if is_running else WALK_FOOTSTEP_INTERVAL


func _setup_game_ui() -> void:
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.layer = 20
	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(0.8, 0.0, 0.0, 0.0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_damage_flash)
	_crosshair = Crosshair.new()
	_crosshair.visible = false
	hud.add_child(_crosshair)
	_health_label = _make_hud_label("Health: %d / %d" % [MAX_HEALTH, MAX_HEALTH], 24.0, 58.0, 22)
	_weapon_label = _make_hud_label("", 58.0, 90.0, 18)
	_update_weapon_ui()
	var district := get_node_or_null("../Diorama/District")
	var intro: String = district.call("intro_text") if district != null and district.has_method("intro_text") else ""
	_start_screen = _make_game_screen(
		"GACHA VILLAGE",
		intro + "\nPlay together: open the same game on another device and pick the same place.\n\nWASD move  |  Shift run  |  Space jump  |  Mouse look\nQ / click: fire or swing  |  1 pistol  2 bat  3 hands (or mouse wheel)\nPlayers can shoot each other: a headshot kills, a body hit takes 15-34, a bat 30.",
		"START GAME",
		_start_game,
		true
	)
	_game_over_screen = _make_game_screen(
		"GAME OVER",
		"The villagers got you.",
		"RESPAWN",
		_restart_game
	)
	_game_over_screen.hide()


func _make_hud_label(label_text: String, top: float, bottom: float, font_size: int) -> Label:
	var label := Label.new()
	label.offset_left = 24.0
	label.offset_top = top
	label.offset_right = 340.0
	label.offset_bottom = bottom
	label.text = label_text
	label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.75, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04, 1.0))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", font_size)
	hud.add_child(label)
	return label


func _make_game_screen(title_text: String, message: String, button_text: String, action: Callable, with_name := false) -> Control:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.045, 0.065, 0.84)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 470.0 if with_name else 360.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.13, 0.16, 0.98)
	panel_style.border_color = Color(0.76, 0.57, 0.3, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 18)
	margin.add_child(contents)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.54, 1.0))
	title.add_theme_font_size_override("font_size", 36)
	contents.add_child(title)

	var description := Label.new()
	description.text = message
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_color_override("font_color", Color(0.91, 0.94, 0.91, 1.0))
	description.add_theme_font_size_override("font_size", 18)
	contents.add_child(description)

	if with_name:
		contents.add_child(_make_location_row())
		_name_edit = LineEdit.new()
		_name_edit.text = Net.player_name
		_name_edit.placeholder_text = "Your name"
		_name_edit.max_length = 16
		_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_edit.custom_minimum_size = Vector2(260.0, 44.0)
		_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_name_edit.add_theme_font_size_override("font_size", 20)
		_name_edit.text_submitted.connect(func(_text: String) -> void: _start_game())
		contents.add_child(_name_edit)

	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(220.0, 52.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	contents.add_child(button)
	overlay.set_meta("description", description)
	return overlay


## One button per place (Net.LOCATIONS); the current one is lit. Picking another
## rebuilds the world there and joins that place's multiplayer room.
func _make_location_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for entry in Net.LOCATIONS:
		var button := Button.new()
		button.text = entry["name"]
		button.toggle_mode = true
		button.button_pressed = entry["id"] == Net.location
		button.custom_minimum_size = Vector2(140.0, 44.0)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 18)
		var lit := StyleBoxFlat.new()
		lit.bg_color = Color(0.76, 0.57, 0.3)
		lit.set_corner_radius_all(8)
		button.add_theme_stylebox_override("pressed", lit)
		button.add_theme_stylebox_override("hover_pressed", lit)
		button.add_theme_color_override("font_pressed_color", Color(0.08, 0.1, 0.12))
		button.add_theme_color_override("font_hover_pressed_color", Color(0.08, 0.1, 0.12))
		var id: String = entry["id"]
		button.pressed.connect(func() -> void: _choose_location(id, button))
		row.add_child(button)
	return row


func _choose_location(id: String, button: Button) -> void:
	if id == Net.location:
		button.button_pressed = true
		return
	if _name_edit != null:
		Net.set_player_name(_name_edit.text)
	Net.set_location(id)
	get_tree().reload_current_scene()


func _update_weapon_ui() -> void:
	if _weapon_label != null:
		_weapon_label.text = "%s   [1] pistol  [2] bat  [3] hands" % WEAPON_NAMES[weapon]


func _update_health_ui() -> void:
	if _health_label == null:
		return
	_health_label.text = "Health: %d / %d" % [health, MAX_HEALTH]
	_health_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.94, 0.75, 1.0) if health > 30 else Color(1.0, 0.35, 0.28, 1.0)
	)


func _start_game() -> void:
	if _game_started:
		return
	_game_started = true
	if _name_edit != null:
		Net.set_player_name(_name_edit.text)
		_name_edit.release_focus()
	_start_screen.hide()
	if _mobile_controls == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _end_game() -> void:
	if _game_over:
		return
	_game_over = true
	_game_over_screen.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	velocity = Vector3.ZERO


## Back into the estate at a random spot with full health; the world (and the other players) carry on.
func _restart_game() -> void:
	_move_to_random_spawn()
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	_protection = SPAWN_PROTECTION
	_can_fire = true
	_shot_pending = false
	_update_health_ui()
	_game_over_screen.hide()
	_game_over = false
	if _mobile_controls == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
