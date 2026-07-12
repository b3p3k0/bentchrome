extends RefCounted
## Settings persistence: JSON round-trip through a throwaway user:// path,
## bad-file tolerance, and reset. Never touches Kevin's real settings.json.

const TMP := "user://_test_settings.json"
const SettingsScene := preload("res://ui/settings.tscn")

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

func test_developer_mode_gates_preserved_options() -> void:
	var gs := _gs()
	var keep_dev: bool = gs.dev_mode
	var keep_god: bool = gs.devgod
	var keep_level: int = gs.start_level_index
	gs.devgod = true
	gs.start_level_index = 4
	gs.dev_mode = false
	t.check(not gs.is_devgod_enabled(), "developer breaker: DEVGOD is inert while master is off")
	t.check(gs.effective_start_level_index() == 0,
		"developer breaker: campaign falls back to Downtown while master is off")
	t.check(gs.devgod and gs.start_level_index == 4,
		"developer breaker: subordinate choices remain stored")
	gs.dev_mode = true
	t.check(gs.is_devgod_enabled(), "developer breaker: remembered DEVGOD returns with master")
	t.check(gs.effective_start_level_index() == 4,
		"developer breaker: remembered start level returns with master")
	gs.dev_mode = keep_dev
	gs.devgod = keep_god
	gs.start_level_index = keep_level

func test_developer_options_menu_contract() -> void:
	var gs := _gs()
	var keep_dev: bool = gs.dev_mode
	var keep_god: bool = gs.devgod
	var keep_level: int = gs.start_level_index
	var screen = SettingsScene.instantiate()
	t.root.add_child(screen)
	var main_names: Array[String] = []
	for row in screen._rows:
		main_names.append(String(row.name))
	t.check(main_names == ["ZOOM DEPTH", "SCREEN SHAKE", "DEVELOPER OPTIONS",
		"RESET TO DEFAULTS", "BACK"], "settings menu: developer controls collapse to one entry")
	var dev_names: Array[String] = []
	for row in screen._dev_rows:
		dev_names.append(String(row.name))
	t.check(dev_names == ["DEVELOPER MODE", "DEVGOD", "START LEVEL", "BACK"],
		"developer dialog: master, subordinate options, and back are present")
	t.check(not bool(screen._rows[2].persist) and not bool(screen._dev_rows[3].persist),
		"developer dialog: opening and closing are non-persisting navigation")

	gs.dev_mode = false
	gs.devgod = true
	gs.start_level_index = 3
	screen._adj_devgod(1)
	screen._adj_level(1)
	t.check(gs.devgod and gs.start_level_index == 3,
		"developer dialog: locked child adjustments preserve remembered values")
	screen._dev_index = 0
	screen._step_dev(1)
	t.check(screen._dev_index == 3, "developer dialog: navigation skips locked children")
	gs.dev_mode = true
	screen._dev_index = 0
	screen._step_dev(1)
	t.check(screen._dev_index == 1, "developer dialog: powered children rejoin navigation")
	screen._open_dev_dialog()
	t.check(screen._dev_dialog != null, "developer dialog: entry opens an in-screen modal")
	screen._close_dev_dialog()
	t.check(screen._dev_dialog == null, "developer dialog: back closes only the modal")
	var title_script: String = FileAccess.get_file_as_string("res://ui/title.gd")
	var title_scene: String = FileAccess.get_file_as_string("res://ui/title.tscn")
	t.check(title_script.contains('const ENTRY_NAMES := ["SINGLE PLAYER"')
		and title_scene.contains('text = "SINGLE PLAYER"'),
		"title menu: runtime label and authored fallback carry the full name")

	gs.dev_mode = keep_dev
	gs.devgod = keep_god
	gs.start_level_index = keep_level
	t.root.remove_child(screen)
	screen.free()

func test_devgod_health_blocks_damage_not_pits() -> void:
	var h = preload("res://vehicles/health.gd").new()
	t.root.add_child(h)
	h.god = true
	h.take_damage(999.0)
	t.check(h.hp == h.max_hp, "devgod: damage bounces off")
	h.kill()
	t.check(h.hp == 0.0, "devgod: pits (kill) still work")
	t.root.remove_child(h)
	h.free()

func test_devgod_rack_never_depletes() -> void:
	var rack = preload("res://vehicles/weapon_rack.gd").new()
	t.root.add_child(rack)
	rack.configure(preload("res://data/weapons/missile_standard.tres"), 3, 0.0)
	rack.god = true
	rack.arm_all_once()
	for i in rack._slots.size():
		t.check(rack.ammo(i) == 1, "devgod: slot %d armed with exactly one" % i)
	rack.consume()
	rack.consume()
	t.check(rack.ammo(rack.selected_index()) == 1, "devgod: firing never depletes")
	t.check(rack.can_consume(), "devgod: always ready to fire")
	t.root.remove_child(rack)
	rack.free()
