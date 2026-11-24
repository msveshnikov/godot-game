class_name Police
extends Node3D
## The heat meter and the police it brings. Every act of violence (a kill, a car
## blown up, a window smashed, a dent) adds heat; it cools off slowly once the
## player behaves. When it fills up a patrol car drives in with lights and siren,
## along the street graph, and two officers (a man and a woman,
## police_officer.gd) get out and fight. Put both down and the heat is gone (and
## they drop a reward); die and they leave, taking part of your money with them
## (player_controller.gd); run far enough and they lose you, at half heat.
## Local to each player: everyone has their own police.

const OFFICER_SCENE: PackedScene = preload("res://villager_bot.tscn")
const OFFICER_SCRIPT = preload("res://police_officer.gd")
const SIREN_SOUND := "res://audio/siren.wav"
const CAR_MODEL := "res://assets/vehicles/car_octavia.glb"
const CAR_SIZE := Vector3(1.81, 1.46, 4.69)
const HEAT_MAX := 100.0
const DECAY_DELAY := 4.0 # seconds of calm before the heat starts to drop
const DECAY_RATE := 3.0 # per second
const REWARD := 150
const ESCAPE_DISTANCE := 75.0
const ESCAPE_TIME := 12.0
const ESCAPE_HEAT := 50.0
const CAR_SPEED := 16.0
const STOP_DISTANCE := 13.0
const MAX_DRIVE_TIME := 18.0
const SPAWN_NEAR := 55.0
const SPAWN_FAR := 90.0

var heat := 0.0
## "idle", "driving" (the car is on its way) or "fight".
var state := "idle"
var player: Node3D

var _crowd: Node
var _calm := 0.0
var _car: AnimatableBody3D
var _car_lights: Array = [] # [red mesh, blue mesh, red light, blue light]
var _siren: AudioStreamPlayer3D
var _officers: Array = []
var _path: Array[Vector3] = []
var _path_s := 0.0
var _path_length := 0.0
var _drive_time := 0.0
var _escape := 0.0
var _flash := 0.0
var _hud: Control
var _bar: ProgressBar
var _bar_fill: StyleBoxFlat
var _label: Label


func _ready() -> void:
	_crowd = get_parent().get_node_or_null("BotCrowd")
	if player != null:
		_build_hud(player.get("hud") as CanvasLayer)


## Something violent happened: `amount` more heat (ignored while the police are already coming).
func add_heat(amount: float) -> void:
	if state != "idle" or amount <= 0.0:
		return
	heat = minf(heat + amount, HEAT_MAX)
	_calm = 0.0
	if heat >= HEAT_MAX:
		_dispatch()


## The player died: the police go home, the heat is gone.
func stand_down() -> void:
	_clear()
	heat = 0.0
	state = "idle"


## Bodies the officers' line of sight goes through: the car and each other.
func own_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if _car != null:
		rids.append(_car.get_rid())
	for officer in _officers:
		if is_instance_valid(officer):
			rids.append_array(officer.call("body_rids"))
	return rids


func hunted() -> Node3D:
	return player


## An officer went down; when both are, the player has won this round.
func officer_down(_officer: Node) -> void:
	for officer in _officers:
		if is_instance_valid(officer) and officer.get("alive"):
			return
	var each := REWARD / maxi(_officers.size(), 1)
	for officer in _officers:
		Coins.spawn(get_parent(), (officer as Node3D).global_position + Vector3.UP * 0.8, each, player.global_position)
	_toast("Police down! Grab the cash.")
	heat = 0.0
	state = "idle"
	_officers.clear()
	_park_car()


func _process(delta: float) -> void:
	if player == null:
		return
	match state:
		"idle":
			_calm += delta
			if _calm > DECAY_DELAY:
				heat = maxf(heat - DECAY_RATE * delta, 0.0)
		"driving":
			_drive(delta)
		"fight":
			_check_escape(delta)
	_flash += delta
	_update_lights()
	_update_hud()


# ------------------------------------------------------------- dispatch ----

