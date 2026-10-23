class_name SaurusRig
extends Node3D
## The imported Saurus model, animated procedurally because it ships without walk/run clips.
## Feet are stepped onto the real ground (raycasts) and the legs solved with two-bone IK, so
## they land on stones, steps and slopes instead of clipping through them; a swinging foot
## lifts over whatever lies between its old and new footholds. The hips drop so the lowest
## foot can reach, and the body, arms and tail follow procedurally.
##
## The player controller decides where the body goes; this node decides how the limbs get
## there. SaurusPose (a SkeletonModifier3D) applies the result to the skeleton each frame.

enum Mode { GROUND, AIR, HANG, CLIMB }

const MODEL_PATH := "res://imported_models/saurian-test-dummy-proxy/saurian-test-dummy-proxy.glb"
const MODEL_SCALE := 1.1
## The mesh is authored facing +Z with the hips 0.75 m off the origin; this recentres it.
const MODEL_OFFSET := Vector3(-0.004, 0.0, -0.746)
const HIDE_COLOR := Color(0.13, 0.36, 0.42)
const HIDE_TINT := Color(0.10, 0.30, 0.30, 0.6)

const ANKLE_HEIGHT := 0.2  ## ankle joint above the sole (world metres)
const STANCE_HALF_WIDTH := 0.16
const GROUND_PROBE_UP := 0.9  ## how far above the body a foothold is searched for
const MAX_FOOT_RISE := 0.6  ## footholds higher than this above the body are rejected
const MAX_FOOT_REACH := 0.9  ## a planted foot further than this from its rest spot steps at once

# Gait tables, blended by speed: walk, run, sprint.
const GAIT_SPEEDS := [2.0, 4.5, 7.0]
const STEP_LENGTH := [0.55, 0.95, 1.3]  ## metres per step
const SWING_FRACTION := [0.42, 0.6, 0.66]  ## share of the cycle each foot spends in the air
const FOOT_LIFT := [0.1, 0.18, 0.24]
const CROUCH := [-0.08, -0.12, -0.16]  ## hips lowered so the knees stay bent
const BOB := [0.03, 0.06, 0.07]
const LEAN := [0.14, 0.26, 0.4]
const ARM_SWING := [0.3, 0.42, 0.5]
const ELBOW_BEND := [0.35, 0.75, 0.95]


class Foot:
	var lateral := 0.0  ## -1 left, +1 right, along the body's right vector
	var phase_offset := 0.0
	var plant := Vector3.ZERO
	var plant_normal := Vector3.UP
	var swinging := false
	var start := Vector3.ZERO
	var end := Vector3.ZERO
	var end_normal := Vector3.UP
	var t := 0.0
	var duration := 0.3
	var lead := 0.0  ## extra prediction time beyond the swing itself
	var phase_driven := false  ## true while the gait phase (not a timer) drives this step
	var lift := 0.1
	var clearance := 0.0
	var pos := Vector3.ZERO  ## current sole position (world)
	var normal := Vector3.UP
	var pitch := 0.0  ## toe down (+) / up (-)
	var air_local := Vector3.ZERO


## Steepest surface a foot will plant on. Rock sides steeper than this are skipped for a
## flatter spot nearby. Raise toward 90 for a wall-gripping (gecko-like) lizard whose feet
## should stick to the nearest surface.
@export_range(0.0, 90.0) var max_foothold_angle_deg := 35.0
## How far a planted foot may tilt to match the ground under it.
@export_range(0.0, 90.0) var max_foot_tilt_deg := 25.0

var mode := Mode.GROUND
var feet: Array[Foot] = []

# Pose read by SaurusPose every frame.
var hips_offset := 0.0  ## vertical, world metres
var lean := 0.0  ## spine pitch forward (rad)
var twist := 0.0
var bank := 0.0  ## roll into turns
var arm_phase := 0.0
var arm_swing := 0.0
var elbow_bend := 0.3
var arm_lower := 0.55
var tail_sway := 0.0
var tail_lift := 0.0
var head_look := 0.0
var hand_targets: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  ## world, left/right
var hand_weight := 0.0
var reach_pole := Vector3.BACK  ## world direction elbows point while reaching

