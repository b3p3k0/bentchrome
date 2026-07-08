extends RefCounted
## Settings persistence: JSON round-trip through a throwaway user:// path,
## bad-file tolerance, and reset. Never touches Kevin's real settings.json.

const TMP := "user://_test_settings.json"

var t

func _init(runner) -> void:
	t = runner

func _gs() -> Node:
	return t.root.get_node(^"/root/GameState")

func test_settings_round_trip() -> void:
	var gs := _gs()
	var keep := {}
	for k in gs.SETTINGS_KEYS:
		keep[k] = gs.get(k)

	gs.zoom_combat = 0.51
	gs.devgod = true
	gs.dev_mode = true
	gs.start_level_index = 3
	gs.screen_shake = false
	gs.save_settings(TMP)
	gs.zoom_combat = 0.62
	gs.devgod = false
	gs.dev_mode = false
	gs.start_level_index = 0
	gs.screen_shake = true
	gs.load_settings(TMP)
	t.check(is_equal_approx(gs.zoom_combat, 0.51), "settings: zoom round-trips")
	t.check(gs.devgod and gs.dev_mode, "settings: toggles round-trip")
	t.check(gs.start_level_index == 3, "settings: level select round-trips")
	t.check(not gs.screen_shake, "settings: shake toggle round-trips")

	# Corrupt file: silently keeps current values (instance-parse, no engine ERROR).
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	gs.load_settings(TMP)
	t.check(gs.start_level_index == 3, "settings: corrupt file changes nothing")
	# Missing file: no-op.
	DirAccess.remove_absolute(TMP)
	gs.load_settings(TMP)
	t.check(gs.devgod, "settings: missing file changes nothing")

	for k in keep:
		gs.set(k, keep[k])
