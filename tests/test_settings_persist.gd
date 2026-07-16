extends RefCounted
## Settings persistence: JSON round-trip through a throwaway user:// path,
## bad-file tolerance, and reset. Never touches Kevin's real settings.json.

const TMP := "user://_test_settings.json"
const SettingsScene := preload("res://ui/settings.tscn")
const GameStateScript := preload("res://game/game_state.gd")

var t

func _init(runner) -> void:
	t = runner

func _gs() -> Node:
	return t.root.get_node(^"/root/GameState")

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event

func test_settings_round_trip() -> void:
	var gs := _gs()
	var keep := {}
	for k in gs.SETTINGS_KEYS:
		keep[k] = gs.get(k)

	gs.zoom_combat = 0.51
	gs.zoom_overview = 0.39
	gs.overview = true
	gs.camera_look_ahead_enabled = false
	gs.camera_look_ahead_distance = 180.0
	gs.devgod = true
	gs.dev_mode = true
	gs.start_level_index = 3
	gs.screen_shake = false
	gs.mp_join_ip = "192.168.1.44"
	gs.mp_join_port = 43555
	gs.mp_host_garage = "Kevin's Chop Shop"
	gs.mp_host_strict = true
	gs.volume_master = 0.85
	gs.volume_music = 0.35
	gs.volume_sfx = 0.6
	gs.save_settings(TMP)
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(TMP))
	t.check(int(saved.get("schema_version", 0)) == gs.SETTINGS_SCHEMA_VERSION,
		"settings: writes current schema version")
	t.check(saved.get("overview", false)
		and not saved.get("camera_look_ahead_enabled", true)
		and is_equal_approx(float(saved.get("camera_look_ahead_distance", 0.0)), 180.0),
		"settings: zoom state and look-ahead controls are persisted")
	gs.zoom_combat = 0.62
	gs.zoom_overview = 0.5
	gs.overview = false
	gs.camera_look_ahead_enabled = true
	gs.camera_look_ahead_distance = 20.0
	gs.devgod = false
	gs.dev_mode = false
	gs.start_level_index = 0
	gs.screen_shake = true
	gs.mp_join_ip = ""
	gs.mp_join_port = 0
	gs.mp_host_garage = ""
	gs.mp_host_strict = false
	gs.volume_master = 1.0
	gs.volume_music = 1.0
	gs.volume_sfx = 1.0
	gs.load_settings(TMP)
	t.check(is_equal_approx(gs.zoom_combat, 0.51)
		and is_equal_approx(gs.zoom_overview, 0.39) and gs.overview,
		"settings: both zoom depths and toggle state round-trip")
	t.check(not gs.camera_look_ahead_enabled
		and is_equal_approx(gs.camera_look_ahead_distance, 180.0),
		"settings: look-ahead enable and distance round-trip")
	t.check(gs.devgod and gs.dev_mode, "settings: toggles round-trip")
	t.check(gs.start_level_index == 3, "settings: level select round-trips")
	t.check(not gs.screen_shake, "settings: shake toggle round-trips")
	t.check(gs.mp_join_ip == "192.168.1.44" and gs.mp_join_port == 43555,
		"settings: last host entry round-trips")
	t.check(gs.mp_host_garage == "Kevin's Chop Shop" and gs.mp_host_strict,
		"settings: garage prefs round-trip (passwords never persist by design)")
	t.check(is_equal_approx(gs.volume_master, 0.85) and is_equal_approx(gs.volume_music, 0.35)
		and is_equal_approx(gs.volume_sfx, 0.6), "settings: volume sliders round-trip")

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