var _skeleton: Skeleton3D
var _exclude: Array[RID] = []
var _phase := 0.0
var _speed := 0.0
var _time := 0.0
var _accel_lean := 0.0
var _hips_smooth := 0.0
var _step_offset := 0.0


func _ready() -> void:
	var scene := load(MODEL_PATH) as PackedScene
	if scene == null:
		push_error("Saurus model not found at %s" % MODEL_PATH)
		return
	var flip := Node3D.new()
	flip.rotation.y = PI
	flip.scale = Vector3.ONE * MODEL_SCALE
	add_child(flip)
	var model := scene.instantiate() as Node3D
	model.position = MODEL_OFFSET
	flip.add_child(model)
	# Stop the imported clip from fighting the procedural pose.
	for player: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
		player.stop()
		player.active = false

	# The model has no UVs, so the pixel texture is mapped triplanar in model space.
	var hide := PixelTex.material(PixelTex.make("saurus_hide", HIDE_COLOR, "plates", 32, 0.1, 7, HIDE_TINT), 32.0, false)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = hide

	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	var pose := SaurusPose.new()
	pose.rig = self
	_skeleton.add_child(pose)

	for i in 2:
		var f := Foot.new()
		f.lateral = -1.0 if i == 0 else 1.0
		f.phase_offset = 0.0 if i == 0 else 0.5
		feet.append(f)
	reset_feet.call_deferred()


## Physics bodies the foot probes should ignore (the player's own capsule).
func set_exclude(rids: Array[RID]) -> void:
	_exclude = rids


func forward() -> Vector3:
	return -global_basis.z


func right() -> Vector3:
	return global_basis.x


## Plants both feet on the ground under their rest positions.
func reset_feet() -> void:
	for f in feet:
		var p := _rest_point(f)
		var hit := _foothold(p)
		f.plant = hit.position if hit else p
		f.plant_normal = hit.normal if hit else Vector3.UP
		f.pos = f.plant
		f.normal = f.plant_normal
		f.swinging = false


## The body was lifted onto a step; keep the hips visually where they were and ease up.
func stepped_up(dy: float) -> void:
	_step_offset -= dy


## Called on touchdown after a jump, fall or climb: each foot takes a quick step down to
## the ground and the hips absorb the impact.
func land(impact := 0.0) -> void:
	mode = Mode.GROUND
	_hips_smooth -= clampf(impact * 0.03, 0.0, 0.2)
	for f in feet:
		var target := _rest_point(f)
		var hit := _foothold(target)
		f.start = f.pos
		f.end = hit.position if hit else target
		f.end_normal = hit.normal if hit else Vector3.UP
		f.plant_normal = f.normal
		f.swinging = true
		f.phase_driven = false
		f.t = 0.0
		f.duration = 0.12
		f.lead = 0.0
		f.lift = 0.02
		f.clearance = 0.0


