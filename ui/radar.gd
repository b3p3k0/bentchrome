extends Control
## North-up minimap: the whole arena at a glance — walls, buildings
## (destructibles vanish when smashed), terrain patches, the repair pad — plus
## live blips. Enemy blips only paint within RANGE of the player, so tracking
## the pack stays a skill. Geometry is duck-typed off collision layers and
## script properties (no class references), snapshotted once the level's
## Boundary exists; the static rects are trivial to redraw every frame.

const VehiclesHelper := preload("res://vehicles/vehicles.gd")

const RANGE := 1500.0
const MIN_BLIP := 48.0  # breakables smaller than this (clutter) stay off the map
const BG := Color(0.03, 0.08, 0.05)
const FRAME := Color(0.25, 0.5, 0.3)
const BUILDING := Color(0.32, 0.32, 0.38)
const BREAKABLE := Color(0.45, 0.38, 0.28)
const STATION := Color(0.92, 0.92, 0.95)
const PLAYER_COLOR := Color(1.0, 0.85, 0.2)
const ENEMY_COLOR := Color(0.95, 0.25, 0.2)
const DUMMY_COLOR := Color(0.5, 0.5, 0.5, 0.6)
const FLOOR_LOW := Color(0.0, 0.0, 0.0, 0.24)      # sea-level plates read sunken
const FLOOR_HIGH := Color(0.75, 0.8, 0.9, 0.16)    # roof/deck plates read raised
const WATER_VOID := Color(0.05, 0.11, 0.16, 0.95)  # deep water: lethal, but wet
const CHEV := 4.0  # enemy chevron half-width (floor above = ^, below = v)

const Catalog := preload("res://levels/entity_catalog.gd")

var _bounds := Rect2()       # world-space arena rect
var _terrain: Array = []     # {rect, color}
var _solids: Array = []      # {rect}
var _breakables: Array = []  # {ref, rect} — skipped once freed
var _stations: Array = []    # world positions
var _floor_low: Array = []   # floor-1 tag rects (dark overlay)
var _floor_high: Array = []  # floor-3 tag rects (light overlay)
var _scanned := false

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not _scanned:
		_scan()
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	draw_rect(Rect2(Vector2.ZERO, size), FRAME, false, 2.0)
	if not _scanned:
		return
	for tz in _terrain:
		draw_rect(_map_rect(tz.rect), tz.color)
	for fl in _floor_low:
		draw_rect(_map_rect(fl), FLOOR_LOW)
	for s in _solids:
		draw_rect(_map_rect(s.rect), BUILDING)
	for fh in _floor_high:
		draw_rect(_map_rect(fh), FLOOR_HIGH)
	for b in _breakables:
		if is_instance_valid(b.ref):
			draw_rect(_map_rect(b.rect), BREAKABLE)
	for st in _stations:
		var p := _map(st)
		draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), STATION, 2.0)
		draw_line(p + Vector2(0, -3), p + Vector2(0, 3), STATION, 2.0)

	var player := VehiclesHelper.local(get_tree()) as Node2D
	if player == null or not is_instance_valid(player):
		return
	for d in get_tree().get_nodes_in_group(&"dummies"):
		draw_circle(_map(d.global_position), 2.0, DUMMY_COLOR)
	# Blips are shape-coded against the player's terrace: same floor (or a
	# legacy level) = the classic dot, a floor above = ^, below = v.
	# DEVGOD sees everything map-wide — a testing aid riding the settings
	# toggle; normal play keeps the RANGE skill gate.
	var gs := get_node_or_null(^"/root/GameState")
	var all_seeing: bool = gs != null and gs.is_devgod_enabled()
	var pf := _floor_of(player)
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not all_seeing and e.global_position.distance_to(player.global_position) > RANGE:
			continue
		var p := _map(e.global_position)
		var ef := _floor_of(e)
		if pf >= 1 and ef >= 1 and ef > pf:
			draw_polyline(PackedVector2Array([
				p + Vector2(-CHEV, 3), p + Vector2(0, -4), p + Vector2(CHEV, 3),
			]), ENEMY_COLOR, 2.0)
		elif pf >= 1 and ef >= 1 and ef < pf:
			draw_polyline(PackedVector2Array([
				p + Vector2(-CHEV, -3), p + Vector2(0, 4), p + Vector2(CHEV, -3),
			]), ENEMY_COLOR, 2.0)
		else:
			draw_circle(p, 3.0, ENEMY_COLOR)
	var spin: float = player.heading + PI / 2
	var p := _map(player.global_position)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -6).rotated(spin),
		p + Vector2(4, 5).rotated(spin),
		p + Vector2(-4, 5).rotated(spin),
	]), PLAYER_COLOR)

