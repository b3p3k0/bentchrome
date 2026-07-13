class_name Callsigns
extends RefCounted
## The callsign roulette's pantry. Ships a default list at res:// and copies
## it to user://callsigns.txt on first multiplayer visit — a real text file a
## novice can edit (one name per line, '#' comments), surviving game updates.
## The loader prefers the user copy, falls back to the shipped list, and
## degrades to a lone Wastelander if both are gone. Paths injectable for tests.

const RES_PATH := "res://assets/data/callsigns.txt"
const USER_PATH := "user://callsigns.txt"
const FALLBACK := "Wastelander"
const NAME_MAX := 24  # parity with NetAuth's handshake trim

static func ensure_user_copy(user_path := USER_PATH, res_path := RES_PATH) -> void:
	if FileAccess.file_exists(user_path):
		return
	var src := FileAccess.get_file_as_string(res_path)
	if src.is_empty():
		return
	var f := FileAccess.open(user_path, FileAccess.WRITE)
	if f:
		f.store_string(src)
		f.close()

static func load_names(user_path := USER_PATH, res_path := RES_PATH) -> Array[String]:
	var text := ""
	if FileAccess.file_exists(user_path):
		text = FileAccess.get_file_as_string(user_path)
	if text.strip_edges().is_empty():
		text = FileAccess.get_file_as_string(res_path)
	var out: Array[String] = []
	for line in text.split("\n"):
		var name := line.strip_edges()
		if name.is_empty() or name.begins_with("#"):
			continue
		out.append(name.left(NAME_MAX))
	if out.is_empty():
		out.append(FALLBACK)
	return out

## A fresh spin; never lands on `exclude` when the list offers a choice.
static func random_name(exclude := "", user_path := USER_PATH, res_path := RES_PATH) -> String:
	var names := load_names(user_path, res_path)
	if names.size() > 1:
		names = names.filter(func(n: String) -> bool: return n != exclude)
	return names[randi() % names.size()]
