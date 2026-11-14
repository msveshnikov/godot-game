extends SceneTree
## Rewrites export_files in export_presets.cfg with everything the game can load, so exports
## ship only that instead of every resource in the project (the Cogito demo content alone
## is ~50 MB).
##
## Run after adding a scene, model or sound:
##   godot --headless --path . -s tools/update_export_files.gd
##
## Walks from the main scene, the autoloads and the Cogito settings file, following real
## resource dependencies, preload()/extends paths in every script (all scripts are exported
## through include_filter "*.gd", and class_name references can compile any of them), and
## any literal res:// path in the game's own scripts and scenes (load() calls). Folders
## res://audio and res://assets are exported whole through include_filter as well.

const PRESETS := "res://export_presets.cfg"

var needed := {}
var queue: Array[String] = []
var literal := RegEx.create_from_string("(res://[^\"'\\s)%]+|uid://[a-z0-9]+)")
var preload_re := RegEx.create_from_string("(?:preload\\(|extends\\s+)\"([^\"]+)\"")


func _initialize() -> void:
	_add("res://node_2d.tscn")
	_add("res://icon.svg")
	_add("res://default_bus_layout.tres")
	_add(String(ProjectSettings.get_setting("cogito/settings/settings_file", "")))
	for prop in ProjectSettings.get_property_list():
		var n: String = prop.name
		if n.begins_with("autoload/"):
			_add(String(ProjectSettings.get_setting(n)).trim_prefix("*"))
	_add_all_scripts("res://")
	while not queue.is_empty():
		_visit(queue.pop_back())

	var files: Array = needed.keys().filter(func(p: String) -> bool: return p.get_extension() != "gd")
	files.sort()
	var line := "export_files=PackedStringArray(%s)" % ", ".join(files.map(func(p: String) -> String: return "\"%s\"" % p))
	var text := FileAccess.get_file_as_string(PRESETS)
	var re := RegEx.create_from_string("(?m)^export_files=PackedStringArray\\(.*\\)$")
	var count := re.search_all(text).size()
	text = re.sub(text, line, true)
	var out := FileAccess.open(PRESETS, FileAccess.WRITE)
	out.store_string(text)
	out.close()
	print("export_files: %d resources written to %d presets" % [files.size(), count])
	quit()


func _add(p: String) -> void:
	if p.begins_with("uid://"):
		var id := ResourceUID.text_to_id(p)
		if id == ResourceUID.INVALID_ID or not ResourceUID.has_id(id):
			return
		p = ResourceUID.get_id_path(id)
	p = p.strip_edges()
	if p == "" or needed.has(p):
		return
	if not FileAccess.file_exists(p) and not ResourceLoader.exists(p):
		return
	needed[p] = true
	queue.append(p)


func _add_all_scripts(dir: String) -> void:
	if FileAccess.file_exists(dir.path_join(".gdignore")) or dir.begins_with("res://.godot"):
		return
	for sub in DirAccess.get_directories_at(dir):
		_add_all_scripts(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "gd":
			_add(dir.path_join(f))


func _visit(p: String) -> void:
	for d in ResourceLoader.get_dependencies(p):
		var parts := String(d).split("::")
		_add(parts[parts.size() - 1])
		_add(parts[0])
	var ext := p.get_extension()
	if p.begins_with("res://addons/"):
		# Addons: only what scripts preload or extend, not every path mentioned in them
		# (CogitoSettings.tres alone would drag in the whole Cogito demo).
		if ext == "gd":
			for m in preload_re.search_all(FileAccess.get_file_as_string(p)):
				var q := m.get_string(1)
				if not q.begins_with("res://") and not q.begins_with("uid://"):
					q = p.get_base_dir().path_join(q).simplify_path()
				_add(q)
	elif ext in ["gd", "tscn", "tres", "gdshader"]:
		for m in literal.search_all(FileAccess.get_file_as_string(p)):
			_add(m.get_string(1))
