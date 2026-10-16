extends CharacterBody3D
## Third-person controller with a Valheim-style orbit camera.
## The body itself never rotates; only the model turns toward the direction of travel,
## so the camera orbits freely around the character.

const INPUT_BINDINGS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"toggle_walk": [KEY_C],
}

@export_group("Movement")
@export var walk_speed := 2.0
@export var run_speed := 4.5
@export var sprint_speed := 7.0
@export var acceleration := 8.0
@export var deceleration := 10.0
@export var turn_speed := 9.0

@export_group("Camera")
@export var mouse_sensitivity := 0.0025
@export var min_pitch_deg := -70.0
@export var max_pitch_deg := 35.0
@export var min_zoom := 1.5
@export var max_zoom := 8.0
@export var zoom_step := 0.5

## Debug: when >= 0, the model animates at this speed while standing still (for screenshots).
var debug_speed := -1.0

var _walk_toggled := false
var _zoom := 4.0
var _prev_speed := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _model: SaurusModel = $SaurusModel
@onready var _yaw: Node3D = $CameraYaw
@onready var _pitch: Node3D = $CameraYaw/CameraPitch
@onready var _arm: SpringArm3D = $CameraYaw/CameraPitch/SpringArm


func _ready() -> void:
	_ensure_input_actions()
	_arm.add_excluded_object(get_rid())
	_pitch.rotation.x = deg_to_rad(-15.0)
	_zoom = _arm.spring_length
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw.rotation.y -= event.relative.x * mouse_sensitivity
		_pitch.rotation.x = clampf(_pitch.rotation.x - event.relative.y * mouse_sensitivity,
				deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom = maxf(min_zoom, _zoom - zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = minf(max_zoom, _zoom + zoom_step)
			MOUSE_BUTTON_LEFT:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("toggle_walk"):
		_walk_toggled = not _walk_toggled


func _process(delta: float) -> void:
	_arm.spring_length = lerpf(_arm.spring_length, _zoom, 1.0 - exp(-10.0 * delta))


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Basis(Vector3.UP, _yaw.rotation.y) * Vector3(input.x, 0.0, input.y)
	var moving := dir.length_squared() > 0.01

	var target_speed := run_speed
	if moving and Input.is_action_pressed("sprint"):
		target_speed = sprint_speed
	elif _walk_toggled:
		target_speed = walk_speed

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if moving else deceleration
	horizontal = horizontal.lerp(dir * target_speed, 1.0 - exp(-rate * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()

	var flat_speed := Vector2(velocity.x, velocity.z).length()
	var prev_yaw := _model.rotation.y
	if flat_speed > 0.2:
		var target_yaw := atan2(-velocity.x, -velocity.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	var turn_rate := angle_difference(prev_yaw, _model.rotation.y) / delta
	var accel := (flat_speed - _prev_speed) / delta
	_prev_speed = flat_speed

	if debug_speed >= 0.0:
		_model.update_motion(debug_speed, 0.0, 0.0, delta)
	else:
		_model.update_motion(flat_speed, accel, turn_rate, delta)


## Registers the default key bindings at runtime so the project file stays hand-editable.
func _ensure_input_actions() -> void:
	for action: String in INPUT_BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in INPUT_BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