func test_zoom_defaults_reset_and_schema_migration() -> void:
	var gs := _gs()
	var keep := {}
	for k in gs.SETTINGS_KEYS:
		keep[k] = gs.get(k)

	var fresh := GameStateScript.new()
	t.check(is_equal_approx(fresh.zoom_combat, 0.55)
		and is_equal_approx(fresh.zoom_overview, 0.42) and not fresh.overview,
		"settings: fresh installs use the balanced combat and overview defaults")
	t.check(fresh.camera_look_ahead_enabled
		and is_equal_approx(fresh.camera_look_ahead_distance, 140.0),
		"settings: fresh installs enable the stronger 140px camera lead")
	fresh.zoom_combat = 0.5
	fresh.zoom_overview = 0.5
	fresh.overview = true
	fresh.camera_look_ahead_enabled = false
	fresh.camera_look_ahead_distance = 20.0
	fresh.reset_settings(TMP)
	t.check(is_equal_approx(fresh.zoom_combat, 0.55)
		and is_equal_approx(fresh.zoom_overview, 0.42) and not fresh.overview
		and fresh.camera_look_ahead_enabled
		and is_equal_approx(fresh.camera_look_ahead_distance, 140.0),
		"settings: reset restores all camera defaults")
	fresh.free()

	_write_settings({"zoom_combat": 0.58, "zoom_overview": 0.42, "overview": true})
	gs.zoom_combat = 0.5
	gs.camera_look_ahead_enabled = false
	gs.camera_look_ahead_distance = 20.0
	gs.load_settings(TMP)
	t.check(is_equal_approx(gs.zoom_combat, 0.55) and gs.overview,
		"settings migration: legacy stock 0.58 advances and its toggle survives")
	t.check(gs.camera_look_ahead_enabled
		and is_equal_approx(gs.camera_look_ahead_distance, 140.0),
		"settings migration: missing look-ahead controls receive new defaults")
	var migrated: Variant = JSON.parse_string(FileAccess.get_file_as_string(TMP))
	t.check(int(migrated.get("schema_version", 0)) == gs.SETTINGS_SCHEMA_VERSION,
		"settings migration: legacy file is immediately version-stamped")

	_write_settings({"zoom_combat": 0.51})
	gs.load_settings(TMP)
	t.check(is_equal_approx(gs.zoom_combat, 0.51),
		"settings migration: customized legacy zoom is preserved")
	migrated = JSON.parse_string(FileAccess.get_file_as_string(TMP))
	t.check(int(migrated.get("schema_version", 0)) == gs.SETTINGS_SCHEMA_VERSION,
		"settings migration: customized file is still version-stamped")

	_write_settings({"schema_version": 2, "zoom_combat": 0.66})
	gs.overview = true
	gs.load_settings(TMP)
	t.check(is_equal_approx(gs.zoom_combat, 0.55) and not gs.overview,
		"settings migration: schema-2 stock 0.66 advances and boots in combat view")

	_write_settings({"schema_version": 2, "zoom_combat": 0.63})
	gs.load_settings(TMP)
	t.check(is_equal_approx(gs.zoom_combat, 0.63),
		"settings migration: customized schema-2 zoom is preserved")

	_write_settings({"schema_version": gs.SETTINGS_SCHEMA_VERSION, "zoom_combat": 0.58,
		"overview": true, "camera_look_ahead_enabled": false,
		"camera_look_ahead_distance": 200.0})
	gs.load_settings(TMP)
	t.check(is_equal_approx(gs.zoom_combat, 0.58) and gs.overview
		and not gs.camera_look_ahead_enabled
		and is_equal_approx(gs.camera_look_ahead_distance, 200.0),
		"settings migration: intentional schema-3 values are never migrated again")
	_write_settings({"schema_version": gs.SETTINGS_SCHEMA_VERSION, "zoom_combat": 0.66})
	gs.load_settings(TMP)
	t.check(is_equal_approx(gs.zoom_combat, 0.66),
		"settings migration: intentional modern 0.66 also remains untouched")

	DirAccess.remove_absolute(TMP)
	for k in keep:
		gs.set(k, keep[k])

func _write_settings(data: Dictionary) -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

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