func _dispatch() -> void:
	state = "driving"
	_clear()
	_build_car()
	_path = _route()
	_path_length = 0.0
	for k in range(1, _path.size()):
		_path_length += _path[k].distance_to(_path[k - 1])
	_path_s = 0.0
	_drive_time = 0.0
	_officers.clear()
	_place_car(0.0)
	for k in 2:
		var officer := OFFICER_SCENE.instantiate() as CharacterBody3D
		officer.set_script(OFFICER_SCRIPT)
		officer.name = "PoliceOfficer%d" % k
		officer.set("bot_index", 300 + k + randi_range(0, 20) * 2) # odd = the woman
		officer.set("crowd", _crowd)
		officer.set("dispatch", self)
		get_parent().add_child(officer)
		officer.global_position = _car.global_position + Vector3.UP * 0.2
		officer.visible = false
		officer.process_mode = Node.PROCESS_MODE_DISABLED
		_officers.append(officer)
	_toast("The police are coming!")


## Street-graph route to the node nearest the player from a node 55-100 m away
## (the most direct of a few tries, so the car doesn't wander off first); a
## straight run in from 30 m if the graph doesn't give one.
func _route() -> Array[Vector3]:
	var route: Array[Vector3] = []
	var at := player.global_position
	if _crowd != null and _crowd.has_method("path_between"):
		var goal: int = _crowd.call("nearest_node", at)
		var starts: Array[int] = _crowd.call("nodes_between", at, SPAWN_NEAR, SPAWN_FAR)
		starts.shuffle()
		var best_length := INF
		for start in starts.slice(0, 12):
			var nodes: Array[int] = _crowd.call("path_between", start, goal)
			if nodes.size() < 2:
				continue
			var points: Array[Vector3] = []
			var length := 0.0
			for node in nodes:
				points.append(_crowd.call("node_position", node))
				if points.size() > 1:
					length += points[-1].distance_to(points[-2])
			# Detour: how much longer than the straight line it is.
			var detour := length / maxf(points[0].distance_to(at), 1.0)
			if detour < best_length:
				best_length = detour
				route = points
	if route.size() < 2:
		var away := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		route = [Vector3(at.x, 0.0, at.z) + away * 30.0, Vector3(at.x, 0.0, at.z) + away * STOP_DISTANCE]
	return route


func _drive(delta: float) -> void:
	_drive_time += delta
	var target := player.global_position
	var here := _car.global_position
	var near := Vector2(here.x - target.x, here.z - target.z).length() < STOP_DISTANCE
	if near or _path_s >= _path_length or _drive_time > MAX_DRIVE_TIME:
		_arrive()
		return
	# Slow down for the corners and the last stretch.
	var speed := CAR_SPEED
	var left := Vector2(here.x - target.x, here.z - target.z).length() - STOP_DISTANCE
	speed = minf(speed, 3.0 + left * 1.2)
	_path_s = minf(_path_s + speed * delta, _path_length)
	_place_car(_path_s)


## Car at distance `s` along the route, facing the way it goes (heading eased round corners).
func _place_car(s: float) -> void:
	if _path.size() < 2:
		return
	var walked := 0.0
	var index := 1
	while index < _path.size() - 1 and walked + _path[index].distance_to(_path[index - 1]) < s:
		walked += _path[index].distance_to(_path[index - 1])
		index += 1
	var a := _path[index - 1]
	var b := _path[index]
	var segment := maxf(a.distance_to(b), 0.001)
	var t := clampf((s - walked) / segment, 0.0, 1.0)
	var pos := a.lerp(b, t)
	var dir := (b - a).normalized()
	if index < _path.size() - 1 and segment - (s - walked) < 5.0:
		var blend := 1.0 - (segment - (s - walked)) / 5.0
		dir = dir.lerp((_path[index + 1] - b).normalized(), blend * 0.5).normalized()
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	var current := _car.global_transform
	var wanted := Transform3D(Basis.looking_at(-dir, Vector3.UP), pos)
	if s > 0.0:
		wanted.basis = current.basis.slerp(wanted.basis, 0.25)
	_car.global_transform = wanted


