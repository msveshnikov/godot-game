extends "res://addons/cogito/CogitoNPC/cogito_npc.gd"
## A person in the estate. Three roles:
##   villager - roams the street graph (bot_crowd.gd) carrying a pistol; on the
##              host it is simulated for real, on other clients it is a puppet that
##              follows the host's network updates. A bullet or a bat blow kills it:
##              the body stays lying where it fell (every client leaves its own
##              copy) and the villager is born again elsewhere, dressed anew.
##              Runs away from armed players.
##   civilian - an unarmed grown-up who wanders a small zone or stands still;
##              can't be hurt, but runs from armed players too.
##   child    - like a civilian, smaller and quicker on its feet.
##   police   - an officer sent by police.gd: uniform and cap, a pistol it really
##              fires; police_officer.gd drives it. Local to the player it hunts.
## Civilians and children are local to each client (not networked).

const PISTOL_SCENE: PackedScene = preload("res://pistol_model.tscn")
const OUTFIT = preload("res://villager_outfit.gd")
const BAGUETTE = preload("res://baguette.gd")
const FOAM_FIRE_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/Spray.ogg")
const PUPPET_SNAP_DISTANCE := 5.0
const HIT_GRACE := 1.5
const STUCK_TIME := 2.5
const FLEE_RANGE := 22.0
const FLEE_TIME := 5.0
const FALL_TIME := 0.45
const OUTFITS_PER_LIFE := 1000 # outfit index = bot_index + lives * this
const CHILD_SCALE := 0.62

@export_enum("villager", "civilian", "child", "police") var role := "villager"
## Villagers only carry their pistols around; turn this on to let them fire at players again.
@export var shoots_back := false
@export var firing_range := 26.0
@export var fire_interval := 2.8
@export var respawn_delay := 6.0
@export var flee_speed := 4.3

var bot_index := 0
var crowd: Node
var puppet := false
var alive := true
## Times this villager was born again; the host streams it so every client dresses it alike.
var lives := 0
## Waterfront villagers follow the promenade loop.
var waterfront := false
## Extra villagers return to the streets near their original patrol on respawn.
var home_node := -1
## Civilians: game-space XZ area they wander in; `stay` keeps them standing where they are.
var zone := Rect2()
var stay := false
var carries_baguette := false
var military_uniform := false

var _rng := RandomNumberGenerator.new()
var _target_node := -1
var _previous_node := -1
var _pause_remaining := 0.0
var _stuck_timer := 0.0
var _attack_timer := 1.0
var _respawn_timer := 0.0
var _hit_grace := 0.0
var _spawn_collision_layer := 0
var _spawn_collision_mask := 0
var _fire_sound: AudioStreamPlayer3D
var _net_position := Vector3.ZERO
var _net_velocity := Vector3.ZERO
var _net_yaw := 0.0
var _net_has_state := false
var _net_age := 0.0
var _flee_from: Node3D
var _flee_timer := 0.0
var _flee_check := 0.0
var _flee_turn := 0.0
var _zone_target := Vector3.ZERO
var _rig: Node3D


func _ready() -> void:
	super._ready()
	_rig = get_node_or_null("Rig") as Node3D
	if role == "police":
		OUTFIT.apply_police(self, bot_index, bot_index % 2 == 1)
	else:
		_apply_outfit()
	_rng.seed = hash(bot_index * 7919 + Time.get_ticks_usec())
	_attack_timer = _rng.randf_range(0.5, fire_interval)
	_spawn_collision_layer = collision_layer
	_spawn_collision_mask = collision_mask
	if role == "villager" or role == "police":
		add_to_group("villagers" if role == "villager" else "police")
		var pistol := PISTOL_SCENE.instantiate() as Node3D
		pistol.name = "VillagerPistol"
		pistol.scale = Vector3.ONE * 0.65
		pistol.rotation.y = -PI / 2.0
		hand_slot.add_child(pistol)
		_fire_sound = AudioStreamPlayer3D.new()
		_fire_sound.stream = FOAM_FIRE_SOUND
		_fire_sound.volume_db = -8.0
		add_child(_fire_sound)
	else:
		add_to_group("civilians")
		_zone_target = global_position
		_pause_remaining = _rng.randf_range(0.0, 3.0)
	if role == "child":
		_make_child()
	if carries_baguette and _rig != null:
		BAGUETTE.attach(_rig.get_node_or_null("Skeleton3D") as Skeleton3D, role == "villager")