func test_settings_submenus_contract() -> void:
	var gs := _gs()
	var keep := {}
	for k in gs.SETTINGS_KEYS:
		keep[k] = gs.get(k)
	var screen = SettingsScene.instantiate()
	t.root.add_child(screen)
	var main_names: Array[String] = []
	for row in screen._rows:
		main_names.append(String(row.name))
	t.check(main_names == ["GRAPHICS", "AUDIO", "CHECK FOR UPDATES",
		"DEVELOPER OPTIONS", "RESET TO DEFAULTS"],
		"settings menu: presentation and audio controls are grouped into submenus")
	t.check(screen._val_open()[0] == "-->",
		"settings menu: nested entries use the submenu affordance")
	var gfx_names: Array[String] = []
	for row in screen._gfx_rows:
		gfx_names.append(String(row.name))
	t.check(gfx_names == ["COMBAT ZOOM", "OVERVIEW ZOOM", "CAMERA LOOK-AHEAD",
		"LOOK-AHEAD DISTANCE", "SCREEN SHAKE", "BACK"],
		"graphics dialog: both depths, lead controls, shake, and back are present")
	var audio_names: Array[String] = []
	for row in screen._audio_rows:
		audio_names.append(String(row.name))
	t.check(audio_names == ["MASTER VOLUME", "MUSIC VOLUME", "SFX VOLUME", "BACK"],
		"audio dialog: the three existing buses and back are present")
	var dev_names: Array[String] = []
	for row in screen._dev_rows:
		dev_names.append(String(row.name))
	t.check(dev_names == ["DEVELOPER MODE", "DEVGOD", "START LEVEL", "SOUNDBOARD", "CAR TUNER", "BACK"],
		"developer dialog: master, subordinate options, and back are present")
	t.check(not bool(screen._rows[0].persist) and not bool(screen._rows[1].persist)
		and not bool(screen._gfx_rows[5].persist) and not bool(screen._audio_rows[3].persist)
		and not bool(screen._dev_rows[5].persist),
		"settings dialogs: opening and closing are non-persisting navigation")
	t.check(screen._rows[0].kind == &"submenu" and screen._rows[1].kind == &"submenu"
		and screen._rows[4].kind == &"action",
		"settings menu: row kinds distinguish values from right-only destinations")

	screen._settings_path = TMP
	screen._unhandled_input(_key(KEY_DOWN))
	t.check(screen._index == 1, "settings input: down arrow advances the row")
	screen._unhandled_input(_key(KEY_UP))
	t.check(screen._index == 0, "settings input: up arrow reverses the row")
	for ignored in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_ENTER, KEY_SPACE]:
		var index_before: int = screen._index
		screen._unhandled_input(_key(ignored))
		t.check(screen._index == index_before,
			"settings input: legacy key %s is ignored" % ignored)
	screen._unhandled_input(_key(KEY_LEFT))
	t.check(screen._gfx_dialog == null, "settings input: left cannot enter Graphics")
	screen._unhandled_input(_key(KEY_RIGHT))
	t.check(screen._gfx_dialog != null, "settings input: right enters Graphics")

	gs.zoom_combat = 0.55
	gs.zoom_overview = 0.42
	gs.camera_look_ahead_enabled = true
	gs.camera_look_ahead_distance = 140.0
	gs.screen_shake = true
	screen._gfx_index = 0
	screen._unhandled_input(_key(KEY_LEFT))
	t.check(is_equal_approx(gs.zoom_combat, 0.54),
		"graphics input: combat zoom adjusts in 0.01 steps")
	screen._unhandled_input(_key(KEY_RIGHT))
	t.check(is_equal_approx(gs.zoom_combat, 0.55),
		"graphics input: combat zoom adjusts in both directions")
	gs.zoom_combat = 0.45
	gs.zoom_overview = 0.45
	screen._gfx_index = 1
	screen._unhandled_input(_key(KEY_RIGHT))
	t.check(is_equal_approx(gs.zoom_overview, 0.45),
		"graphics input: overview can never become closer than combat")
	gs.zoom_combat = 0.55
	gs.zoom_overview = 0.55
	screen._gfx_index = 0
	screen._unhandled_input(_key(KEY_LEFT))
	t.check(is_equal_approx(gs.zoom_combat, 0.55),
		"graphics input: combat cannot cross an existing overview depth")
	gs.zoom_overview = 0.42
	screen._gfx_index = 2
	screen._unhandled_input(_key(KEY_RIGHT))
	var retained_distance: float = gs.camera_look_ahead_distance
	screen._gfx_index = 3
	screen._unhandled_input(_key(KEY_LEFT))
	t.check(not gs.camera_look_ahead_enabled
		and is_equal_approx(gs.camera_look_ahead_distance, retained_distance - 10.0),
		"graphics input: disabling lead retains an independently tunable distance")
	screen._gfx_index = 4
	screen._unhandled_input(_key(KEY_RIGHT))
	t.check(not gs.screen_shake, "graphics input: Screen Shake moved into this dialog")
	var autosaved: Variant = JSON.parse_string(FileAccess.get_file_as_string(TMP))
	t.check(not autosaved.camera_look_ahead_enabled
		and is_equal_approx(float(autosaved.camera_look_ahead_distance), 130.0),
		"graphics input: camera changes autosave immediately")

	screen._gfx_index = 5
	screen._unhandled_input(_key(KEY_LEFT))
	t.check(screen._gfx_dialog != null, "graphics input: left cannot activate Back")
	screen._unhandled_input(_key(KEY_RIGHT))
	t.check(screen._gfx_dialog == null, "graphics input: Back closes only the nested menu")
	screen._index = 0
	screen._unhandled_input(_key(KEY_RIGHT))
	t.check(screen._gfx_dialog != null, "graphics input: the dialog can be reopened")
	screen._unhandled_input(_key(KEY_ESCAPE))
	t.check(screen._gfx_dialog == null, "graphics input: escape closes the nested menu first")

	screen._index = 1
	screen._unhandled_input(_key(KEY_LEFT))
	t.check(screen._audio_dialog == null, "settings input: left cannot enter Audio")
	screen._unhandled_input(_key(KEY_RIGHT))
	t.check(screen._audio_dialog != null, "settings input: right enters Audio")
	gs.volume_master = 0.80
	gs.volume_music = 0.30
	gs.volume_sfx = 0.55
	gs.apply_audio_settings()
	screen._audio_index = 0
	screen._unhandled_input(_key(KEY_LEFT))
	var master_bus := AudioServer.get_bus_index(&"Master")
	t.check(is_equal_approx(gs.volume_master, 0.75)
		and master_bus >= 0
		and is_equal_approx(AudioServer.get_bus_volume_db(master_bus), linear_to_db(0.75)),
		"audio input: a 5% Master step previews immediately on the live bus")
	gs.volume_master = 0.0
	screen._unhandled_input(_key(KEY_LEFT))
	t.check(gs.volume_master == 0.0, "audio input: volume clamps at 0%")
	gs.volume_master = 1.0
	screen._unhandled_input(_key(KEY_RIGHT))
	t.check(gs.volume_master == 1.0, "audio input: volume clamps at 100%")
	screen._audio_index = 1
	screen._unhandled_input(_key(KEY_RIGHT))
	screen._audio_index = 2
	screen._unhandled_input(_key(KEY_RIGHT))
	var audio_saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(TMP))
	t.check(is_equal_approx(float(audio_saved.volume_music), 0.35)
		and is_equal_approx(float(audio_saved.volume_sfx), 0.60),
		"audio input: Music and SFX changes autosave immediately")
	screen._audio_index = 3
	screen._unhandled_input(_key(KEY_LEFT))
	t.check(screen._audio_dialog != null, "audio input: left cannot activate Back")
	screen._unhandled_input(_key(KEY_RIGHT))
	t.check(screen._audio_dialog == null, "audio input: Back closes only the nested menu")
	screen._index = 1
	screen._unhandled_input(_key(KEY_RIGHT))
	t.check(screen._audio_dialog != null, "audio input: the dialog can be reopened")
	screen._unhandled_input(_key(KEY_ESCAPE))
	t.check(screen._audio_dialog == null, "audio input: escape closes the nested menu first")

	screen._index = 3  # DEVELOPER OPTIONS follows Graphics, Audio, and updater
	screen._unhandled_input(_key(KEY_LEFT))
	t.check(screen._dev_dialog == null, "settings input: left cannot enter Developer Options")
	screen._unhandled_input(_key(KEY_RIGHT))
	t.check(screen._dev_dialog != null, "settings input: right enters Developer Options")
	screen._unhandled_input(_key(KEY_ESCAPE))
	t.check(screen._dev_dialog == null, "developer input: escape closes only its submenu")

	gs.dev_mode = false
	gs.devgod = true
	gs.start_level_index = 3
	screen._adj_devgod(1)
	screen._adj_level(1)
	t.check(gs.devgod and gs.start_level_index == 3,
		"developer dialog: locked child adjustments preserve remembered values")
	screen._dev_index = 0
	screen._step_dev(1)
	t.check(screen._dev_index == 5, "developer dialog: navigation skips locked children")
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

	for k in keep:
		gs.set(k, keep[k])
	gs.apply_audio_settings()
	DirAccess.remove_absolute(TMP)
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
