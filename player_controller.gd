extends CharacterBody3D

const SHOT_SOUND: AudioStream = preload("res://audio/pistol_shot.ogg")
const MOBILE_CONTROLS_SCRIPT = preload("res://mobile_controls.gd")
const BAT_HIT_SOUND: AudioStream = preload("res://audio/bat_hit.ogg")
const BAT_WOOSH_SOUND: AudioStream = preload("res://audio/bat_woosh.ogg")
const BAT_RANGE := 2.6
const BAT_HIT_DELAY := 0.24 # from the start of the swing to the moment the bat comes down
const BAT_COOLDOWN := 0.62
const WEAPON_NAMES := {"pistol": "Desert Eagle", "bat": "Baseball bat", "bazooka": "Bazooka", "none": "Hands", "m4a1": "M4A1"}
const ROCKET_RELOAD := 1.4 # seconds between rockets
const ROCKET_KICK := 0.06
const MAX_HEALTH := 100
const FIRE_INTERVAL := 0.22
const M4A1_FIRE_INTERVAL := 0.10
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
## What smashing things pays (coins popping out) and how much heat it draws (police.gd).
const CASH_DENT := 5
const CASH_CRACK := 10
const CASH_SMASH := 25
const CASH_CAR := 40
const DENTS_PAID_PER_CAR := 6
const HEAT_DENT := 3.0
const HEAT_CRACK := 5.0
const HEAT_SMASH := 10.0
const HEAT_CAR := 30.0
const HEAT_KILL := 20.0
const CASH_WALL := 30 # a hole blown in a building
const CASH_CRATER := 10
const HEAT_ROCKET := 25.0
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
var _health_bar: HealthBar
var _weapon_bar: WeaponBar
var _bat_sound: AudioStreamPlayer
var _woosh_sound: AudioStreamPlayer
var _game_over_screen: Control
var _pause_screen: Control
var _pause_button: Button
var _shop: Shop
var _paused := false
var _crosshair: Crosshair
var _damage_flash: ColorRect
var _protection := 0.0
var _auto_yaw_speed := 0.0
var _money_label: Label
var _toast_label: Label
var _police: Police
var _shake := 0.0
var _vibration_ends_at := 0
var _vibration_amplitude := 0.0
## Bat blows paid so far per car ("<cars node id>:<index>"), so one car can't be farmed forever.
var _dents_paid := {}


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
	_police = Police.new()
	_police.name = "Police"
	_police.player = self
	get_parent().add_child.call_deferred(_police)
	Game.money_changed.connect(_on_money_changed)
	model.call("apply_look", Game.look)
	_start_game.call_deferred()
	Game.look_changed.connect(func() -> void: model.call("apply_look", Game.look))
	Game.arsenal_changed.connect(_on_arsenal_changed)
	_on_arsenal_changed.call_deferred()


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
	return _game_started and not _game_over and not _paused


## People run away from a player holding a pistol or a bat.
func is_armed() -> bool:
	return weapon != "none"


func set_weapon(value: String) -> void:
	if not WeaponBar.ORDER.has(value) or value == weapon:
		return
	if value == "bazooka" and not Game.has_bazooka:
		show_toast("Buy the bazooka in the SHOP ($%d)" % Game.BAZOOKA_PRICE)
		return
	if value == "m4a1" and not Game.has_m4a1:
		show_toast("Buy the M4A1 in the SHOP ($%d)" % Game.M4A1_PRICE)
		return
	weapon = value
	_shot_pending = false
	model.call("set_weapon", weapon)
	_update_weapon_ui()


func _cycle_weapon(step: int) -> void:
	var at := WeaponBar.ORDER.find(weapon)
	for k in WeaponBar.ORDER.size():
		at = posmod(at + step, WeaponBar.ORDER.size())
		var next: String = WeaponBar.ORDER[at]
		if (next != "bazooka" or Game.has_bazooka) and (next != "m4a1" or Game.has_m4a1):
			set_weapon(next)
			return


