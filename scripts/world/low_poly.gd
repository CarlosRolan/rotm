class_name LowPoly
extends RefCounted
## Flat-shaded low-poly mesh builders for scenery: rocks, hills, spires, trunks, branches,
## tusks, stakes, terrain, ponds and hanging fronds. The meshes carry no UVs; PixelTex
## materials map them triplanar.


## Low-poly sphere with noise-displaced vertices and flat-shaded faces, for rocks and hills.
## `inward` turns the faces to the inside, for cave domes seen from within.
static func faceted_sphere(radius: float, seed: int, segments: int, rings: int, jitter: float, inward := false) -> ArrayMesh:
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

	var b := _Builder.new()
	for i in range(0, indices.size(), 3):
		var tri: Array[Vector3] = []
		for k in 3:
			var v := verts[indices[i + k]]
			tri.append(v * (1.0 + noise.get_noise_3dv(v) * jitter))
		# Faces point away from the centre, or toward it for a dome seen from inside.
		var hint := (tri[0] + tri[1] + tri[2]) * (2.0 if inward else 0.0)
		b.tri(tri[0], tri[1], tri[2], hint)
	return b.commit()


## Generalised cylinder through `points`, with radius `radii[i]` at each point. A zero
## radius closes it in a point (stakes, horns, stalactites); otherwise the ends are capped.
## `jitter` roughens each ring so bark and rock don't look machined.
static func tube(points: PackedVector3Array, radii: PackedFloat32Array, sides := 6, jitter := 0.0, seed := 0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var count := points.size()
	var axis := Vector3.ZERO
	var rings: Array[PackedVector3Array] = []
	for i in count:
		var dir := (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized()
		if i == 0:
			axis = Vector3.FORWARD if absf(dir.dot(Vector3.RIGHT)) > 0.9 else Vector3.RIGHT
		axis = (axis - dir * axis.dot(dir)).normalized()  # carried along so the rings don't twist
		var side := dir.cross(axis)
		var ring := PackedVector3Array()
		for s in sides:
			var a := TAU * s / sides
			var r := radii[i] * (1.0 + rng.randf_range(-jitter, jitter))
			ring.append(points[i] + (axis * cos(a) + side * sin(a)) * r)
		rings.append(ring)

	var b := _Builder.new()
	for i in count - 1:
		var inside := (points[i] + points[i + 1]) * 0.5
		for s in sides:
			var n := (s + 1) % sides
			b.quad(rings[i][s], rings[i][n], rings[i + 1][n], rings[i + 1][s], inside)
	if radii[0] > 0.0:
		b.fan(points[0], rings[0], points[0] + (points[1] - points[0]).normalized())
	if radii[count - 1] > 0.0:
		b.fan(points[count - 1], rings[count - 1], points[count - 1] - (points[count - 1] - points[count - 2]).normalized())
	return b.commit()


## Tapering spike or rock column standing on the origin, `height` tall, wobbling a little
## sideways. `top` > 0 leaves a flat top that fraction of the base radius (mesas, stumps).
static func spire(radius: float, height: float, sides := 6, jitter := 0.15, seed := 0, top := 0.0, segments := 3) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in segments + 1:
		var t := float(i) / segments
		var wobble := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * radius * jitter * t
		points.append(Vector3(0.0, height * t, 0.0) + wobble)
		radii.append(radius * lerpf(1.0, top, t))
	return tube(points, radii, sides, jitter * 0.5, seed)


## Flat irregular polygon facing up, centred on the origin: ponds, lily pads, rugs.
## `gap` leaves that many wedges out (the notch of a lily pad).
static func disc(radius: float, sides := 12, jitter := 0.0, seed := 0, gap := 0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ring := PackedVector3Array()
	for s in sides:
		var a := TAU * s / sides
		ring.append(Vector3(cos(a), 0.0, sin(a)) * radius * (1.0 + rng.randf_range(-jitter, jitter)))
	var b := _Builder.new()
	for s in range(gap, sides):
		b.tri(Vector3.ZERO, ring[s], ring[(s + 1) % sides], Vector3.DOWN)
	return b.commit()


## Ground grid `size` metres across with `cells` squares per side, flat-shaded, its height
## at each corner given by `height.call(x, z)`.
static func terrain(size: float, cells: int, height: Callable) -> ArrayMesh:
	var step := size / cells
	var corners := PackedVector3Array()
	for j in cells + 1:
		for i in cells + 1:
			var x := -size * 0.5 + i * step
			var z := -size * 0.5 + j * step
			corners.append(Vector3(x, height.call(x, z), z))
	var b := _Builder.new()
	for j in cells:
		for i in cells:
			var a := corners[j * (cells + 1) + i]
			var c := corners[(j + 1) * (cells + 1) + i + 1]
			b.quad(a, corners[j * (cells + 1) + i + 1], c, corners[(j + 1) * (cells + 1) + i], (a + c) * 0.5 + Vector3.DOWN)
	return b.commit()


## Two crossed strips one unit long, split into `segments` rows so a swaying vertex shader
## can bend them: hanging from the origin down to y = -1 (willow fronds, vines), or
## standing up to y = 1 (grass, reeds). Scale the instance's Y to set the length.
static func cross_strip(width: float, segments := 4, hanging := true) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var dir := -1.0 if hanging else 1.0
	for plane in 2:
		var across := Vector3(width * 0.5, 0, 0) if plane == 0 else Vector3(0, 0, width * 0.5)
		var normal := Vector3.BACK if plane == 0 else Vector3.RIGHT
		for s in segments:
			var y0 := dir * float(s) / segments
			var y1 := dir * float(s + 1) / segments
			# Narrower toward the free end.
			var w0 := across * (1.0 - 0.5 * float(s) / segments)
			var w1 := across * (1.0 - 0.5 * float(s + 1) / segments)
			var quad: Array[Vector3] = [Vector3(0, y0, 0) - w0, Vector3(0, y0, 0) + w0,
					Vector3(0, y1, 0) + w1, Vector3(0, y1, 0) - w1]
			for k: int in [0, 1, 2, 0, 2, 3]:
				verts.append(quad[k])
				normals.append(normal)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Collects flat-shaded triangles, turning each one to face away from an `inside` point.
class _Builder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()

	func tri(a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
		var n := (c - a).cross(b - a)
		if n.length_squared() < 1e-12:
			return  # degenerate (pole or collapsed tip)
		n = n.normalized()
		if n.dot((a + b + c) / 3.0 - inside) < 0.0:
			# Facing inward: swap the winding so the visible side is the outside.
			var t := b
			b = c
			c = t
			n = -n
		verts.append(a)
		verts.append(b)
		verts.append(c)
		for k in 3:
			normals.append(n)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3) -> void:
		tri(a, b, c, inside)
		tri(a, c, d, inside)

	func fan(center: Vector3, ring: PackedVector3Array, inside: Vector3) -> void:
		for s in ring.size():
			tri(center, ring[s], ring[(s + 1) % ring.size()], inside)

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
