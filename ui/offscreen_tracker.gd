class_name OffscreenTracker
extends Node2D
## Viewer-relative edge awareness. World positions are projected through the
## active camera canvas; only combatants outside the centered 720px play square
## earn a paint-colored arrow. Arrows share the radar's sensor bound
## (Vehicles.sensed_others) — off the scope means off the rim too. One node
## owns/reuses all marker state and draw calls — no per-frame Control churn as
## opponents cross the boundary.

const VehiclesHelper := preload("res://vehicles/vehicles.gd")
const ExplosionScene := preload("res://environment/explosion.tscn")

const PLAY_RECT := Rect2(280.0, 0.0, 720.0, 720.0)
const EDGE_INSET := 14.0
const HYSTERESIS := 6.0
const MARKER_GAP := 18.0
const TIP := 9.0
const WING := 6.0
const HIT_BURST_SCALE := 0.22
const HIT_BURST_COOLDOWN_MS := 250

var _states: Dictionary = {}  # instance id -> {ref, visible, pos, angle, color, outline}
var _draw_records: Array = []
var _last_burst_ms: Dictionary = {}  # victim instance id -> last confirmation

func _ready() -> void:
	z_index = 20

func _process(_delta: float) -> void:
	var tree := get_tree()
	var viewer := VehiclesHelper.local(tree) as Node2D
	if viewer == null or not is_instance_valid(viewer):
		_states.clear()
		_draw_records.clear()
		queue_redraw()
		return
	var canvas := get_viewport().get_canvas_transform()
	var viewer_screen := world_to_screen(canvas, viewer.global_position)
	if not PLAY_RECT.has_point(viewer_screen):
		viewer_screen = PLAY_RECT.get_center()
	var seen: Dictionary = {}
	_draw_records.clear()
	for car_v in VehiclesHelper.sensed_others(tree, viewer):
		var car := car_v as Node2D
		if car == null:
			continue
		var id := car.get_instance_id()
		seen[id] = true
		var screen := world_to_screen(canvas, car.global_position)
		var state: Dictionary = _states.get(id, {"ref": car, "visible": false})
		if not state.get("hit_connected", false) and car.has_signal(&"combat_hit"):
			car.connect(&"combat_hit", _on_combat_hit.bind(car))
			state.hit_connected = true
		var was_visible: bool = state.get("visible", false)
		var visible_now := not PLAY_RECT.grow(HYSTERESIS).has_point(screen)
		if was_visible:
			visible_now = not PLAY_RECT.grow(-HYSTERESIS).has_point(screen)
		state.ref = car
		state.visible = visible_now
		if visible_now:
			var edge_rect := PLAY_RECT.grow(-EDGE_INSET)
			var pos := edge_intersection(viewer_screen, screen, edge_rect)
			var dir := (screen - viewer_screen).normalized()
			var color := marker_color(car)
			state.pos = pos
			state.angle = dir.angle()
			state.color = color
			state.outline = contrast_outline(color)
			_draw_records.append(state)
		_states[id] = state
	for id in _states.keys():
		if not seen.has(id):
			_states.erase(id)
			_last_burst_ms.erase(id)
	separate_overlaps(_draw_records, PLAY_RECT.grow(-EDGE_INSET))
	queue_redraw()

func _draw() -> void:
	for rec_v in _draw_records:
		var rec: Dictionary = rec_v
		var rot := Transform2D(float(rec.angle), rec.pos)
		var pts := PackedVector2Array([
			rot * Vector2(TIP, 0.0),
			rot * Vector2(-WING, -WING),
			rot * Vector2(-WING, WING),
		])
		draw_colored_polygon(pts, rec.color)
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, rec.outline, 2.0, true)

func is_tracking(car: Node) -> bool:
	if car == null or not is_instance_valid(car):
		return false
	var state: Dictionary = _states.get(car.get_instance_id(), {})
	return bool(state.get("visible", false))

func tracked_position(car: Node) -> Vector2:
	if not is_tracking(car):
		return Vector2.INF
	return _states[car.get_instance_id()].pos

