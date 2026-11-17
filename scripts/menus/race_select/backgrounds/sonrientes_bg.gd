extends RaceBackground
## Sonrientes: a swamp at dusk. A great weeping willow leans over dark ponds full of lily
## pads, reeds and cattails; green mist hangs over the water, purple bulbs glow among the
## reeds, fireflies wander and clouds of mosquitoes hover over the ponds.

## Ponds as (x, z, radius).
const PONDS: Array[Vector3] = [Vector3(0.6, -5.6, 3.6), Vector3(-6.8, -9.5, 3.4), Vector3(5.6, -2.6, 2.0),
		Vector3(-3.7, -1.5, 1.3), Vector3(8.5, -11.5, 3.8), Vector3(-1.5, -14.0, 3.0)]
const WATER_Y := -0.03

var _bark: StandardMaterial3D


func _build() -> void:
	_bark = _mat("son_bark", Color(0.25, 0.21, 0.15), "bands", 61, Color(0.20, 0.25, 0.13, 0.5), 0.12)

	var env := _environment()
	env.background_mode = Environment.BG_SKY
	env.sky = _sky(Color(0.05, 0.09, 0.11), Color(0.30, 0.38, 0.24), Color(0.08, 0.10, 0.07))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.26, 0.34, 0.22)
	env.fog_density = 0.022
	env.fog_sky_affect = 0.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.62, 0.78, 0.55)
	env.volumetric_fog_length = 32.0
	env.ssr_enabled = true
	_sun(Vector3(-14, 150, 0), Color(0.78, 0.88, 0.62), 0.8)
	_stage_lights(Color(0.86, 1.0, 0.82), 4.0, Color(0.72, 0.36, 1.0), 9.0)

	_ground()
	_ponds()
	_willow(Vector3(-2.9, 0, -10.0))
	_dead_tree(Vector3(9.5, 0, -16.0), 1)
	_dead_tree(Vector3(-13.0, 0, -18.0), 2)
	_dead_tree(Vector3(2.6, 0, -19.0), 3)
	_log(Vector3(-2.4, 0.05, -5.0), Vector3(2.6, 0.05, -4.2))
	_reeds()
	for spot: Vector3 in [Vector3(2.8, 0, -3.4), Vector3(-2.6, 0, -2.6), Vector3(4.0, 0, -7.6), Vector3(-8.6, 0, -6.4)]:
		_glow_bulbs(spot)
	# Fireflies over the water and mosquitoes swarming above the ponds.
	_motes(Vector3(0, 1.5, -7), Vector3(10, 1.2, 6), 40, Color(0.72, 1.0, 0.35), 0.05, 4.0, 6.0, Vector3.ZERO, 0.5, 0.2)
	for i in PONDS.size() - 1:
		var pond := PONDS[i]
		_motes(Vector3(pond.x, 1.3, pond.y), Vector3(0.7, 0.45, 0.7), 45, Color(0.04, 0.04, 0.03), 0.035, 0.0, 1.4,
				Vector3.ZERO, 6.0, 1.2)


func _ground() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 12
	noise.frequency = 0.08
	var height := func(x: float, z: float) -> float:
		var h := noise.get_noise_2d(x, z) * 0.18 + 0.05
		for pond in PONDS:
			var d := Vector2(x - pond.x, z - pond.y).length() / pond.z
			h -= (1.0 - smoothstep(0.75, 1.3, d)) * 0.35  # basins for the water
		return h * smoothstep(0.9, 2.2, Vector2(x, z).length())
	var mud := _mat("son_mud", Color(0.21, 0.17, 0.10), "speckle", 62, Color(0.18, 0.24, 0.10, 0.6), 0.12)
	_place(LowPoly.terrain(100.0, 100, height), mud, Vector3.ZERO)
	# Mossy hump of roots the character stands on.
	var moss := _mat("son_moss", Color(0.24, 0.34, 0.13), "speckle", 63, Color(0.34, 0.40, 0.16, 0.5), 0.12)
	_place(LowPoly.faceted_sphere(1.4, 64, 16, 8, 0.08), moss, Vector3(0, -0.18, 0), Vector3.ZERO, Vector3(1.0, 0.14, 1.0))
	for i in 5:
		var out := Vector3(cos(TAU * i / 5.0 + 0.5), 0, sin(TAU * i / 5.0 + 0.5))
		var root := [out * 0.9 + Vector3(0, 0.05, 0), out * 1.7 + Vector3(0, 0.12, 0), out * 2.6 - Vector3(0, 0.2, 0)]
		_place(LowPoly.tube(root, [0.13, 0.09, 0.03], 5, 0.15, i), _bark, Vector3.ZERO)


