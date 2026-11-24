extends Node
## Background sound of the estate: distant city hum, wind in the trees and
## birdsong everywhere, plus the creak of the playground swings near it.

const LAYERS := [
	# [path, volume dB]
	["res://audio/city_hum.wav", -17.0],
	["res://audio/wind.wav", -21.0],
	["res://audio/birds.ogg", -13.0],
]
const SWING_CREAK := "res://audio/swing_creak.wav"

## Game-space spot of the playground swings (set by the district).
var swing_position := Vector3.ZERO
## [path, volume dB] loops; a district may set its own mix before adding this node.
var layers: Array = LAYERS


func _ready() -> void:
	for layer in layers:
		var player := AudioStreamPlayer.new()
		player.stream = _looping(layer[0])
		player.volume_db = layer[1]
		player.bus = &"Ambience" # its own volume slider (settings.gd)
		player.autoplay = true
		add_child(player)
	if swing_position != Vector3.ZERO:
		var creak := AudioStreamPlayer3D.new()
		creak.stream = _looping(SWING_CREAK)
		creak.position = swing_position
		creak.unit_size = 4.0
		creak.max_distance = 35.0
		creak.volume_db = -8.0
		creak.bus = &"Ambience"
		creak.autoplay = true
		add_child(creak)


static func _looping(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream is AudioStreamWAV:
		var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		return wav
	if stream is AudioStreamOggVorbis:
		var ogg := (stream as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		ogg.loop = true
		return ogg
	return stream