func _on_combat_hit(attacker: Node2D, victim: Node2D) -> void:
	var viewer := VehiclesHelper.local(get_tree()) as Node2D
	if viewer == null or attacker != viewer or not is_tracking(victim):
		return
	var id := victim.get_instance_id()
	var now := Time.get_ticks_msec()
	var fatal: bool = victim.has_method(&"get_hp") and float(victim.call(&"get_hp")) <= 0.0
	if not fatal and now - int(_last_burst_ms.get(id, -HIT_BURST_COOLDOWN_MS)) < HIT_BURST_COOLDOWN_MS:
		return
	_last_burst_ms[id] = now
	var boom := ExplosionScene.instantiate()
	boom.name = "FatalHitBurst" if fatal else "HitBurst"
	boom.position = tracked_position(victim)
	boom.tint = marker_color(victim)
	boom.size_scale = HIT_BURST_SCALE
	boom.allow_camera_shake = false
	boom.allow_night_light = false
	boom.ring_only = not fatal
	add_child(boom)

static func world_to_screen(canvas: Transform2D, world: Vector2) -> Vector2:
	return canvas * world

static func edge_intersection(origin: Vector2, target: Vector2, rect: Rect2) -> Vector2:
	var dir := target - origin
	if dir == Vector2.ZERO:
		return rect.get_center()
	var tx := INF
	var ty := INF
	if absf(dir.x) > 0.0001:
		var edge_x := rect.end.x if dir.x > 0.0 else rect.position.x
		tx = (edge_x - origin.x) / dir.x
	if absf(dir.y) > 0.0001:
		var edge_y := rect.end.y if dir.y > 0.0 else rect.position.y
		ty = (edge_y - origin.y) / dir.y
	var hit := origin + dir * minf(tx, ty)
	return Vector2(clampf(hit.x, rect.position.x, rect.end.x),
		clampf(hit.y, rect.position.y, rect.end.y))

static func contrast_outline(color: Color) -> Color:
	return VehiclesHelper.contrast_outline(color)

static func marker_color(car: Node) -> Color:
	return VehiclesHelper.paint_color(car)

## Spread close markers along the edge they already occupy; bearings remain in
## order and no marker can leak into the opaque gutters.
static func separate_overlaps(records: Array, rect: Rect2) -> void:
	var edges := {"left": [], "right": [], "top": [], "bottom": []}
	for rec_v in records:
		var rec: Dictionary = rec_v
		var p: Vector2 = rec.pos
		var distances := {
			"left": absf(p.x - rect.position.x), "right": absf(p.x - rect.end.x),
			"top": absf(p.y - rect.position.y), "bottom": absf(p.y - rect.end.y),
		}
		var edge := "left"
		for candidate in ["right", "top", "bottom"]:
			if float(distances[candidate]) < float(distances[edge]):
				edge = candidate
		rec["edge"] = edge
		edges[edge].append(rec)
	for edge in edges:
		var line: Array = edges[edge]
		if line.size() < 2:
			continue
		var horizontal: bool = edge == "top" or edge == "bottom"
		line.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (a.pos.x if horizontal else a.pos.y) < (b.pos.x if horizontal else b.pos.y))
		var start := 0
		while start < line.size():
			var finish := start
			while finish + 1 < line.size():
				var a: Vector2 = line[finish].pos
				var b: Vector2 = line[finish + 1].pos
				var gap := absf(b.x - a.x) if horizontal else absf(b.y - a.y)
				if gap >= MARKER_GAP:
					break
				finish += 1
			if finish > start:
				var first: Vector2 = line[start].pos
				var last: Vector2 = line[finish].pos
				var center := (first.x + last.x) * 0.5 if horizontal else (first.y + last.y) * 0.5
				var count := finish - start + 1
				for j in count:
					var axis := center + (float(j) - float(count - 1) * 0.5) * MARKER_GAP
					var rec: Dictionary = line[start + j]
					var p: Vector2 = rec.pos
					if horizontal:
						p.x = clampf(axis, rect.position.x, rect.end.x)
					else:
						p.y = clampf(axis, rect.position.y, rect.end.y)
					rec.pos = p
			start = finish + 1
