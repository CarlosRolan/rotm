extends CharacterBody3D
## Third-person controller: Valheim-style orbit camera, walk/run/sprint, jump, automatic
## step-up onto small obstacles, mantling onto low ledges and grabbing high ones to hang
## and climb up. The body never rotates; the rig turns to face the movement direction.

enum State { GROUND, AIR, HANG, CLIMB }

const INPUT_BINDINGS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"toggle_walk": [KEY_C],
	"jump": [KEY_SPACE],
}
const BODY_RADIUS := 0.45
const BODY_HEIGHT := 2.2
const COYOTE_TIME := 0.25  ## seconds without floor contact before counting as airborne
const GROUND_TOLERANCE := 0.7  ## floor this close below still counts as grounded

@export_group("Movement")
@export var walk_speed := 2.0
@export var run_speed := 4.5
@export var sprint_speed := 7.0
@export var acceleration := 8.0
@export var deceleration := 10.0
@export var turn_speed := 9.0
@export var air_control := 2.0
@export var jump_velocity := 5.0

@export_group("Climbing")
@export var max_step_height := 0.45  ## obstacles up to this are stepped onto automatically
@export var mantle_min := 0.45  ## ledges between these heights (above the feet) are climbed
@export var mantle_max := 1.5  ## straight onto with Space
@export var hang_max := 2.6  ## highest ledge above the feet that can be grabbed mid-jump
@export var hang_drop := 2.1  ## body origin below the ledge while hanging
@export var climb_time := 1.3
@export var mantle_time := 0.8

@export_group("Camera")
@export var mouse_sensitivity := 0.0025
@export var min_pitch_deg := -70.0
@export var max_pitch_deg := 35.0
@export var min_zoom := 1.5
@export var max_zoom := 8.0
@export var zoom_step := 0.5

# Debug overrides used by the screenshot harness (see test_level.gd).
var debug_move := Vector3.ZERO  ## world direction to walk in, bypassing input
var debug_speed := 0.0
var debug_jump := false

var _state := State.GROUND
var _walk_toggled := false
var _zoom := 4.0
var _prev_speed := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _ledge := {}
var _climb_t := 0.0
var _climb_from := Vector3.ZERO
var _climb_from_hang := false
var _regrab_timer := 0.0
var _fall_speed := 0.0
var _air_time := 0.0

@onready var _rig: SaurusRig = $SaurusRig
@onready var _shape: CollisionShape3D = $Collision
@onready var _yaw: Node3D = $CameraYaw
@onready var _pitch: Node3D = $CameraYaw/CameraPitch
@onready var _arm: SpringArm3D = $CameraYaw/CameraPitch/SpringArm


func _ready() -> void:
	_ensure_input_actions()
	_arm.add_excluded_object(get_rid())
	_rig.set_exclude([get_rid()])
	_pitch.rotation.x = deg_to_rad(-15.0)
	_zoom = _arm.spring_length
	floor_snap_length = max_step_height
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
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
	match _state:
		State.GROUND:
			_ground_move(delta)
		State.AIR:
			_air_move(delta)
		State.HANG:
			_hang(delta)
		State.CLIMB:
			_climb(delta)


