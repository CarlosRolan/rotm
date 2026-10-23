extends Node3D
## Greybox test level for tuning movement and feel. Built in code so obstacles are easy
## to move around while we iterate. Only basic sun + sky lighting for now.
##
## Areas (spawn at the origin, facing -Z):
##   ramps 10..50 degrees ............ east (+X)
##   stepping-stone paths ............ west (-X)
##   rocky field ..................... north, through the gate
##   stairs (0.2 m and 0.4 m steps) .. north-east
##   climbing walls 0.6..3.2 m ....... south (+Z), behind the ruins
##
## Debug: run with `-- --screenshot=<file.png>` to save frames and quit. Options:
##   --shot-yaw=<deg> --shot-pitch=<deg> --shot-zoom=<m>   camera
##   --shot-pos=<x,y,z> --shot-face=<deg>                   start position / facing
##   --shot-walk=<deg> --shot-speed=<m/s>                   walk this world heading
##   --shot-jump=<frame,frame,...>                          press jump on these frames
##   --shot-wait=<frames> --shot-count=<n> --shot-every=<frames>   burst of numbered shots

const GROUND_SIZE := 160.0

var _grass: StandardMaterial3D
var _dirt: StandardMaterial3D
var _stone: StandardMaterial3D
var _bricks: StandardMaterial3D
var _dark_bricks: StandardMaterial3D
var _wood: StandardMaterial3D
var _rock: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	_make_materials()
	_build_lighting()
	_build_ground()
	_build_wall_gate(Vector3(0, 0, -14))
	_build_ruins(Vector3(0, 0, 12))
	_build_ramps(Vector3(10, 0, -3))
	_build_stairs(Vector3(36, 0, -3))
	_build_stepping_stones(Vector3(-10, 0, -2))
	_build_rocky_field(Vector3(0, 0, -26), Vector2(18, 18))
	_build_climb_walls(Vector3(-15, 0, 24))
	_build_tunnel(Vector3(-36, 0, 8), 10.0)

	var args := _user_args()
	if args.has("screenshot"):
		_run_screenshot(args)


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
	_hill(Vector3(-30, -8.5, -24), 10.0, 21)
	_hill(Vector3(34, -9.0, 22), 11.0, 22)


## Stone wall with a gate leading to the rocky field.
func _build_wall_gate(center: Vector3) -> void:
	var height := 4.0
	var opening := 3.0
	var segment := 7.5
	for side in [-1, 1]:
		_block(center + Vector3(side * (opening + segment) * 0.5, height * 0.5, 0), Vector3(segment, height, 0.8), _bricks)
	_block(center + Vector3(0, height - 0.6, 0), Vector3(opening, 1.2, 0.8), _bricks)


## Ramps of increasing steepness side by side, each rising to a 2 m platform.
## Floors steeper than the controller's 46 degree limit can't be walked up.
func _build_ramps(origin: Vector3) -> void:
	var height := 2.0
	var width := 3.0
	var angles := [10, 20, 30, 40, 50]
	for i in angles.size():
		var a := deg_to_rad(angles[i])
		var run := height / tan(a)
		var slope_len := sqrt(run * run + height * height)
		var x := origin.x + i * (width + 1.5)
		var thickness := 0.4
		var mid := Vector3(x, height * 0.5 - thickness * 0.5 / cos(a), origin.z - run * 0.5)
		_block(mid, Vector3(width, thickness, slope_len), _stone, Vector3(a, 0, 0))
		# Fill under the slope so it reads as solid, then a landing on top.
		_block(Vector3(x, height * 0.5, origin.z - run - 1.5), Vector3(width, height, 3.0), _stone)
		_label(Vector3(x, 0.6, origin.z + 0.8), "%d°" % angles[i])


## Two staircases: 0.2 m steps (stepped automatically) and 0.4 m steps (near the limit).
func _build_stairs(origin: Vector3) -> void:
	for s in 2:
		var rise := 0.2 if s == 0 else 0.4
		var steps := 8 if s == 0 else 5
		var x := origin.x + s * 5.0
		for i in steps:
			var h := rise * (i + 1)
			_block(Vector3(x, h * 0.5, origin.z - 0.4 - i * 0.8), Vector3(3.0, h, 0.8), _bricks)
		_label(Vector3(x, 0.6, origin.z + 0.8), "%.1f m" % rise)


## Three stepping-stone paths heading north: low, medium and high/irregular stones.
func _build_stepping_stones(origin: Vector3) -> void:
	var paths := [[0.04, 0.14, 0.75], [0.1, 0.3, 0.85], [0.15, 0.45, 1.0]]
	for p in paths.size():
		var x := origin.x - p * 4.0
		var z := origin.z
		var cfg: Array = paths[p]
		while z > origin.z - 22.0:
			var r := _rng.randf_range(0.3, 0.45)
			var h := _rng.randf_range(cfg[0], cfg[1])
			var pos := Vector3(x + _rng.randf_range(-0.5, 0.5), h * 0.5, z)
			_stone_slab(pos, r, h, Vector3(_rng.randf_range(-0.08, 0.08), _rng.randf(), _rng.randf_range(-0.08, 0.08)))
			z -= cfg[2] + _rng.randf_range(-0.1, 0.25)
		_label(Vector3(x, 0.6, origin.z + 1.5), ["low", "medium", "high"][p])


