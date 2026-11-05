extends StaticBody3D

const SWITCH_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/Kenney/metalClick.ogg")

@export var off_ambient_energy := 0.04

@onready var prompt: Label3D = $Prompt
@onready var toggle: MeshInstance3D = $Toggle
@onready var environment: WorldEnvironment = get_tree().current_scene.get_node("WorldEnvironment") as WorldEnvironment

var is_on := true
var _on_ambient_energy: float
var _on_ambient_source: int
var _on_ambient_color: Color
var _audio_player: AudioStreamPlayer3D


func _ready() -> void:
	_on_ambient_energy = environment.environment.ambient_light_energy
	_on_ambient_source = environment.environment.ambient_light_source
	_on_ambient_color = environment.environment.ambient_light_color
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.stream = SWITCH_SOUND
	_audio_player.unit_size = 3.0
	add_child(_audio_player)
	_update_lighting()


func interact() -> void:
	is_on = not is_on
	_update_lighting()
	_audio_player.play()


func _update_lighting() -> void:
	prompt.text = "E - LIGHTS OFF" if is_on else "E - LIGHTS ON"
	toggle.rotation_degrees.x = -25.0 if is_on else 25.0
	if is_on:
		environment.environment.ambient_light_source = _on_ambient_source
		environment.environment.ambient_light_color = _on_ambient_color
		environment.environment.ambient_light_energy = _on_ambient_energy
	else:
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color(0.01, 0.01, 0.01, 1)
		environment.environment.ambient_light_energy = off_ambient_energy

	for node in get_tree().current_scene.find_children("*", "", true, false):
		if node is Light3D:
			node.visible = is_on
		elif node is MeshInstance3D and node.is_in_group("room_light_fixtures"):
			node.visible = is_on
