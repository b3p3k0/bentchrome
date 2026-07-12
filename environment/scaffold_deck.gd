class_name ScaffoldDeck
extends Node2D
## One rectangular floor-3 scaffold segment: visible steel deck, floor tag,
## road handling override, classified edges, and the dock-style underpass fade.
## Every edge is exactly one of: RAIL (full guard static), GATE (an opening of
## gate_width covered by a neighboring deck or ramp mouth; the two shoulders
## get Gate* statics), DROP (authored bail-out lip - no static, danger paint),
## or seam (unlisted - fully covered by a neighbor, nothing built or drawn).
## gate_offset shifts every gate opening off its edge center; it is shared by
## all gate edges on the deck, so only single-gate decks should use it.

const Floors := preload("res://game/floors.gd")
const FloorZoneScript := preload("res://environment/floor_zone.gd")
const TerrainZoneScript := preload("res://environment/terrain_zone.gd")
const UnderFade := preload("res://environment/under_fade.gd")

const EDGE_TOP := 1
const EDGE_RIGHT := 2
const EDGE_BOTTOM := 4
const EDGE_LEFT := 8
const RAIL_W := 10.0
const PLANK := 32.0
const BAY := 128.0
const POST_INSET := 14.0
const POST_SPACING := 256.0
const SHADOW_OFFSET := Vector2(18, 24)
const SHADOW_ALPHA := 0.24

@export var size := Vector2(448, 448)
@export var floor_index := 3
@export_flags("Top", "Right", "Bottom", "Left") var rail_edges := 0
@export_flags("Top", "Right", "Bottom", "Left") var gate_edges := 0
@export var gate_width := 256.0
@export var gate_offset := 0.0
@export_flags("Top", "Right", "Bottom", "Left") var drop_edges := 0
@export var terrain_type: StringName = &"road"
@export var deck_color := Color(0.40, 0.42, 0.46)
@export var edge_color := Color(0.92, 0.72, 0.18)

var _under_area: Area2D

func _ready() -> void:
	z_index = 1
	_add_floor()
	_add_terrain()
	_add_rails()
	_add_understructure()
	_add_underpass()
	queue_redraw()

## Ground-level structure (cast shadow, support posts, base plates) lives on
## its own canvas so it stays visible while the deck plane fades under traffic.
func _add_understructure() -> void:
	var under := Understructure.new()
	under.name = "Understructure"
	under.z_index = -1
	add_child(under)

class Understructure:
	extends Node2D
	func _draw() -> void:
		var deck := get_parent() as ScaffoldDeck
		if deck != null:
			deck._paint_understructure(self)

func _add_floor() -> void:
	var zone := FloorZoneScript.new() as FloorZone
	zone.name = "Floor"
	zone.floor_index = floor_index
	zone.size = size
	add_child(zone)

func _add_terrain() -> void:
	var zone := TerrainZoneScript.new() as TerrainZone
	zone.name = "Terrain"
	zone.terrain_type = terrain_type
	zone.terrain_priority = Ramp.TERRAIN_PRIORITY
	zone.collision_layer = 128
	zone.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	zone.add_child(col)
	add_child(zone)

func _add_rails() -> void:
	for edge: int in [EDGE_TOP, EDGE_RIGHT, EDGE_BOTTOM, EDGE_LEFT]:
		var extent := _edge_extent(edge)
		if (rail_edges & edge) != 0:
			_add_edge_static("Rail%d" % edge, edge, -extent, extent)
		elif (gate_edges & edge) != 0:
			var lo := gate_offset - gate_width * 0.5
			var hi := gate_offset + gate_width * 0.5
			if -extent < lo:
				_add_edge_static("Gate%d_a" % edge, edge, -extent, lo)
			if hi < extent:
				_add_edge_static("Gate%d_b" % edge, edge, hi, extent)

## Half-length of an edge along its own axis (x for Top/Bottom, y for Left/Right).
func _edge_extent(edge: int) -> float:
	return size.x * 0.5 if edge in [EDGE_TOP, EDGE_BOTTOM] else size.y * 0.5

## One guard static covering [from_a, to_a] along the edge axis.
func _add_edge_static(body_name: String, edge: int, from_a: float, to_a: float) -> void:
	var half := size * 0.5
	var mid := (from_a + to_a) * 0.5
	var span := to_a - from_a
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 4 | Floors.floor_bit(floor_index)
	body.collision_mask = 0
	var body_size: Vector2
	match edge:
		EDGE_TOP:
			body.position = Vector2(mid, -half.y)
			body_size = Vector2(span, RAIL_W)
		EDGE_BOTTOM:
			body.position = Vector2(mid, half.y)
			body_size = Vector2(span, RAIL_W)
		EDGE_LEFT:
			body.position = Vector2(-half.x, mid)
			body_size = Vector2(RAIL_W, span)
		_:
			body.position = Vector2(half.x, mid)
			body_size = Vector2(RAIL_W, span)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = body_size
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _add_underpass() -> void:
	_under_area = UnderFade.build_area(size)
	add_child(_under_area)

