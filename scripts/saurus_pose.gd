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
const SIDE := [1.0, -1.0]  ## left limbs sit on +X in skeleton space

var rig: SaurusRig

var _hips := -1
var _neck := -1
var _head := -1
var _spine: Array[int] = []
var _tail: Array[int] = []
var _legs: Array[PackedInt32Array] = []
var _arms: Array[PackedInt32Array] = []
var _foot_rest: Array[Basis] = []


func _ready() -> void:
	var sk := get_skeleton()
	_hips = sk.find_bone(HIPS)
	_neck = sk.find_bone(NECK)
	_head = sk.find_bone(HEAD)
	for n in SPINE:
		_spine.append(sk.find_bone(n))
	for n in TAIL:
		_tail.append(sk.find_bone(n))
	for chain in LEGS:
		_legs.append(PackedInt32Array(chain.map(func(n: String) -> int: return sk.find_bone(n))))
		_foot_rest.append(sk.get_bone_global_rest(_legs[-1][2]).basis)
	for chain in ARMS:
		_arms.append(PackedInt32Array(chain.map(func(n: String) -> int: return sk.find_bone(n))))


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or rig == null or rig.feet.is_empty():
		return
	sk.reset_bone_poses()  # fully procedural for now; drop this when blending real clips
	var to_skel := sk.global_transform.affine_inverse()
	var dir_to_skel := to_skel.basis

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
			_rotate(sk, arm[0], Basis(Vector3.RIGHT, swing) * Basis(Vector3.BACK, -side * rig.arm_lower))
			_rotate(sk, arm[1], Basis(Vector3.RIGHT, -rig.elbow_bend))

	for i in 2:
		var leg := _legs[i]
		var f: SaurusRig.Foot = rig.feet[i]
		var up := rig.foot_up(f)
		var ankle := to_skel * (f.pos + up * SaurusRig.ANKLE_HEIGHT)
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