func _is_touch_device() -> bool:
	if OS.get_cmdline_user_args().has("--touch"): # tools: see the phone layout on a PC
		return true
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return OS.has_feature("web") and DisplayServer.is_touchscreen_available()


func _process(delta: float) -> void:
	_protection = maxf(_protection - delta, 0.0)
	_aim_target = _get_aim_target()
	model.set("aim_point", _aim_target)
	model.set("has_aim_point", true)
	if _crosshair != null:
		_crosshair.visible = is_playing() and weapon in ["pistol", "bazooka", "m4a1"]
	_shake = move_toward(_shake, 0.0, delta * 1.6)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.35
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.35
	_fit_game_screen(_game_over_screen)
	_fit_game_screen(_pause_screen)
	if _pause_button != null:
		_pause_button.visible = is_playing()
	if _weapon_bar != null:
		_weapon_bar.visible = is_playing()
	if _mobile_controls != null:
		_mobile_controls.visible = is_playing()
		if _mobile_controls.fire_held:
			_attack()
		_auto_camera(delta)
	elif weapon == "m4a1" and (Input.is_physical_key_pressed(KEY_Q) or (
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	)):
		_pull_trigger()
	# The trigger snaps the arm up first; the round leaves the barrel once it points at the target.
	if _shot_pending and model.call("is_gun_raised"):
		_shot_pending = false
		_fire_shot()


func _input(event: InputEvent) -> void:
	if not is_playing():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_attack()
		elif event.keycode >= KEY_1 and event.keycode < KEY_1 + WeaponBar.ORDER.size():
			set_weapon(WeaponBar.ORDER[event.keycode - KEY_1])
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
	if _paused and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_resume()
		return
	if not is_playing():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look_delta(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_pause()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()


func _apply_look_delta(relative: Vector2) -> void:
	var sensitivity := mouse_sensitivity * Settings.look_sensitivity
	rotate_y(-relative.x * sensitivity)
	var vertical_mouse_direction := 1.0 if invert_mouse_y != Settings.invert_y else -1.0
	camera_pivot.rotate_x(relative.y * sensitivity * vertical_mouse_direction)
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
		"pistol", "m4a1":
			_pull_trigger()
		"bat":
			_swing_bat()
		"bazooka":
			_fire_rocket()


## The camera jolts (0..1), e.g. from a blast nearby.
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func vibrate_near_blast(at: Vector3, radius: float, max_duration_ms: int) -> void:
	var strength := 1.0 - global_position.distance_to(at) / radius
	if strength > 0.0:
		_vibrate_device(roundi(lerpf(24.0, float(max_duration_ms), strength)), lerpf(0.22, 1.0, strength))


func _vibrate_device(duration_ms: int, amplitude: float) -> void:
	if not is_playing() or not _is_touch_device():
		return
	var now := Time.get_ticks_msec()
	var ends_at := now + duration_ms
	# A nearby blast can replace recoil. Weaker blasts in the same chain should
	# not interrupt or repeatedly restart a stronger pulse already playing.
	if now < _vibration_ends_at and (amplitude <= _vibration_amplitude or ends_at <= _vibration_ends_at):
		return
	_vibration_ends_at = ends_at
	_vibration_amplitude = amplitude
	Input.vibrate_handheld(duration_ms, amplitude)


func _fire_rocket() -> void:
	if not is_playing() or weapon != "bazooka" or not _can_fire:
		return
	if not Game.use_rocket():
		_can_fire = false
		show_toast("Out of rockets! $%d each in the SHOP (5 at most)" % Game.ROCKET_PRICE)
		await get_tree().create_timer(0.6).timeout
		_can_fire = true
		return
	_can_fire = false
	var muzzle := (model.call("get_muzzle") as Marker3D).global_position
	# Toward what the crosshair is on: the camera ray, from level with the player.
	var forward := -camera.global_basis.z
	var from := camera.global_position + forward * maxf((global_position - camera.global_position).dot(forward), 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * Rocket.RANGE)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit.get("position", from + forward * Rocket.RANGE)
	var direction := muzzle.direction_to(target) if muzzle.distance_to(target) > 1.5 else forward
	var rocket := Rocket.launch(get_parent(), muzzle, direction, Net.my_id, true, [get_rid()])
	Net.rocket_serial += 1
	var rocket_id := Net.rocket_serial
	rocket.exploded.connect(_on_rocket_exploded.bind(rocket_id))
	var net_world := get_parent().get_node_or_null("NetWorld")
	if net_world != null:
		net_world.call("broadcast_rocket", muzzle, direction, rocket_id)
	model.call("fire_effects")
	shake(0.25)
	_vibrate_device(58, 0.48)
	_crosshair.kick()
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x + ROCKET_KICK, deg_to_rad(-60.0), deg_to_rad(35.0))
	await get_tree().create_timer(ROCKET_RELOAD).timeout
	_can_fire = true


