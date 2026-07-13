extends RefCounted
## Mode select (the garage door): cursor skips the greyed SINGLE BATTLE row
## from both directions, a confirm on it stays inert, the Driver's Ed
## sub-dialog opens/closes/toggles, and each sign-up option stamps the right
## GameState.game_mode. The scene is load()ed at test time, NOT const-
## preloaded: mode_select.gd names autoloads, which only compile once
## autoloads are registered — suite preloads happen before that. Branches
## that swap scenes (ESC to title, ROAD TRIP, sub-dialog launch) stay
## untested here; the human flow pass covers them.

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
	t.check(menu._index == 0, "mode: cursor boots on DRIVER'S ED")
	_press(menu, &"move_down")
	t.check(menu._index == 1, "mode: down lands on ROAD TRIP")
	_press(menu, &"move_down")
	t.check(menu._index == 0, "mode: down from ROAD TRIP hops SINGLE BATTLE")
	_press(menu, &"move_up")
	t.check(menu._index == 1, "mode: up from DRIVER'S ED hops SINGLE BATTLE")
	t.check(menu._entries[2].modulate == menu.DISABLED_TEXT,
		"mode: SINGLE BATTLE wears the disabled grey")
	t.check(not menu._entries[2].text.begins_with("["),
		"mode: SINGLE BATTLE never renders the cursor brackets")
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
	menu._activate()  # cursor boots on DRIVER'S ED
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