func update_ground(velocity: Vector3, accel: float, turn_rate: float, delta: float) -> void:
	mode = Mode.GROUND
	_time += delta
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	_speed = hv.length()
	var moving := _speed > 0.15
	var move := clampf(_speed / GAIT_SPEEDS[0], 0.0, 1.0)
	var step_len := _gait(STEP_LENGTH)
	var swing_frac := _gait(SWING_FRACTION)
	var cycle := 2.0 * step_len / maxf(_speed, 0.05)

	if moving:
		_phase = fmod(_phase + delta / cycle, 1.0)

	# While moving, the gait phase alone decides where each foot is in its step, so a foot
	# can never fall behind the rhythm: it lifts when its window opens and lands when it
	# closes, whatever the other foot is doing (running has both feet in the air at once).
	var swing_time := swing_frac * cycle
	var stance_half := cycle * (1.0 - swing_frac) * 0.5
	for i in feet.size():
		var f := feet[i]
		var other := feet[1 - i]
		var window := _swing_window(f, swing_frac)
		if moving and window >= 0.0:
			if not f.swinging or not f.phase_driven:
				_begin_swing(f, hv, swing_time, stance_half, _gait(FOOT_LIFT))
				f.phase_driven = true
			f.t = maxf(f.t, window)
			f.duration = swing_time
			f.lead = stance_half
			_update_swing(f, hv)
		elif f.swinging and f.phase_driven:
			# Window closed (or we stopped) before the foot landed: finish quickly, no snapping.
			f.phase_driven = false
			f.duration = minf(f.duration, 0.1 / maxf(1.0 - f.t, 0.05))
			f.lead = 0.0
		if f.swinging and not f.phase_driven:
			f.t = minf(f.t + delta / f.duration, 1.0)
			_update_swing(f, hv)
		elif not f.swinging:
			var err := _flat(f.plant - _rest_point(f)).length()
			if err > MAX_FOOT_REACH:
				# Emergency step: the foot is out of the leg's reach (sharp turn, shove, slide).
				_begin_swing(f, hv, 0.15, 0.0, 0.08)
			elif not moving and not other.swinging and err > 0.2:
				# Settling step after stopping or turning on the spot.
				_begin_swing(f, hv, 0.26, 0.0, 0.07)
		if not f.swinging:
			f.pos = f.plant
			f.normal = f.plant_normal
			f.pitch = 0.0

	# Hips drop so the lower foothold can be reached (stepping down, slopes, uneven stones).
	var low := 0.0
	for f in feet:
		var y := (f.end.y if f.swinging else f.plant.y) - global_position.y
		low = minf(low, y)
	var crouch: float = lerpf(CROUCH[0] * 0.7, _gait(CROUCH), move)
	_hips_smooth = lerpf(_hips_smooth, clampf(low, -0.55, 0.0) + crouch, 1.0 - exp(-12.0 * delta))
	_step_offset = lerpf(_step_offset, 0.0, 1.0 - exp(-10.0 * delta))
	# Lowest just after each foot lands.
	var bob := (cos(TAU * 2.0 * (_phase - swing_frac)) + 1.0) * 0.5 * _gait(BOB) * move
	hips_offset = _hips_smooth + _step_offset - bob

	_accel_lean = lerpf(_accel_lean, clampf(accel * 0.03, -0.2, 0.2), 1.0 - exp(-6.0 * delta))
	lean = lerpf(lean, lerpf(0.08, _gait(LEAN), move) + _accel_lean, 1.0 - exp(-8.0 * delta))
	bank = lerpf(bank, clampf(turn_rate * _speed * 0.02, -0.25, 0.25), 1.0 - exp(-6.0 * delta))
	# Arms swing opposite the legs: phase 0 is the left foot passing under the body.
	arm_phase = TAU * (_phase - swing_frac * 0.5)
	twist = sin(arm_phase) * 0.12 * move
	arm_swing = _gait(ARM_SWING) * move
	elbow_bend = lerpf(elbow_bend, lerpf(0.3, _gait(ELBOW_BEND), move), 1.0 - exp(-8.0 * delta))
	arm_lower = lerpf(arm_lower, 0.55, 1.0 - exp(-6.0 * delta))
	tail_lift = lerpf(tail_lift, 0.25 * clampf((_speed - GAIT_SPEEDS[0]) / 3.0, 0.0, 1.0), 1.0 - exp(-4.0 * delta))
	tail_sway = sin(arm_phase) * 0.12 * move + sin(_time * 1.1) * 0.08 * (1.0 - move)
	head_look = (sin(_time * 0.37) * 0.25 + sin(_time * 0.13 + 1.0) * 0.15) * (1.0 - move)
	hand_weight = move_toward(hand_weight, 0.0, delta * 6.0)


