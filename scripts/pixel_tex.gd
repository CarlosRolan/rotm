class_name PixelTex
extends RefCounted
## Small procedural textures sampled without smoothing: the source of the Valheim-style
## pixel look. Models stay medium-poly and render at full resolution; only the surfaces
## are pixelated.

## How many texels cover one meter of world geometry. Lower = chunkier pixels.
const WORLD_PIXELS_PER_METER := 20.0

static var _cache: Dictionary = {}


## Returns a tileable texture of `base` colour with clumpy noise plus a surface pattern.
## style: "noise", "speckle", "bricks", "planks", "scales", "bands".
## If `tint` has alpha, a second noise layer blends patches of it in, giving the uneven,
## hand-painted colour of Valheim textures instead of a flat hue.
static func make(key: String, base: Color, style := "noise", size := 32, variation := 0.1, seed := 1, tint := Color(0, 0, 0, 0)) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.15
	var clumps := noise.get_seamless_image(size, size)
	noise.seed = seed + 101
	noise.frequency = 0.08
	var patches := noise.get_seamless_image(size, size)
	# "plates": Voronoi cells with dark outlines, like the painted scale plates on the minis.
	var cells: Image = null
	if style == "plates":
		var cell_noise := FastNoiseLite.new()
		cell_noise.seed = seed
		cell_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		cell_noise.frequency = 0.12
		cell_noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		cells = cell_noise.get_seamless_image(size, size, false, false, 0.0)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var shade := (clumps.get_pixel(x, y).r - 0.5) * variation * 2.0
			shade += rng.randf_range(-variation, variation) * 0.35
			shade += _pattern(style, x, y, size, rng)
			if cells:
				var edge := cells.get_pixel(x, y).r
				if edge < 0.14:
					shade -= 0.45
				elif edge < 0.28:
					shade -= 0.2
				else:
					shade += (edge - 0.28) * 0.3  # plate centres catch a little light
			var colour := base.lerp(tint, patches.get_pixel(x, y).r * tint.a) if tint.a > 0.0 else base
			img.set_pixel(x, y, _shade(colour, shade))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Matte material with nearest-neighbour sampling and triplanar mapping, so texel size is
## the same on every surface regardless of how a mesh is scaled.
static func material(tex: Texture2D, pixels_per_meter := WORLD_PIXELS_PER_METER, world_space := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.95
	m.metallic_specular = 0.2
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world_space
	m.uv1_scale = Vector3.ONE * (pixels_per_meter / tex.get_width())
	return m


@warning_ignore("integer_division")
static func _pattern(style: String, x: int, y: int, size: int, rng: RandomNumberGenerator) -> float:
	match style:
		"speckle":
			var r := rng.randf()
			if r < 0.08:
				return -0.2
			if r > 0.95:
				return 0.15
		"bricks":
			var bh := size / 4
			var bw := size / 2
			var row := y / bh
			var bx := (x + (bw / 2 if row % 2 == 1 else 0)) % bw
			var by := y % bh
			if by == 0 or bx == 0:
				return -0.35
			if by == 1:
				return 0.06
		"planks":
			var pw := size / 4
			if x % pw == 0:
				return -0.3
			if (x * 13 + (y / 6) * 7) % 5 == 0:
				return -0.08
		"scales":
			# Soft, irregular scale rows: a hint of texture under the painted colour.
			var sw := 4
			var sh := 3
			var row := y / sh
			var sx := (x + (sw / 2 if row % 2 == 1 else 0)) % sw
			var sy := y % sh
			if sy == sh - 1 and rng.randf() < 0.7:
				return -0.1
			if sx == 0 and rng.randf() < 0.5:
				return -0.05
			return 0.02
		"bands":
			if y % 4 == 3:
				return -0.08
			return 0.03
	return 0.0


static func _shade(c: Color, amount: float) -> Color:
	return c.lightened(amount) if amount > 0.0 else c.darkened(-amount)
