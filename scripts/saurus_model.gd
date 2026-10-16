class_name SaurusModel
extends Node3D
## Placeholder Saurus warrior built from primitive meshes, with procedural locomotion.
## Based on the Seraphon Saurus references: upright and humanoid, broad chest, pale
## front from throat to groin, crested head with open jaws, short spined tail, bronze trim.
## Faces -Z, feet at y = 0. When a real rigged model replaces it, keep update_motion()
## as the interface the player controller talks to.

const HIDE_COLOR := Color(0.13, 0.36, 0.42)
const HIDE_TINT := Color(0.10, 0.30, 0.30, 0.6)  # greener patches through the blue
const SPINE_COLOR := Color(0.09, 0.24, 0.29)
const BELLY_COLOR := Color(0.66, 0.76, 0.69)
const MOUTH_COLOR := Color(0.62, 0.28, 0.32)
const CLAW_COLOR := Color(0.84, 0.78, 0.60)
const BRONZE_COLOR := Color(0.60, 0.43, 0.21)
const EYE_COLOR := Color(0.90, 0.55, 0.15)
## Chunky texels like the Valheim reference.
const BODY_PIXELS_PER_METER := 32.0

# Gait speeds (m/s) the animation blends between. Match the controller's speeds.
const WALK_SPEED := 2.0
const RUN_SPEED := 4.5
const SPRINT_SPEED := 7.0
# Distance covered per step in each gait; drives cadence so feet keep pace with the ground.
const WALK_STEP := 0.75
const RUN_STEP := 1.15
const SPRINT_STEP := 1.5

# Digitigrade but stocky leg: thigh forward, shin back, short metatarsal.
const THIGH_LEN := 0.45
const SHIN_LEN := 0.42
const META_LEN := 0.22
const THIGH_REST := 0.35
const SHIN_REST := -0.85
const META_REST := 0.6
const HIP_HEIGHT := 1.13
const TORSO_REST := -0.12
const NECK_REST := -0.25
const HEAD_REST := 0.37
const JAW_REST := -0.2
const ARM_REST := 0.2
const ELBOW_REST := 0.4

var _mat_hide: StandardMaterial3D
var _mat_spine: StandardMaterial3D
var _mat_belly: StandardMaterial3D
var _mat_mouth: StandardMaterial3D
var _mat_claw: StandardMaterial3D
var _mat_bronze: StandardMaterial3D
var _mat_eye: StandardMaterial3D

var _hips: Node3D
var _torso: Node3D
var _neck: Node3D
var _head: Node3D
var _jaw: Node3D
var _legs: Array[Dictionary] = []
var _arms: Array[Dictionary] = []
var _tail: Array[Node3D] = []
var _tail_rest: Array[float] = []

var _phase := 0.0
var _time := 0.0
var _speed := 0.0
var _accel_lean := 0.0
var _bank := 0.0


func _ready() -> void:
	_make_materials()
	_build()


