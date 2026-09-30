extends RefCounted
## Bumper Stickers: authored-catalog contract, persistence, SP gates, dynamic
## roster goals, campaign cascade, and the real Vehicle death hook.

const StickersScript := preload("res://game/stickers.gd")
const Difficulty := preload("res://game/difficulty.gd")
const HitTags := preload("res://game/hit_tags.gd")
const VehiclesHelper := preload("res://vehicles/vehicles.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")
const EndScreenScene := preload("res://ui/end_screen.tscn")

const TMP_PROFILE := "user://_test_stickers.json"
const TMP_ROSTER := "user://_test_stickers_roster.json"

var t


class CampaignFlowStub extends Node:
	var CAMPAIGN: Array = []


func _init(runner) -> void:
	t = runner


func _store(roster := "res://assets/data/roster.json") -> Node:
	DirAccess.remove_absolute(TMP_PROFILE)
	var store: Node = t.root.get_node(^"/root/Stickers")
	store.roster_path = roster
	store.load_catalog()
	store.load_profile(TMP_PROFILE)
	return store


func _gate_state() -> Dictionary:
	var gs: Node = t.root.get_node(^"/root/GameState")
	var net: Node = t.root.get_node(^"/root/Net")
	return {
		"mode": gs.game_mode,
		"pending": gs.pending_level_path,
		"dev_mode": gs.dev_mode,
		"devgod": gs.devgod,
		"net_mode": net.mode,
	}


func _set_earnable() -> void:
	var gs: Node = t.root.get_node(^"/root/GameState")
	var net: Node = t.root.get_node(^"/root/Net")
	gs.game_mode = &"campaign"
	gs.pending_level_path = ""
	gs.dev_mode = false
	gs.devgod = false
	net.mode = 0


func _restore_gate(state: Dictionary) -> void:
	var gs: Node = t.root.get_node(^"/root/GameState")
	var net: Node = t.root.get_node(^"/root/Net")
	gs.game_mode = state.mode
	gs.pending_level_path = state.pending
	gs.dev_mode = state.dev_mode
	gs.devgod = state.devgod
	net.mode = state.net_mode


func _cleanup_temp() -> void:
	DirAccess.remove_absolute(TMP_PROFILE)
	DirAccess.remove_absolute(TMP_ROSTER)
	var store: Node = t.root.get_node_or_null(^"/root/Stickers")
	if store:
		store.roster_path = "res://assets/data/roster.json"
		store.load_profile(TMP_PROFILE)


func _write_roster(characters: Array) -> void:
	var file := FileAccess.open(TMP_ROSTER, FileAccess.WRITE)
	file.store_string(JSON.stringify({"characters": characters}, "\t"))
	file.close()


func _car(parent: Node, faction: StringName) -> Vehicle:
	var car := VehicleScene.instantiate() as Vehicle
	car.faction = faction
	car.stats = (load("res://data/vehicles/ghost.tres") as VehicleStats).duplicate()
	parent.add_child(car)
	return car


func _vehicle_fixture() -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	var player := _car(container, &"player")
	VehiclesHelper.mark_local(player)
	var enemy := _car(container, &"enemies")
	return {"container": container, "player": player, "enemy": enemy}


func _done_vehicle(fixture: Dictionary) -> void:
	var container: Node = fixture.container
	if is_instance_valid(container):
		t.root.remove_child(container)
		container.free()


func _end_screen_fixture() -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var screen := EndScreenScene.instantiate()
	screen.win_keeps_rolling = true
	container.add_child(screen)
	return {"container": container, "screen": screen}


func _done_end_screen(fixture: Dictionary) -> void:
	t.current_scene = null
	var container: Node = fixture.container
	t.root.remove_child(container)
	container.free()


