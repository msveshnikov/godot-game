extends StaticBody3D

const SLIDE_SOUND: AudioStream = preload("res://addons/cogito/Assets/Audio/squidge316_sliding-door_01.ogg")

@export var pull_distance := 0.65
@export var pull_duration := 0.3

@onready var prompt: Label3D = $Prompt
@onready var foam_pistol: Area3D = $FoamPistol

var is_open := false
var _closed_position: Vector3
var _pull_tween: Tween
var _audio_player: AudioStreamPlayer3D
var _pistol_available := false


func _ready() -> void:
	_closed_position = position
	_set_pistol_available(false)
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.stream = SLIDE_SOUND
	_audio_player.unit_size = 3.0
	_audio_player.max_distance = 15.0
	add_child(_audio_player)


func interact() -> void:
	if _pull_tween and _pull_tween.is_running():
		return

	is_open = not is_open
	prompt.text = "E - PUSH" if is_open else "E - PULL"
	if not is_open:
		_set_pistol_available(false)
	_audio_player.play()
	var target_position := _closed_position
	if is_open:
		target_position.z += pull_distance
	_pull_tween = create_tween()
	_pull_tween.tween_property(self, "position", target_position, pull_duration)
	_pull_tween.tween_callback(_set_pistol_available.bind(is_open))


func can_take_pistol() -> bool:
	return is_open and _pistol_available and foam_pistol.get_parent() == self


func _set_pistol_available(available: bool) -> void:
	_pistol_available = available
	if foam_pistol.get_parent() != self:
		return

	foam_pistol.visible = available
	foam_pistol.monitoring = available
	foam_pistol.monitorable = available
