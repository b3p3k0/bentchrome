extends Control
## North-up minimap: the whole arena at a glance — walls, buildings
## (destructibles vanish when smashed), terrain patches, the repair pad — plus
## live blips. Enemy blips only paint within RANGE of the player, so tracking
## the pack stays a skill. Geometry is duck-typed off collision layers and
## script properties (no class references), snapshotted once the level's
## Boundary exists; the static rects are trivial to redraw every frame.

const RANGE := 1500.0
const BG := Color(0.03, 0.08, 0.05)
const FRAME := Color(0.25, 0.5, 0.3)
const BUILDING := Color(0.32, 0.32, 0.38)
const BREAKABLE := Color(0.45, 0.38, 0.28)
const STATION := Color(0.92, 0.92, 0.95)
const PLAYER_COLOR := Color(1.0, 0.85, 0.2)
const ENEMY_COLOR := Color(0.95, 0.25, 0.2)
const DUMMY_COLOR := Color(0.5, 0.5, 0.5, 0.6)

const Catalog := preload("res://levels/entity_catalog.gd")

var _bounds := Rect2()       # world-space arena rect
var _terrain: Array = []     # {rect, color}
var _solids: Array = []      # {rect}
var _breakables: Array = []  # {ref, rect} — skipped once freed
var _stations: Array = []    # world positions
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
	for s in _solids:
		draw_rect(_map_rect(s.rect), BUILDING)
	for b in _breakables:
		if is_instance_valid(b.ref):
			draw_rect(_map_rect(b.rect), BREAKABLE)
	for st in _stations:
		var p := _map(st)
		draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), STATION, 2.0)
		draw_line(p + Vector2(0, -3), p + Vector2(0, 3), STATION, 2.0)

	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null or not is_instance_valid(player):
		return
	for d in get_tree().get_nodes_in_group(&"dummies"):
		draw_circle(_map(d.global_position), 2.0, DUMMY_COLOR)
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e.global_position.distance_to(player.global_position) <= RANGE:
			draw_circle(_map(e.global_position), 3.0, ENEMY_COLOR)
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
				_breakables.append({"ref": node, "rect": rect})
			else:
				_solids.append({"rect": rect})
		elif node is Area2D and "terrain_type" in node:
			var color: Color = Catalog.TERRAIN_COLORS.get(String(node.terrain_type), Color(0.4, 0.4, 0.4))
			color.a = 0.55
			_terrain.append({"rect": _body_rect(node), "color": color})
		elif node is Area2D and "cooldown_seconds" in node:
			_stations.append(node.global_position)
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
