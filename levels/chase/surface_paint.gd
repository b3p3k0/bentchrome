extends RefCounted
## Route 666's surfaces wear the arenas' paint. Every driveable surface on the
## highway carries the colour and speckle material a hand-built arena gives
## that surface — Catalog.TERRAIN_COLORS + LevelLoader._speckle_material, the
## one shared standard — so the dirt here is the dirt you learned in Downtown
## Derby and "if I hit that, my car will do X" travels between levels. The
## arenas' asphalt has no shared table (every scene authors the same
## SM_asphalt numbers by hand), so this is where the chase keeps its copy,
## test-locked against downtown's. RoadGrid is the arenas' GridFloor clipped
## to the asphalt strip: the same faint 128px survey lines, world-anchored.

const Catalog := preload("res://levels/entity_catalog.gd")
const Loader := preload("res://levels/level_loader.gd")
const SPECKLE_SHADER := preload("res://shaders/terrain_speckle.gdshader")

## The arenas' worn tarmac (downtown / freeway / suburbs / capital / drivers_ed SM_asphalt).
const ASPHALT := Color(0.11, 0.11, 0.13)
const ASPHALT_SPECKLE := {"speckle": Color(0.06, 0.06, 0.08), "density": 0.4, "intensity": 0.35, "scale": 6.0}
## Poured concrete — Ground Floor Gore's slab family (its 0.44-0.47 greys sit
## under a dusk tint; this is that read in daylight), road handling: the toll
## plaza and the truckstop forecourt read as pavement because they ARE.
const CONCRETE := Color(0.36, 0.37, 0.40)
const CONCRETE_SPECKLE := {"speckle": Color(0.29, 0.30, 0.33), "density": 0.4, "intensity": 0.35, "scale": 6.0}
const GRID := 128.0
const GRID_LINE := Color(1, 1, 1, 0.08)   # GridFloor's default

static var _cache: Dictionary = {}

## The zone's Vis in arena dress: catalog colour + the cached speckle material
## for its surface. Road/unknown surfaces get the asphalt grain.
static func dress(vis: Polygon2D, kind: StringName) -> void:
	var key := String(kind)
	if Catalog.TERRAIN_COLORS.has(key):
		vis.color = Catalog.TERRAIN_COLORS[key]
		vis.material = Loader._speckle_material(key)
	else:
		vis.color = ASPHALT
		vis.material = asphalt_material()

static func terrain_material(kind: StringName) -> ShaderMaterial:
	var mat: ShaderMaterial = Loader._speckle_material(String(kind))
	return mat if mat != null else asphalt_material()

static func asphalt_material() -> ShaderMaterial:
	return _flat("asphalt", ASPHALT, ASPHALT_SPECKLE)

static func concrete_material() -> ShaderMaterial:
	return _flat("concrete", CONCRETE, CONCRETE_SPECKLE)

static func _flat(key: String, base: Color, params: Dictionary) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = SPECKLE_SHADER
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("speckle_color", params["speckle"])
	mat.set_shader_parameter("density", params["density"])
	mat.set_shader_parameter("intensity", params["intensity"])
	mat.set_shader_parameter("scale", params["scale"])
	mat.set_shader_parameter("shimmer", 0.0)
	_cache[key] = mat
	return mat

## The flat tone a surface reads as once its translucent arena colour lies
## over asphalt — what accents painted ON it (ruts, damp patches) key off.
static func tone(kind: StringName) -> Color:
	var c: Color = Catalog.TERRAIN_COLORS.get(String(kind), ASPHALT)
	return Color(ASPHALT.r, ASPHALT.g, ASPHALT.b).lerp(Color(c.r, c.g, c.b), c.a)

## The survey grid, clipped to the road: horizontal lines where the asphalt
## is at that world y, vertical lines over the stretch of each station leg
## where the asphalt covers that world x. Chunk-local like everything else
## (start_d anchors the lines to world y so they never slide at a seam).
class RoadGrid extends Node2D:
	var ds: Array = []
	var cx: Array = []
	var half: Array = []
	var start_d := 0.0

	func _draw() -> void:
		if ds.size() < 2:
			return
		var len: float = ds[ds.size() - 1]
		# Horizontal: world y = k*GRID -> local y = world y + start_d.
		var k := floorf((-start_d) / GRID)
		while k * GRID + start_d >= -len:
			var y := k * GRID + start_d
			if y <= 0.0:
				var d := -y
				var si := _leg_at(d)
				var t := _leg_t(si, d)
				var c: float = lerpf(cx[si], cx[si + 1], t)
				var h: float = lerpf(half[si], half[si + 1], t)
				draw_line(Vector2(c - h, y), Vector2(c + h, y), GRID_LINE, 1.0)
			k -= 1.0
		# Vertical: for each leg, each world x on the grid inside the leg's
		# span draws over the t-range where left(t) <= x <= right(t).
		for i in ds.size() - 1:
			var l0: float = cx[i] - half[i]
			var r0: float = cx[i] + half[i]
			var l1: float = cx[i + 1] - half[i + 1]
			var r1: float = cx[i + 1] + half[i + 1]
			var y0: float = -ds[i]
			var y1: float = -ds[i + 1]
			var kx := ceilf(minf(l0, l1) / GRID)
			while kx * GRID <= maxf(r0, r1):
				var x := kx * GRID
				var t_lo := 0.0
				var t_hi := 1.0
				# left(t) <= x
				if absf(l1 - l0) > 0.001:
					var tl := (x - l0) / (l1 - l0)
					if l1 > l0:
						t_hi = minf(t_hi, tl)
					else:
						t_lo = maxf(t_lo, tl)
				elif l0 > x:
					t_hi = -1.0
				# right(t) >= x
				if absf(r1 - r0) > 0.001:
					var tr := (x - r0) / (r1 - r0)
					if r1 > r0:
						t_lo = maxf(t_lo, tr)
					else:
						t_hi = minf(t_hi, tr)
				elif r0 < x:
					t_hi = -1.0
				if t_hi > t_lo:
					draw_line(Vector2(x, lerpf(y0, y1, t_lo)), Vector2(x, lerpf(y0, y1, t_hi)), GRID_LINE, 1.0)
				kx += 1.0

	func _leg_at(d: float) -> int:
		for i in ds.size() - 1:
			if d <= float(ds[i + 1]):
				return i
		return ds.size() - 2

	func _leg_t(i: int, d: float) -> float:
		var a: float = ds[i]
		var b: float = ds[i + 1]
		return 0.0 if b <= a else clampf((d - a) / (b - a), 0.0, 1.0)
