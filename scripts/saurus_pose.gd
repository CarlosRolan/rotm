class_name SaurusPose
extends SkeletonModifier3D
## Applies SaurusRig's procedural pose to the Mixamo skeleton every frame: hips offset,
## spine lean and twist, two-bone IK for the legs (and arms when reaching for a ledge),
## foot alignment to the ground, arm swing, head and tail.
##
## Works in skeleton space, where the model faces +Z, up is +Y and its left is +X.
## World-space targets from the rig are converted with the skeleton's global transform.

const HIPS := "mixamorig_Hips"
const SPINE := ["mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2"]
const NECK := "mixamorig_Neck"
const HEAD := "mixamorig_Head"
const LEGS := [["mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot"],
		["mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot"]]
const ARMS := [["mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand"],
		["mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand"]]
const TAIL := ["Bone_025", "Bone_024", "Bone_023", "Bone_022", "Bone_021", "Bone_020",
		"Bone_019", "Bone_018", "Bone_017", "Bone_016", "Bone_015"]
const TOES := ["mixamorig_LeftToeBase", "mixamorig_RightToeBase"]
const SIDE := [1.0, -1.0]  ## left limbs sit on +X in skeleton space
## How far below horizontal the upper arm hangs in the test dummy's A-pose rest. `arm_lower`
## is tuned against it; models resting in a T-pose are lowered by the difference.
const A_POSE_ARM_DROP := 0.84

var rig: SaurusRig

var _hips := -1
var _neck := -1
var _head := -1
var _spine: Array[int] = []
var _tail: Array[int] = []
var _legs: Array[PackedInt32Array] = []
var _arms: Array[PackedInt32Array] = []
var _foot_rest: Array[Basis] = []
var _arm_rest_fix := 0.0
var _clip_tracks: Array[Vector3i] = []  ## (track, bone, track type) for the rig's run clip


func _ready() -> void:
	var sk := get_skeleton()
	_hips = sk.find_bone(HIPS)
	_neck = sk.find_bone(NECK)
	_head = sk.find_bone(HEAD)
	for n in SPINE:
		_spine.append(sk.find_bone(n))
	for n in TAIL:  # not every model has a tail
		if sk.find_bone(n) >= 0:
			_tail.append(sk.find_bone(n))
	for chain in LEGS:
		_legs.append(PackedInt32Array(chain.map(func(n: String) -> int: return sk.find_bone(n))))
		_foot_rest.append(sk.get_bone_global_rest(_legs[-1][2]).basis)
	for chain in ARMS:
		_arms.append(PackedInt32Array(chain.map(func(n: String) -> int: return sk.find_bone(n))))
	var shoulder := sk.get_bone_global_rest(_arms[0][0]).origin
	var elbow := sk.get_bone_global_rest(_arms[0][1]).origin
	_arm_rest_fix = A_POSE_ARM_DROP - atan2(shoulder.y - elbow.y, absf(elbow.x - shoulder.x))
	if rig.run_clip:
		_prepare_clip(sk)


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or rig == null or rig.feet.is_empty():
		return
	var to_skel := sk.global_transform.affine_inverse()
	var dir_to_skel := to_skel.basis

	# The run clip, feet corrected onto the ground. Blended over the procedural pose below.
	var weight := rig.clip_weight if not _clip_tracks.is_empty() else 0.0
	var clip_pose: Array[Transform3D] = []
	if weight > 0.0:
		_apply_clip(sk, dir_to_skel)
		if weight >= 1.0:
			return
		for b in sk.get_bone_count():
			clip_pose.append(sk.get_bone_pose(b))

	sk.reset_bone_poses()
	_apply_procedural(sk, to_skel, dir_to_skel)
	if weight > 0.0:
		for b in sk.get_bone_count():
			sk.set_bone_pose(b, sk.get_bone_pose(b).interpolate_with(clip_pose[b], weight))