## The car stops; the officers get out on either side and go for the player.
func _arrive() -> void:
	state = "fight"
	_escape = 0.0
	var xf := _car.global_transform
	var sides := [xf.basis.x * 1.7, -xf.basis.x * 1.7]
	for k in _officers.size():
		var officer := _officers[k] as CharacterBody3D
		if not is_instance_valid(officer):
			continue
		officer.global_position = xf.origin + sides[k % 2] + Vector3.UP * 0.1
		officer.process_mode = Node.PROCESS_MODE_INHERIT
		officer.call("engage", player)
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if _siren != null and is_instance_valid(_siren):
			_siren.stop())


func _check_escape(delta: float) -> void:
	var nearest := INF
	for officer in _officers:
		if is_instance_valid(officer) and officer.get("alive"):
			nearest = minf(nearest, (officer as Node3D).global_position.distance_to(player.global_position))
	if nearest > ESCAPE_DISTANCE:
		_escape += delta
	else:
		_escape = 0.0
	if _escape > ESCAPE_TIME:
		_toast("You lost the police.")
		_clear()
		heat = ESCAPE_HEAT
		_calm = 0.0
		state = "idle"


## The fight is over: the car stays a while with its lights on, then goes.
func _park_car() -> void:
	var car := _car
	_car = null
	if _siren != null:
		_siren.stop()
	get_tree().create_timer(40.0).timeout.connect(func() -> void:
		if is_instance_valid(car):
			car.queue_free())
	# The lights keep flashing on the parked car.
	var lights := _car_lights
	_car_lights = []
	var blink := car.create_tween().set_loops(160)
	blink.tween_callback(func() -> void: _set_light_pair(lights, true)).set_delay(0.13)
	blink.tween_callback(func() -> void: _set_light_pair(lights, false)).set_delay(0.13)


## Officers and car gone (bodies already lying on the street stay).
func _clear() -> void:
	for officer in _officers:
		if is_instance_valid(officer) and officer.get("alive"):
			officer.queue_free()
	_officers.clear()
	if _car != null:
		_car.queue_free()
	_car = null
	_car_lights = []
	_siren = null


# ------------------------------------------------------------------ car ----

func _build_car() -> void:
	_car = AnimatableBody3D.new()
	_car.name = "PoliceCar"
	_car.sync_to_physics = false
	var shape := BoxShape3D.new()
	shape.size = Vector3(CAR_SIZE.x, CAR_SIZE.y - 0.15, CAR_SIZE.z - 0.1)
	var shape_node := CollisionShape3D.new()
	shape_node.shape = shape
	shape_node.position.y = CAR_SIZE.y * 0.5 + 0.07
	_car.add_child(shape_node)
	get_parent().add_child(_car)

	var mesh := _car_mesh()
	if mesh != null:
		var body := MeshInstance3D.new()
		body.mesh = mesh
		var white := StandardMaterial3D.new()
		white.albedo_color = Color(0.94, 0.95, 0.96)
		white.metallic = 0.4
		white.roughness = 0.3
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			if material != null and material.resource_name == "Paint":
				body.set_surface_override_material(surface, white)
		_car.add_child(body)
	# Blue band along both sides, POLICE on the doors.
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.06, 0.2, 0.62)
	blue.roughness = 0.35
	for side in [-1.0, 1.0]:
		var band := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.02, 0.16, CAR_SIZE.z * 0.86)
		box.material = blue
		band.mesh = box
		band.position = Vector3(side * (CAR_SIZE.x * 0.5 + 0.005), 0.62, 0.0)
		_car.add_child(band)
		var word := Label3D.new()
		word.text = "POLICE"
		word.font_size = 64
		word.pixel_size = 0.004
		word.modulate = Color(0.06, 0.2, 0.62)
		word.outline_size = 0
		word.position = Vector3(side * (CAR_SIZE.x * 0.5 + 0.015), 0.86, -0.1)
		word.rotation.y = side * PI / 2.0
		_car.add_child(word)
	# Light bar: red on the left, blue on the right.
	var bar_base := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(1.1, 0.07, 0.24)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.05, 0.05, 0.06)
	base_box.material = black
	bar_base.mesh = base_box
	bar_base.position = Vector3(0.0, CAR_SIZE.y + 0.02, -0.25)
	_car.add_child(bar_base)
	for colour in [Color(1.0, 0.08, 0.05), Color(0.1, 0.3, 1.0)]:
		var lamp := MeshInstance3D.new()
		var lamp_box := BoxMesh.new()
		lamp_box.size = Vector3(0.48, 0.1, 0.2)
		var glow := StandardMaterial3D.new()
		glow.albedo_color = colour.darkened(0.5)
		glow.emission_enabled = true
		glow.emission = colour
		glow.emission_energy_multiplier = 0.0
		lamp_box.material = glow
		lamp.mesh = lamp_box
		var x := -0.27 if colour.r > 0.5 else 0.27
		lamp.position = Vector3(x, CAR_SIZE.y + 0.1, -0.25)
		_car.add_child(lamp)
		_car_lights.append(lamp)
	for colour in [Color(1.0, 0.1, 0.05), Color(0.15, 0.3, 1.0)]:
		var light := OmniLight3D.new()
		light.light_color = colour
		light.omni_range = 9.0
		light.light_energy = 0.0
		light.position = Vector3(-0.4 if colour.r > 0.5 else 0.4, CAR_SIZE.y + 0.4, -0.25)
		_car.add_child(light)
		_car_lights.append(light)
	_siren = AudioStreamPlayer3D.new()
	_siren.stream = _looping_wav(SIREN_SOUND)
	_siren.unit_size = 14.0
	_siren.max_distance = 160.0
	_siren.volume_db = -2.0
	_car.add_child(_siren)
	_siren.play()


