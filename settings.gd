extends Node
## Autoload "Settings": graphics, sound and controls, picked in the settings panel
## (settings_panel.gd) and kept in user://settings.cfg next to the player's name.
## Graphics apply to whatever game scene is running (world.gd calls apply_scene),
## sound goes straight to the audio buses.

signal changed

const PATH := "user://settings.cfg"
## Quality presets: render scale, shadows, glow, anti-aliasing.
const QUALITY := {
	"low": {"scale": 0.6, "shadows": false, "glow": false, "msaa": Viewport.MSAA_DISABLED},
	"medium": {"scale": 0.8, "shadows": true, "glow": true, "msaa": Viewport.MSAA_DISABLED},
	"high": {"scale": 1.0, "shadows": true, "glow": true, "msaa": Viewport.MSAA_2X},
}

var quality := "high"
var render_scale := 1.0
var shadows := true
var fullscreen := false
var volume := 0.8 # 0..1, everything
var ambience := 0.8 # 0..1, city hum, wind and birds
var look_sensitivity := 1.0 # times the default
var invert_y := false


func _init() -> void:
	if _is_small_device():
		quality = "medium"
		render_scale = QUALITY["medium"]["scale"]
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		quality = str(config.get_value("graphics", "quality", quality))
		if not QUALITY.has(quality):
			quality = "high"
		render_scale = clampf(float(config.get_value("graphics", "render_scale", render_scale)), 0.5, 1.0)
		shadows = bool(config.get_value("graphics", "shadows", QUALITY[quality]["shadows"]))
		fullscreen = bool(config.get_value("graphics", "fullscreen", false))
		volume = clampf(float(config.get_value("audio", "volume", volume)), 0.0, 1.0)
		ambience = clampf(float(config.get_value("audio", "ambience", ambience)), 0.0, 1.0)
		look_sensitivity = clampf(float(config.get_value("controls", "look_sensitivity", 1.0)), 0.3, 2.5)
		invert_y = bool(config.get_value("controls", "invert_y", false))


func _ready() -> void:
	apply_audio()
	_apply_window()


## Phones and the browser on a phone start on medium.
static func _is_small_device() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Can this build go fullscreen (desktop and browser; phones always are).
static func can_fullscreen() -> bool:
	return not _is_small_device()


func set_quality(value: String) -> void:
	if not QUALITY.has(value):
		return
	quality = value
	render_scale = QUALITY[value]["scale"]
	shadows = QUALITY[value]["shadows"]
	_changed()


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	_changed()


func _changed() -> void:
	apply_audio()
	_apply_window()
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("apply_settings"):
		scene.call("apply_settings")
	changed.emit()
	_save()


## Graphics for a game scene: the root viewport's render scale and anti-aliasing,
## the sun's shadows and the environment's glow.
func apply_scene(scene: Node) -> void:
	var viewport := scene.get_viewport()
	viewport.scaling_3d_scale = render_scale
	viewport.msaa_3d = QUALITY[quality]["msaa"]
	for light in scene.find_children("*", "DirectionalLight3D", true, false):
		(light as DirectionalLight3D).shadow_enabled = shadows
	for node in scene.find_children("*", "WorldEnvironment", true, false):
		var environment := (node as WorldEnvironment).environment
		if environment != null:
			environment.glow_enabled = QUALITY[quality]["glow"]


func apply_audio() -> void:
	_bus_volume("Master", volume)
	_bus_volume("Ambience", ambience)


static func _bus_volume(bus: String, amount: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, amount <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(amount, 0.001)))


func _apply_window() -> void:
	if not can_fullscreen():
		return
	var wanted := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	var now := DisplayServer.window_get_mode()
	var is_full := now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen != is_full:
		DisplayServer.window_set_mode(wanted)


func _save() -> void:
	var config := ConfigFile.new()
	config.load(PATH) # keep the player's name and place (net.gd)
	config.set_value("graphics", "quality", quality)
	config.set_value("graphics", "render_scale", render_scale)
	config.set_value("graphics", "shadows", shadows)
	config.set_value("graphics", "fullscreen", fullscreen)
	config.set_value("audio", "volume", volume)
	config.set_value("audio", "ambience", ambience)
	config.set_value("controls", "look_sensitivity", look_sensitivity)
	config.set_value("controls", "invert_y", invert_y)
	config.save(PATH)
