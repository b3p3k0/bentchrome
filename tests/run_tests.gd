extends SceneTree
## Minimal headless test runner (no framework — mirrors tools/import_roster.gd).
## Run: godot --headless --path . -s res://tests/run_tests.gd   (or tools/test.sh)
## Prints "TESTS: PASS|FAIL ..." and exits 0/1. Add new suites to SUITES.

const SUITES := [
	preload("res://tests/test_status_effects.gd"),
	preload("res://tests/test_weapon_rack.gd"),
	preload("res://tests/test_ammo_carry.gd"),
	preload("res://tests/test_weapon_lock.gd"),
	preload("res://tests/test_rear_missile.gd"),
	preload("res://tests/test_pickup_cue.gd"),
	preload("res://tests/test_hit_feedback.gd"),
	preload("res://tests/test_impact_fx.gd"),
	preload("res://tests/test_mg_heat.gd"),
	preload("res://tests/test_specials_data.gd"),
	preload("res://tests/test_enemy_driver.gd"),
	preload("res://tests/test_ai_fight_director.gd"),
	preload("res://tests/test_final_duel.gd"),
	preload("res://tests/test_level_schema.gd"),
	preload("res://tests/test_entity_catalog.gd"),
	preload("res://tests/test_level_loader.gd"),
	preload("res://tests/test_editor_document.gd"),
	preload("res://tests/test_driving_controller.gd"),
	preload("res://tests/test_terrain_profiles.gd"),
	preload("res://tests/test_mud_rain.gd"),
	preload("res://tests/test_destructible_block.gd"),
	preload("res://tests/test_clutter.gd"),
	preload("res://tests/test_ambient_life.gd"),
	preload("res://tests/test_car_paint.gd"),
	preload("res://tests/test_camera_legibility.gd"),
	preload("res://tests/test_roster_contract.gd"),
	preload("res://tests/test_disarm.gd"),
	preload("res://tests/test_freeze.gd"),
	preload("res://tests/test_tornado.gd"),
	preload("res://tests/test_pulse.gd"),
	preload("res://tests/test_spawn_distance.gd"),
	preload("res://tests/test_car_select_bio.gd"),
	preload("res://tests/test_input_bindings.gd"),
	preload("res://tests/test_antler_lock.gd"),
	preload("res://tests/test_burst_fire.gd"),
	preload("res://tests/test_settings_persist.gd"),
	preload("res://tests/test_tuning_deck.gd"),
	preload("res://tests/test_ram_destructible.gd"),
	preload("res://tests/test_dash_ram.gd"),
	preload("res://tests/test_health_station.gd"),
	preload("res://tests/test_pit_zone.gd"),
	preload("res://tests/test_floors.gd"),
	preload("res://tests/test_weapon_gating.gd"),
	preload("res://tests/test_deep_water.gd"),
	preload("res://tests/test_hazard_curb.gd"),
	preload("res://tests/test_floor_navigation.gd"),
	preload("res://tests/test_dock_level.gd"),
	preload("res://tests/test_ground_floor.gd"),
	preload("res://tests/test_construction_site.gd"),
	preload("res://tests/test_signature_generator.gd"),
	preload("res://tests/test_retrofit_floors.gd"),
	preload("res://tests/test_turret.gd"),
	preload("res://tests/test_mine.gd"),
	preload("res://tests/test_audio_director.gd"),
	preload("res://tests/test_music_director.gd"),
	preload("res://tests/test_corner_escape.gd"),
	preload("res://tests/test_no_camping.gd"),
	preload("res://tests/test_spawner_pool.gd"),
	preload("res://tests/test_chase_course.gd"),
	preload("res://tests/test_horde_wall.gd"),
	preload("res://tests/test_chase_driver.gd"),
	preload("res://tests/test_chase_director.gd"),
	preload("res://tests/test_stadium_level.gd"),
	preload("res://tests/test_goliath_trailer.gd"),
	preload("res://tests/test_goliath_boss.gd"),
	preload("res://tests/test_goliath_driver.gd"),
	preload("res://tests/test_difficulty.gd"),
	preload("res://tests/test_botlab.gd"),
	preload("res://tests/test_net_auth.gd"),
	preload("res://tests/test_net_manifest.gd"),
	preload("res://tests/test_net_banlist.gd"),
	preload("res://tests/test_net_roster.gd"),
	preload("res://tests/test_match_config.gd"),
	preload("res://tests/test_local_player.gd"),
	preload("res://tests/test_offscreen_tracker.gd"),
	preload("res://tests/test_sensors.gd"),
	preload("res://tests/test_net_puppet.gd"),
	preload("res://tests/test_network_driver.gd"),
	preload("res://tests/test_mp_match.gd"),
	preload("res://tests/test_mp_ui_focus.gd"),
	preload("res://tests/test_net_state_snapshot.gd"),
	preload("res://tests/test_net_fx.gd"),
	preload("res://tests/test_callsigns.gd"),
	preload("res://tests/test_match_director.gd"),
	preload("res://tests/test_spectator_rig.gd"),
	preload("res://tests/test_unique_rides.gd"),
	preload("res://tests/test_doppelganger.gd"),
	preload("res://tests/test_mp_maps.gd"),
	preload("res://tests/test_tutorial_level.gd"),
	preload("res://tests/test_mode_select.gd"),
	preload("res://tests/test_tutorial_director.gd"),
	preload("res://tests/test_floor_props.gd"),
	preload("res://tests/test_economy.gd"),
	preload("res://tests/test_garage_catalog.gd"),
	preload("res://tests/test_car_deck.gd"),
	preload("res://tests/test_stat_rebase.gd"),  # keep LAST: golden lock audits .tres hygiene
]

var _checks := 0
var _failures := 0

func _init() -> void:
	# Nodes added in _init() are not readied (root enters the tree only after
	# MainLoop init). Defer to the first process frame; from there add_child()
	# fires _ready/@onready synchronously, so tests run straight-line.
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)

func _run_all() -> void:
	for suite_script in SUITES:
		var suite = suite_script.new(self)
		for m in suite.get_method_list():
			if m.name.begins_with("test_"):
				# await lets integration tests pump frames; sync tests pass through
				await suite.call(m.name)
	if _failures > 0:
		print("TESTS: FAIL (%d checks, %d failures)" % [_checks, _failures])
		quit(1)
	else:
		print("TESTS: PASS (%d checks)" % _checks)
		quit(0)

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + label)

func check_approx(got: float, want: float, label: String) -> void:
	check(is_equal_approx(got, want), "%s (got %s, want %s)" % [label, got, want])