## Dark reflective water in each basin, with duckweed and lily pads.
func _ponds() -> void:
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.07, 0.10, 0.06)
	water.roughness = 0.05
	water.metallic_specular = 0.8
	var weed := _mat("son_weed", Color(0.30, 0.44, 0.12), "speckle", 65, Color(0.40, 0.50, 0.15, 0.5), 0.15)
	var pad := _mat("son_pad", Color(0.20, 0.38, 0.14), "speckle", 66, Color(0.30, 0.44, 0.16, 0.4), 0.1)
	for i in PONDS.size():
		var pond := PONDS[i]
		var centre := Vector3(pond.x, WATER_Y, pond.y)
		_place(LowPoly.disc(pond.z * 1.1, 14, 0.12, i), water, centre)
		for k in 3:
			var p := centre + Vector3(_rng.randf_range(-0.6, 0.6), 0.01, _rng.randf_range(-0.6, 0.6)) * pond.z
			_place(LowPoly.disc(_rng.randf_range(0.3, 0.7), 7, 0.3, k + i * 3), weed, p)
		for k in int(pond.z * 2.5):
			var a := _rng.randf_range(0, TAU)
			var p := centre + Vector3(cos(a), 0, sin(a)) * pond.z * sqrt(_rng.randf()) * 0.85 + Vector3(0, 0.015, 0)
			_place(LowPoly.disc(_rng.randf_range(0.14, 0.3), 9, 0.08, k), pad, p, Vector3(0, _rng.randf_range(0, 360), 0))


## Weeping willow: a gnarled trunk on spreading roots, arching branches, a dark crown and
## hundreds of fronds swaying down toward the water.
func _willow(pos: Vector3) -> void:
	_place(LowPoly.tube([pos - Vector3(0, 0.4, 0), pos + Vector3(0.2, 1.3, 0.1), pos + Vector3(-0.15, 2.5, 0.15),
			pos + Vector3(0.25, 3.5, -0.1), pos + Vector3(0.1, 4.3, 0)], [0.9, 0.62, 0.55, 0.5, 0.42], 8, 0.12, 67),
			_bark, Vector3.ZERO)
	for i in 6:
		var out := Vector3(cos(TAU * i / 6.0), 0, sin(TAU * i / 6.0))
		var root := [pos + out * 0.35 + Vector3(0, 0.6, 0), pos + out * 1.2 + Vector3(0, 0.15, 0), pos + out * 2.2 - Vector3(0, 0.3, 0)]
		_place(LowPoly.tube(root, [0.26, 0.15, 0.04], 5, 0.15, i + 20), _bark, Vector3.ZERO)

	var leaves := _mat("son_leaves", Color(0.20, 0.30, 0.11), "speckle", 68, Color(0.30, 0.38, 0.12, 0.5), 0.12)
	var anchors: Array[Vector3] = []
	var top := pos + Vector3(0.1, 4.1, 0)
	for i in 8:
		var a := TAU * i / 8.0 + 0.3
		var out := Vector3(cos(a), 0, sin(a))
		var branch := [top - out * 0.1, top + out * 1.4 + Vector3(0, 0.9, 0), top + out * 2.8 + Vector3(0, 1.1, 0),
				top + out * 3.9 + Vector3(0, 0.55, 0)]
		_place(LowPoly.tube(branch, [0.24, 0.15, 0.08, 0.02], 5, 0.1, i + 30), _bark, Vector3.ZERO)
		_place(LowPoly.faceted_sphere(_rng.randf_range(1.3, 1.8), i + 40, 8, 5, 0.2), leaves,
				top + out * 2.6 + Vector3(0, 1.3, 0), Vector3.ZERO, Vector3(1.0, 0.5, 1.0))
		for k in 45:
			var t := _rng.randf_range(0.25, 1.0)
			var along: Vector3 = branch[1].lerp(branch[2], t * 2.0) if t < 0.5 else branch[2].lerp(branch[3], t * 2.0 - 1.0)
			anchors.append(along + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.0, 0.5), _rng.randf_range(-0.6, 0.6)))

	var fronds: Array[Transform3D] = []
	for anchor in anchors:
		var length := minf(_rng.randf_range(1.8, 4.3), anchor.y - 0.2)
		var basis := Basis(Vector3.UP, _rng.randf_range(0, TAU)).scaled(Vector3(1.0, length, 1.0))
		fronds.append(Transform3D(basis, anchor))
	var tex := PixelTex.make("son_frond", Color(0.34, 0.50, 0.18), "speckle", 32, 0.14, 69, Color(0.44, 0.56, 0.20, 0.5))
	_scatter(LowPoly.cross_strip(0.22, 5, true), _foliage(tex, Color(1.45, 1.4, 0.8), true, 0.22, 0.9), fronds)


