extends Node2D
## World-space view of the open level: draws the wall band exactly where
## LevelLoader builds it plus a ghost per entity (catalog colors, so the
## preview matches the game's flat-polygon look), and owns mouse interaction —
## armed-tool placement, click select, drag move, Delete. Terrain rects are
## the painting card's job.
##
## The editor camera (a later sibling) sees input first and eats space+drag
## pans, so a press reaching this node is always meant for the level.

signal selection_changed(selection: Dictionary)  # {} = nothing selected
signal tool_cancelled  # ESC/RMB dropped the armed tool; palette should reset

const Schema := preload("res://levels/level_schema.gd")
const Catalog := preload("res://levels/entity_catalog.gd")

const SNAP := 64.0
const TAG_FONT_SIZE := 28
# Bottom-to-top draw order; hit-testing walks it top-to-bottom.
const DRAW_ORDER := ["blocks", "pickups", "dummies", "enemy_spawns"]

var document: EditorDocument
var tool_id := "select"
var selection := {}  # {"list_key": String, "index": int}; player_spawn uses index -1

var _dragging := false

func bind(doc: EditorDocument) -> void:
	document = doc
	document.changed.connect(queue_redraw)
	queue_redraw()

func set_tool(id: String) -> void:
	tool_id = id
	if id != "select" and not selection.is_empty():
		_set_selection({})

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_on_press(get_global_mouse_position())
			MOUSE_BUTTON_RIGHT:
				_cancel()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = false
	elif event is InputEventMouseMotion and _dragging and not selection.is_empty():
		_move_selected(_snap(get_global_mouse_position()))
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_cancel()
			KEY_DELETE, KEY_BACKSPACE:
				_delete_selected()

func _on_press(world: Vector2) -> void:
	if tool_id == "select":
		_set_selection(_hit_test(world))
		_dragging = not selection.is_empty()
	else:
		_place(world)

## Places the armed entity (player start moves instead — it always exists).
## The tool stays armed for repeat placement until ESC/RMB.
func _place(world: Vector2) -> void:
	var entry := Catalog.by_id(tool_id)
	var pos := _snap(world)
	if entry.list_key == "player_spawn":
		document.move_player_spawn(pos)
		_set_selection({"list_key": "player_spawn", "index": -1})
		return
	if entry.has("max_count") and document.count(entry.list_key) >= entry.max_count:
		return
	var entity := {"pos": [pos.x, pos.y]}
	for key in entry.get("preset", {}):
		entity[key] = entry.preset[key]
	for prop in entry.get("props", []):
		entity[prop.key] = prop.default.duplicate() if prop.default is Array else prop.default
	var index := document.add_entity(entry.list_key, entity)
	_set_selection({"list_key": entry.list_key, "index": index})

func _move_selected(pos: Vector2) -> void:
	if selection.list_key == "player_spawn":
		document.move_player_spawn(pos)
	else:
		document.move_entity(selection.list_key, selection.index, pos)

func _delete_selected() -> void:
	if selection.is_empty() or selection.list_key == "player_spawn":
		return  # the player start is required; it can be moved, never removed
	document.remove_entity(selection.list_key, selection.index)
	_set_selection({})

func _cancel() -> void:
	_dragging = false
	if tool_id != "select":
		tool_cancelled.emit()
	elif not selection.is_empty():
		_set_selection({})

func _set_selection(new_selection: Dictionary) -> void:
	selection = new_selection
	selection_changed.emit(selection)
	queue_redraw()

func _hit_test(world: Vector2) -> Dictionary:
	if _entity_rect("player_spawn", document.level.player_spawn).has_point(world):
		return {"list_key": "player_spawn", "index": -1}
	var order := DRAW_ORDER.duplicate()
	order.reverse()
	for list_key in order:
		var list: Array = document.level[list_key]
		for i in range(list.size() - 1, -1, -1):
			if _entity_rect(list_key, list[i]).has_point(world):
				return {"list_key": list_key, "index": i}
	return {}

func _entity_rect(list_key: String, entity: Dictionary) -> Rect2:
	var pos := Vector2(entity.pos[0], entity.pos[1])
	if list_key == "blocks":
		var size := Vector2(entity.size[0], entity.size[1])
		return Rect2(pos - size * 0.5, size)
	var half: Vector2 = Catalog.for_entity(list_key, entity).ghost.half_size
	return Rect2(pos - half, half * 2)

func _snap(world: Vector2) -> Vector2:
	return world.snapped(Vector2(SNAP, SNAP))

# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if document == null:
		return
	_draw_walls()
	for list_key in DRAW_ORDER:
		var list: Array = document.level[list_key]
		for entity in list:
			_draw_ghost(list_key, entity)
	_draw_player()
	if not selection.is_empty():
		var entity: Dictionary = document.level.player_spawn \
				if selection.list_key == "player_spawn" \
				else document.level[selection.list_key][selection.index]
		draw_rect(_entity_rect(selection.list_key, entity).grow(6.0), Color.WHITE, false, 3.0)

func _draw_walls() -> void:
	var half := document.bounds_half()
	var t := Schema.WALL_THICKNESS
	draw_rect(Rect2(-half, Vector2(half.x * 2, t)), Catalog.WALL_COLOR)
	draw_rect(Rect2(Vector2(-half.x, half.y - t), Vector2(half.x * 2, t)), Catalog.WALL_COLOR)
	draw_rect(Rect2(Vector2(-half.x, -half.y), Vector2(t, half.y * 2)), Catalog.WALL_COLOR)
	draw_rect(Rect2(Vector2(half.x - t, -half.y), Vector2(t, half.y * 2)), Catalog.WALL_COLOR)
	draw_rect(Rect2(-half, half * 2), Color(1, 1, 1, 0.25), false, 2.0)

func _draw_ghost(list_key: String, entity: Dictionary) -> void:
	var entry := Catalog.for_entity(list_key, entity)
	var rect := _entity_rect(list_key, entity)
	draw_rect(rect, entry.ghost.color)
	_draw_tag(rect, entry.ghost.tag)

func _draw_player() -> void:
	var spawn: Dictionary = document.level.player_spawn
	var entry := Catalog.by_id("player_spawn")
	var rect := _entity_rect("player_spawn", spawn)
	draw_rect(rect, entry.ghost.color)
	# Facing arrow: heading_deg 0 = nose up, clockwise.
	var center := rect.get_center()
	var nose := center + Vector2.UP.rotated(deg_to_rad(float(spawn.heading_deg))) * 48.0
	draw_line(center, nose, entry.ghost.color, 3.0)
	_draw_tag(rect, entry.ghost.tag)

func _draw_tag(rect: Rect2, tag: String) -> void:
	if tag.is_empty():
		return
	var font := ThemeDB.fallback_font
	var pos := Vector2(rect.position.x, rect.position.y - 6.0)
	draw_string(font, pos, tag, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, TAG_FONT_SIZE, Color(1, 1, 1, 0.9))
