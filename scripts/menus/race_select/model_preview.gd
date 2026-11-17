class_name ModelPreview
extends Node3D
## Character viewer of the race-selection screen. Loads a model, scales it to the race's
## height and stands it on the origin facing the camera (+Z). It turns at most MAX_YAW_DEG
## either way (160 degrees in all); the camera's tilt is RaceSelect's job. Plays the
## model's own animations if it has any; otherwise it stays in its default pose.

signal animations_changed(names: PackedStringArray)

const MAX_YAW_DEG := 80.0
const START_YAW_DEG := -20.0

var yaw_target := deg_to_rad(START_YAW_DEG)
var current_animation := ""

var _turntable: Node3D
var _model: Node3D
var _player: AnimationPlayer


func _ready() -> void:
	_turntable = Node3D.new()
	_turntable.rotation.y = yaw_target
	add_child(_turntable)


func _process(delta: float) -> void:
	_turntable.rotation.y = lerpf(_turntable.rotation.y, yaw_target, 1.0 - exp(-12.0 * delta))


func turn(radians: float) -> void:
	set_yaw(yaw_target + radians)


func set_yaw(radians: float) -> void:
	var limit := deg_to_rad(MAX_YAW_DEG)
	yaw_target = clampf(radians, -limit, limit)


## Shows the model at `path`, `height` metres tall. Returns false if it can't be loaded.
func show_model(path: String, height: float) -> bool:
	if _model:
		_model.free()
		_model = null
		_player = null
	current_animation = ""
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Preview model not found at %s" % path)
		animations_changed.emit(PackedStringArray())
		return false

	var model := scene.instantiate() as Node3D
	var bounds := _bounds(model)
	# Centre it on its own footprint so it turns on the spot, and stand it on the floor.
	model.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	_model = Node3D.new()
	_model.scale = Vector3.ONE * height / maxf(bounds.size.y, 0.01)
	_model.rotation.y = 0.0 if _faces_camera(model) else PI
	_model.add_child(model)
	_turntable.add_child(_model)

	var names := PackedStringArray()
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_player = players[0]
		for anim_name in _player.get_animation_list():
			if anim_name != "RESET":
				names.append(anim_name)
		_player.animation_finished.connect(_on_animation_finished)
	if not names.is_empty():
		play(names[0])
	animations_changed.emit(names)
	return true


## Loops `anim_name`, or goes back to the default pose with "".
func play(anim_name: String) -> void:
	current_animation = anim_name
	if _player == null:
		return
	if anim_name == "":
		_player.stop()
		for skeleton: Skeleton3D in _model.find_children("*", "Skeleton3D", true, false):
			skeleton.reset_bone_poses()
	else:
		_player.play(anim_name)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == current_animation:
		_player.play(anim_name)  # imported clips often aren't set to loop


## Bounding box of every mesh in the model, in the model's own space.
static func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var node: Node = mi
		while node != root and node is Node3D:
			xf = (node as Node3D).transform * xf
			node = node.get_parent()
		var mesh_box := xf * mi.mesh.get_aabb()
		box = mesh_box if first else box.merge(mesh_box)
		first = false
	return box


## Rigged models tell their facing from the feet (toes ahead of the ankle); unrigged ones
## are assumed to face +Z, as Meshy exports them.
static func _faces_camera(model: Node3D) -> bool:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return true
	var sk: Skeleton3D = skeletons[0]
	var foot := sk.find_bone("mixamorig_LeftFoot")
	var toe := sk.find_bone("mixamorig_LeftToeBase")
	if foot < 0 or toe < 0:
		return true
	return sk.get_bone_global_rest(toe).origin.z >= sk.get_bone_global_rest(foot).origin.z