func update_air(velocity: Vector3, delta: float) -> void:
	if mode != Mode.AIR:
		mode = Mode.AIR
		for f in feet:
			f.air_local = f.pos - global_position
			f.swinging = false
	_time += delta
	# Tuck the legs, one slightly forward; reach down when falling fast.
	var falling := clampf(-velocity.y / 6.0, 0.0, 1.0)
	for f in feet:
		var tuck := right() * f.lateral * 0.17 + forward() * (0.15 if f.lateral < 0.0 else -0.05) \
				+ Vector3.UP * lerpf(0.4, 0.15, falling)
		f.air_local = f.air_local.lerp(tuck, 1.0 - exp(-10.0 * delta))
		f.pos = global_position + f.air_local
		f.normal = Vector3.UP
		f.pitch = lerpf(f.pitch, 0.3, 1.0 - exp(-8.0 * delta))
	hips_offset = lerpf(hips_offset, -0.05, 1.0 - exp(-8.0 * delta))
	lean = lerpf(lean, 0.12, 1.0 - exp(-6.0 * delta))
	arm_lower = lerpf(arm_lower, 0.2, 1.0 - exp(-6.0 * delta))
	elbow_bend = lerpf(elbow_bend, 0.7, 1.0 - exp(-6.0 * delta))
	arm_swing = lerpf(arm_swing, 0.0, 1.0 - exp(-6.0 * delta))
	tail_lift = lerpf(tail_lift, 0.35, 1.0 - exp(-4.0 * delta))
	hand_weight = move_toward(hand_weight, 0.0, delta * 6.0)


## Hanging or climbing: the controller supplies every limb target.
func update_reach(new_mode: Mode, hands: Array[Vector3], weight: float, foot_targets: Array[Vector3],
		foot_normals: Array[Vector3], body_lean: float, pole: Vector3, delta: float) -> void:
	mode = new_mode
	_time += delta
	hand_targets = hands
	hand_weight = weight
	reach_pole = pole
	for i in feet.size():
		var f := feet[i]
		f.swinging = false
		f.pos = foot_targets[i]
		f.normal = foot_normals[i]
		f.pitch = lerpf(f.pitch, 0.0, 1.0 - exp(-8.0 * delta))
	hips_offset = lerpf(hips_offset, 0.0, 1.0 - exp(-10.0 * delta))
	lean = lerpf(lean, body_lean, 1.0 - exp(-10.0 * delta))
	twist = 0.0
	bank = 0.0
	arm_swing = 0.0
	head_look = 0.0
	tail_lift = lerpf(tail_lift, -0.2, 1.0 - exp(-4.0 * delta))
	tail_sway = sin(_time * 1.3) * 0.06


## Starts a step from wherever the foot is now. Timed steps (landing, settling, emergency)
## advance on their own clock; gait steps are then switched to follow the phase.
func _begin_swing(f: Foot, hv: Vector3, duration: float, lead: float, lift: float) -> void:
	f.swinging = true
	f.phase_driven = false
	f.t = 0.0
	f.duration = duration
	f.lead = lead
	f.lift = lift
	f.start = f.pos
	f.plant_normal = f.normal
	_retarget(f, hv)


## Progress (0..1) through this foot's swing window in the gait cycle, or -1 outside it.
func _swing_window(f: Foot, swing_frac: float) -> float:
	var local := fmod(_phase - f.phase_offset + 1.0, 1.0)
	return local / swing_frac if local < swing_frac else -1.0


func _update_swing(f: Foot, hv: Vector3) -> void:
	if f.t < 0.6:
		_retarget(f, hv)  # keep steering toward where the body is heading
	var e := smoothstep(0.0, 1.0, f.t)
	f.pos = f.start.lerp(f.end, e) + Vector3.UP * (sin(f.t * PI) * (f.lift + f.clearance))
	f.normal = f.plant_normal.slerp(f.end_normal, e)
	# Heel lifts as the foot leaves the ground, toes come up before it lands.
	f.pitch = sin(f.t * PI) * lerpf(0.6, -0.25, f.t) * clampf(f.lift * 5.0, 0.3, 1.0)
	if f.t >= 1.0:
		f.swinging = false
		f.phase_driven = false
		f.plant = f.end
		f.plant_normal = f.end_normal