## Our rocket hit something: the blast here and on every screen, every car near
## it goes up, shop windows round it blow out, and it all pays (and draws heat).
func _on_rocket_exploded(at: Vector3, normal: Vector3, surface: String, collider: Object, rocket_id: int) -> void:
	var scene := get_parent()
	var net_world := scene.get_node_or_null("NetWorld")
	var tram_progress := -1.0
	if collider != null and is_instance_valid(collider):
		var cars := (collider as Node).get_parent()
		if cars is DublinTram:
			surface = cars.rocket_surface
			if cars.wreck_by_rocket():
				tram_progress = cars.progress()
		elif _shot_target(collider) != null:
			surface = "body"
		elif cars != null and cars.has_method("cars_near") and not (cars.call("cars_near", at, 3.5) as Array).is_empty():
			surface = "car"
	Rocket.explode(scene, at, normal, surface, Net.my_id)
	if net_world != null:
		net_world.call("broadcast_blast", at, normal, surface, rocket_id, tram_progress)
	_police.add_heat(HEAT_ROCKET)
	if surface == "wall":
		_reward(at + normal * 1.5, CASH_WALL, 5.0)
	elif surface == "ground":
		_reward(at + Vector3.UP, CASH_CRATER, 0.0)
	var district := scene.get_node_or_null("Diorama/District")
	if district == null:
		return
	for cars: Node in [district, district.get_node_or_null("Traffic")]:
		if cars == null or not cars.has_method("cars_near"):
			continue
		for index: int in cars.call("cars_near", at, Rocket.CAR_RADIUS):
			var s: float = cars.call("car_progress", index)
			if cars.call("blow_up_car", index, s, Net.my_id):
				if net_world != null:
					net_world.call("broadcast_car", "traffic" if cars.name == "Traffic" else "parked", index, s)
				var wreck: Transform3D = cars.call("car_transform", index)
				_reward(wreck.origin + Vector3.UP * 1.0, CASH_CAR, HEAT_CAR)
	if district.has_method("blow_out_windows"):
		for point: Vector3 in district.call("blow_out_windows", at, Rocket.WINDOW_RADIUS):
			if net_world != null:
				net_world.call("broadcast_window", point)
				net_world.call("broadcast_window", point)
			if Net.ranking_available:
				Net.send({"t": "rank_glass"})
			_reward(point, CASH_SMASH, HEAT_SMASH)


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
	var people := get_tree().get_nodes_in_group("villagers") + get_tree().get_nodes_in_group("police")
	for villager in people:
		var body := villager as Node3D
		if not body.call("can_be_hit"):
			continue
		var to_body := body.global_position - global_position
		to_body.y = 0.0
		if to_body.length() > BAT_RANGE:
			continue
		if to_body.length() > 0.4 and forward.dot(to_body.normalized()) < 0.45:
			continue
		if body.is_in_group("villagers"):
			body.call("receive_hit", "bat", Net.my_id)
			_police.add_heat(HEAT_KILL)
		else:
			body.call("receive_hit", "bat")
			ShotFx.blood(get_tree().current_scene, body.global_position + Vector3.UP * 1.2, forward)
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
	if not hit_any:
		hit_any = _bat_hit_world(forward)
	if hit_any:
		_bat_sound.pitch_scale = randf_range(0.9, 1.1)
		_bat_sound.play()


