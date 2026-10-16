extends Node3D
## Greybox test level for tuning movement and feel. Built in code so obstacles are easy
## to move around while we iterate. Only basic sun + sky lighting for now: no fog,
## volumetrics or post effects yet.
##
## Debug: run with `-- --screenshot=<file.png>` to save a frame and quit. Optional
## `--shot-yaw=<deg>`, `--shot-pitch=<deg>`, `--shot-zoom=<m>` frame the camera; `--shot-speed=<m/s>` poses the gait.

const GROUND_SIZE := 120.0

var _grass: StandardMaterial3D
var _dirt: StandardMaterial3D
var _stone: StandardMaterial3D
var _bricks: StandardMaterial3D
var _dark_bricks: StandardMaterial3D
var _wood: StandardMaterial3D
var _rock: StandardMaterial3D


func _ready() -> void:
	_make_materials()
	_build_lighting()
	_build_ground()
	_build_wall_gate(Vector3(0, 0, -14))
	_build_tunnel(Vector3(-12, 0, 6), 10.0)
	_build_ramp_platform(Vector3(12, 0, 6))
	_build_ruins(Vector3(0, 0, 14))
	_build_props()

	var args := _user_args()
	if args.has("screenshot"):
		_take_screenshot(args)


func _make_materials() -> void:
	_grass = PixelTex.material(PixelTex.make("grass", Color(0.27, 0.33, 0.16), "speckle", 32, 0.09, 1, Color(0.36, 0.33, 0.17, 0.6)))
	_dirt = PixelTex.material(PixelTex.make("dirt", Color(0.30, 0.24, 0.17), "speckle", 32, 0.12, 2))
	_stone = PixelTex.material(PixelTex.make("stone", Color(0.42, 0.41, 0.38), "noise", 32, 0.12, 3, Color(0.38, 0.40, 0.33, 0.5)))
	_bricks = PixelTex.material(PixelTex.make("bricks", Color(0.45, 0.43, 0.39), "bricks", 32, 0.1, 4))
	_dark_bricks = PixelTex.material(PixelTex.make("dark_bricks", Color(0.26, 0.26, 0.25), "bricks", 32, 0.1, 5))
	_wood = PixelTex.material(PixelTex.make("wood", Color(0.36, 0.25, 0.15), "planks", 32, 0.08, 6))
	_rock = PixelTex.material(PixelTex.make("rock", Color(0.33, 0.33, 0.31), "noise", 32, 0.16, 11, Color(0.30, 0.34, 0.24, 0.4)))


func _build_lighting() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.38, 0.48)
	sky_mat.sky_horizon_color = Color(0.60, 0.60, 0.56)
	sky_mat.ground_horizon_color = Color(0.45, 0.43, 0.40)
	sky_mat.ground_bottom_color = Color(0.15, 0.14, 0.12)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)


func _build_ground() -> void:
	_block(Vector3(0, -0.5, 0), Vector3(GROUND_SIZE, 1, GROUND_SIZE), _grass)
	# Gentle hills to test slopes (sphere caps poking out of the ground, under 45 degrees).
	_hill(Vector3(-22, -8.5, -20), 10.0, 21)
	_hill(Vector3(24, -9.0, -18), 11.0, 22)


## Stone wall with a gate opening to walk through.
func _build_wall_gate(center: Vector3) -> void:
	var height := 4.0
	var thickness := 0.8
	var opening := 3.0
	var segment := 5.5
	for side in [-1, 1]:
		_block(center + Vector3(side * (opening + segment) * 0.5, height * 0.5, 0), Vector3(segment, height, thickness), _bricks)
	_block(center + Vector3(0, height - 0.6, 0), Vector3(opening, 1.2, thickness), _bricks)


## Tunnel running along Z: two walls and a roof, with a dirt floor.
func _build_tunnel(center: Vector3, length: float) -> void:
	var inner_width := 3.2
	var inner_height := 3.0
	var t := 0.8
	for side in [-1, 1]:
		_block(center + Vector3(side * (inner_width + t) * 0.5, inner_height * 0.5, 0), Vector3(t, inner_height, length), _dark_bricks)
	_block(center + Vector3(0, inner_height + t * 0.5, 0), Vector3(inner_width + t * 2.0, t, length), _dark_bricks)
	_decal_box(center + Vector3(0, 0.01, 0), Vector3(inner_width, 0.02, length + 2.0), _dirt)


## Raised platform reached by an 18 degree ramp from the -Z side.
func _build_ramp_platform(center: Vector3) -> void:
	var height := 1.5
	var size := 5.0
	_block(center + Vector3(0, height * 0.5, 0), Vector3(size, height, size), _stone)
	var angle := deg_to_rad(18.0)
	var run := height / tan(angle)
	var slope_len := sqrt(run * run + height * height)
	var thickness := 0.3
	var edge_z := center.z - size * 0.5
	var mid := Vector3(center.x, height * 0.5 - thickness * 0.5 / cos(angle), edge_z - run * 0.5)
	_block(mid, Vector3(3.0, thickness, slope_len), _wood, Vector3(-angle, 0, 0))
	# Crates on top for scale.
	_block(center + Vector3(1.2, height + 0.5, 1.2), Vector3.ONE, _wood)


