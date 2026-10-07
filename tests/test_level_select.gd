extends RefCounted
## The fight card (SINGLE BATTLE's level picker): the player filter lists melee
## arenas and the chase while Developer Mode also exposes miniboss/boss fights;
## omitted slots are hidden, not disabled. A pick stamps
## GameState.battle_level_index; and the battle slot is run state that survives
## reset_campaign (car select resets the run BEFORE launching into the slot).
## The scene is load()ed at test time, NOT const-preloaded: level_select.gd
## names autoloads, which only compile once autoloads are registered. Routing
## confirms (scene swaps) stay untested here — _commit_pick is isolated for
## exactly that.

var t

func _init(runner) -> void:
	t = runner

func _fresh() -> Control:
	var screen: Control = (load("res://ui/level_select.tscn") as PackedScene).instantiate()
	t.root.add_child(screen)
	return screen

func test_fight_card_filter() -> void:
	var flow: Node = t.root.get_node(^"/root/SceneFlow")
	var script: Script = load("res://ui/level_select.gd")
	var player_rows: Array = script.listed_slots(flow.CAMPAIGN, false)
	var player_tails: Array[String] = []
	for row_v in player_rows:
		var row: Dictionary = row_v
		var profile: Dictionary = flow.CAMPAIGN[int(row.campaign_index)]
		player_tails.append(String(profile.scene).get_file())
	t.check(player_tails == ["arena_assault.tscn", "dock.tscn", "downtown.tscn",
			"freeway.tscn", "suburbs.tscn", "buzzard_run.tscn", "snowy.tscn", "ground_floor_gore.tscn",
			"capital_city_carnage.tscn"],
		"fight card: every melee/duel arena and the chase are selectable, in tour order")
	for row_v in player_rows:
		var row: Dictionary = row_v
		var profile: Dictionary = flow.CAMPAIGN[int(row.campaign_index)]
		t.check(StringName(profile.encounter) != &"miniboss"
			and StringName(profile.encounter) != &"boss",
			"fight card: %s stays player-visible without Developer Mode" % row.name)
	var dev_rows: Array = script.listed_slots(flow.CAMPAIGN, true)
	var boss_names: Array[String] = []
	for row_v in dev_rows:
		var row: Dictionary = row_v
		var profile: Dictionary = flow.CAMPAIGN[int(row.campaign_index)]
		if StringName(profile.encounter) in [&"miniboss", &"boss"]:
			boss_names.append(String(row.name))
	t.check(boss_names == ["Lackey's Arena", "Goliath's Arena"],
		"fight card: Developer Mode adds miniboss and boss fights in tour order")
	t.check(dev_rows.size() == player_rows.size() + 2,
		"fight card: Developer Mode adds only the two boss encounters")

func test_screen_boots_onto_a_live_row() -> void:
	var gs: Node = t.root.get_node(^"/root/GameState")
	var before: bool = gs.dev_mode
	gs.dev_mode = false
	var screen := _fresh()
	t.check(screen._entries.size() == screen._rows.size()
		and screen._rows.size() == 10,
		"fight card: nine player fights plus BACK")
	t.check(String(screen._rows[screen._index].name) == "Arena Assault",
		"fight card: first live slot is Arena Assault")
	screen._step(-1)
	t.check(String(screen._rows[screen._index].name) == "BACK",
		"fight card: moving up from the first fight wraps to BACK")
	t.root.remove_child(screen)
	screen.free()
	gs.dev_mode = before

func test_dev_mode_builds_boss_rows() -> void:
	var gs: Node = t.root.get_node(^"/root/GameState")
	var before: bool = gs.dev_mode
	gs.dev_mode = true
	var screen := _fresh()
	var names: Array[String] = []
	for row_v in screen._rows:
		var row: Dictionary = row_v
		names.append(String(row.name))
	t.check("Lackey's Arena" in names and "Goliath's Arena" in names,
		"fight card: Developer Mode exposes both boss shortcuts")
	t.check(screen._rows.size() == 12,
		"fight card: eleven campaign fights plus BACK in Developer Mode")
	t.root.remove_child(screen)
	screen.free()
	gs.dev_mode = before

func test_pick_stamps_battle_slot() -> void:
	var gs: Node = t.root.get_node(^"/root/GameState")
	var flow: Node = t.root.get_node(^"/root/SceneFlow")
	var before: int = gs.battle_level_index
	var screen := _fresh()
	for row_v in screen._rows:
		var row: Dictionary = row_v
		if int(row.campaign_index) >= 0 \
				and String(flow.CAMPAIGN[int(row.campaign_index)].scene).ends_with("snowy.tscn"):
			screen._commit_pick(row)
	t.check(String(flow.CAMPAIGN[gs.battle_level_index].scene).ends_with("snowy.tscn"),
		"fight card: a pick stamps the campaign slot index")
	gs.battle_level_index = before
	t.root.remove_child(screen)
	screen.free()

func test_battle_slot_is_run_state_and_survives_reset() -> void:
	var gs_script: Script = load("res://game/game_state.gd")
	var fresh: Node = gs_script.new()
	t.check(fresh.battle_level_index == 0, "fight card: battle slot defaults to 0")
	t.check(not fresh.SETTINGS_KEYS.has("battle_level_index")
		and not fresh.SETTINGS_KEYS.has("start_level_index"),
		"fight card: battle slot never persists; the old START LEVEL key is retired")
	fresh.battle_level_index = 9
	fresh.reset_campaign()
	t.check(fresh.battle_level_index == 9,
		"fight card: reset_campaign leaves the pending battle slot alone")
	fresh.free()