func _map(world: Vector2) -> Vector2:
	var s := minf(size.x / _bounds.size.x, size.y / _bounds.size.y)
	var offset := (size - _bounds.size * s) * 0.5
	return offset + (world - _bounds.position) * s

func _map_rect(r: Rect2) -> Rect2:
	var a := _map(r.position)
	return Rect2(a, _map(r.end) - a)

## One pass over the level: bounds from the layer-2 boundary, buildings from
## layer-4 bodies (Health child = breakable), terrain from zones, the repair
## pad by its cooldown property. Retries until a boundary shows up.
func _scan() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_terrain.clear()
	_solids.clear()
	_breakables.clear()
	_stations.clear()
	_floor_low.clear()
	_floor_high.clear()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var found_wall := false
	var stack: Array = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.push_back(child)
		if node is StaticBody2D and node.collision_layer & 2:
			for c in node.get_children():
				if c is CollisionShape2D and c.shape is RectangleShape2D:
					found_wall = true
					var half: Vector2 = c.shape.size * 0.5
					lo = lo.min(c.global_position - half)
					hi = hi.max(c.global_position + half)
		elif node is StaticBody2D and node.collision_layer & 4:
			var rect := _body_rect(node)
			if rect.size == Vector2.ZERO:
				continue
			if _has_health(node):
				if rect.size.x < MIN_BLIP and rect.size.y < MIN_BLIP:
					continue  # 1-HP clutter: too small to matter, keeps the map readable
				_breakables.append({"ref": node, "rect": rect})
			else:
				_solids.append({"rect": rect})
		elif node is Area2D and "terrain_type" in node:
			var color: Color = Catalog.TERRAIN_COLORS.get(String(node.terrain_type), Color(0.4, 0.4, 0.4))
			color.a = 0.55
			_terrain.append({"rect": _body_rect(node), "color": color})
		elif node is Area2D and "cooldown_seconds" in node:
			_stations.append(node.global_position)
		elif node is Area2D and "is_pit" in node:
			# Drop-offs paint as near-black voids so the edge reads on the map.
			_terrain.append({"rect": Rect2(node.global_position - node.size * 0.5, node.size),
				"color": Color(0.01, 0.01, 0.02, 0.95)})
		elif node is Area2D and "is_deep_water" in node:
			# Deep water: same lethal-void treatment, but reads as sea.
			_terrain.append({"rect": Rect2(node.global_position - node.size * 0.5, node.size),
				"color": WATER_VOID})
		elif node is Area2D and "floor_index" in node and "size" in node:
			# Floor-tag plates: low terraces darken, high ones lighten; the
			# mid floor is the baseline and stays unpainted. (The size guard
			# matters: ramps and mines carry floor_index too, but no rect.)
			var rect := Rect2(node.global_position - node.size * 0.5, node.size)
			if int(node.floor_index) == 1:
				_floor_low.append(rect)
			elif int(node.floor_index) >= 3:
				_floor_high.append(rect)
	if found_wall:
		_bounds = Rect2(lo, hi - lo)
		_scanned = true

func _body_rect(node: Node2D) -> Rect2:
	for c in node.get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			return Rect2(c.global_position - c.shape.size * 0.5, c.shape.size)
	return Rect2()

func _has_health(node: Node) -> bool:
	for c in node.get_children():
		if c.name == "Health":
			return true
	return false

func _floor_of(node: Node) -> int:
	var f: Variant = node.get("floor_index")
	return int(f) if f is int else -1