func test_catalog_lint() -> void:
	var json := JSON.new()
	t.check(json.parse(FileAccess.get_file_as_string(StickersScript.CATALOG_PATH)) == OK,
		"stickers catalog: real JSON parses")
	var rows: Array = json.data.get("stickers", [])
	var ids: Dictionary = {}
	var produced_kills: Dictionary = {}
	for file in DirAccess.get_files_at("res://data/weapons"):
		if not file.ends_with(".tres"):
			continue
		var hit_id := StringName(file.get_basename())
		for family in HitTags.families(hit_id):
			produced_kills["kills.%s" % String(family)] = true
	for hit_id in [HitTags.MG, HitTags.RAM, HitTags.SIDE_SLIDE]:
		for family in HitTags.families(hit_id):
			produced_kills["kills.%s" % String(family)] = true
	var produced_counts := {
		"deaths": true,
		"deaths.fall": true,
		"deaths.drown": true,
		"deaths.enemy_fire": true,
		"campaign_won.easy": true,
		"campaign_won.medium": true,
		"campaign_won.hard": true,
		"tutorial_done": true,
		"splats": true,
	}
	for stat in produced_kills:
		produced_counts[stat] = true
	for row_v in rows:
		var row: Dictionary = row_v
		var id := String(row.get("id", ""))
		var rule: Dictionary = row.get("rule", {})
		var rule_type := String(rule.get("type", ""))
		t.check(not id.is_empty() and not ids.has(id),
			"stickers catalog: id '%s' is present and unique" % id)
		ids[id] = true
		t.check(not String(row.get("name", "")).is_empty()
			and not String(row.get("blurb", "")).is_empty(),
			"stickers catalog: '%s' has display copy" % id)
		t.check(rule_type in ["count", "set_covers_roster", "set_covers_specials"],
			"stickers catalog: '%s' uses a known rule" % id)
		t.check(not String(rule.get("stat", "")).is_empty(),
			"stickers catalog: '%s' names a stat" % id)
		if rule_type == "count":
			t.check(int(rule.get("goal", 0)) > 0,
				"stickers catalog: '%s' has a positive goal" % id)
			var stat := String(rule.get("stat", ""))
			t.check(produced_counts.has(stat),
				"stickers catalog: count stat '%s' has a producer" % stat)
	t.check(rows.size() == 20, "stickers catalog: all 20 authored rows are present")


func test_profile_round_trip() -> void:
	_cleanup_temp()
	var source := StickersScript.new()
	source.counters = {"kills.fire": 17, "deaths": 3}
	source.sets = {"kill_ids": ["molotov", "taser"], "campaign_cars": ["ghost"]}
	source.unlocked = {"backyard_bbq": 123456, "day_tripper": 234567}
	source.seen = ["day_tripper"]
	source.save_profile(TMP_PROFILE)
	var loaded := StickersScript.new()
	loaded.load_profile(TMP_PROFILE)
	t.check(loaded.counters == source.counters, "stickers profile: counters round-trip")
	t.check(loaded.sets == source.sets, "stickers profile: unique sets round-trip")
	t.check(loaded.unlocked == source.unlocked, "stickers profile: unlock times round-trip")
	t.check(loaded.seen == source.seen, "stickers profile: seen ids round-trip")
	source.free()
	loaded.free()
	_cleanup_temp()


func test_earning_gate() -> void:
	var keep := _gate_state()
	var store := _store()
	var gs: Node = t.root.get_node(^"/root/GameState")
	var net: Node = t.root.get_node(^"/root/Net")
	_set_earnable()
	gs.dev_mode = true
	gs.devgod = true
	store.record_kill(null, &"mg")
	t.check(store.counters.is_empty(), "stickers gate: DEVGOD blocks kills")
	gs.devgod = false
	store.record_kill(null, &"mg")
	t.check(int(store.counters.get("kills.mg", 0)) == 1,
		"stickers gate: Developer Mode alone does not block")
	store.reset_profile()
	net.mode = 1
	store.record_kill(null, &"mg")
	t.check(store.counters.is_empty(), "stickers gate: active Net blocks kills")
	net.mode = 0
	for mode in [&"tutorial", &"test_drive"]:
		gs.game_mode = mode
		store.record_kill(null, &"mg")
	t.check(store.counters.is_empty(), "stickers gate: tutorial lanes do not count kills")
	gs.game_mode = &"campaign"
	gs.pending_level_path = "user://custom.json"
	store.record_kill(null, &"mg")
	t.check(store.counters.is_empty(), "stickers gate: custom/editor levels do not count")
	_restore_gate(keep)
	_cleanup_temp()


func test_family_counting_and_fresh_drain() -> void:
	var keep := _gate_state()
	_set_earnable()
	var store := _store()
	for i in 50:
		store.record_kill(null, &"molotov")
	t.check(int(store.counters.get("kills.molotov", 0)) == 50
		and int(store.counters.get("kills.fire", 0)) == 50,
		"stickers families: molotov advances its id and fire family")
	t.check(store.is_unlocked(&"backyard_bbq"),
		"stickers families: fifty fire kills unlock Backyard BBQ")
	var fresh: Array = store.drain_fresh()
	t.check(fresh.count(&"backyard_bbq") == 1,
		"stickers fresh: new unlock is drained exactly once")
	t.check(store.drain_fresh().is_empty(), "stickers fresh: second drain is empty")
	_restore_gate(keep)
	_cleanup_temp()