func _process(delta: float) -> void:
	if _under_area == null:
		return
	var target := UnderFade.target_alpha(_under_area, z_index)
	self_modulate.a = move_toward(self_modulate.a, target, UnderFade.SPEED * delta)

func _edge_kind(edge: int) -> StringName:
	if (rail_edges & edge) != 0:
		return &"rail"
	if (gate_edges & edge) != 0:
		return &"gate"
	if (drop_edges & edge) != 0:
		return &"drop"
	return &"seam"

## Point at coordinate `a` along the edge axis, pushed `inset` px toward the
## deck interior (negative inset reaches past the edge).
func _edge_point(edge: int, a: float, inset: float) -> Vector2:
	var half := size * 0.5
	match edge:
		EDGE_TOP:
			return Vector2(a, -half.y + inset)
		EDGE_BOTTOM:
			return Vector2(a, half.y - inset)
		EDGE_LEFT:
			return Vector2(-half.x + inset, a)
		_:
			return Vector2(half.x - inset, a)

func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), deck_color)
	_draw_grating(half)
	_draw_edge_light(half)
	_draw_wear(half)
	for edge: int in [EDGE_TOP, EDGE_RIGHT, EDGE_BOTTOM, EDGE_LEFT]:
		var extent := _edge_extent(edge)
		match _edge_kind(edge):
			&"rail":
				_draw_rail_span(edge, -extent, extent)
			&"gate":
				var lo := gate_offset - gate_width * 0.5
				var hi := gate_offset + gate_width * 0.5
				if -extent < lo:
					_draw_rail_span(edge, -extent, lo)
				if hi < extent:
					_draw_rail_span(edge, hi, extent)
			&"drop":
				_draw_drop_lip(edge, extent)
	for p in _post_points():
		draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), deck_color.lightened(0.16))
		draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), deck_color.darkened(0.35), false, 2.0)

## Steel-grating read: fine plank lines every 32px, heavier bay lines every
## 128px, both axes, phase-locked to the WORLD grid so seams between abutting
## decks carry the pattern straight across (local fallback when rotated).
func _draw_grating(half: Vector2) -> void:
	var fine := deck_color.darkened(0.12)
	var heavy := deck_color.darkened(0.26)
	var origin := global_position if rotation == 0.0 else Vector2.ZERO
	var wx := ceilf((origin.x - half.x) / PLANK) * PLANK
	while wx <= origin.x + half.x - 2.0:
		var lx := wx - origin.x
		if absf(lx) < half.x - 1.0:
			var bay_line := fposmod(wx, BAY) < 0.5
			draw_line(Vector2(lx, -half.y + 2), Vector2(lx, half.y - 2),
				heavy if bay_line else fine, 2.0 if bay_line else 1.0)
		wx += PLANK
	var wy := ceilf((origin.y - half.y) / PLANK) * PLANK
	while wy <= origin.y + half.y - 2.0:
		var ly := wy - origin.y
		if absf(ly) < half.y - 1.0:
			var bay_line := fposmod(wy, BAY) < 0.5
			draw_line(Vector2(-half.x + 2, ly), Vector2(half.x - 2, ly),
				heavy if bay_line else fine, 2.0 if bay_line else 1.0)
		wy += PLANK

## NW light: lit top/left lips, shaded bottom/right lips — only on real edges,
## so merged seams read as one continuous surface.
func _draw_edge_light(half: Vector2) -> void:
	if _edge_kind(EDGE_TOP) != &"seam":
		draw_rect(Rect2(-half, Vector2(size.x, 6)), Color(1, 1, 1, 0.10))
	if _edge_kind(EDGE_LEFT) != &"seam":
		draw_rect(Rect2(-half, Vector2(6, size.y)), Color(1, 1, 1, 0.10))
	if _edge_kind(EDGE_BOTTOM) != &"seam":
		draw_rect(Rect2(Vector2(-half.x, half.y - 6), Vector2(size.x, 6)), Color(0, 0, 0, 0.12))
	if _edge_kind(EDGE_RIGHT) != &"seam":
		draw_rect(Rect2(Vector2(half.x - 6, -half.y), Vector2(6, size.y)), Color(0, 0, 0, 0.12))

func _draw_wear(half: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position))
	for i in 3:
		var gx := floorf(rng.randf_range(-half.x + 24, half.x - 56) / PLANK) * PLANK
		var gy := rng.randf_range(-half.y + 16, half.y - 24)
		draw_rect(Rect2(Vector2(gx + 3, gy), Vector2(PLANK - 6, 7)), Color(0.08, 0.08, 0.10, 0.55))
	for i in 5:
		var p := Vector2(rng.randf_range(-half.x + 12, half.x - 12),
			rng.randf_range(-half.y + 10, half.y - 10))
		var d := Vector2(rng.randf_range(18.0, 42.0), rng.randf_range(-4.0, 4.0))
		draw_line(p, p + d, deck_color.darkened(0.3 + rng.randf() * 0.15), 2.0)