func _make_child() -> void:
	if _rig != null:
		_rig.scale = Vector3.ONE * CHILD_SCALE
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		var capsule := (shape_node.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		capsule.height *= CHILD_SCALE
		capsule.radius *= 0.8
		shape_node.shape = capsule
		shape_node.position.y *= CHILD_SCALE
	walk_speed *= 1.25
	flee_speed *= 0.9
	walk_volume_db -= 6.0


## True for anyone a player can kill (adult villagers and the police).
func can_be_hit() -> bool:
	return (role == "villager" or role == "police") and alive


func _physics_process(delta: float) -> void:
	_hit_grace = maxf(_hit_grace - delta, 0.0)
	if puppet:
		_puppet_process(delta)
		return
	if not alive:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	super._physics_process(delta)

	_update_flee(delta)
	if _flee_timer > 0.0:
		_flee(delta)
	elif role == "villager":
		_wander(delta)
	else:
		_wander_zone(delta)
	move_and_slide()
	if role == "villager" and shoots_back and _flee_timer <= 0.0:
		_update_attack(delta)


# ------------------------------------------------------------ simulation ----

func _wander(delta: float) -> void:
	if crowd == null:
		return
	if _pause_remaining > 0.0:
		_pause_remaining -= delta
		_stop_horizontal_motion(delta)
		return

	if _target_node < 0:
		_target_node = crowd.nearest_node(global_position, waterfront)
	var direction: Vector3 = crowd.node_position(_target_node, waterfront) - global_position
	direction.y = 0.0

	if direction.length() < 0.8:
		var next: int = crowd.pick_next(_target_node, _previous_node, _rng, waterfront)
		_previous_node = _target_node
		_target_node = next
		_stuck_timer = 0.0
		# Sometimes stop and loiter for a while.
		if _rng.randf() < 0.35:
			_pause_remaining = _rng.randf_range(2.0, 8.0)
		return

	# Blocked by a player or a parked car for too long: turn back.
	if get_real_velocity().length() < 0.3:
		_stuck_timer += delta
		if _stuck_timer > STUCK_TIME:
			_stuck_timer = 0.0
			var back: int = _previous_node if _previous_node >= 0 else crowd.nearest_node(global_position, waterfront)
			_previous_node = _target_node
			_target_node = back
	else:
		_stuck_timer = 0.0

	direction = direction.normalized()
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	face_direction(global_position + direction)


## Civilians: stroll between random points of their zone, with pauses; or just stand.
func _wander_zone(delta: float) -> void:
	if stay or _pause_remaining > 0.0:
		_pause_remaining -= delta
		_stop_horizontal_motion(delta)
		if stay and zone.has_area():
			var home := Vector3(zone.get_center().x, global_position.y, zone.get_center().y)
			if global_position.distance_to(home) > 1.5:
				_walk_towards(home, walk_speed)
		return
	var to_target := _zone_target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.6 or not zone.has_area():
		if zone.has_area():
			_zone_target = Vector3(_rng.randf_range(zone.position.x, zone.end.x), global_position.y,
				_rng.randf_range(zone.position.y, zone.end.y))
		_pause_remaining = _rng.randf_range(0.5, 2.5) if role == "child" else _rng.randf_range(2.0, 7.0)
		return
	if get_real_velocity().length() < 0.2:
		_stuck_timer += delta
		if _stuck_timer > 1.5:
			_stuck_timer = 0.0
			_zone_target = global_position
	else:
		_stuck_timer = 0.0
	_walk_towards(_zone_target, walk_speed)


func _walk_towards(target: Vector3, speed: float) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		return
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	face_direction(global_position + direction)


func _stop_horizontal_motion(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, walk_speed * delta * 4.0)
	velocity.z = move_toward(velocity.z, 0.0, walk_speed * delta * 4.0)


## Look around a few times a second for an armed player in sight and close enough.
func _update_flee(delta: float) -> void:
	_flee_timer = maxf(_flee_timer - delta, 0.0)
	_flee_check -= delta
	if _flee_check > 0.0 or crowd == null:
		return
	_flee_check = 0.25
	var eye := global_position + Vector3.UP * (1.0 if role == "child" else 1.55)
	for player in crowd.call("armed_players"):
		var target := (player as Node3D).global_position + Vector3.UP * 1.0
		if eye.distance_to(target) > FLEE_RANGE:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, target)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.get("collider") != player:
			continue
		if _flee_timer <= 0.0:
			_flee_turn = _rng.randf_range(-0.5, 0.5)
		_flee_from = player
		_flee_timer = FLEE_TIME
		_pause_remaining = 0.0
		return