## The bat coming down on whatever is in front when nobody is: a car (it dents,
## parked or driving), a shop window (cracks, then smashes), or just a wall.
## True if it hit anything at all.
func _bat_hit_world(forward: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 0.45
	var side := forward.cross(Vector3.UP).normalized()
	var best := {}
	var best_dir := forward
	var best_distance := INF
	# A fan of rays over the reach of the swing: straight ahead first, down to the waist.
	for pitch: float in [-0.12, -0.45, 0.15]:
		for yaw: float in [0.0, -0.3, 0.3, -0.6, 0.6]:
			var dir := (forward.rotated(Vector3.UP, yaw) + Vector3.UP * pitch).normalized()
			var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * BAT_RANGE)
			query.exclude = [get_rid()]
			var hit := space.intersect_ray(query)
			if hit.is_empty() or _shot_target(hit.get("collider")) != null:
				continue
			var distance := origin.distance_to(hit["position"])
			if distance < best_distance - 0.15:
				best_distance = distance
				best = hit
				best_dir = dir
	if best.is_empty():
		return false
	var owner := (best["collider"] as Node).get_parent()
	var net_world := get_tree().current_scene.get_node_or_null("NetWorld")
	if owner != null and owner.has_method("car_index_at") and owner.has_method("dent_car"):
		var index: int = owner.call("car_index_at", best)
		if index >= 0:
			var xf: Transform3D = owner.call("car_transform", index)
			var swing := (best_dir + Vector3.DOWN * 0.6).normalized()
			var on_body := CarDamage.ray_mesh(owner.call("car_mesh", index), xf, origin, best["position"] + best_dir * 2.2)
			var point: Vector3
			var glass := false
			var push: Vector3
			if on_body.is_empty():
				point = xf.affine_inverse() * (best["position"] as Vector3)
				push = xf.basis.inverse() * swing
			else:
				point = on_body["point"]
				glass = on_body["glass"]
				push = (-(on_body["normal"] as Vector3) * 0.7 + (xf.basis.inverse() * swing) * 0.3).normalized()
			var first_dent: bool = not owner.call("car_is_dented", index)
			if owner.call("dent_car", index, point, push, glass):
				if net_world != null:
					net_world.call("broadcast_dent", "traffic" if owner.name == "Traffic" else "parked", index, point, push, glass, first_dent)
				var key := "%d:%d" % [owner.get_instance_id(), index]
				var paid := int(_dents_paid.get(key, 0))
				if paid < DENTS_PAID_PER_CAR:
					_dents_paid[key] = paid + 1
					_reward(best["position"], CASH_DENT, HEAT_DENT)
			return true
	_smash_window(best, net_world)
	return true


## A blow or a round landing on a wall: smash the shop window there, if it is one.
func _smash_window(hit: Dictionary, net_world: Node) -> void:
	var owner := (hit["collider"] as Node).get_parent()
	if owner == null or not owner.has_method("smash_window"):
		return
	var point: Vector3 = hit["position"]
	var stage := int(owner.call("smash_window", point))
	if stage > 0:
		if net_world != null:
			net_world.call("broadcast_window", point)
		if stage == 1:
			_reward(point, CASH_CRACK, HEAT_CRACK)
		else:
			if Net.ranking_available:
				Net.send({"t": "rank_glass"})
			_reward(point, CASH_SMASH, HEAT_SMASH)