## Ring of broken pillars.
func _build_ruins(center: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 7:
		var a := TAU * i / 7.0
		var pos := center + Vector3(cos(a), 0, sin(a)) * 6.0
		var h := rng.randf_range(1.2, 4.5)
		_pillar(pos, 0.5, h)
		if h > 3.5:
			_block(pos + Vector3(0, h + 0.2, 0), Vector3(1.4, 0.4, 1.4), _stone, Vector3(0, a, 0))


func _build_props() -> void:
	# Low rectangular block and a tall monolith.
	_block(Vector3(6, 0.6, -6), Vector3(3, 1.2, 2), _stone)
	_block(Vector3(-7, 2.5, -8), Vector3(1.5, 5, 1.5), _dark_bricks, Vector3(0, 0.3, 0))
	# Narrow gap between two blocks: 1.0 m wide, the 0.8 m wide capsule just fits.
	_block(Vector3(-4.0, 1, -3), Vector3(1.5, 2, 2), _bricks)
	_block(Vector3(-1.5, 1, -3), Vector3(1.5, 2, 2), _bricks)
	# Crate stack.
	for p in [Vector3(4, 0.5, 3), Vector3(5.1, 0.5, 3.2), Vector3(4.5, 1.5, 3.1)]:
		_block(p, Vector3.ONE, _wood, Vector3(0, p.x * 0.3, 0))
	# Boulders, half buried.
	var rocks := [[Vector3(8, 0.2, -12), 1.2], [Vector3(-9, 0.1, -2), 0.9], [Vector3(3, 0.0, 9), 0.7],
			[Vector3(-16, 0.3, -6), 1.6], [Vector3(16, 0.2, 14), 1.3], [Vector3(-3, 0.0, 18), 0.8]]
	for i in rocks.size():
		_boulder(rocks[i][0], rocks[i][1], 100 + i)


func _block(pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	_add_visual_and_shape(body, mesh, mat, shape)
	add_child(body)
	return body


func _pillar(pos: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, height * 0.5, 0)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.9
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	_add_visual_and_shape(body, mesh, _stone, shape)
	add_child(body)


func _boulder(pos: Vector3, radius: float, seed: int) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = seed * 1.7
	var shape := SphereShape3D.new()
	shape.radius = radius * 0.9
	_add_visual_and_shape(body, _faceted_sphere(radius, seed, 8, 5, 0.35), _rock, shape)
	add_child(body)


func _hill(pos: Vector3, radius: float, seed: int) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := SphereShape3D.new()
	shape.radius = radius
	_add_visual_and_shape(body, _faceted_sphere(radius, seed, 24, 12, 0.03), _grass, shape)
	add_child(body)


## Visual-only box (no collision), e.g. floor detail.
func _decal_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _add_visual_and_shape(body: StaticBody3D, mesh: Mesh, mat: Material, shape: Shape3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)


## Low-poly sphere with noise-displaced vertices and flat-shaded faces, for rocks and hills.
func _faceted_sphere(radius: float, seed: int, segments: int, rings: int, jitter: float) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = segments
	sphere.rings = rings
	var arrays := sphere.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 1.2 / radius

	var out_verts := PackedVector3Array()
	var out_normals := PackedVector3Array()
	for i in range(0, indices.size(), 3):
		var tri: Array[Vector3] = []
		for k in 3:
			var v := verts[indices[i + k]]
			tri.append(v * (1.0 + noise.get_noise_3dv(v) * jitter))
		var n := (tri[2] - tri[0]).cross(tri[1] - tri[0])
		if n.length_squared() < 1e-10:
			continue  # degenerate triangle at a pole
		n = n.normalized()
		if n.dot(tri[0] + tri[1] + tri[2]) < 0.0:
			n = -n  # always point away from the centre
		for k in 3:
			out_verts.append(tri[k])
			out_normals.append(n)

	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = out_verts
	out[Mesh.ARRAY_NORMAL] = out_normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


func _user_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	return args


func _take_screenshot(args: Dictionary) -> void:
	var yaw: Node3D = $Player/CameraYaw
	var pitch: Node3D = $Player/CameraYaw/CameraPitch
	var arm: SpringArm3D = $Player/CameraYaw/CameraPitch/SpringArm
	for i in 5:
		await get_tree().process_frame
	if args.has("shot-yaw"):
		yaw.rotation.y = deg_to_rad(float(args["shot-yaw"]))
	if args.has("shot-pitch"):
		pitch.rotation.x = deg_to_rad(float(args["shot-pitch"]))
	if args.has("shot-speed"):
		$Player.debug_speed = float(args["shot-speed"])
	if args.has("shot-zoom"):
		$Player.set("_zoom", float(args["shot-zoom"]))
		arm.spring_length = float(args["shot-zoom"])
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args["screenshot"])
	get_tree().quit()