## Called every physics frame by the controller.
## speed: horizontal m/s. accel: change in speed (m/s^2). turn_rate: facing change (rad/s).
func update_motion(speed: float, accel: float, turn_rate: float, delta: float) -> void:
	_time += delta
	_speed = lerpf(_speed, speed, 1.0 - exp(-10.0 * delta))
	_accel_lean = lerpf(_accel_lean, clampf(accel * 0.035, -0.25, 0.25), 1.0 - exp(-6.0 * delta))
	_bank = lerpf(_bank, clampf(turn_rate * _speed * 0.025, -0.3, 0.3), 1.0 - exp(-6.0 * delta))

	var move := clampf(_speed / WALK_SPEED, 0.0, 1.0)
	var run_t := clampf((_speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0.0, 1.0)
	var sprint_t := clampf((_speed - RUN_SPEED) / (SPRINT_SPEED - RUN_SPEED), 0.0, 1.0)
	var idle := 1.0 - move
	var gait := func(walk_v: float, run_v: float, sprint_v: float) -> float:
		return lerpf(lerpf(walk_v, run_v, run_t), sprint_v, sprint_t)

	# One full cycle is two steps.
	var step_len: float = gait.call(WALK_STEP, RUN_STEP, SPRINT_STEP)
	_phase = fmod(_phase + _speed * delta / step_len * PI, TAU)
	var s := sin(_phase)

	var swing_amp: float = gait.call(0.35, 0.55, 0.7) * move
	var knee_lift: float = gait.call(0.5, 1.0, 1.3) * move
	var lean: float = gait.call(0.05, 0.18, 0.35) * move
	var arm_amp: float = gait.call(0.35, 0.55, 0.6) * move
	var elbow_bend: float = gait.call(0.15, 0.8, 0.95) * move
	var bob: float = gait.call(0.03, 0.06, 0.08) * move
	var twist: float = gait.call(0.08, 0.12, 0.1) * move

	var breathe := sin(_time * 1.6)
	var look := sin(_time * 0.37) * 0.25 + sin(_time * 0.13 + 1.0) * 0.15  # idle glances around

	# Hips: bob twice per cycle (lowest when the legs are spread), bank into turns,
	# and a slow weight shift when standing.
	_hips.position.y = HIP_HEIGHT + bob * cos(_phase * 2.0) * 0.5 - 0.02 * run_t
	_hips.position.x = sin(_time * 0.5) * 0.02 * idle
	_hips.rotation.y = s * twist * 0.5
	_hips.rotation.z = _bank + sin(_time * 0.5) * 0.02 * idle + s * 0.03 * move

	_torso.rotation.x = TORSO_REST - lean - _accel_lean + breathe * 0.02 * (0.5 + idle)
	_torso.rotation.y = -s * twist * 1.5
	_torso.rotation.z = -_bank * 0.4
	# Head stays level and steady while the body moves under it.
	_head.rotation.x = HEAD_REST + lean + _accel_lean - 0.1 * sprint_t
	_head.rotation.y = s * twist + look * idle
	_jaw.rotation.x = JAW_REST - breathe * 0.03 - 0.15 * sprint_t

	for leg in _legs:
		var ph: float = _phase + (PI if leg.side > 0 else 0.0)
		var lift := maxf(0.0, cos(ph)) * knee_lift  # bend the knee while the leg swings forward
		var thigh: Node3D = leg.thigh
		var shin: Node3D = leg.shin
		var meta: Node3D = leg.meta
		var foot: Node3D = leg.foot
		thigh.rotation.x = THIGH_REST + sin(ph) * swing_amp + lift * 0.3
		shin.rotation.x = SHIN_REST - lift
		meta.rotation.x = META_REST + lift * 0.5
		foot.rotation.x = -(thigh.rotation.x + shin.rotation.x + meta.rotation.x)

	for arm in _arms:
		var ph: float = _phase + (0.0 if arm.side > 0 else PI)  # opposite to the leg on the same side
		var shoulder: Node3D = arm.shoulder
		var elbow: Node3D = arm.elbow
		shoulder.rotation.x = ARM_REST + lean + _accel_lean + sin(ph) * arm_amp + breathe * 0.02 * idle
		elbow.rotation.x = ELBOW_REST + elbow_bend + maxf(0.0, sin(ph)) * 0.2 * move

	# Tail: lifts to counterbalance when running, sways in a wave that lags the hips.
	for i in _tail.size():
		var seg := _tail[i]
		var lift_tail := -0.22 * run_t if i == 0 else 0.0
		seg.rotation.x = _tail_rest[i] + lift_tail + sin(_phase * 2.0 - i * 0.5) * 0.03 * move
		seg.rotation.y = sin(_phase - i * 0.6) * (0.06 + 0.03 * i) * move \
				+ sin(_time * 1.1 - i * 0.5) * 0.05 * idle - _bank * 0.3


func _make_materials() -> void:
	var ppm := BODY_PIXELS_PER_METER
	_mat_hide = PixelTex.material(PixelTex.make("saurus_hide", HIDE_COLOR, "plates", 32, 0.1, 7, HIDE_TINT), ppm, false)
	_mat_spine = PixelTex.material(PixelTex.make("saurus_spine", SPINE_COLOR, "noise", 16, 0.1, 9), ppm, false)
	_mat_belly = PixelTex.material(PixelTex.make("saurus_belly", BELLY_COLOR, "bands", 32, 0.06, 8), ppm, false)
	_mat_mouth = PixelTex.material(PixelTex.make("saurus_mouth", MOUTH_COLOR, "noise", 16, 0.1, 12), ppm, false)
	_mat_claw = PixelTex.material(PixelTex.make("saurus_claw", CLAW_COLOR, "noise", 16, 0.06, 10), ppm, false)
	_mat_bronze = PixelTex.material(PixelTex.make("bronze", BRONZE_COLOR, "noise", 16, 0.15, 13), ppm, false)
	_mat_bronze.metallic = 0.6
	_mat_bronze.roughness = 0.5
	_mat_eye = StandardMaterial3D.new()
	_mat_eye.albedo_color = EYE_COLOR
	_mat_eye.roughness = 0.3


func _build() -> void:
	_hips = _pivot(self, Vector3(0, HIP_HEIGHT, 0))
	_part(_hips, _sphere(0.25), _mat_hide, Vector3(0, 0, 0.02), Basis.IDENTITY, Vector3(1.35, 0.85, 1.1))
	# Belt with bronze side plates hanging over the thighs.
	_part(_hips, _taper(0.3, 0.31, 0.08), _mat_bronze, Vector3(0, 0.1, 0), Basis.IDENTITY, Vector3(1.15, 1.0, 1.0))
	for side in [-1, 1]:
		_part(_hips, _box(Vector3(0.18, 0.24, 0.03)), _mat_bronze, Vector3(side * 0.3, -0.06, -0.04),
				Basis.from_euler(Vector3(0, side * 0.5, side * 0.22)))

	_torso = _pivot(_hips, Vector3(0, 0.08, 0), Vector3(TORSO_REST, 0, 0))
	_part(_torso, _capsule(0.24, 0.55), _mat_hide, Vector3(0, 0.2, 0), Basis.IDENTITY, Vector3(1.3, 1.0, 1.0))
	_part(_torso, _sphere(0.32), _mat_hide, Vector3(0, 0.52, 0.02), Basis.IDENTITY, Vector3(1.35, 0.95, 1.0))
	# Pale front from throat to groin, with pecs.
	_part(_torso, _sphere(0.25), _mat_belly, Vector3(0, 0.36, -0.15), Basis.IDENTITY, Vector3(1.15, 1.8, 0.55))
	for side in [-1, 1]:
		_part(_torso, _sphere(0.14), _mat_belly, Vector3(side * 0.13, 0.57, -0.2), Basis.IDENTITY, Vector3(1.2, 0.9, 0.6))
	# Spines down the back.
	for i in 5:
		_spike(_torso, Vector3(0, 0.12 + i * 0.15, 0.28 - absf(i - 2.5) * 0.02), Vector3(0, 0.5, 1), 0.12 + i * 0.01, 0.035, _mat_spine)

	_build_head()
	for side in [-1, 1]:
		_build_arm(side)
		_build_leg(side)
	_build_tail()


func _build_head() -> void:
	_neck = _pivot(_torso, Vector3(0, 0.72, -0.04), Vector3(NECK_REST, 0, 0))
	_part(_neck, _taper(0.14, 0.19, 0.22), _mat_hide, Vector3(0, 0.1, 0), Basis.IDENTITY, Vector3(1.05, 1.0, 1.1))
	_part(_neck, _sphere(0.12), _mat_belly, Vector3(0, 0.06, -0.09), Basis.IDENTITY, Vector3(1.0, 1.4, 0.7))

	_head = _pivot(_neck, Vector3(0, 0.18, -0.05), Vector3(HEAD_REST, 0, 0))
	var fwd := Basis.from_euler(Vector3(-PI / 2, 0, 0))  # cylinder axis -> forward (-Z)
	_part(_head, _sphere(0.15), _mat_hide, Vector3(0, 0.06, -0.02), Basis.IDENTITY, Vector3(1.05, 0.9, 1.15))
	_part(_head, _sphere(0.14), _mat_hide, Vector3(0, 0.12, 0.06), Basis.IDENTITY, Vector3(1.1, 0.7, 1.2))  # crown bulk
	# Short, deep snout.
	_part(_head, _taper(0.085, 0.125, 0.21), _mat_hide, Vector3(0, 0.03, -0.18), fwd, Vector3(1.15, 1.0, 1.0))
	_part(_head, _sphere(0.07), _mat_hide, Vector3(0, 0.04, -0.28), Basis.IDENTITY, Vector3(1.2, 0.9, 1.0))
	_part(_head, _box(Vector3(0.15, 0.03, 0.22)), _mat_mouth, Vector3(0, -0.03, -0.18))
	for side in [-1, 1]:
		_part(_head, _sphere(0.028), _mat_eye, Vector3(side * 0.11, 0.09, -0.1))
		_part(_head, _box(Vector3(0.08, 0.04, 0.14)), _mat_hide, Vector3(side * 0.09, 0.13, -0.1), Basis.from_euler(Vector3(0.2, 0, side * 0.35)))
		for i in 5:
			_part(_head, _prism(Vector3(0.022, 0.05, 0.022)), _mat_claw,
					Vector3(side * 0.075 * (1.0 - i * 0.08), -0.045, -0.1 - i * 0.05), Basis.from_euler(Vector3(0, 0, PI)))
		# Swept-back horns and cheek spikes.
		_spike(_head, Vector3(side * 0.12, 0.12, 0.08), Vector3(side * 0.5, 0.35, 1.0), 0.22, 0.04, _mat_bronze)
		_spike(_head, Vector3(side * 0.13, -0.02, 0.02), Vector3(side * 1.0, -0.1, 0.5), 0.1, 0.03, _mat_hide)
	# Crown of crest spines rising back.
	var crest := [[Vector3(0, 0.17, -0.04), 0.2], [Vector3(0, 0.19, 0.05), 0.26], [Vector3(0, 0.17, 0.14), 0.2]]
	for c in crest:
		_spike(_head, c[0], Vector3(0, 1.0, 0.6), c[1], 0.045, _mat_spine)
	for side in [-1, 1]:
		_spike(_head, Vector3(side * 0.07, 0.16, 0.02), Vector3(side * 0.35, 1.0, 0.7), 0.15, 0.035, _mat_spine)

	_jaw = _pivot(_head, Vector3(0, -0.04, -0.02), Vector3(JAW_REST, 0, 0))
	_part(_jaw, _taper(0.06, 0.1, 0.26), _mat_belly, Vector3(0, -0.04, -0.16), fwd, Vector3(1.1, 1.0, 0.55))
	_part(_jaw, _capsule(0.035, 0.2), _mat_mouth, Vector3(0, -0.01, -0.14), fwd, Vector3(1.4, 1.0, 0.6))  # tongue
	for side in [-1, 1]:
		for i in 4:
			_part(_jaw, _prism(Vector3(0.02, 0.04, 0.02)), _mat_claw, Vector3(side * 0.06 * (1.0 - i * 0.1), 0.0, -0.12 - i * 0.05))


func _build_arm(side: int) -> void:
	var shoulder := _pivot(_torso, Vector3(side * 0.43, 0.62, 0), Vector3(ARM_REST, 0, side * 0.2))
	_part(shoulder, _sphere(0.145), _mat_hide, Vector3.ZERO, Basis.IDENTITY, Vector3(1.1, 1.0, 1.0))
	_part(shoulder, _capsule(0.1, 0.4), _mat_hide, Vector3(0, -0.17, 0), Basis.IDENTITY, Vector3(1.0, 1.0, 1.1))
	var elbow := _pivot(shoulder, Vector3(0, -0.34, 0), Vector3(ELBOW_REST, 0, 0))
	_part(elbow, _taper(0.1, 0.075, 0.34), _mat_hide, Vector3(0, -0.16, 0))
	_part(elbow, _taper(0.088, 0.085, 0.1), _mat_bronze, Vector3(0, -0.24, 0))  # bracer
	var hand := _pivot(elbow, Vector3(0, -0.33, 0))
	_part(hand, _sphere(0.065), _mat_hide, Vector3(0, -0.05, 0), Basis.IDENTITY, Vector3(1.0, 1.0, 0.8))
	for f in 3:
		var finger := _pivot(hand, Vector3((f - 1) * 0.035, -0.09, -0.01), Vector3(0.35, 0, 0))
		_part(finger, _capsule(0.022, 0.1), _mat_hide, Vector3(0, -0.04, 0))
		_spike(finger, Vector3(0, -0.085, 0), Vector3(0, -1, -0.3), 0.06, 0.018, _mat_claw)
	var thumb := _pivot(hand, Vector3(-side * 0.05, -0.05, -0.04), Vector3(0.8, 0, -side * 0.4))
	_part(thumb, _capsule(0.022, 0.08), _mat_hide, Vector3(0, -0.03, 0))
	_spike(thumb, Vector3(0, -0.07, 0), Vector3(0, -1, -0.2), 0.05, 0.016, _mat_claw)
	_arms.append({"shoulder": shoulder, "elbow": elbow, "side": side})


func _build_leg(side: int) -> void:
	var thigh := _pivot(_hips, Vector3(side * 0.22, -0.05, 0), Vector3(THIGH_REST, 0, 0))
	_part(thigh, _capsule(0.16, 0.55), _mat_hide, Vector3(0, -0.2, 0), Basis.IDENTITY, Vector3(1.0, 1.0, 1.2))
	var shin := _pivot(thigh, Vector3(0, -THIGH_LEN, 0), Vector3(SHIN_REST, 0, 0))
	_part(shin, _taper(0.11, 0.08, 0.44), _mat_hide, Vector3(0, -0.2, 0))
	_part(shin, _box(Vector3(0.14, 0.1, 0.05)), _mat_bronze, Vector3(0, -0.02, -0.1))  # knee guard
	var meta := _pivot(shin, Vector3(0, -SHIN_LEN, 0), Vector3(META_REST, 0, 0))
	_part(meta, _capsule(0.075, 0.28), _mat_hide, Vector3(0, -0.1, 0))
	_part(meta, _taper(0.085, 0.085, 0.06), _mat_bronze, Vector3(0, -0.03, 0))  # ankle band
	var foot := _pivot(meta, Vector3(0, -META_LEN, 0), Vector3(-(THIGH_REST + SHIN_REST + META_REST), 0, 0))
	_part(foot, _box(Vector3(0.16, 0.07, 0.16)), _mat_hide, Vector3(0, -0.035, -0.04))
	var fwd := Basis.from_euler(Vector3(-PI / 2, 0, 0))
	for t in 3:
		var x := (t - 1) * 0.055
		_part(foot, _capsule(0.03, 0.16), _mat_hide, Vector3(x, -0.04, -0.15), fwd)
		_spike(foot, Vector3(x, -0.04, -0.22), Vector3(0, -0.3, -1), 0.07, 0.022, _mat_claw)
	_spike(foot, Vector3(0, -0.03, 0.04), Vector3(0, -0.3, 1), 0.06, 0.02, _mat_claw)  # dewclaw
	_legs.append({"thigh": thigh, "shin": shin, "meta": meta, "foot": foot, "side": side})


func _build_tail() -> void:
	var parent := _hips
	var pos := Vector3(0, -0.02, 0.22)
	var radius := 0.2
	var seg_len := 0.25
	var back := Basis.from_euler(Vector3(PI / 2, 0, 0))  # cylinder axis -> backward (+Z)
	for i in 5:
		var rest := 0.4 if i == 0 else -0.03
		var seg := _pivot(parent, pos, Vector3(rest, 0, 0))
		var r_end := radius * 0.7
		_part(seg, _taper(r_end, radius, seg_len + 0.04), _mat_hide, Vector3(0, 0, seg_len * 0.5), back)
		_spike(seg, Vector3(0, radius * 0.8, seg_len * 0.4), Vector3(0, 0.6, 1), 0.11 - i * 0.015, 0.03, _mat_spine)
		_tail.append(seg)
		_tail_rest.append(rest)
		parent = seg
		pos = Vector3(0, 0, seg_len)
		radius = r_end


## A cone pointing along `dir`, its base at `pos`.
func _spike(parent: Node3D, pos: Vector3, dir: Vector3, length: float, radius: float, mat: Material) -> void:
	var d := dir.normalized()
	_part(parent, _taper(0.0, radius, length), mat, pos + d * length * 0.5, Basis(Quaternion(Vector3.UP, d)))


func _pivot(parent: Node3D, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	return node


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, basis := Basis.IDENTITY, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis * Basis.from_scale(scl), pos)
	parent.add_child(mi)
	return mi


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 4
	return m


func _taper(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top_radius
	m.bottom_radius = bottom_radius
	m.height = height
	m.radial_segments = 10
	m.rings = 1
	return m


func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	return m
