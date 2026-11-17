extends RaceBackground
## Escamaduras: a predators' war camp in a red-rock canyon at sunset, on the surface. A
## palisade of sharpened stakes with trophy skulls on the gate, a hide-roofed hut flanked by
## tusks, the ribs of a great kill, braziers and war banners, and canyon walls fading into
## the dust.

var _wood: StandardMaterial3D
var _bone: StandardMaterial3D
var _rope: StandardMaterial3D


func _build() -> void:
	_wood = _mat("esc_wood", Color(0.30, 0.19, 0.11), "planks", 23)
	_bone = _mat("esc_bone", Color(0.84, 0.78, 0.64), "noise", 26, Color(0.62, 0.55, 0.42, 0.5))
	_rope = _mat("esc_rope", Color(0.52, 0.40, 0.24), "bands", 24)

	var env := _environment()
	env.background_mode = Environment.BG_SKY
	env.sky = _sky(Color(0.26, 0.09, 0.10), Color(0.98, 0.52, 0.24), Color(0.30, 0.16, 0.10))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.86, 0.46, 0.26)
	env.fog_density = 0.014
	env.fog_sky_affect = 0.2
	# Low sun behind the camp: it backlights the stakes and shows on the horizon.
	_sun(Vector3(-9, 195, 0), Color(1.0, 0.62, 0.36), 1.5)
	_stage_lights(Color(1.0, 0.80, 0.62), 3.2, Color(1.0, 0.42, 0.18), 7.0)

	_ground()
	_canyon()
	_palisade(9.5)
	_hut(Vector3(5.6, 0, -6.4))
	_ribs(Vector3(-4.6, 0, -4.2), Vector3(-0.45, 0, -1).normalized())
	_brazier(Vector3(-2.5, 0, -1.4))
	_brazier(Vector3(2.7, 0, -2.0))
	_banner(Vector3(-1.5, 0, -8.6))
	_banner(Vector3(1.5, 0, -8.6))
	# Dust blowing across the camp.
	_motes(Vector3(0, 1.4, -3), Vector3(9, 1.4, 5), 70, Color(0.95, 0.62, 0.36), 0.045, 0.0, 6.0,
			Vector3(0.9, 0.05, 0.1), 0.4)


func _ground() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.05
	var height := func(x: float, z: float) -> float:
		var away := smoothstep(4.0, 12.0, Vector2(x, z).length())
		return noise.get_noise_2d(x, z) * 1.2 * away
	var dirt := _mat("esc_dirt", Color(0.50, 0.27, 0.16), "speckle", 20, Color(0.58, 0.36, 0.20, 0.5), 0.12)
	_place(LowPoly.terrain(130.0, 52, height), dirt, Vector3(0, -0.12, 0))
	# Stone dais the character stands on.
	var stone := _mat("esc_dais", Color(0.40, 0.30, 0.26), "bricks", 22)
	_place(LowPoly.tube([Vector3(0, -0.4, 0), Vector3(0, 0, 0)], [1.9, 1.75], 8, 0.04, 5), stone, Vector3.ZERO)


## Red mesas and spires on both sides and far behind, banded like sediment.
func _canyon() -> void:
	var rock := _mat("esc_rock", Color(0.62, 0.30, 0.18), "bands", 21, Color(0.80, 0.50, 0.28, 0.5), 0.12)
	var dark_rock := _mat("esc_rock_dark", Color(0.42, 0.20, 0.14), "bands", 27, Color(0.55, 0.30, 0.18, 0.5), 0.12)
	for side: float in [-1.0, 1.0]:
		for i in 7:
			var pos := Vector3(side * (11.0 + i * 1.8 + _rng.randf_range(0.0, 4.0)), -0.5, -3.0 - i * 7.0 + _rng.randf_range(-2.0, 2.0))
			var mesa := LowPoly.spire(_rng.randf_range(2.6, 4.6), _rng.randf_range(7.0, 15.0), 7, 0.12, i * 3 + 1, 0.75, 4)
			_place(mesa, rock if i % 2 == 0 else dark_rock, pos, Vector3(0, _rng.randf_range(0, 360), 0))
		for i in 4:
			var pos := Vector3(side * (8.5 + _rng.randf_range(0.0, 6.0)), -0.3, -6.0 - i * 8.0)
			_place(LowPoly.spire(_rng.randf_range(0.8, 1.4), _rng.randf_range(7.0, 12.0), 6, 0.25, i * 5 + 2), rock, pos)
	for i in 7:
		var pos := Vector3(-42.0 + i * 14.0 + _rng.randf_range(-3.0, 3.0), -1.0, -58.0 + _rng.randf_range(-6.0, 6.0))
		_place(LowPoly.spire(_rng.randf_range(7.0, 10.0), _rng.randf_range(12.0, 22.0), 8, 0.1, i + 40, 0.8, 4), rock, pos)


