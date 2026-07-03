class_name EditorDocument
extends RefCounted
## The level editor's in-memory model: one LevelSchema dictionary plus file
## state. Every mutation goes through a method here (never poke .level from
## UI code) so dirty tracking and undo see everything. Undo is snapshot-based
## (levels are a few KB; deep copies beat inverse-op bookkeeping), with
## same-key coalescing so a drag is one undo step, not sixty.

signal changed  # any level-content mutation, or a whole-document swap

const Schema := preload("res://levels/level_schema.gd")
const UNDO_LIMIT := 100

var level: Dictionary = Schema.make_empty()
var path: String = ""  # empty = never saved
var dirty: bool = false

var _undo_stack: Array[Dictionary] = []  # {level, dirty, key}
var _redo_stack: Array[Dictionary] = []  # {level, dirty}

func new_level() -> void:
	level = Schema.make_empty()
	path = ""
	dirty = false
	_undo_stack.clear()
	_redo_stack.clear()
	changed.emit()

## Returns problems ([] = opened fine). Malformed JSON refuses to open;
## validation errors open anyway (creators must be able to reopen WIP levels)
## but are reported for the status line.
func open(from_path: String) -> Array[String]:
	var text := FileAccess.get_file_as_string(from_path)
	if text.is_empty():
		return ["can't read " + from_path]
	var parsed := Schema.parse(text)
	if parsed.is_empty():
		return ["not a level file (malformed JSON): " + from_path]
	level = parsed
	path = from_path
	dirty = false
	_undo_stack.clear()
	_redo_stack.clear()
	changed.emit()
	return Schema.validate(level)

func save_as(to_path: String) -> Error:
	var file := FileAccess.open(to_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(Schema.serialize(level))
	file.close()
	path = to_path
	dirty = false
	changed.emit()
	return OK

func save() -> Error:
	return ERR_FILE_BAD_PATH if path.is_empty() else save_as(path)

func validate() -> Array[String]:
	return Schema.validate(level)

## Coming back from a playtest: reload the exact playtested state (including
## edits that were never saved) but point the document back at its real file.
## Dirty iff the content no longer matches what's on disk there.
func restore_playtest(playtest_path: String, original_path: String) -> Array[String]:
	var problems := open(playtest_path)
	if path != playtest_path:
		return problems  # playtest file unreadable/corrupt; document unchanged
	path = original_path
	dirty = original_path.is_empty() \
			or FileAccess.get_file_as_string(original_path) != Schema.serialize(level)
	changed.emit()
	return problems

func bounds_half() -> Vector2:
	return Vector2(level.bounds.width, level.bounds.height) * 0.5

## name / author / description
func set_field(key: String, value: String) -> void:
	if level[key] == value:
		return
	_snapshot("field:" + key)
	level[key] = value
	_mutated()

func set_bounds(width: float, height: float) -> void:
	if level.bounds.width == width and level.bounds.height == height:
		return
	_snapshot("bounds")
	level.bounds = {"width": width, "height": height}
	_mutated()

# --- undo / redo --------------------------------------------------------------

func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	_redo_stack.append({"level": level.duplicate(true), "dirty": dirty})
	var entry: Dictionary = _undo_stack.pop_back()
	level = entry.level
	dirty = entry.dirty
	changed.emit()
	return true

func redo() -> bool:
	if _redo_stack.is_empty():
		return false
	_undo_stack.append({"level": level.duplicate(true), "dirty": dirty, "key": ""})
	var entry: Dictionary = _redo_stack.pop_back()
	level = entry.level
	dirty = entry.dirty
	changed.emit()
	return true

## Breaks the coalescing chain — call when a continuous gesture ends (drag
## release), so the next drag of the same entity is its own undo step.
func end_action() -> void:
	if not _undo_stack.is_empty():
		_undo_stack[-1].key = ""

## Pushes the pre-mutation state. Consecutive mutations sharing a non-empty
## key coalesce into the oldest snapshot (one undo step per gesture).
func _snapshot(key: String) -> void:
	if not key.is_empty() and not _undo_stack.is_empty() and _undo_stack[-1].key == key:
		return
	_undo_stack.append({"level": level.duplicate(true), "dirty": dirty, "key": key})
	if _undo_stack.size() > UNDO_LIMIT:
		_undo_stack.pop_front()
	_redo_stack.clear()

# --- entity mutations (canvas/palette/inspector go through these) ------------

func count(list_key: String) -> int:
	return level[list_key].size()

## Appends and returns the new index.
func add_entity(list_key: String, entry: Dictionary) -> int:
	_snapshot("")
	level[list_key].append(entry)
	_mutated()
	return level[list_key].size() - 1

func remove_entity(list_key: String, index: int) -> void:
	_snapshot("")
	level[list_key].remove_at(index)
	_mutated()

func move_entity(list_key: String, index: int, pos: Vector2) -> void:
	var entry: Dictionary = level[list_key][index]
	if entry.pos[0] == pos.x and entry.pos[1] == pos.y:
		return
	_snapshot("move:%s:%d" % [list_key, index])
	entry.pos = [pos.x, pos.y]
	_mutated()

func set_entity_prop(list_key: String, index: int, key: String, value: Variant) -> void:
	if index >= count(list_key):
		return  # stale selection after an undo; nothing to edit
	var entry: Dictionary = level[list_key][index]
	if entry.get(key) == value:
		return
	_snapshot("prop:%s:%d:%s" % [list_key, index, key])
	entry[key] = value
	_mutated()

## The player spawn always exists (schema default), so "placing" it moves it.
func move_player_spawn(pos: Vector2) -> void:
	if level.player_spawn.pos[0] == pos.x and level.player_spawn.pos[1] == pos.y:
		return
	_snapshot("move:player")
	level.player_spawn.pos = [pos.x, pos.y]
	_mutated()

func set_player_heading(deg: float) -> void:
	if level.player_spawn.heading_deg == deg:
		return
	_snapshot("prop:player:heading")
	level.player_spawn.heading_deg = deg
	_mutated()

func _mutated() -> void:
	dirty = true
	changed.emit()