func test_stale_attribution_window_does_not_credit_kill() -> void:
	var keep := _gate_state()
	_set_earnable()
	var store := _store()
	var fixture := _vehicle_fixture()
	var player: Vehicle = fixture.player
	var enemy: Vehicle = fixture.enemy
	enemy.stamp_hit(player, &"missile_homing")
	enemy.last_hit_ms = Time.get_ticks_msec() - StickersScript.ATTRIBUTION_MS - 1000
	enemy.get_node(^"Health").kill()
	t.check(store.counters.is_empty(),
		"stickers attribution: an eleven-second-old player hit gets no kill")
	_done_vehicle(fixture)
	_restore_gate(keep)
	_cleanup_temp()


func test_set_covers_roster_tracks_live_roster_size() -> void:
	var keep := _gate_state()
	_set_earnable()
	_write_roster([
		{"id": "alpha", "special_def": "molotov"},
		{"id": "beta", "special_def": "chill_out"},
	])
	var store := _store(TMP_ROSTER)
	store.record_event(&"campaign_won", {"tier": Difficulty.Tier.EASY, "car": "alpha"})
	t.check(store.progress(&"gotta_crash_em_all") == Vector2i(1, 2),
		"stickers roster set: one of two reports 1/2")
	store.record_event(&"campaign_won", {"tier": Difficulty.Tier.EASY, "car": "beta"})
	t.check(store.is_unlocked(&"gotta_crash_em_all"),
		"stickers roster set: both authored cars unlock coverage")
	store.reset_profile()
	_write_roster([
		{"id": "alpha", "special_def": "molotov"},
		{"id": "beta", "special_def": "chill_out"},
		{"id": "gamma", "special_def": "taser"},
	])
	store.roster_path = TMP_ROSTER  # re-point: the roster goal is cached per path
	store.record_event(&"campaign_won", {"tier": Difficulty.Tier.EASY, "car": "alpha"})
	store.record_event(&"campaign_won", {"tier": Difficulty.Tier.EASY, "car": "beta"})
	t.check(store.progress(&"gotta_crash_em_all") == Vector2i(2, 3)
		and not store.is_unlocked(&"gotta_crash_em_all"),
		"stickers roster set: adding a car grows the live goal to three")
	_restore_gate(keep)
	_cleanup_temp()


func test_set_covers_specials_excludes_zero_damage_defs() -> void:
	var keep := _gate_state()
	_set_earnable()
	_write_roster([
		{"id": "armed", "special_def": "molotov"},
		{"id": "peace", "special_def": "chill_out"},
	])
	var store := _store(TMP_ROSTER)
	store.record_kill(null, &"molotov")
	t.check(store.progress(&"special_delivery") == Vector2i(1, 1),
		"stickers specials set: zero-damage Chill Out is excluded from the goal")
	t.check(store.is_unlocked(&"special_delivery"),
		"stickers specials set: the sole damaging special completes coverage")
	_restore_gate(keep)
	_cleanup_temp()


func test_campaign_difficulty_cascade() -> void:
	var keep := _gate_state()
	_set_earnable()
	var store := _store()
	store.record_event(&"campaign_won", {"tier": Difficulty.Tier.HARD, "car": "ghost"})
	t.check(int(store.counters.get("campaign_won.hard", 0)) == 1
		and int(store.counters.get("campaign_won.medium", 0)) == 1
		and int(store.counters.get("campaign_won.easy", 0)) == 1,
		"stickers campaign: HARD cascades through all lower tiers")
	t.check(store.is_unlocked(&"road_king") and store.is_unlocked(&"long_hauler")
		and store.is_unlocked(&"day_tripper"),
		"stickers campaign: HARD unlocks all three completion stickers")
	t.check("ghost" in store.sets.get("campaign_cars", []),
		"stickers campaign: winning car joins campaign coverage")
	store.reset_profile()
	store.record_event(&"campaign_won", {"tier": Difficulty.Tier.EASY, "car": "ghost"})
	t.check(store.is_unlocked(&"day_tripper") and not store.is_unlocked(&"long_hauler")
		and not store.is_unlocked(&"road_king"),
		"stickers campaign: EASY unlocks only Day Tripper")
	_restore_gate(keep)
	_cleanup_temp()