func _pull_trigger() -> void:
	if not is_playing() or not _can_fire or _shot_pending:
		return
	_can_fire = false
	var rifle := weapon == "m4a1"
	if rifle and Game.m4a1_rounds <= 0:
		show_toast("Out of M4A1 ammo! %d rounds for $%d in the SHOP" % [
			Game.M4A1_PACK_SIZE, Game.M4A1_PACK_SIZE * Game.M4A1_ROUND_PRICE])
		await get_tree().create_timer(1.5).timeout
	else:
		_shot_pending = true
		model.call("raise_gun")
		await get_tree().create_timer(M4A1_FIRE_INTERVAL if rifle else FIRE_INTERVAL).timeout
	_can_fire = true


## One round, hitscan: it goes where the crosshair points (the camera ray), and the
## tracer is drawn from the muzzle. Villagers die from any hit; other players take
## damage by where they were hit (pistol_damage) and are told over the network.
func _fire_shot() -> void:
	if not is_playing():
		return
	if weapon == "m4a1" and not Game.use_m4a1_round():
		return
	var scene := get_tree().current_scene
	var muzzle := (model.call("get_muzzle") as Marker3D).global_position
	var hit := _shoot_ray()
	var end: Vector3 = hit.get("position", camera.global_position - camera.global_basis.z * SHOT_RANGE)
	var target := _shot_target(hit.get("collider"))
	var flesh := false
	var net_world := scene.get_node_or_null("NetWorld")
	if target != null and target.is_in_group("villagers"):
		if target.call("can_be_hit"):
			_police.add_heat(HEAT_KILL)
		target.call("receive_hit", "pistol", Net.my_id)
		flesh = true
	elif target != null and target.is_in_group("police"):
		var wound := pistol_damage((target as Node3D).global_position, end, muzzle.direction_to(end))
		target.call("take_damage", float(wound[0]))
		_crosshair.show_hit(wound[1] == "head")
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
		_smash_window(hit, net_world)
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
	if cars.call("blow_up_car", index, s, Net.my_id):
		if net_world != null:
			net_world.call("broadcast_car", "traffic" if cars.name == "Traffic" else "parked", index, s)
		var wreck: Transform3D = cars.call("car_transform", index)
		_reward(wreck.origin + Vector3.UP * 1.0, CASH_CAR, HEAT_CAR)


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
		if node.is_in_group("villagers") or node.is_in_group("civilians") or node.is_in_group("remote_players") or node.is_in_group("police"):
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
	var how: String = {"head": " with a headshot", "bat": " with a bat", "blast": " with an exploding car", "rocket": " with a bazooka"}.get(zone, "")
	var text := "The villagers got you."
	if zone == "police":
		text = "The police got you."
	elif zone == "blast" and (killer.is_empty() or attacker == Net.my_id):
		text = "You were too close to an exploding car."
	elif zone == "rocket" and (killer.is_empty() or attacker == Net.my_id):
		text = "You were caught in your own rocket blast."
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
	if _paused:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
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
	_health_bar = HealthBar.new()
	_health_bar.position = Vector2(20.0, 18.0)
	hud.add_child(_health_bar)
	_money_label = _make_hud_label("", 54.0, 90.0, 26)
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	_money_label.pivot_offset = Vector2(0.0, 18.0)
	_on_money_changed(Game.money)
	_toast_label = Label.new()
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -360.0
	_toast_label.offset_right = 360.0
	_toast_label.offset_top = 96.0
	_toast_label.offset_bottom = 140.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 28)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_toast_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	_toast_label.add_theme_constant_override("outline_size", 8)
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.modulate.a = 0.0
	hud.add_child(_toast_label)
	# The weapon slots: along the bottom on a keyboard, along the top on a touch
	# screen (the thumbs' controls fill the bottom corners there), tap to pick.
	_weapon_bar = WeaponBar.new()
	_weapon_bar.show_keys = _mobile_controls == null
	_weapon_bar.bazooka_price = Game.BAZOOKA_PRICE
	_weapon_bar.max_rockets = Game.MAX_ROCKETS
	hud.add_child(_weapon_bar)
	if _mobile_controls == null:
		_weapon_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_KEEP_SIZE, 14)
	else:
		_weapon_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE, 10)
	_weapon_bar.picked.connect(func(kind: String) -> void:
		if is_playing():
			set_weapon(kind))
	_update_weapon_ui()
	_game_over_screen = _make_game_screen("GAME OVER", "The villagers got you.", [
		["SHOP", _open_shop, false],
		["MENU", _to_main_menu, false],
		["RESPAWN", _restart_game, true],
	])
	_game_over_screen.hide()
	_pause_screen = _make_game_screen("PAUSED", _controls_text(), [
		["RESUME", _resume, true],
		["SHOP", _open_shop, false],
		["SETTINGS", _open_settings, false],
		["MAIN MENU", _to_main_menu, false],
	])
	_pause_screen.hide()
	if _mobile_controls != null:
		# Touch screens have no Esc: a pause button up by the status line.
		_pause_button = Button.new()
		_pause_button.text = "II"
		_pause_button.theme = UiTheme.get_theme()
		_pause_button.focus_mode = Control.FOCUS_NONE
		_pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_pause_button.offset_left = -84.0
		_pause_button.offset_right = -24.0
		_pause_button.offset_top = 96.0
		_pause_button.offset_bottom = 150.0
		_pause_button.pressed.connect(_pause)
		hud.add_child(_pause_button)