func _apply_procedural(sk: Skeleton3D, to_skel: Transform3D, dir_to_skel: Basis) -> void:
	# Hips: height, pelvis yaw against the shoulders, roll into turns.
	var hips := sk.get_bone_global_pose(_hips)
	var offset := dir_to_skel * Vector3(0.0, rig.hips_offset, 0.0)
	var hips_rot := Basis(Vector3.BACK, -rig.bank) * Basis(Vector3.UP, -rig.twist * 0.5)
	sk.set_bone_global_pose(_hips, Transform3D(hips_rot * hips.basis, hips.origin + offset))

	# Spine: lean forward and twist the shoulders, spread over three bones.
	for b in _spine:
		_rotate(sk, b, Basis(Vector3.UP, rig.twist * 0.5) * Basis(Vector3.RIGHT, rig.lean / 3.0))
	# Head stays level and looks around a little.
	_rotate(sk, _neck, Basis(Vector3.RIGHT, -rig.lean * 0.4))
	_rotate(sk, _head, Basis(Vector3.UP, rig.head_look - rig.twist * 0.5) * Basis(Vector3.RIGHT, -rig.lean * 0.5))

	for i in 2:
		var arm := _arms[i]
		var side: float = SIDE[i]
		if rig.hand_weight > 0.5:
			var pole := (dir_to_skel * (rig.reach_pole + rig.right() * -side * 0.8)).normalized()
			_solve_two_bone(sk, arm[0], arm[1], arm[2], to_skel * rig.hand_targets[i], pole)
		else:
			# Lower the arms from the A-pose, then swing them opposite the legs.
			var swing := sin(rig.arm_phase) * rig.arm_swing * side
			_rotate(sk, arm[0], Basis(Vector3.RIGHT, swing) * Basis(Vector3.BACK, -side * (rig.arm_lower + _arm_rest_fix)))
			_rotate(sk, arm[1], Basis(Vector3.RIGHT, -rig.elbow_bend))

	for i in 2:
		var leg := _legs[i]
		var f: SaurusRig.Foot = rig.feet[i]
		var up := rig.foot_up(f)
		var ankle := to_skel * (f.pos + up * rig.ankle_height)
		var pole := (dir_to_skel * (rig.forward() + rig.right() * f.lateral * 0.15)).normalized()
		_solve_two_bone(sk, leg[0], leg[1], leg[2], ankle, pole)
		# Foot flat on the ground it stands on, plus heel/toe roll while stepping.
		var n := (dir_to_skel * up).normalized()
		var foot := sk.get_bone_global_pose(leg[2])
		var basis := Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.RIGHT, f.pitch) * _foot_rest[i]
		sk.set_bone_global_pose(leg[2], Transform3D(basis, foot.origin))

	for i in _tail.size():
		var falloff := 1.0 - float(i) / _tail.size()
		_rotate(sk, _tail[i], Basis(Vector3.UP, rig.tail_sway * 0.25 * (1.0 + i * 0.1))
				* Basis(Vector3.RIGHT, rig.tail_lift * 0.15 * falloff))


## Poses the skeleton from the run clip at the rig's clip phase, then moves each foot up or
## down by the ground under it (two-bone IK, knee kept where the clip bends it), tilts it to
## the slope while it is near the ground, and drops the hips so the lower foot can reach.
func _apply_clip(sk: Skeleton3D, dir_to_skel: Basis) -> void:
	sk.reset_bone_poses()
	var time := rig.clip_phase * rig.run_clip.length
	for tr in _clip_tracks:
		if tr.z == Animation.TYPE_POSITION_3D:
			sk.set_bone_pose_position(tr.y, rig.run_clip.position_track_interpolate(tr.x, time))
		else:
			sk.set_bone_pose_rotation(tr.y, rig.run_clip.rotation_track_interpolate(tr.x, time))

	var to_world := sk.global_transform
	var targets: Array[Vector3] = []
	var poles: Array[Vector3] = []
	var feet: Array[Basis] = []
	for i in 2:
		var leg := _legs[i]
		var foot := sk.get_bone_global_pose(leg[2])
		var ankle := to_world * foot.origin
		rig.clip_feet[i] = ankle
		var lift := ankle.y - rig.global_position.y - rig.ankle_height
		var contact := 1.0 - clampf(lift / 0.2, 0.0, 1.0)
		var n := (dir_to_skel * rig.limit_tilt(rig.clip_normals[i])).normalized()
		var tilt := Quaternion.IDENTITY.slerp(Quaternion(Vector3.UP, n), contact)
		targets.append(foot.origin + dir_to_skel * Vector3(0.0, rig.clip_ground[i], 0.0))
		poles.append(sk.get_bone_global_pose(leg[1]).origin - sk.get_bone_global_pose(leg[0]).origin)
		feet.append(Basis(tilt) * foot.basis)

	var hips := sk.get_bone_global_pose(_hips)
	sk.set_bone_global_pose(_hips, Transform3D(Basis(Vector3.BACK, -rig.bank) * hips.basis,
			hips.origin + dir_to_skel * Vector3(0.0, rig.clip_hips, 0.0)))
	for i in 2:
		var leg := _legs[i]
		_solve_two_bone(sk, leg[0], leg[1], leg[2], targets[i], poles[i])
		sk.set_bone_global_pose(leg[2], Transform3D(feet[i], sk.get_bone_global_pose(leg[2]).origin))