func _ground_move(delta: float) -> void:
	var dir := _input_dir()
	var moving := dir.length_squared() > 0.01

	if _jump_pressed():
		var ledge := _find_ledge(mantle_min, mantle_max)
		if not ledge.is_empty():
			_start_climb(ledge, false)
			return
		velocity.y = jump_velocity

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if moving else deceleration
	horizontal = horizontal.lerp(dir * _target_speed(moving), 1.0 - exp(-rate * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y -= _gravity * delta
	move_and_slide()
	if moving and is_on_wall():
		_try_step_up(dir)

	var turn := _face_velocity(delta)
	# Bumping over rocks briefly lifts the capsule off the floor; only count it as airborne
	# after a jump, a real drop, or a while without contact. Otherwise the legs would tuck
	# and replant on every bump.
	_air_time = 0.0 if is_on_floor() else _air_time + delta
	if not is_on_floor() and (velocity.y > 2.0 or _air_time > COYOTE_TIME or not _ground_below(GROUND_TOLERANCE)):
		_state = State.AIR
		_rig.update_air(velocity, delta)
		return
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	var accel := (flat_speed - _prev_speed) / delta
	_prev_speed = flat_speed
	_rig.update_ground(velocity, accel, turn, delta)


func _air_move(delta: float) -> void:
	_regrab_timer -= delta
	var dir := _input_dir()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if dir.length_squared() > 0.01:
		horizontal = horizontal.lerp(dir * maxf(horizontal.length(), run_speed * 0.5), 1.0 - exp(-air_control * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y -= _gravity * delta
	_fall_speed = maxf(_fall_speed, -velocity.y)
	move_and_slide()
	_face_velocity(delta)

	if is_on_floor():
		_state = State.GROUND
		_rig.land(_fall_speed)
		_fall_speed = 0.0
		return
	if _regrab_timer <= 0.0 and velocity.y < 2.5:
		var ledge := _find_ledge(0.3, hang_max)
		if not ledge.is_empty():
			if ledge.top - global_position.y <= mantle_max:
				_start_climb(ledge, false)
			else:
				_start_hang(ledge)
			return
	_rig.update_air(velocity, delta)


func _hang(delta: float) -> void:
	var raw := _input_raw()
	if _jump_pressed() or Input.is_action_just_pressed("move_forward"):
		_start_climb(_ledge, true)
		return
	if raw.y > 0.5:  # back: let go
		_state = State.AIR
		velocity = _ledge.normal * 1.5
		_regrab_timer = 0.5
		return
	var pose := _climb_pose(0.0)
	_rig.update_reach(SaurusRig.Mode.HANG, pose.hands, 1.0, pose.feet, pose.foot_normals, 0.1, _ledge.normal, delta)


func _climb(delta: float) -> void:
	_climb_t = minf(_climb_t + delta / (climb_time if _climb_from_hang else mantle_time), 1.0)
	var pose := _climb_pose(_climb_t)
	global_position = pose.body
	_rig.update_reach(SaurusRig.Mode.CLIMB, pose.hands, pose.hand_weight, pose.feet, pose.foot_normals,
			pose.lean, _ledge.normal, delta)
	if _climb_t >= 1.0:
		_state = State.GROUND
		velocity = Vector3.ZERO
		_prev_speed = 0.0
		_rig.land()


func _start_hang(ledge: Dictionary) -> void:
	_state = State.HANG
	_ledge = ledge
	velocity = Vector3.ZERO
	_fall_speed = 0.0
	_face(-ledge.normal)
	global_position = ledge.edge + ledge.normal * BODY_RADIUS + Vector3.DOWN * hang_drop


func _start_climb(ledge: Dictionary, from_hang: bool) -> void:
	_state = State.CLIMB
	_ledge = ledge
	_climb_t = 0.0
	_climb_from = global_position
	_climb_from_hang = from_hang
	velocity = Vector3.ZERO
	_fall_speed = 0.0
	_face(-ledge.normal)


## Body position and limb targets along the climb, t in [0, 1]. t = 0 from a hang is the
## hanging pose itself. Hands hold the edge, feet walk up the wall, one knee comes over the
## edge, then the body stands up on top.
func _climb_pose(t: float) -> Dictionary:
	var edge: Vector3 = _ledge.edge
	var n: Vector3 = _ledge.normal
	var inward := -n
	var side := inward.cross(Vector3.UP).normalized()  # body's right while facing the wall
	var hang := edge + n * BODY_RADIUS + Vector3.DOWN * hang_drop
	var top := edge + inward * 0.65

	var keys: Array[Vector3]
	var times: Array[float]
	if _climb_from_hang or t == 0.0 and _state == State.HANG:
		keys = [hang, edge + n * 0.42 + Vector3.DOWN * 1.2, edge + inward * 0.15 + Vector3.DOWN * 0.45, top]
		times = [0.0, 0.45, 0.72, 1.0]
	else:
		var start := _climb_from
		var pull := edge + n * 0.4
		pull.y = maxf(start.y, edge.y - 0.9)
		keys = [start, pull, edge + inward * 0.15 + Vector3.DOWN * 0.35, top]
		times = [0.0, 0.4, 0.7, 1.0]
	var body := keys[-1]
	for i in range(1, keys.size()):
		if t <= times[i]:
			var k := smoothstep(0.0, 1.0, (t - times[i - 1]) / (times[i] - times[i - 1]))
			body = keys[i - 1].lerp(keys[i], k)
			break

	var hands: Array[Vector3] = [edge + inward * 0.05 - side * 0.22, edge + inward * 0.05 + side * 0.22]
	var hand_weight := 1.0 - smoothstep(0.8, 0.95, t)

	# Feet press on the wall below the body, then step onto the top.
	var wall_point := body - n * (body - edge).dot(n) + n * 0.1
	var feet: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for i in 2:
		var lateral := -1.0 if i == 0 else 1.0
		var on_wall := wall_point + side * lateral * 0.16 + Vector3.UP * (0.3 + 0.15 * lateral)
		var on_top := edge + inward * 0.2 + side * lateral * 0.16
		var stand := top + side * lateral * SaurusRig.STANCE_HALF_WIDTH
		var lead_t := 0.5 if i == 0 else 0.68  # left knee comes up first
		var p := on_wall.lerp(on_top, smoothstep(lead_t, lead_t + 0.15, t))
		p = p.lerp(stand, smoothstep(0.82, 1.0, t))
		feet.append(p)
		normals.append(n.lerp(Vector3.UP, smoothstep(lead_t, lead_t + 0.15, t)).normalized())
	var lean := 0.15 + sin(t * PI) * 0.5
	return {"body": body, "hands": hands, "hand_weight": hand_weight, "feet": feet,
			"foot_normals": normals, "lean": lean}


## Looks for a climbable ledge in front of the character whose top is between min_h and
## max_h above the feet, with room to stand on it. Returns {top, edge, normal} or {}.
func _find_ledge(min_h: float, max_h: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var fwd := _rig.forward()
	var base := global_position
	var exclude: Array[RID] = [get_rid()]

	var probe_h := maxf(min_h, 0.3)
	var wall := _ray(space, base + Vector3.UP * probe_h, base + Vector3.UP * probe_h + fwd * (BODY_RADIUS + 0.6), exclude)
	if wall.is_empty() or absf(wall.normal.y) > 0.3:
		return {}
	var over: Vector3 = wall.position - wall.normal * 0.25
	var top_hit := _ray(space, Vector3(over.x, base.y + max_h + 0.2, over.z), Vector3(over.x, base.y + min_h - 0.05, over.z), exclude)
	if top_hit.is_empty() or top_hit.normal.y < 0.7:
		return {}
	var top_y: float = top_hit.position.y
	if top_y - base.y < min_h or top_y - base.y > max_h:
		return {}
	# Exact edge and wall normal just below the top.
	var at := Vector3(base.x, top_y - 0.1, base.z)
	var face := _ray(space, at, at + fwd * (BODY_RADIUS + 1.0), exclude)
	if face.is_empty():
		return {}
	var normal := Vector3(face.normal.x, 0.0, face.normal.z).normalized()
	var edge := Vector3(face.position.x, top_y, face.position.z)
	# Room to stand up on top?
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _shape.shape
	q.transform = Transform3D(Basis.IDENTITY, edge - normal * 0.65 + Vector3.UP * (BODY_HEIGHT * 0.5 + 0.05))
	q.exclude = exclude
	if not space.intersect_shape(q, 1).is_empty():
		return {}
	return {"top": top_y, "edge": edge, "normal": normal}


## Lifts the body onto a small obstacle it walked into, if there is floor on top of it.
func _try_step_up(dir: Vector3) -> void:
	var motion := dir.normalized() * 0.3
	var step := Vector3.UP * max_step_height
	var from := global_transform
	if test_move(from, step):
		return  # no headroom
	var raised := from.translated(step)
	if test_move(raised, motion):
		return  # still blocked: a wall, not a step
	var ahead := raised.translated(motion)
	var col := KinematicCollision3D.new()
	if not test_move(ahead, -step * 1.05, col) or col.get_normal().y < 0.7:
		return
	var new_pos := ahead.origin + col.get_travel()
	var dy := new_pos.y - global_position.y
	if dy < 0.03:
		return
	global_position = new_pos
	_rig.stepped_up(dy)


func _target_speed(moving: bool) -> float:
	if debug_speed > 0.0 and debug_move != Vector3.ZERO:
		return debug_speed
	if moving and Input.is_action_pressed("sprint"):
		return sprint_speed
	return walk_speed if _walk_toggled else run_speed


func _input_raw() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _input_dir() -> Vector3:
	if debug_move != Vector3.ZERO:
		return debug_move.normalized()
	var input := _input_raw()
	return Basis(Vector3.UP, _yaw.rotation.y) * Vector3(input.x, 0.0, input.y)


func _jump_pressed() -> bool:
	if debug_jump:
		debug_jump = false
		return true
	return Input.is_action_just_pressed("jump")


## Turns the rig toward the horizontal velocity; returns the turn rate (rad/s).
func _face_velocity(delta: float) -> float:
	var prev_yaw := _rig.rotation.y
	if Vector2(velocity.x, velocity.z).length() > 0.2:
		var target_yaw := atan2(-velocity.x, -velocity.z)
		_rig.rotation.y = lerp_angle(_rig.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	return angle_difference(prev_yaw, _rig.rotation.y) / delta


func _face(dir: Vector3) -> void:
	_rig.rotation.y = atan2(-dir.x, -dir.z)


func _ground_below(depth: float) -> bool:
	var hit := _ray(get_world_3d().direct_space_state, global_position + Vector3.UP * 0.2,
			global_position + Vector3.DOWN * depth, [get_rid()])
	return not hit.is_empty()


static func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = exclude
	return space.intersect_ray(q)


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
