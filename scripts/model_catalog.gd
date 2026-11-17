class_name ModelCatalog
## The rigged character models the test level can swap between. Every .glb under
## `imported_models/` whose skeleton has the Mixamo bones SaurusPose drives is listed, so a
## new rigged mesh shows up in the menu just by dropping it in. Unrigged meshes are skipped.

const ROOT := "res://imported_models"
const DEFAULT_MODEL := "res://imported_models/Crystal_Sentinel/Crystal_Sentinel.glb"
const SETTINGS_PATH := "user://test_model.cfg"
const REQUIRED_BONES := ["mixamorig_Hips", "mixamorig_LeftUpLeg", "mixamorig_LeftLeg",
		"mixamorig_LeftFoot", "mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot"]


## [{name, path}] for every usable model, sorted by name.
static func scan() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for path in glb_files(ROOT):
		if is_rigged(path):
			out.append({"name": path.get_file().get_basename().replace("_", " "), "path": path})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	return out


## The model to load at start: `-- --model=<file name>` on the command line, then the race
## picked on the selection screen (Session autoload), then the last one picked in the
## test level's menu, then the default.
static func initial() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			var wanted := arg.trim_prefix("--model=").to_lower()
			for m in scan():
				if m.path.get_file().get_basename().to_lower() == wanted:
					return m.path
			push_warning("Model '%s' not found, using the default" % wanted)
	var session := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Session")
	if session and session.get("model_path") != "":
		return session.get("model_path")
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var saved: String = cfg.get_value("model", "path", "")
		if ResourceLoader.exists(saved):
			return saved
	return DEFAULT_MODEL


static func remember(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("model", "path", path)
	cfg.save(SETTINGS_PATH)


## Every .glb under `dir_path`, recursively.
static func glb_files(dir_path: String = ROOT) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		out.append_array(glb_files(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.get_extension().to_lower() == "glb":
			out.append(dir_path.path_join(file))
	return out


## Reads only the glTF JSON chunk (not the mesh data) to check for a skin with the bones
## the procedural pose needs.
static func is_rigged(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 20:
		return false
	f.seek(12)
	var json_len := f.get_32()
	f.get_32()  # chunk type "JSON"
	var data: Variant = JSON.parse_string(f.get_buffer(json_len).get_string_from_utf8())
	if not data is Dictionary or data.get("skins", []).is_empty():
		return false
	var names := {}
	for node: Dictionary in data.get("nodes", []):
		names[String(node.get("name", "")).replace(":", "_")] = true  # Godot renames "mixamorig:Hips"
	return REQUIRED_BONES.all(func(b: String) -> bool: return names.has(b))
