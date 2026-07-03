class_name EditorDocument
extends RefCounted
## The level editor's in-memory model: one LevelSchema dictionary plus file
## state. Every mutation goes through a method here (never poke .level from
## UI code) so dirty tracking — and undo, when it lands — see everything.

signal changed  # any level-content mutation, or a whole-document swap

const Schema := preload("res://levels/level_schema.gd")

var level: Dictionary = Schema.make_empty()
var path: String = ""  # empty = never saved
var dirty: bool = false

func new_level() -> void:
	level = Schema.make_empty()
	path = ""
	dirty = false
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

func bounds_half() -> Vector2:
	return Vector2(level.bounds.width, level.bounds.height) * 0.5

## name / author / description
func set_field(key: String, value: String) -> void:
	if level[key] == value:
		return
	level[key] = value
	_mutated()

func set_bounds(width: float, height: float) -> void:
	if level.bounds.width == width and level.bounds.height == height:
		return
	level.bounds = {"width": width, "height": height}
	_mutated()

# --- entity mutations (canvas/palette/inspector go through these) ------------

func count(list_key: String) -> int:
	return level[list_key].size()

## Appends and returns the new index.
func add_entity(list_key: String, entry: Dictionary) -> int:
	level[list_key].append(entry)
	_mutated()
	return level[list_key].size() - 1

func remove_entity(list_key: String, index: int) -> void:
	level[list_key].remove_at(index)
	_mutated()

func move_entity(list_key: String, index: int, pos: Vector2) -> void:
	var entry: Dictionary = level[list_key][index]
	if entry.pos[0] == pos.x and entry.pos[1] == pos.y:
		return
	entry.pos = [pos.x, pos.y]
	_mutated()

func set_entity_prop(list_key: String, index: int, key: String, value: Variant) -> void:
	var entry: Dictionary = level[list_key][index]
	if entry.get(key) == value:
		return
	entry[key] = value
	_mutated()

## The player spawn always exists (schema default), so "placing" it moves it.
func move_player_spawn(pos: Vector2) -> void:
	if level.player_spawn.pos[0] == pos.x and level.player_spawn.pos[1] == pos.y:
		return
	level.player_spawn.pos = [pos.x, pos.y]
	_mutated()

func set_player_heading(deg: float) -> void:
	if level.player_spawn.heading_deg == deg:
		return
	level.player_spawn.heading_deg = deg
	_mutated()

func _mutated() -> void:
	dirty = true
	changed.emit()