## Finds where the swinging foot should land: under its rest position, ahead by the
## velocity over the remaining flight plus half a stance. Footholds too high are rejected
## (that's a wall, not a step) by shortening the prediction.
func _retarget(f: Foot, hv: Vector3) -> void:
	var remaining := f.duration * (1.0 - f.t) + f.lead
	var found := false
	for factor: float in [1.0, 0.5, 0.0]:
		var hit := _foothold(_rest_point(f) + hv * remaining * factor)
		if not hit.is_empty():
			f.end = hit.position
			f.end_normal = hit.normal
			found = true
			break
	if not found:
		f.end = _rest_point(f)
		f.end_normal = Vector3.UP
	f.clearance = _clearance(f.start, f.end)


## Highest bump between two footholds, so the swing arc clears stones in the way.
func _clearance(a: Vector3, b: Vector3) -> float:
	var highest := 0.0
	for i in range(1, 6):
		var t := i / 6.0
		var p := a.lerp(b, t)
		var hit := _ground(p, 0.7, 0.3)
		if hit:
			highest = maxf(highest, hit.position.y - p.y)
	return minf(highest + 0.05, 0.6) if highest > 0.0 else 0.0


## Ground near `p` that a foot can stand on: not too high above the body and not too steep.
## Steep faces (the sides of rocks) are skipped in favour of a flatter spot a few
## centimetres away; failing that, the lowest spot found is used with the foot kept level.
func _foothold(p: Vector3) -> Dictionary:
	var min_up := cos(deg_to_rad(max_foothold_angle_deg))
	var lowest := {}
	for offset: Vector3 in [Vector3.ZERO, forward() * 0.15, -forward() * 0.15, right() * 0.1, -right() * 0.1]:
		var hit := _ground(p + offset)
		if hit.is_empty() or hit.position.y - global_position.y > MAX_FOOT_RISE:
			continue
		if hit.normal.y >= min_up:
			return hit
		if lowest.is_empty() or hit.position.y < lowest.position.y:
			lowest = hit
	if not lowest.is_empty():
		lowest.normal = Vector3.UP
	return lowest


## The up direction a foot is aligned to, tilted toward the ground normal by at most
## max_foot_tilt_deg. Feet braced on a wall while hanging or climbing keep the wall normal.
func foot_up(f: Foot) -> Vector3:
	if mode == Mode.HANG or mode == Mode.CLIMB:
		return f.normal
	var angle := Vector3.UP.angle_to(f.normal)
	var limit := deg_to_rad(max_foot_tilt_deg)
	return f.normal if angle <= limit else Vector3.UP.slerp(f.normal, limit / angle)


func _rest_point(f: Foot) -> Vector3:
	return global_position + right() * f.lateral * STANCE_HALF_WIDTH


func _ground(p: Vector3, above := GROUND_PROBE_UP, below := 1.5) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * above, p - Vector3.UP * below)
	q.exclude = _exclude
	return get_world_3d().direct_space_state.intersect_ray(q)


func _gait(table: Array) -> float:
	if _speed <= GAIT_SPEEDS[0]:
		return table[0]
	if _speed <= GAIT_SPEEDS[1]:
		return lerpf(table[0], table[1], (_speed - GAIT_SPEEDS[0]) / (GAIT_SPEEDS[1] - GAIT_SPEEDS[0]))
	return lerpf(table[1], table[2], clampf((_speed - GAIT_SPEEDS[1]) / (GAIT_SPEEDS[2] - GAIT_SPEEDS[1]), 0.0, 1.0))



static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
