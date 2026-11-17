extends RaceBackground
## Tiemblatierras: a settlement of painted hide tents and carved totems on a meadow deep
## inside a great cavern. A shaft of daylight falls through a crack in the roof; purple
## crystals and green fungi glow along the walls, and spores drift in the haze.

const DOME_CENTER := Vector3(0, 3, -14)
const DOME_RADII := Vector3(46, 23, 36)

var _wood: StandardMaterial3D
var _stone: StandardMaterial3D


func _build() -> void:
	_wood = _mat("tie_wood", Color(0.34, 0.24, 0.15), "planks", 43)
	_stone = _mat("tie_stone", Color(0.30, 0.28, 0.30), "noise", 44, Color(0.36, 0.30, 0.42, 0.4), 0.14)

	var env := _environment()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.30, 0.48)
	env.ambient_light_energy = 0.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.78, 0.76, 0.92)
	env.volumetric_fog_length = 48.0
	# Daylight through a crack in the roof, falling across the meadow behind the character.
	_spot(Vector3(-2.0, 24.0, -10.0), Vector3(-0.6, 0, -5.5), Color(1.0, 0.92, 0.74), 40.0, 9.0, 40.0, 8.0)
	_stage_lights(Color(1.0, 0.76, 0.52), 4.5, Color(0.66, 0.42, 1.0), 8.0)

	_cave()
	_meadow()
	_tipi(Vector3(-6.2, 0, -8.0), 1)
	_tipi(Vector3(6.6, 0, -9.6), 2)
	_tipi(Vector3(-1.2, 0, -15.0), 3)
	_totem(Vector3(-3.3, 0, -4.0), 4)
	_totem(Vector3(3.7, 0, -5.0), 5)
	_campfire(Vector3(0.9, 0, -6.6))
	for cluster: Array in [[Vector3(-10, 0, -9), 1.4], [Vector3(11, 0, -6), 1.2], [Vector3(-7.5, 0, -19), 1.8],
			[Vector3(9, 0, -18), 1.6], [Vector3(3, 0, -24), 2.2], [Vector3(-13, 0, -2), 1.0]]:
		_crystals(cluster[0], cluster[1])
	for patch: Vector3 in [Vector3(-2.6, 0, -3.4), Vector3(2.4, 0, -3.0), Vector3(-8.5, 0, -6.0), Vector3(7.5, 0, -12.5)]:
		_mushrooms(patch)
	# Spores floating in the cavern air.
	_motes(Vector3(0, 2.5, -6), Vector3(10, 2.5, 7), 80, Color(0.55, 1.0, 0.45), 0.04, 3.0, 8.0, Vector3.ZERO, 0.4, 0.15)
	_motes(Vector3(0, 3.0, -10), Vector3(12, 3.0, 8), 50, Color(0.75, 0.45, 1.0), 0.05, 3.0, 9.0, Vector3.ZERO, 0.4, 0.15)


## Cave floor, the rock dome seen from inside, stalactites and stalagmites.
func _cave() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 8
	noise.frequency = 0.06
	var height := func(x: float, z: float) -> float:
		return noise.get_noise_2d(x, z) * 0.9 * smoothstep(5.0, 13.0, Vector2(x, z).length())
	var floor_mat := _mat("tie_floor", Color(0.27, 0.23, 0.16), "speckle", 45, Color(0.22, 0.32, 0.15, 0.5), 0.12)
	_place(LowPoly.terrain(110.0, 44, height), floor_mat, Vector3.ZERO)

	var dome_mat := _mat("tie_dome", Color(0.24, 0.21, 0.26), "noise", 46, Color(0.30, 0.22, 0.36, 0.5), 0.16)
	_place(LowPoly.faceted_sphere(1.0, 47, 26, 14, 0.06, true), dome_mat, DOME_CENTER, Vector3.ZERO, DOME_RADII)

	for i in 46:
		var x := _rng.randf_range(-28.0, 28.0)
		var z := _rng.randf_range(-36.0, 2.0)
		var roof := _roof_height(x, z)
		if roof < 4.0:
			continue
		var length := _rng.randf_range(2.0, 7.0)
		_place(LowPoly.spire(_rng.randf_range(0.4, 1.1), length, 6, 0.2, i + 100), _stone,
				Vector3(x, roof + 1.0, z), Vector3(180, _rng.randf_range(0, 360), 0))
	for i in 18:
		var a := _rng.randf_range(-PI * 0.85, PI * 0.85)
		var d := _rng.randf_range(10.0, 22.0)
		var pos := Vector3(sin(a) * d * 1.2, -0.3, -cos(a) * d - 4.0)
		_place(LowPoly.spire(_rng.randf_range(0.5, 1.3), _rng.randf_range(1.5, 5.5), 6, 0.2, i + 150), _stone, pos)
	for i in 12:
		var a := _rng.randf_range(-PI * 0.9, PI * 0.9)
		var pos := Vector3(sin(a) * 26.0, 0.0, -cos(a) * 22.0 - 10.0)
		_place(LowPoly.faceted_sphere(_rng.randf_range(2.5, 5.0), i + 170, 8, 5, 0.3), _stone, pos)