## Maps the clip's tracks to bones and measures it: the speed at which a planted foot
## slides back (so the clip can be played without foot sliding at any speed) and the phase
## where the left foot lifts off (to keep it in step with the procedural gait).
func _prepare_clip(sk: Skeleton3D) -> void:
	var clip := rig.run_clip
	for t in clip.get_track_count():
		var bone := sk.find_bone(str(clip.track_get_path(t)).get_slice(":", 1))
		var type := clip.track_get_type(t)
		if bone >= 0 and (type == Animation.TYPE_POSITION_3D or type == Animation.TYPE_ROTATION_3D):
			_clip_tracks.append(Vector3i(t, bone, type))

	const SAMPLES := 64
	var dt := clip.length / SAMPLES
	var speeds: Array[float] = []
	for i in 2:
		var toe := sk.find_bone(TOES[i])
		if toe < 0:
			toe = _legs[i][2]
		var heights: Array[float] = []
		var reach: Array[float] = []  # toe ahead of the hips
		for s in SAMPLES:
			var pose := _clip_global_poses(sk, s * dt)
			heights.append(pose[toe].origin.y)
			reach.append(pose[toe].origin.z - pose[_hips].origin.z)
		var planted: float = heights.min() + 0.03
		for s in SAMPLES:
			var next := (s + 1) % SAMPLES
			if heights[s] <= planted and heights[next] <= planted:
				speeds.append((reach[s] - reach[next]) / dt)
			elif i == 0 and heights[s] <= planted:
				rig.run_clip_offset = float(next) / SAMPLES
	if not speeds.is_empty():
		var total := 0.0
		for v in speeds:
			total += v
		rig.run_clip_speed = maxf(total / speeds.size() * SaurusRig.MODEL_SCALE, 1.0)


## Skeleton-space pose of every bone at `time` in the run clip, without touching the skeleton.
func _clip_global_poses(sk: Skeleton3D, time: float) -> Array[Transform3D]:
	var local: Array[Transform3D] = []
	for b in sk.get_bone_count():
		local.append(sk.get_bone_rest(b))
	for tr in _clip_tracks:
		if tr.z == Animation.TYPE_POSITION_3D:
			local[tr.y].origin = rig.run_clip.position_track_interpolate(tr.x, time)
		else:
			local[tr.y].basis = Basis(rig.run_clip.rotation_track_interpolate(tr.x, time))
	var out: Array[Transform3D] = local.duplicate()
	var stack := Array(sk.get_parentless_bones())
	while not stack.is_empty():
		var b: int = stack.pop_back()
		for child in sk.get_bone_children(b):
			out[child] = out[b] * local[child]
			stack.append(child)
	return out


## Rotates a bone about its own joint, in skeleton space.
static func _rotate(sk: Skeleton3D, bone: int, rot: Basis) -> void:
	var g := sk.get_bone_global_pose(bone)
	sk.set_bone_global_pose(bone, Transform3D(rot * g.basis, g.origin))


## Analytic two-bone IK: bends root->mid->end so `end` reaches `target`, with the middle
## joint pointing toward `pole`. Bones between mid and end keep their pose, so it also
## works for the right leg's extra bone.
static func _solve_two_bone(sk: Skeleton3D, root: int, mid: int, end: int, target: Vector3, pole: Vector3) -> void:
	var root_pose := sk.get_bone_global_pose(root)
	var a := root_pose.origin
	var b := sk.get_bone_global_pose(mid).origin
	var c := sk.get_bone_global_pose(end).origin
	var la := a.distance_to(b)
	var lb := b.distance_to(c)
	var to_target := target - a
	var d := clampf(to_target.length(), absf(la - lb) + 0.001, la + lb - 0.001)
	var u := to_target.normalized()
	var v := pole - u * pole.dot(u)
	if v.length_squared() < 1e-6:
		v = (b - a) - u * (b - a).dot(u)
	v = v.normalized()
	var cos_a := clampf((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
	var knee := a + u * (la * cos_a) + v * (la * sqrt(1.0 - cos_a * cos_a))

	var r1 := Quaternion((b - a).normalized(), (knee - a).normalized())
	sk.set_bone_global_pose(root, Transform3D(Basis(r1) * root_pose.basis, a))
	var mid_pose := sk.get_bone_global_pose(mid)
	var c2 := sk.get_bone_global_pose(end).origin
	var r2 := Quaternion((c2 - mid_pose.origin).normalized(), (a + u * d - mid_pose.origin).normalized())
	sk.set_bone_global_pose(mid, Transform3D(Basis(r2) * mid_pose.basis, mid_pose.origin))
