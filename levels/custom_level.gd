extends Node2D
## Runtime host for JSON custom levels. Resolves the level path from
## GameState.pending_level_path (editor playtest / future menu) or a
## `--level=<path>` user arg (debug launch), validates, then builds via
## LevelLoader. Invalid or missing levels bail back to the title screen.
##   godot --path . res://levels/custom_level.tscn -- --level=user://levels/foo.json

const Schema := preload("res://levels/level_schema.gd")
const Loader := preload("res://levels/level_loader.gd")

func _ready() -> void:
	var path := _resolve_path()
	if path.is_empty():
		_bail("custom_level: no level given (set GameState.pending_level_path or pass --level=<path>)")
		return
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_bail("custom_level: can't read " + path)
		return
	var level := Schema.parse(text)
	var errors := Schema.validate(level)
	if not errors.is_empty():
		for err in errors:
			push_error("custom_level: %s: %s" % [path, err])
		_bail("custom_level: %d validation error(s) in %s" % [errors.size(), path])
		return
	Loader.build(level, self)
	add_child(load("res://ui/hud.tscn").instantiate())
	add_child(load("res://ui/pause_menu.tscn").instantiate())
	var dev := get_node_or_null(^"/root/Dev")
	if dev and dev.enabled:
		add_child(load("res://ui/dev_dashboard.tscn").instantiate())
	print("[boot] custom level ready — %s" % level.name)

func _resolve_path() -> String:
	var gs := get_node_or_null(^"/root/GameState")
	if gs and not gs.pending_level_path.is_empty():
		return gs.pending_level_path
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			return arg.trim_prefix("--level=")
	return ""

func _bail(message: String) -> void:
	push_error(message)
	var flow := get_node_or_null(^"/root/SceneFlow")
	if flow:
		flow.to_title.call_deferred()