## Field of half-buried rocks of many sizes to walk and run across.
func _build_rocky_field(center: Vector3, size: Vector2) -> void:
	for i in 170:
		var p := center + Vector3(_rng.randf_range(-size.x, size.x) * 0.5, 0, _rng.randf_range(-size.y, size.y) * 0.5)
		var r := _rng.randf_range(0.08, 0.32) if i % 7 != 0 else _rng.randf_range(0.35, 0.6)
		p.y = r * _rng.randf_range(-0.2, 0.3)
		_boulder(p, r, 200 + i)


## Walls of increasing height: low ones are mantled with Space, high ones need a jump
## and a ledge grab.
func _build_climb_walls(origin: Vector3) -> void:
	var heights := [0.6, 1.0, 1.4, 2.0, 2.6, 3.2]
	for i in heights.size():
		var h: float = heights[i]
		var x := origin.x + i * 5.0
		_block(Vector3(x, h * 0.5, origin.z + 1.5), Vector3(3.5, h, 3.0), _bricks if i % 2 == 0 else _dark_bricks)
		_label(Vector3(x, 0.6, origin.z - 0.8), "%.1f m" % h)


## Tunnel running along Z: two walls and a roof, with a dirt floor.
func _build_tunnel(center: Vector3, length: float) -> void:
	var inner_width := 3.2
	var inner_height := 3.0
	var t := 0.8
	for side in [-1, 1]:
		_block(center + Vector3(side * (inner_width + t) * 0.5, inner_height * 0.5, 0), Vector3(t, inner_height, length), _dark_bricks)
	_block(center + Vector3(0, inner_height + t * 0.5, 0), Vector3(inner_width + t * 2.0, t, length), _dark_bricks)
	_decal_box(center + Vector3(0, 0.01, 0), Vector3(inner_width, 0.02, length + 2.0), _dirt)


## Ring of broken pillars.
func _build_ruins(center: Vector3) -> void:
	for i in 7:
		var a := TAU * i / 7.0
		var pos := center + Vector3(cos(a), 0, sin(a)) * 6.0
		var h := _rng.randf_range(1.2, 4.5)
		_pillar(pos, 0.5, h)
		if h > 3.5:
			_block(pos + Vector3(0, h + 0.2, 0), Vector3(1.4, 0.4, 1.4), _stone, Vector3(0, a, 0))


func _label(pos: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.01
	label.font_size = 48
	label.outline_size = 12
	add_child(label)


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


func _stone_slab(pos: Vector3, radius: float, height: float, rot: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.85
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	mesh.rings = 1
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	_add_visual_and_shape(body, mesh, _stone, shape)
	add_child(body)


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
	_add_visual_and_shape(body, _faceted_sphere(radius, seed, 8, 5, 0.3), _rock, shape)
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


func _run_screenshot(args: Dictionary) -> void:
	var player := $Player
	var yaw: Node3D = $Player/CameraYaw
	var pitch: Node3D = $Player/CameraYaw/CameraPitch
	var arm: SpringArm3D = $Player/CameraYaw/CameraPitch/SpringArm
	var rig: SaurusRig = $Player/SaurusRig
	if args.has("shot-pos"):
		var p: PackedFloat64Array = args["shot-pos"].split_floats(",")
		player.global_position = Vector3(p[0], p[1], p[2])
	await get_tree().physics_frame
	await get_tree().physics_frame
	rig.reset_feet()
	if args.has("shot-face"):
		rig.rotation.y = deg_to_rad(float(args["shot-face"]))
	if args.has("shot-yaw"):
		yaw.rotation.y = deg_to_rad(float(args["shot-yaw"]))
	if args.has("shot-pitch"):
		pitch.rotation.x = deg_to_rad(float(args["shot-pitch"]))
	if args.has("shot-zoom"):
		player.set("_zoom", float(args["shot-zoom"]))
		arm.spring_length = float(args["shot-zoom"])
	if args.has("shot-walk"):
		var heading := deg_to_rad(float(args["shot-walk"]))
		player.debug_move = Vector3(-sin(heading), 0, -cos(heading))
		player.debug_speed = float(args.get("shot-speed", "4.5"))
	var jumps := PackedInt32Array()
	if args.has("shot-jump"):
		for s in args["shot-jump"].split(","):
			jumps.append(int(s))

	var wait := int(args.get("shot-wait", "45"))
	var count := int(args.get("shot-count", "1"))
	var every := int(args.get("shot-every", "10"))
	var path: String = args["screenshot"]
	var frame := 0
	var taken := 0
	while taken < count:
		await get_tree().physics_frame
		frame += 1
		if frame in jumps:
			player.debug_jump = true
		if frame >= wait and (frame - wait) % every == 0:
			await RenderingServer.frame_post_draw
			var out := path if count == 1 else path.replace(".png", "_%02d.png" % taken)
			get_viewport().get_texture().get_image().save_png(out)
			taken += 1
	get_tree().quit()
