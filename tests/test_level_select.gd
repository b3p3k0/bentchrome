extends RefCounted
## The fight card (SINGLE BATTLE's level picker): the filter lists melee
## arenas selectable and placeholder slots greyed while boss/chase slots
## stay off the card entirely; the screen boots its cursor onto a live row
## and hops greyed ones; a pick stamps GameState.battle_level_index; and the
## battle slot is run state that survives reset_campaign (car select resets
## the run BEFORE launching into the slot). The scene is load()ed at test
## time, NOT const-preloaded: level_select.gd names autoloads, which only
## compile once autoloads are registered. Routing confirms (scene swaps)
## stay untested here — _commit_pick is isolated for exactly that.

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
	var rows: Array = script.listed_slots(flow.CAMPAIGN)
	var enabled_tails: Array[String] = []
	var locked_names: Array[String] = []
	for row_v in rows:
		var row: Dictionary = row_v
		if bool(row.enabled):
			var profile: Dictionary = flow.CAMPAIGN[int(row.campaign_index)]
			enabled_tails.append(String(profile.scene).get_file())
		else:
			locked_names.append(String(row.name))
	t.check(enabled_tails == ["dock.tscn", "downtown.tscn", "freeway.tscn",
			"suburbs.tscn", "snowy.tscn", "ground_floor_gore.tscn"],
		"fight card: every melee arena is selectable, in tour order")
	t.check(locked_names == ["Arena Assault", "Terminal Terror",
			"Slaughter on the Strip", "Capital City Carnage"],
		"fight card: unbuilt slots hang greyed as coming attractions")
	for row_v in rows:
		var row: Dictionary = row_v
		var profile: Dictionary = flow.CAMPAIGN[int(row.campaign_index)]
		t.check(StringName(profile.encounter) != &"miniboss"
			and StringName(profile.encounter) != &"boss"
			and StringName(profile.encounter) != &"chase",
			"fight card: %s is not a boss or chase slot" % row.name)

func test_screen_boots_onto_a_live_row() -> void:
	var screen := _fresh()
	t.check(screen._entries.size() == screen._rows.size()
		and screen._rows.size() == 11,
		"fight card: ten tour rows plus BACK")
	t.check(bool(screen._rows[screen._index].enabled),
		"fight card: cursor never boots onto a greyed slot")
	t.check(String(screen._rows[screen._index].name) == "Piers of Pain",
		"fight card: first live slot is Piers of Pain")
	var first: int = screen._index
	screen._step(-1)
	t.check(bool(screen._rows[screen._index].enabled) and screen._index != first,
		"fight card: cursor hop lands live going up too")
	t.check(screen._entries[0].modulate == screen.DISABLED_TEXT,
		"fight card: greyed slot wears the disabled grey")
	t.root.remove_child(screen)
	screen.free()

func test_pick_stamps_battle_slot() -> void:
	var gs: Node = t.root.get_node(^"/root/GameState")
	var flow: Node = t.root.get_node(^"/root/SceneFlow")
	var before: int = gs.battle_level_index
	var screen := _fresh()
	for row_v in screen._rows:
		var row: Dictionary = row_v
		if bool(row.enabled) and int(row.campaign_index) >= 0 \
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