func test_end_screen_reports_only_campaign_finale_once() -> void:
	var keep := _gate_state()
	var gs: Node = t.root.get_node(^"/root/GameState")
	var selected_was: StringName = gs.selected_vehicle_id
	var tier_was: int = Difficulty.tier
	var scene_was: Node = t.current_scene
	var real_flow: Node = t.root.get_node(^"/root/SceneFlow")
	t.root.remove_child(real_flow)
	var flow := CampaignFlowStub.new()
	flow.name = "SceneFlow"
	t.root.add_child(flow)

	_set_earnable()
	gs.selected_vehicle_id = &"ghost"
	Difficulty.tier = Difficulty.Tier.MEDIUM
	var store := _store()
	# The lightweight current scene has an empty scene_file_path. Put that path
	# last in the stub campaign so the test exercises the same comparison as
	# the real stadium entry without booting the whole boss arena.
	flow.CAMPAIGN = [{"scene": "res://tests/mid.tscn"}, {"scene": ""}]
	var finale := _end_screen_fixture()
	finale.screen._show(true)
	finale.screen._show(true)  # re-entry must never double-credit the same card
	t.check(int(store.counters.get("campaign_won.medium", 0)) == 1
		and int(store.counters.get("campaign_won.easy", 0)) == 1,
		"end screen stickers: campaign finale records the selected tier exactly once")
	t.check(store.sets.get("campaign_cars", []).count("ghost") == 1,
		"end screen stickers: finale records the winning car exactly once")
	_done_end_screen(finale)

	store.reset_profile()
	gs.game_mode = &"single_battle"
	var battle := _end_screen_fixture()
	battle.screen._show(true)
	t.check(store.counters.is_empty() and store.sets.is_empty(),
		"end screen stickers: a single battle in the finale scene records nothing")
	_done_end_screen(battle)

	store.reset_profile()
	gs.game_mode = &"campaign"
	flow.CAMPAIGN = [{"scene": ""}, {"scene": "res://tests/finale.tscn"}]
	var middle := _end_screen_fixture()
	middle.screen._show(true)
	t.check(store.counters.is_empty() and store.sets.is_empty(),
		"end screen stickers: a mid-campaign win records nothing")
	_done_end_screen(middle)

	t.root.remove_child(flow)
	flow.free()
	t.root.add_child(real_flow)
	t.current_scene = scene_was
	gs.selected_vehicle_id = selected_was
	Difficulty.tier = tier_was
	_restore_gate(keep)
	_cleanup_temp()


func test_death_classification_through_vehicle_hook() -> void:
	var keep := _gate_state()
	_set_earnable()
	var cases := [
		{"kind": &"pit", "specific": "deaths.fall"},
		{"kind": &"water", "specific": "deaths.drown"},
		{"kind": &"missile", "specific": "deaths.enemy_fire"},
		{"kind": &"ram", "specific": ""},
	]
	for case_v in cases:
		var case: Dictionary = case_v
		var store := _store()
		var fixture := _vehicle_fixture()
		var player: Vehicle = fixture.player
		var enemy: Vehicle = fixture.enemy
		match case.kind:
			&"pit":
				player.fall_into_pit(player.global_position)
			&"water":
				player.sink_into_water()
			&"missile":
				player.stamp_hit(enemy, &"missile_homing")
			&"ram":
				player.stamp_hit(enemy, HitTags.RAM)
		player.get_node(^"Health").kill()
		t.check(int(store.counters.get("deaths", 0)) == 1,
			"stickers death hook: %s increments total deaths" % String(case.kind))
		if not String(case.specific).is_empty():
			t.check(int(store.counters.get(case.specific, 0)) == 1,
				"stickers death hook: %s reaches %s" % [case.kind, case.specific])
		else:
			t.check(not store.counters.has("deaths.enemy_fire"),
				"stickers death hook: enemy ram is an other death, not enemy fire")
		if case.kind == &"water":
			t.check(not store.counters.has("deaths.fall"),
				"stickers death hook: water is drown, never fall")
		_done_vehicle(fixture)
	_restore_gate(keep)
	_cleanup_temp()


func test_unseen_and_mark_seen() -> void:
	var keep := _gate_state()
	_set_earnable()
	var store := _store()
	store.record_event(&"campaign_won", {"tier": Difficulty.Tier.EASY, "car": "ghost"})
	t.check(&"day_tripper" in store.unseen(), "stickers seen: fresh unlock begins unseen")
	store.mark_seen()
	t.check(store.unseen().is_empty() and "day_tripper" in store.seen,
		"stickers seen: mark_seen acknowledges every unlocked id")
	_restore_gate(keep)
	_cleanup_temp()