func _draw_rail_span(edge: int, a: float, b: float) -> void:
	_draw_edge_span(edge, a, b, Color(0, 0, 0, 0.25), 2.0, RAIL_W * 0.5 + 1.0)
	_draw_edge_span(edge, a, b, edge_color, RAIL_W)
	var t := a + 8.0
	while t <= b - 8.0:
		_draw_edge_span(edge, t - 2.0, t + 2.0, Color(0.24, 0.20, 0.06), RAIL_W)
		t += 64.0

## Unguarded bail-out lip: torn dark edge, 45-degree hazard tape band, and
## seeded broken planks poking past the rim — unmistakably not a railed edge.
func _draw_drop_lip(edge: int, extent: float) -> void:
	_draw_edge_span(edge, -extent, extent, Color(0.10, 0.09, 0.08), 5.0)
	var step := 26.0
	var t := -extent
	var k := 0
	while t < extent - 1.0:
		var t2 := minf(t + step, extent)
		var col := Color(0.86, 0.68, 0.10) if k % 2 == 0 else Color(0.10, 0.10, 0.11)
		draw_colored_polygon(PackedVector2Array([
			_edge_point(edge, t, 6.0),
			_edge_point(edge, t2, 6.0),
			_edge_point(edge, minf(t2 + 9.0, extent), 18.0),
			_edge_point(edge, minf(t + 9.0, extent), 18.0),
		]), col)
		t = t2
		k += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position)) + edge
	for i in 3:
		var c := rng.randf_range(-extent + 30.0, extent - 30.0)
		draw_colored_polygon(PackedVector2Array([
			_edge_point(edge, c - 12.0, -6.0),
			_edge_point(edge, c + 12.0, -6.0),
			_edge_point(edge, c + 10.0, 6.0),
			_edge_point(edge, c - 14.0, 6.0),
		]), deck_color.darkened(0.22))

## A stripe over [from_a, to_a] along the given edge, in local space.
func _draw_edge_span(edge: int, from_a: float, to_a: float, color: Color, width: float,
		inset := 0.0) -> void:
	draw_line(_edge_point(edge, from_a, inset), _edge_point(edge, to_a, inset), color, width)

## Support legs sit at every real corner and every <=POST_SPACING interval
## along rail/gate/drop edges; seam edges carry the neighbor's structure.
func _post_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for edge: int in [EDGE_TOP, EDGE_RIGHT, EDGE_BOTTOM, EDGE_LEFT]:
		var kind := _edge_kind(edge)
		if kind == &"seam":
			continue
		var extent := _edge_extent(edge)
		var spans: Array = []
		if kind == &"gate":
			var lo := gate_offset - gate_width * 0.5
			var hi := gate_offset + gate_width * 0.5
			if -extent < lo:
				spans.append([-extent, lo])
			if hi < extent:
				spans.append([hi, extent])
		else:
			spans.append([-extent, extent])
		for span: Array in spans:
			var a := float(span[0]) + POST_INSET
			var b := float(span[1]) - POST_INSET
			if b <= a:
				continue
			var count := maxi(int(ceilf((b - a) / POST_SPACING)), 1)
			for i in count + 1:
				var p := _edge_point(edge, a + (b - a) * float(i) / float(count), POST_INSET)
				var dup := false
				for q in pts:
					if p.distance_to(q) < 30.0:
						dup = true
						break
				if not dup:
					pts.append(p)
	return pts

## Called by the Understructure child: cast shadow (clamped where a neighbor
## deck continues, so a faded neighbor never reveals a stray blob) plus the
## support posts with base plates and contact shadows.
func _paint_understructure(c: CanvasItem) -> void:
	var half := size * 0.5
	var rect := Rect2(-half + SHADOW_OFFSET, size)
	if _edge_kind(EDGE_RIGHT) == &"seam":
		rect.size.x = half.x - rect.position.x
	if _edge_kind(EDGE_BOTTOM) == &"seam":
		rect.size.y = half.y - rect.position.y
	c.draw_rect(rect, Color(0, 0, 0, SHADOW_ALPHA))
	for p in _post_points():
		var plate: Vector2 = p + Vector2(12, 16)
		c.draw_rect(Rect2(plate + Vector2(-11, -7), Vector2(30, 26)), Color(0, 0, 0, 0.20))
		c.draw_line(p, plate, Color(0.26, 0.28, 0.32), 6.0)
		c.draw_rect(Rect2(plate - Vector2(13, 13), Vector2(26, 26)), Color(0.22, 0.23, 0.26))
		c.draw_rect(Rect2(plate - Vector2(13, 13), Vector2(26, 26)), Color(0.32, 0.34, 0.38), false, 2.0)