## The controls, for the pause screen.
func _controls_text() -> String:
	if _mobile_controls != null:
		return "Left thumb: walk, pull further to run  |  Right thumb: look\nFIRE: shoot or swing  |  WEAPON: cycle the slots at the top  |  JUMP"
	return "WASD move  |  Shift run  |  Space jump  |  Mouse look\nQ / click: fire or swing  |  %s (or mouse wheel)\nEsc: pause" % WeaponBar.shortcut_text()


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


## A full-screen panel over the game (game over, pause): a title, a message and a
## row of buttons [text, action, primary?]. Fitted to the screen every frame.
func _make_game_screen(title_text: String, message: String, buttons: Array) -> Control:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.045, 0.065, 0.78)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.theme = UiTheme.get_theme()
	hud.add_child(overlay)

	var panel := PanelContainer.new()
	overlay.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 14)
	margin.add_child(contents)

	var title := UiTheme.heading(title_text, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, 40.0)
	contents.add_child(scroll)

	var description := Label.new()
	description.text = message
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 19)
	scroll.add_child(description)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	contents.add_child(row)
	for entry in buttons:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(200.0 if entry[2] else 140.0, 56.0)
		if entry[2]:
			button.theme_type_variation = &"PrimaryButton"
			button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(entry[1])
		row.add_child(button)
	overlay.set_meta("description", description)
	overlay.set_meta("panel", panel)
	overlay.set_meta("scroll", scroll)
	overlay.set_meta("max_height", 420.0)
	_fit_game_screen(overlay)
	return overlay


func _open_shop() -> void:
	if is_instance_valid(_shop) and _shop.visible:
		return
	_shop = Shop.open(hud, Callable(), self if _paused and not _game_over else null)


func whiskey_restores() -> int:
	if not _game_started or not _paused or _game_over or health <= 0:
		return 0
	return clampi(MAX_HEALTH - health, 0, Game.WHISKEY_HEAL)


## Buy and drink in one action. A failed purchase changes neither health nor cash.
func buy_whiskey() -> int:
	var healed := whiskey_restores()
	if healed == 0 or Game.money < Game.WHISKEY_PRICE:
		return 0
	health += healed
	_update_health_ui()
	Game.add_money(-Game.WHISKEY_PRICE)
	return healed