## Height of the dome's ceiling above (x, z).
func _roof_height(x: float, z: float) -> float:
	var dx := x / DOME_RADII.x
	var dz := (z - DOME_CENTER.z) / DOME_RADII.z
	var inside := 1.0 - dx * dx - dz * dz
	return DOME_CENTER.y + DOME_RADII.y * sqrt(inside) if inside > 0.0 else 0.0


## Grassy mounds and tufts around the camp: the meadow, under ground.
func _meadow() -> void:
	var grass_mat := _mat("tie_grass", Color(0.30, 0.42, 0.17), "speckle", 48, Color(0.42, 0.48, 0.20, 0.5), 0.12)
	for i in 9:
		var a := _rng.randf_range(-PI, PI)
		var d := _rng.randf_range(4.0, 12.0)
		var pos := Vector3(sin(a) * d, -0.35, -absf(cos(a)) * d - 1.0)
		var r := _rng.randf_range(1.2, 2.6)
		_place(LowPoly.faceted_sphere(r, i + 60, 9, 5, 0.12), grass_mat, pos, Vector3.ZERO, Vector3(1.0, 0.35, 1.0))
	var tufts: Array[Transform3D] = []
	for i in 900:
		var a := _rng.randf_range(-PI, PI)
		var d := sqrt(_rng.randf()) * 13.0 + 1.6
		var pos := Vector3(sin(a) * d, 0.0, -cos(a) * d * 0.9 - 2.0)
		if pos.z > 1.0:
			continue  # keep the view of the feet clear
		var basis := Basis(Vector3.UP, _rng.randf_range(0, TAU)).scaled(Vector3(1.0, _rng.randf_range(0.2, 0.55), 1.0))
		tufts.append(Transform3D(basis, pos))
	var tex := PixelTex.make("tie_tuft", Color(0.32, 0.46, 0.18), "speckle", 32, 0.12, 49)
	_scatter(LowPoly.cross_strip(0.16, 2, false), _foliage(tex, Color(1.25, 1.2, 0.7), false, 0.06, 1.6), tufts)


## Tent of painted hides on crossed poles, its door turned toward the camp.
func _tipi(pos: Vector3, seed: int) -> void:
	var hide := _mat("tie_hide", Color(0.72, 0.56, 0.38), "bands", 41, Color(0.62, 0.40, 0.24, 0.45))
	var stripe := _mat("tie_stripe", Color(0.56, 0.16, 0.10), "noise", 42)
	var stripe2 := _mat("tie_stripe2", Color(0.12, 0.40, 0.42), "noise", 50)
	var radius := 2.0
	var height := 4.3
	_place(LowPoly.spire(radius, height, 8, 0.0, seed), hide, pos)
	for band: Array in [[0.9, 1.25, stripe], [1.45, 1.6, stripe2]]:
		var r0: float = radius * (1.0 - band[0] / height) + 0.02
		var r1: float = radius * (1.0 - band[1] / height) + 0.02
		_place(LowPoly.tube([pos + Vector3(0, band[0], 0), pos + Vector3(0, band[1], 0)], [r0, r1], 8), band[2], Vector3.ZERO)
	for i in 6:
		var out := Vector3(cos(TAU * i / 6.0 + seed), 0, sin(TAU * i / 6.0 + seed))
		_place(LowPoly.tube([pos + out * radius * 0.92, pos + Vector3(0, height + 1.0, 0) - out * 0.4], [0.05, 0.035], 4),
				_wood, Vector3.ZERO)
	var to_camp := Vector3(-pos.x, 0, 4.0 - pos.z).normalized()
	var door := BoxMesh.new()
	door.size = Vector3(0.95, 1.4, 0.05)
	var door_mi := _place(door, _mat("tie_door", Color(0.07, 0.05, 0.04)), pos + to_camp * (radius * 0.84) + Vector3(0, 0.66, 0))
	door_mi.basis = Basis.looking_at(-to_camp, Vector3.UP) * Basis(Vector3.RIGHT, -atan(radius / height))


