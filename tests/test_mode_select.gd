extends RefCounted
## Mode select (the garage door): cursor skips the greyed SINGLE BATTLE row
## from both directions, a confirm on it stays inert, the Driver's Ed
## sub-dialog opens/closes/toggles, and each sign-up option stamps the right
## GameState.game_mode. The scene is load()ed at test time, NOT const-
## preloaded: mode_select.gd names autoloads, which only compile once
## autoloads are registered — suite preloads happen before that. Branches
## that swap scenes (ESC to title, ROAD TRIP routing, sub-dialog launch) stay
## untested here; their state commits are isolated below and the human flow
## pass covers navigation.

const Difficulty := preload("res://game/difficulty.gd")

var t

func _init(runner) -> void:
	t = runner

func _fresh() -> Control:
	var menu: Control = (load("res://ui/mode_select.tscn") as PackedScene).instantiate()
	t.root.add_child(menu)
	return menu

func _press(menu: Control, action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	menu._unhandled_input(ev)

func test_nav_skips_disabled_row() -> void:
	var menu := _fresh()
	t.check(menu._index == 1, "mode: cursor boots on ROAD TRIP")
	_press(menu, &"move_down")
	t.check(menu._index == menu.BACK_INDEX, "mode: down from ROAD TRIP hops to BACK")
	_press(menu, &"move_down")
	t.check(menu._index == 0, "mode: down from BACK wraps to DRIVER'S ED")
	_press(menu, &"move_down")
	t.check(menu._index == 1, "mode: down from DRIVER'S ED lands on ROAD TRIP")
	_press(menu, &"move_up")
	t.check(menu._index == 0, "mode: up from ROAD TRIP lands on DRIVER'S ED")
	_press(menu, &"move_up")
	t.check(menu._index == menu.BACK_INDEX, "mode: up from DRIVER'S ED lands on BACK")
	_press(menu, &"move_up")
	t.check(menu._index == 1, "mode: up from BACK hops SINGLE BATTLE")
	t.check(menu._entries[2].modulate == menu.DISABLED_TEXT,
		"mode: SINGLE BATTLE wears the disabled grey")
	t.check(not menu._entries[2].text.begins_with("["),
		"mode: SINGLE BATTLE never renders the cursor brackets")
	t.check(menu._entries[menu.BACK_INDEX].text == "BACK",
		"mode: BACK is a visible selectable row")
	t.root.remove_child(menu)
	menu.free()

func test_disabled_confirm_inert() -> void:
	var menu := _fresh()
	menu._index = 2  # unreachable via nav; forced to prove confirm stays dead
	menu._activate()
	t.check(not menu._done, "mode: confirm on the disabled row does nothing")
	t.check(menu._sub == null, "mode: disabled row opens no dialog")
	t.root.remove_child(menu)
	menu.free()

func test_sub_dialog_open_toggle_close() -> void:
	var menu := _fresh()
	menu._index = 0
	menu._activate()
	t.check(menu._sub != null, "mode: DRIVER'S ED opens the sign-up dialog")
	t.check(not menu._done, "mode: the dialog alone leaves the screen live")
	t.check(menu._sub_index == 0, "mode: FIRST TIME DRIVER is the default")
	_press(menu, &"move_down")
	t.check(menu._sub_index == 1, "mode: nav toggles to TEST DRIVE")
	_press(menu, &"move_up")
	t.check(menu._sub_index == 0, "mode: nav toggles back")
	_press(menu, &"pause")
	t.check(menu._sub == null, "mode: ESC closes the dialog, not the screen")
	t.check(not menu._done, "mode: list is live again after the dialog closes")
	t.root.remove_child(menu)
	menu.free()

func test_sub_dialog_explicit_back() -> void:
	var menu := _fresh()
	menu._index = 0
	menu._activate()
	_press(menu, &"move_up")  # first choice wraps to the visible BACK row
	t.check(menu._sub_index == menu.SUB_BACK_INDEX,
		"mode: Driver's Ed dialog exposes BACK")
	_press(menu, &"select_confirm")
	t.check(menu._sub == null, "mode: dialog BACK closes only the dialog")
	t.check(not menu._done, "mode: dialog BACK leaves lane selection live")
	t.root.remove_child(menu)
	menu.free()

func test_title_quit_entry_uses_safe_confirm() -> void:
	var title: Control = (load("res://ui/title.tscn") as PackedScene).instantiate()
	t.root.add_child(title)
	t.check(title._entries.size() == 5 and title.ENTRY_NAMES[4] == "QUIT GAME",
		"title: QUIT GAME is a visible fifth entry")
	title._index = 4
	title._activate()
	t.check(title._quit != null and title._quit_index == 1,
		"title: explicit quit opens the existing confirm on NO")
	_press(title, &"pause")
	t.check(title._quit == null and not title._done,
		"title: ESC still closes the quit confirm without leaving")
	t.root.remove_child(title)
	title.free()

func test_road_trip_starts_on_medium() -> void:
	var gs: Node = t.root.get_node_or_null("/root/GameState")
	t.check(gs != null, "mode: GameState autoload live for ROAD TRIP")
	if gs == null:
		return
	var before_mode: StringName = gs.game_mode
	var before_tier: int = Difficulty.tier
	var menu := _fresh()
	Difficulty.tier = Difficulty.Tier.HARD
	menu._commit_road_trip()
	t.check(gs.game_mode == &"campaign", "mode: ROAD TRIP stamps campaign")
	t.check(Difficulty.tier == Difficulty.Tier.MEDIUM,
		"mode: ROAD TRIP starts on ROAD RAGING COMMUTER")
	gs.game_mode = before_mode
	Difficulty.tier = before_tier
	t.root.remove_child(menu)
	menu.free()

func test_difficulty_return_keeps_explicit_pick() -> void:
	var before_tier: int = Difficulty.tier
	Difficulty.tier = Difficulty.Tier.EASY
	var screen: Control = (load("res://ui/difficulty_select.tscn") as PackedScene).instantiate()
	t.root.add_child(screen)
	t.check(screen._index == screen.ORDER.find(Difficulty.Tier.EASY),
		"mode: returning to difficulty keeps the explicit license pick")
	screen._index = screen.BACK_INDEX
	screen._highlight()
	t.check(screen._entries[screen.BACK_INDEX].text == "[ BACK ]",
		"mode: difficulty exposes selectable BACK")
	t.check(Difficulty.tier == Difficulty.Tier.EASY,
		"mode: browsing difficulty BACK does not mutate the tier")
	Difficulty.tier = before_tier
	t.root.remove_child(screen)
	screen.free()

func test_sub_choice_stamps_game_mode() -> void:
	var gs: Node = t.root.get_node_or_null("/root/GameState")
	t.check(gs != null, "mode: GameState autoload live under the runner")
	if gs == null:
		return
	var before: StringName = gs.game_mode
	var menu := _fresh()
	menu._sub_index = 0
	menu._commit_sub_choice()
	t.check(gs.game_mode == &"tutorial", "mode: FIRST TIME DRIVER stamps tutorial")
	menu._sub_index = 1
	menu._commit_sub_choice()
	t.check(gs.game_mode == &"test_drive", "mode: TEST DRIVE stamps test_drive")
	gs.game_mode = before  # restore the live autoload — later suites read it
	t.root.remove_child(menu)
	menu.free()

func test_game_mode_defaults_to_campaign() -> void:
	var gs_script: Script = load("res://game/game_state.gd")
	var fresh: Node = gs_script.new()
	t.check(fresh.game_mode == &"campaign", "mode: game_mode defaults to campaign")
	fresh.free()

## DEVGOD contradicts a syllabus that grades real actions (god consume()
## never depletes -> the bay-fire latch can never land; god Health takes no
## fender ding). It stands down for the lesson lane ONLY — the test-drive
## lane is the developer's bench and keeps it.
func test_devgod_inert_during_lessons() -> void:
	var gs_script: Script = load("res://game/game_state.gd")
	var fresh: Node = gs_script.new()
	fresh.dev_mode = true
	fresh.devgod = true
	fresh.game_mode = &"tutorial"
	t.check(not fresh.is_devgod_enabled(), "mode: DEVGOD inert during lessons")
	fresh.game_mode = &"test_drive"
	t.check(fresh.is_devgod_enabled(), "mode: DEVGOD live on the test-drive bench")
	fresh.game_mode = &"campaign"
	t.check(fresh.is_devgod_enabled(), "mode: DEVGOD untouched in campaign")
	fresh.free()