func _open_settings() -> void:
	SettingsPanel.open(hud)


## Esc / the pause button: the pause menu over the game. The world (and the other
## players) carry on; this player just stands there, safe from nothing.
func _pause() -> void:
	if not is_playing():
		return
	_paused = true
	_pause_screen.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _mobile_controls != null:
		_mobile_controls.call("release_all")


## Android's back button closes the shop before leaving the pause menu.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if is_instance_valid(_shop) and _shop.visible:
		_shop.close()
	elif _game_started and not _game_over:
		if _paused:
			_resume()
		else:
			_pause()


func _resume() -> void:
	_paused = false
	_pause_screen.hide()
	if _mobile_controls == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _to_main_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://main_menu.tscn")


## Sizes and centres a game-over / pause panel in the part of the screen the
## on-screen keyboard leaves free. Called on creation and every frame while shown.
func _fit_game_screen(overlay: Control) -> void:
	if overlay == null or not overlay.visible:
		return
	var panel := overlay.get_meta("panel") as Control
	var view := get_viewport().get_visible_rect().size
	var keyboard := 0.0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		var window := Vector2(DisplayServer.window_get_size())
		if window.y > 0.0:
			keyboard = DisplayServer.virtual_keyboard_get_height() * view.y / window.y
	var free_height := maxf(view.y - keyboard, 160.0)
	var gap := 10.0
	var width := minf(view.x - 2.0 * gap, 760.0)
	var height := minf(free_height - 2.0 * gap, float(overlay.get_meta("max_height")))
	var rect := Rect2(Vector2((view.x - width) * 0.5, maxf((free_height - height) * 0.5, gap)), Vector2(width, height))
	if panel.position != rect.position or panel.size != rect.size:
		panel.position = rect.position
		panel.size = rect.size
		(overlay.get_meta("scroll") as ScrollContainer).scroll_vertical = 0


## Coins worth `cash` pop out at `at` (toward the player), and the police take note.
func _reward(at: Vector3, cash: int, heat: float) -> void:
	Coins.spawn(get_parent(), at, cash, global_position)
	if _police != null:
		_police.add_heat(heat)


## A line of news in the middle of the screen for a few seconds.
func show_toast(text: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	var tween := _toast_label.create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.8)


func _on_money_changed(value: int) -> void:
	if _money_label == null:
		return
	var before := _money_label.text
	_money_label.text = "$ %s" % _thousands(value)
	if not before.is_empty() and before != _money_label.text:
		_money_label.scale = Vector2.ONE * 1.25
		_money_label.create_tween().tween_property(_money_label, "scale", Vector2.ONE, 0.25)


## 12345 -> "12,345"
static func _thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


func _update_weapon_ui() -> void:
	if _weapon_bar != null:
		_weapon_bar.set_state(weapon, Game.has_bazooka, Game.rockets, Game.has_m4a1, Game.m4a1_rounds)
	if _mobile_controls != null:
		_mobile_controls.weapon = weapon
		_mobile_controls.loaded = Game.rockets > 0


func _on_arsenal_changed() -> void:
	_update_weapon_ui()
	model.call("set_loaded", Game.rockets > 0)
	if weapon == "bazooka" and not Game.has_bazooka:
		set_weapon("pistol")


func _update_health_ui() -> void:
	if _health_bar != null:
		_health_bar.set_health(health, MAX_HEALTH)


func _start_game() -> void:
	if _game_started:
		return
	_game_started = true
	if _mobile_controls == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _end_game() -> void:
	if _game_over:
		return
	_game_over = true
	var lost := Game.lose_on_death()
	if lost > 0:
		var label := _game_over_screen.get_meta("description", null) as Label
		if label != null:
			label.text += "
You dropped $%d." % lost
	if _police != null:
		_police.stand_down()
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