## Arc of sharpened stakes leaning outward, lashed with rope, with a gate straight behind
## the character and a trophy skull on each gate post.
func _palisade(radius: float) -> void:
	var gate := 0.17
	for half: float in [-1.0, 1.0]:
		var lashing := PackedVector3Array()
		for i in 17:
			var a := half * lerpf(gate, 1.25, i / 16.0)
			var out := Vector3(sin(a), 0, -cos(a))
			var base := out * radius
			var post := i == 0
			var h := (3.6 if post else 2.6) + _rng.randf_range(-0.3, 0.5)
			var top := base + Vector3(0, h, 0) + out * 0.3
			var r := 0.24 if post else 0.17
			_place(LowPoly.tube([base - Vector3(0, 0.4, 0), base.lerp(top, 0.82), top], [r, r * 0.95, 0.0], 6, 0.08, i + 50),
					_wood, Vector3.ZERO)
			lashing.append(base + out * 0.12 + Vector3(0, 1.1, 0))
			if post:
				_skull(top + Vector3(0, -0.55, 0) - out * 0.28, out)
		var radii := PackedFloat32Array()
		radii.resize(lashing.size())
		radii.fill(0.045)
		_place(LowPoly.tube(lashing, radii, 4), _rope, Vector3.ZERO)


## Horned skull of some great beast, facing away from the palisade's centre.
func _skull(pos: Vector3, facing: Vector3) -> void:
	var skull := _place(LowPoly.faceted_sphere(0.3, 61, 7, 5, 0.15), _bone, pos)
	skull.basis = Basis.looking_at(facing, Vector3.UP) * Basis.from_scale(Vector3(1.0, 0.8, 1.3))
	var side := facing.cross(Vector3.UP).normalized()
	for s: float in [-1.0, 1.0]:
		var root := pos + side * s * 0.22 + Vector3(0, 0.12, 0)
		var horn := [root, root + side * s * 0.35 + Vector3(0, 0.25, 0), root + side * s * 0.45 + Vector3(0, 0.6, 0) - facing * 0.15]
		_place(LowPoly.tube(horn, [0.09, 0.06, 0.0], 5), _bone, Vector3.ZERO)


## Round hut with a conical hide roof, its door turned toward the camp, framed by tusks.
func _hut(pos: Vector3) -> void:
	var hide := _mat("esc_hide", Color(0.52, 0.27, 0.17), "bands", 28, Color(0.36, 0.16, 0.10, 0.5))
	_place(LowPoly.tube([pos + Vector3(0, -0.3, 0), pos + Vector3(0, 1.6, 0)], [1.75, 1.65], 9, 0.05, 31), _wood, Vector3.ZERO)
	_place(LowPoly.spire(2.35, 2.5, 9, 0.06, 32), hide, pos + Vector3(0, 1.45, 0))
	for i in 5:
		var a := TAU * i / 5.0
		var tip := pos + Vector3(0, 3.7, 0)
		_place(LowPoly.tube([tip - Vector3(cos(a), 0, sin(a)) * 0.2 - Vector3(0, 0.5, 0), tip + Vector3(cos(a), 2.0, sin(a)) * 0.35],
				[0.05, 0.0], 4), _wood, Vector3.ZERO)
	var door_dir := Vector3(-pos.x, 0, -pos.z).normalized()
	var side := door_dir.cross(Vector3.UP)
	var door := BoxMesh.new()
	door.size = Vector3(0.9, 1.3, 0.1)
	var door_mi := _place(door, _mat("esc_door", Color(0.06, 0.04, 0.03)), pos + door_dir * 1.68 + Vector3(0, 0.6, 0))
	door_mi.rotation.y = atan2(door_dir.x, door_dir.z)
	for s: float in [-1.0, 1.0]:
		var base := pos + door_dir * 2.0 + side * s * 0.8
		var tusk := [base - Vector3(0, 0.3, 0), base + Vector3(0, 1.1, 0) + door_dir * 0.35, base + Vector3(0, 2.0, 0) - side * s * 0.35]
		_place(LowPoly.tube(tusk, [0.15, 0.11, 0.0], 6), _bone, Vector3.ZERO)