## Totem pole of carved, painted drums with a winged crest, its faces turned to the camp.
func _totem(pos: Vector3, seed: int) -> void:
	var paints: Array[StandardMaterial3D] = [
		_mat("tie_ochre", Color(0.74, 0.52, 0.24), "noise", 51),
		_mat("tie_teal", Color(0.14, 0.42, 0.42), "noise", 52),
		_mat("tie_red", Color(0.58, 0.15, 0.10), "noise", 53),
		_wood,
	]
	var dark := _mat("tie_carve", Color(0.06, 0.04, 0.03), "noise", 54)
	var face := Vector3(-pos.x, 0, 4.0 - pos.z).normalized()
	var side := face.cross(Vector3.UP).normalized()
	var y := -0.2
	for i in 4:
		var h := 0.75 if i < 3 else 0.6
		var r := 0.42 - i * 0.04
		_place(LowPoly.tube([pos + Vector3(0, y, 0), pos + Vector3(0, y + h * 0.5, 0), pos + Vector3(0, y + h, 0)],
				[r, r * 1.12, r], 7, 0.03, seed * 10 + i), paints[(i + seed) % paints.size()], Vector3.ZERO)
		# Carved face: two deep eyes and a beak or snout.
		var front := pos + face * r * 1.05 + Vector3(0, y + h * 0.62, 0)
		for s: float in [-1.0, 1.0]:
			_place(BoxMesh.new(), dark, front + side * s * 0.14, Vector3.ZERO, Vector3(0.12, 0.08, 0.06))
		var snout := front - Vector3(0, 0.2, 0)
		_place(LowPoly.tube([snout, snout + face * 0.22 - Vector3(0, 0.08, 0)], [0.07, 0.0], 4), paints[(i + seed + 1) % paints.size()], Vector3.ZERO)
		y += h
	var top := pos + Vector3(0, y, 0)
	for s: float in [-1.0, 1.0]:
		var wing := [top - Vector3(0, 0.25, 0), top + side * s * 0.9 + Vector3(0, 0.2, 0), top + side * s * 1.5 + Vector3(0, 0.55, 0)]
		_place(LowPoly.tube(wing, [0.14, 0.11, 0.0], 4), paints[seed % 3], Vector3.ZERO)
	_place(LowPoly.spire(0.22, 0.6, 5, 0.0, seed), paints[(seed + 2) % 3], top - Vector3(0, 0.1, 0))


## Ring of stones around crossed logs and a fire.
func _campfire(pos: Vector3) -> void:
	for i in 9:
		var a := TAU * i / 9.0
		_place(LowPoly.faceted_sphere(0.2, i + 70, 6, 4, 0.25), _stone, pos + Vector3(cos(a), 0.02, sin(a)) * 0.62)
	for i in 3:
		var a := TAU * i / 3.0
		var out := Vector3(cos(a), 0, sin(a))
		_place(LowPoly.tube([pos + out * 0.5 + Vector3(0, 0.05, 0), pos - out * 0.1 + Vector3(0, 0.3, 0)], [0.08, 0.06], 5),
				_wood, Vector3.ZERO)
	_fire(pos + Vector3(0, 0.08, 0), 1.15, 4.5)


## A cluster of glowing purple crystals with their light.
func _crystals(pos: Vector3, size: float) -> void:
	var glow := _glow(Color(0.66, 0.32, 1.0), 2.6)
	var count := 4 + int(size * 2.0)
	for i in count:
		var dir := Vector3(_rng.randf_range(-0.6, 0.6), 1.0, _rng.randf_range(-0.6, 0.6)).normalized()
		var length := size * _rng.randf_range(0.6, 1.5)
		var r := size * _rng.randf_range(0.09, 0.15)
		var base := pos + Vector3(_rng.randf_range(-0.4, 0.4), -0.1, _rng.randf_range(-0.4, 0.4)) * size
		_place(LowPoly.tube([base, base + dir * length * 0.8, base + dir * length], [r, r * 1.1, 0.0], 5), glow, Vector3.ZERO)
	_omni(pos + Vector3(0, size, 0), Color(0.62, 0.32, 1.0), 2.2, 7.0 * size)


## Glowing green fungi, a few caps on pale stems.
func _mushrooms(pos: Vector3) -> void:
	var stem := _mat("tie_stem", Color(0.78, 0.76, 0.62), "noise", 55)
	var cap := _glow(Color(0.38, 1.0, 0.32), 1.3)
	for i in 5:
		var p := pos + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
		var h := _rng.randf_range(0.15, 0.55)
		var r := h * _rng.randf_range(0.35, 0.6)
		_place(LowPoly.tube([p - Vector3(0, 0.05, 0), p + Vector3(0, h, 0)], [0.045, 0.035], 5), stem, Vector3.ZERO)
		_place(LowPoly.faceted_sphere(r, i + 80, 7, 4, 0.1), cap, p + Vector3(0, h, 0), Vector3.ZERO, Vector3(1.0, 0.5, 1.0))
	_omni(pos + Vector3(0, 0.6, 0), Color(0.4, 1.0, 0.35), 0.8, 3.0)
