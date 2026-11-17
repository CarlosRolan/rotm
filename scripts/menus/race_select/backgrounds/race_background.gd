class_name RaceBackground
extends Node3D
## Base for the race-selection backdrops. The character stands on the origin facing +Z,
## where the camera is; each backdrop builds its set behind and around that spot in
## `_build()` with the helpers here: pixel materials, low-poly props, fires, lights and
## floating particles. Everything is decoration (no collision).

const FOLIAGE_SHADER := preload("res://shaders/foliage_sway.gdshader")

var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _flicker_lights: Array[OmniLight3D] = []
var _flicker_energy: Array[float] = []
var _flames: Array[Node3D] = []
var _swaying: Array[Node3D] = []


func _ready() -> void:
	_rng.seed = 7
	_build()


## Overridden by each backdrop.
func _build() -> void:
	pass


func _process(delta: float) -> void:
	_time += delta
	for i in _flicker_lights.size():
		var k := i * 1.7
		_flicker_lights[i].light_energy = _flicker_energy[i] * (0.85 + 0.1 * sin(_time * 11.0 + k) + 0.05 * sin(_time * 23.0 + k * 2.3))
	for i in _flames.size():
		var k := i * 2.1
		var s := 1.0 + 0.14 * sin(_time * 13.0 + k) + 0.07 * sin(_time * 31.0 + k)
		_flames[i].scale = Vector3(1.0 / sqrt(s), s, 1.0 / sqrt(s))
	for i in _swaying.size():
		_swaying[i].rotation.x = sin(_time * 1.4 + i * 1.3) * 0.07 + sin(_time * 3.1 + i) * 0.02


# --- Environment and lights ---------------------------------------------------------

## Filmic tonemap, soft bloom for fire and bioluminescence, and ambient occlusion.
func _environment() -> Environment:
	var env := Environment.new()
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.ssao_enabled = true
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	return env


func _sky(top: Color, horizon: Color, ground: Color) -> Sky:
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = top
	mat.sky_horizon_color = horizon
	mat.ground_horizon_color = horizon.darkened(0.3)
	mat.ground_bottom_color = ground
	mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = mat
	return sky


func _sun(rotation_deg: Vector3, colour: Color, energy: float) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = rotation_deg
	sun.light_color = colour
	sun.light_energy = energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	return sun


func _omni(pos: Vector3, colour: Color, energy: float, light_range: float, flicker := false, shadows := false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = shadows
	add_child(light)
	if flicker:
		_flicker_lights.append(light)
		_flicker_energy.append(energy)
	return light


func _spot(pos: Vector3, target: Vector3, colour: Color, energy: float, angle := 30.0, light_range := 12.0,
		fog_energy := 0.0, shadows := true) -> SpotLight3D:
	var light := SpotLight3D.new()
	add_child(light)
	var up := Vector3.FORWARD if absf((target - pos).normalized().y) > 0.95 else Vector3.UP
	light.look_at_from_position(pos, target, up)
	light.light_color = colour
	light.light_energy = energy
	light.spot_angle = angle
	light.spot_range = light_range
	light.light_volumetric_fog_energy = fog_energy
	light.shadow_enabled = shadows
	return light


## Key light from the camera's left and a rim light behind the character, so it reads
## clearly against any backdrop.
func _stage_lights(key: Color, key_energy: float, rim: Color, rim_energy: float) -> void:
	_spot(Vector3(-2.6, 3.6, 4.2), Vector3(0, 1.0, 0), key, key_energy, 30.0, 12.0)
	_spot(Vector3(1.6, 3.2, -3.0), Vector3(0, 1.3, 0), rim, rim_energy, 35.0, 9.0, 0.0, false)


# --- Materials and props -------------------------------------------------------------

func _mat(key: String, colour: Color, style := "noise", seed := 1, tint := Color(0, 0, 0, 0), variation := 0.1) -> StandardMaterial3D:
	return PixelTex.material(PixelTex.make(key, colour, style, 32, variation, seed, tint))


func _glow(colour: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	return m


## Swaying foliage material for LowPoly.cross_strip MultiMeshes.
func _foliage(tex: Texture2D, tip: Color, hanging: bool, sway: float, speed := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE_SHADER
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("tip_color", tip)
	m.set_shader_parameter("hanging", hanging)
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("speed", speed)
	return m


func _place(mesh: Mesh, mat: Material, pos: Vector3, rotation_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rotation_deg
	mi.scale = scl
	add_child(mi)
	return mi


func _scatter(mesh: Mesh, mat: Material, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mmi


## Low-poly flames with a flickering light and rising embers.
func _fire(pos: Vector3, size := 1.0, light_energy := 3.0) -> void:
	var outer := _glow(Color(1.0, 0.38, 0.06), 4.0)
	var inner := _glow(Color(1.0, 0.8, 0.3), 6.0)
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		var offset := Vector3(cos(a), 0.0, sin(a)) * 0.13 * size
		_flames.append(_place(LowPoly.spire(0.17 * size, 0.75 * size * (1.0 - 0.18 * i), 5, 0.3, i + 3), outer, pos + offset))
	_flames.append(_place(LowPoly.spire(0.11 * size, 0.5 * size, 5, 0.2, 9), inner, pos))
	_omni(pos + Vector3(0, 0.7 * size, 0), Color(1.0, 0.55, 0.22), light_energy, 8.0 * size, true, true)
	_motes(pos + Vector3(0, 0.5 * size, 0), Vector3(0.18, 0.1, 0.18) * size, 18, Color(1.0, 0.45, 0.12), 0.035, 5.0,
			1.6, Vector3(0, 1.3, 0), 0.5)


## Floating particles: embers, dust, spores, fireflies or mosquitoes. With `glow` > 0 they
## are emissive and bloom; with 0 they are flat specks of `colour`. They drift along
## `velocity` and wander with `turbulence`, fading in and out over `lifetime` seconds.
func _motes(pos: Vector3, extents: Vector3, amount: int, colour: Color, size: float, glow: float,
		lifetime := 4.0, velocity := Vector3.ZERO, turbulence := 0.0, wander := 0.2) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.gravity = Vector3.ZERO
	if velocity == Vector3.ZERO:
		pm.spread = 180.0
		pm.initial_velocity_min = 0.0
		pm.initial_velocity_max = wander
	else:
		pm.direction = velocity.normalized()
		pm.spread = 20.0
		pm.initial_velocity_min = velocity.length() * 0.6
		pm.initial_velocity_max = velocity.length()
	if turbulence > 0.0:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = turbulence
		pm.turbulence_noise_scale = 1.2
		pm.turbulence_noise_speed_random = 1.0
		pm.turbulence_influence_min = 0.3
		pm.turbulence_influence_max = 0.8
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp

	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = colour
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = glow
	else:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = m

	var p := GPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.process_material = pm
	p.draw_pass_1 = quad
	var reach := extents + (velocity.abs() + Vector3.ONE * (wander + turbulence)) * lifetime
	p.visibility_aabb = AABB(-reach, reach * 2.0)
	add_child(p)
	return p