## Ribs of a great kill rising from the dust in a row along `dir`.
func _ribs(pos: Vector3, dir: Vector3) -> void:
	var side := dir.cross(Vector3.UP).normalized()
	for i in 6:
		var c := pos + dir * i * 0.75
		var h := 2.4 - absf(i - 2.0) * 0.25
		for s: float in [-1.0, 1.0]:
			var rib := [c + side * s * 1.4 - Vector3(0, 0.3, 0), c + side * s * 1.35 + Vector3(0, h * 0.6, 0),
					c + side * s * 0.35 + Vector3(0, h, 0)]
			_place(LowPoly.tube(rib, [0.12, 0.1, 0.05], 5, 0.05, i), _bone, Vector3.ZERO)
	var spine := PackedVector3Array()
	for i in 7:
		spine.append(pos + dir * (i * 0.75 - 0.3) + Vector3(0, 2.4 - absf(i - 2.5) * 0.22, 0))
	var radii := PackedFloat32Array()
	radii.resize(spine.size())
	radii.fill(0.14)
	_place(LowPoly.tube(spine, radii, 5, 0.1, 9), _bone, Vector3.ZERO)


## Iron bowl of burning coals on three legs.
func _brazier(pos: Vector3) -> void:
	var iron := _mat("esc_iron", Color(0.16, 0.14, 0.13), "noise", 25)
	for i in 3:
		var out := Vector3(cos(TAU * i / 3.0), 0, sin(TAU * i / 3.0))
		_place(LowPoly.tube([pos + out * 0.45, pos + out * 0.15 + Vector3(0, 0.85, 0)], [0.045, 0.04], 4), iron, Vector3.ZERO)
	_place(LowPoly.tube([pos + Vector3(0, 0.72, 0), pos + Vector3(0, 0.92, 0), pos + Vector3(0, 1.02, 0)], [0.12, 0.42, 0.5], 7), iron, Vector3.ZERO)
	_place(LowPoly.disc(0.44, 7, 0.0), _glow(Color(0.9, 0.22, 0.05), 2.5), pos + Vector3(0, 1.03, 0))
	_fire(pos + Vector3(0, 1.0, 0), 0.9, 3.5)


## Tall pole with a blood-red war banner that flaps in the wind.
func _banner(pos: Vector3) -> void:
	_place(LowPoly.tube([pos - Vector3(0, 0.3, 0), pos + Vector3(0, 4.4, 0)], [0.07, 0.06], 5), _wood, Vector3.ZERO)
	_place(LowPoly.tube([pos + Vector3(-0.6, 4.1, 0), pos + Vector3(0.6, 4.1, 0)], [0.05, 0.05], 4), _wood, Vector3.ZERO)
	var hinge := Node3D.new()
	hinge.position = pos + Vector3(0, 4.05, 0.02)
	add_child(hinge)
	_swaying.append(hinge)
	var cloth := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.05, 2.0, 0.03)
	cloth.mesh = box
	cloth.material_override = _mat("esc_banner", Color(0.50, 0.07, 0.05), "bands", 29, Color(0.30, 0.03, 0.03, 0.5))
	cloth.position = Vector3(0, -1.0, 0)
	hinge.add_child(cloth)
	# Three claw slashes painted in black.
	var mark := _mat("esc_mark", Color(0.06, 0.05, 0.05), "noise", 30)
	for i in 3:
		var slash := MeshInstance3D.new()
		var stroke := BoxMesh.new()
		stroke.size = Vector3(0.07, 0.9, 0.02)
		slash.mesh = stroke
		slash.material_override = mark
		slash.position = Vector3(-0.22 + i * 0.22, -1.05, 0.02)
		slash.rotation.z = 0.35
		hinge.add_child(slash)