## Bare dead tree half lost in the mist.
func _dead_tree(pos: Vector3, seed: int) -> void:
	var dead := _mat("son_dead", Color(0.16, 0.15, 0.13), "bands", 70)
	var h := 5.0 + seed
	var lean := Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.4, 0.4))
	_place(LowPoly.tube([pos - Vector3(0, 0.3, 0), pos + Vector3(0, h * 0.5, 0) + lean * 0.4, pos + Vector3(0, h, 0) + lean],
			[0.35, 0.22, 0.05], 6, 0.12, seed), dead, Vector3.ZERO)
	for i in 4:
		var y := h * _rng.randf_range(0.4, 0.85)
		var out := Vector3(cos(i * 1.9 + seed), 0, sin(i * 1.9 + seed))
		var base := pos + Vector3(0, y, 0) + lean * (y / h)
		var length := _rng.randf_range(1.2, 2.4)
		_place(LowPoly.tube([base, base + out * length * 0.6 + Vector3(0, length * 0.4, 0), base + out * length + Vector3(0, length * 0.9, 0)],
				[0.12, 0.06, 0.0], 5, 0.1, i + seed * 10), dead, Vector3.ZERO)


## Mossy fallen log lying across the water.
func _log(from: Vector3, to: Vector3) -> void:
	var mossy := _mat("son_log", Color(0.24, 0.22, 0.14), "bands", 71, Color(0.24, 0.34, 0.12, 0.6), 0.12)
	_place(LowPoly.tube([from, from.lerp(to, 0.5) + Vector3(0, 0.08, 0), to], [0.24, 0.26, 0.22], 7, 0.1, 72), mossy, Vector3.ZERO)


## Reeds around every pond, some topped with cattails.
func _reeds() -> void:
	var stalks: Array[Transform3D] = []
	var cattail := _mat("son_cattail", Color(0.30, 0.18, 0.09), "noise", 73)
	for i in PONDS.size():
		var pond := PONDS[i]
		for k in int(pond.z * 30.0):
			var a := _rng.randf_range(0, TAU)
			var d := pond.z * _rng.randf_range(0.85, 1.3)
			var pos := Vector3(pond.x + cos(a) * d, WATER_Y, pond.y + sin(a) * d)
			if pos.z > -1.0 or Vector2(pos.x, pos.z).length() < 2.2:
				continue  # keep the character and the view in front of it clear
			var h := _rng.randf_range(0.5, 1.2)
			stalks.append(Transform3D(Basis(Vector3.UP, _rng.randf_range(0, TAU)).scaled(Vector3(1.0, h, 1.0)), pos))
			if _rng.randf() < 0.12:
				var head := pos + Vector3(0, h + 0.05, 0)
				_place(LowPoly.tube([head, head + Vector3(0, 0.22, 0)], [0.04, 0.035], 5), cattail, Vector3.ZERO)
	var tex := PixelTex.make("son_reed", Color(0.36, 0.46, 0.18), "speckle", 32, 0.1, 74, Color(0.46, 0.40, 0.18, 0.5))
	_scatter(LowPoly.cross_strip(0.045, 3, false), _foliage(tex, Color(1.3, 1.15, 0.7), false, 0.08, 1.3), stalks)


## A few glowing purple bulbs on stalks: the swamp's poisonous light.
func _glow_bulbs(pos: Vector3) -> void:
	var stalk := _mat("son_stalk", Color(0.20, 0.26, 0.12), "noise", 75)
	var bulb := _glow(Color(0.72, 0.32, 1.0), 3.0)
	for i in 3:
		var p := pos + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
		var h := _rng.randf_range(0.4, 0.9)
		_place(LowPoly.tube([p - Vector3(0, 0.1, 0), p + Vector3(0.05, h, 0)], [0.025, 0.02], 4), stalk, Vector3.ZERO)
		_place(LowPoly.faceted_sphere(_rng.randf_range(0.07, 0.12), i + 90, 6, 4, 0.1), bulb, p + Vector3(0.05, h + 0.05, 0))
	_omni(pos + Vector3(0, 0.8, 0), Color(0.7, 0.32, 1.0), 1.6, 4.0)
