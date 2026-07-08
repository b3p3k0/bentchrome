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