func _flee(delta: float) -> void:
	if _flee_from == null or not is_instance_valid(_flee_from):
		_flee_timer = 0.0
		return
	var away := global_position - _flee_from.global_position
	away.y = 0.0
	if away.length() < 0.1:
		away = -global_basis.z
	away = away.normalized().rotated(Vector3.UP, _flee_turn)
	# Ran into a wall or a car: veer off to one side.
	if get_real_velocity().length() < 0.6:
		_stuck_timer += delta
		if _stuck_timer > 0.5:
			_stuck_timer = 0.0
			_flee_turn = wrapf(_flee_turn + (PI * 0.5 if _rng.randf() < 0.5 else -PI * 0.5), -PI, PI)
	else:
		_stuck_timer = 0.0
	velocity.x = away.x * flee_speed
	velocity.z = away.z * flee_speed
	face_direction(global_position + away)
	if _flee_timer <= 0.1:
		_target_node = -1 # pick the nearest street node again once calm


func _update_attack(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer > 0.0 or crowd == null:
		return

	var target: Node3D = crowd.pick_target(global_position, firing_range)
	if target == null:
		_attack_timer = 0.5
		return

	var muzzle_position := global_position + Vector3.UP * 1.3
	var target_position := target.global_position + Vector3.UP * 0.45
	var query := PhysicsRayQueryParameters3D.create(muzzle_position, target_position)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.get("collider") != target:
		_attack_timer = 0.5
		return

	_attack_timer = fire_interval * _rng.randf_range(0.8, 1.3)
	face_direction(target.global_position)
	crowd.fire(self, muzzle_position, muzzle_position.direction_to(target_position))


func play_fire_sound() -> void:
	if _fire_sound != null:
		_fire_sound.play()


## A bullet ("pistol") or a bat blow ("bat") kills a villager on the spot.
func receive_hit(kind := "pistol", attacker := 0) -> void:
	if not can_be_hit():
		return
	if puppet:
		# Someone else simulates this bot: tell the host, show it right away.
		crowd.report_hit(bot_index, kind)
		_hit_grace = HIT_GRACE
		_die()
		return
	_die()
	if role == "villager" and attacker > 0 and Net.ranking_available and Net.is_host():
		Net.send({"t": "rank_npc", "i": bot_index, "by": attacker})
	_respawn_timer = respawn_delay


## Drop dead: a copy of the body falls and stays; this villager hides until reborn.
func _die() -> void:
	if not alive:
		return
	_leave_corpse()
	_set_alive(false)


## Copy of the posed skeleton and clothes (and the pistol in hand), falling flat on
## its back, then a pool of blood spreading under it. Kept by the crowd.
func _leave_corpse() -> void:
	if _rig == null or crowd == null:
		return
	var skeleton := _rig.get_node_or_null("Skeleton3D") as Skeleton3D
	if skeleton == null:
		return
	var copy := skeleton.duplicate() as Skeleton3D
	for child in copy.get_children():
		if child.name in ["Mannequin", "PoliceCap", "MilitaryCap", "BaguetteGrip"]:
			continue
		if child.name == "HandAttachment":
			for part in child.get_children():
				if part.name != "HandSlot":
					part.free()
			continue
		child.free()
	var corpse := Node3D.new()
	corpse.name = "Corpse"
	var body := Node3D.new()
	body.add_child(copy)
	copy.transform = skeleton.transform
	corpse.add_child(body)
	crowd.call("add_corpse", corpse)
	var ground_y := global_position.y + _rig.position.y
	var start := _rig.global_transform
	start.basis = Basis(Vector3.UP, _rig.global_basis.get_euler().y + _rng.randf_range(-0.3, 0.3)).scaled(_rig.global_basis.get_scale())
	body.global_transform = start
	var tween := body.create_tween()
	tween.tween_property(body, "rotation:x", -PI * 0.5, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(body, "position:y", body.position.y + 0.2, FALL_TIME)
	tween.tween_callback(func() -> void: _spread_blood(corpse, body, ground_y))


static var _blood_material: StandardMaterial3D


func _spread_blood(corpse: Node3D, body: Node3D, ground_y: float) -> void:
	if _blood_material == null:
		_blood_material = StandardMaterial3D.new()
		_blood_material.albedo_color = Color(0.3, 0.015, 0.02)
		_blood_material.roughness = 0.15
		_blood_material.metallic_specular = 0.8
	var disc := CylinderMesh.new()
	disc.top_radius = 0.55
	disc.bottom_radius = 0.55
	disc.height = 0.004
	disc.radial_segments = 20
	disc.rings = 1
	var pool := MeshInstance3D.new()
	pool.mesh = disc
	pool.material_override = _blood_material
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	corpse.add_child(pool)
	var chest := body.global_transform * Vector3(0.0, 1.0, 0.0)
	pool.global_position = Vector3(chest.x, ground_y + 0.012, chest.z)
	pool.scale = Vector3(0.15, 1.0, 0.15)
	var stretch := _rng.randf_range(0.8, 1.25)
	pool.create_tween().tween_property(pool, "scale", Vector3(stretch, 1.0, 1.0 / stretch), 6.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _respawn() -> void:
	global_position = crowd.respawn_position(_rng, waterfront, home_node)
	velocity = Vector3.ZERO
	_target_node = -1
	_previous_node = -1
	_pause_remaining = _rng.randf_range(0.0, 2.0)
	_attack_timer = 1.5
	_reborn(lives + 1)
	_set_alive(true)


## A new person, not the one lying over there: same slot in the crowd, new clothes.
func _reborn(life: int) -> void:
	lives = life
	_apply_outfit()


func _apply_outfit() -> void:
	var index := bot_index + lives * OUTFITS_PER_LIFE
	if military_uniform:
		OUTFIT.apply_military(self, index)
	else:
		OUTFIT.apply(self, index)


func _set_alive(value: bool) -> void:
	alive = value
	visible = value
	collision_layer = _spawn_collision_layer if value else 0
	collision_mask = _spawn_collision_mask if value else 0
	if not value and _fire_sound != null:
		_fire_sound.stop()
	for collision_shape in find_children("", "CollisionShape3D", true, false):
		(collision_shape as CollisionShape3D).set_deferred("disabled", not value)


# ------------------------------------------------------------- networking ----

## [x, y, z, yaw, vx, vz, state, lives] streamed by the host; state 1 alive, 0 dead.
func net_state() -> Array:
	return [
		snappedf(global_position.x, 0.01), snappedf(global_position.y, 0.01), snappedf(global_position.z, 0.01),
		snappedf(rotation.y, 0.01), snappedf(velocity.x, 0.01), snappedf(velocity.z, 0.01), 1 if alive else 0, lives,
	]


func apply_net_state(state: Array) -> void:
	if state.size() < 7:
		return
	_net_position = Vector3(state[0], state[1], state[2])
	_net_yaw = float(state[3])
	_net_velocity = Vector3(state[4], 0.0, state[5])
	var net_state_value := int(state[6])
	if not _net_has_state or global_position.distance_to(_net_position) > PUPPET_SNAP_DISTANCE:
		global_position = _net_position
		rotation.y = _net_yaw
	_net_has_state = true
	_net_age = 0.0
	if _hit_grace > 0.0 and net_state_value == 1:
		return # our own hit hasn't reached the host yet
	var net_alive := net_state_value != 0
	if alive and not net_alive:
		_die()
	elif net_alive and not alive:
		_set_alive(true)
	var net_lives := int(state[7]) if state.size() >= 8 else lives
	if net_lives != lives:
		_reborn(net_lives)


func set_puppet(value: bool) -> void:
	if puppet == value:
		return
	puppet = value
	if puppet:
		_net_has_state = false
		_hit_grace = 0.0
		return
	# Taking over the simulation: carry on from wherever the puppet stands.
	velocity = Vector3.ZERO
	_target_node = -1
	_previous_node = -1
	_pause_remaining = 0.0
	if not alive:
		_respawn_timer = respawn_delay * 0.5


func _puppet_process(delta: float) -> void:
	if not _net_has_state:
		return
	# Dead-reckon briefly between packets, but don't wander off if the host goes quiet.
	_net_age += delta
	if _net_age < 0.3:
		_net_position += _net_velocity * delta
	global_position = global_position.lerp(_net_position, 1.0 - exp(-10.0 * delta))
	rotation.y = lerp_angle(rotation.y, _net_yaw, 1.0 - exp(-10.0 * delta))
	velocity = _net_velocity if _net_age < 0.5 else Vector3.ZERO # drives the walk animation
	if alive and footsteps_enabled:
		npc_footsteps(delta)