func _car_mesh() -> Mesh:
	var scene := load(CAR_MODEL) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	var found := root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	root.free()
	return mesh


func _update_lights() -> void:
	if _car_lights.size() < 4:
		return
	_set_light_pair(_car_lights, fmod(_flash, 0.5) < 0.25)


## Red or blue half lit, the other dark.
static func _set_light_pair(lights: Array, red_on: bool) -> void:
	if lights.size() < 4:
		return
	for k in 2:
		var on := red_on if k == 0 else not red_on
		var lamp := lights[k] as MeshInstance3D
		if not is_instance_valid(lamp):
			return
		((lamp.mesh as BoxMesh).material as StandardMaterial3D).emission_energy_multiplier = 4.0 if on else 0.0
		(lights[k + 2] as OmniLight3D).light_energy = 3.0 if on else 0.0


static func _looping_wav(path: String) -> AudioStream:
	var stream := load(path) as AudioStreamWAV
	if stream == null:
		return null
	stream = stream.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


# ------------------------------------------------------------------ HUD ----

func _build_hud(layer: CanvasLayer) -> void:
	if layer == null:
		return
	_hud = VBoxContainer.new()
	_hud.position = Vector2(24.0, 128.0)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_theme_constant_override("separation", 2)
	layer.add_child(_hud)
	_label = Label.new()
	_label.text = "HEAT"
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.75))
	_label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
	_label.add_theme_constant_override("outline_size", 5)
	_hud.add_child(_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(200.0, 12.0)
	_bar.max_value = HEAT_MAX
	_bar.show_percentage = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	back.set_corner_radius_all(4)
	back.border_color = Color(0.12, 0.08, 0.04)
	back.set_border_width_all(1)
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", back)
	_bar.add_theme_stylebox_override("fill", _bar_fill)
	_hud.add_child(_bar)


func _update_hud() -> void:
	if _bar == null:
		return
	_hud.visible = player.call("is_playing") and (heat > 0.0 or state != "idle")
	if state == "idle":
		_bar.value = heat
		_bar_fill.bg_color = Color(1.0, 0.85, 0.2).lerp(Color(0.95, 0.15, 0.1), heat / HEAT_MAX)
		_label.text = "HEAT"
		_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.75))
		return
	_bar.value = HEAT_MAX
	var red := fmod(_flash, 0.5) < 0.25
	_bar_fill.bg_color = Color(0.95, 0.12, 0.08) if red else Color(0.15, 0.35, 1.0)
	_label.text = "POLICE ON THE WAY" if state == "driving" else "POLICE"
	_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if red else Color(0.5, 0.7, 1.0))


func _toast(text: String) -> void:
	if player != null and player.has_method("show_toast"):
		player.call("show_toast", text)
