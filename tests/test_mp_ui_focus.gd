extends RefCounted
## MP menus use Godot's button-focus navigation. Every screen must seed focus,
## and destructive confirms must land on their safe choice.

var t

func _init(runner) -> void:
	t = runner

func _focus_owner() -> Control:
	return t.root.get_viewport().gui_get_focus_owner()

func _free_ui(node: Node) -> void:
	var focused := _focus_owner()
	if focused:
		focused.release_focus()
	t.root.remove_child(node)
	node.free()

func test_mp_menu_seeds_each_panel_focus() -> void:
	var menu: Control = (load("res://ui/mp_menu.tscn") as PackedScene).instantiate()
	t.root.add_child(menu)
	await t.process_frame
	t.check(_focus_owner() == menu._panel_default_focus[&"home"],
		"mp ui: front door focuses HOST A GAME")
	menu._show(&"host")
	await t.process_frame
	t.check(_focus_owner() == menu._panel_default_focus[&"host"],
		"mp ui: host panel focuses OPEN THE DOORS")
	menu._show(&"join")
	await t.process_frame
	t.check(_focus_owner() == menu._server_list,
		"mp ui: join panel focuses the keyboard-selectable server list")
	menu._show(&"home")  # closes the discovery listener before teardown
	_free_ui(menu)

func test_mp_lobby_focus_and_safe_confirm() -> void:
	var lobby: Control = (load("res://ui/mp_lobby.tscn") as PackedScene).instantiate()
	t.root.add_child(lobby)
	await t.process_frame
	t.check(_focus_owner() == lobby._start_btn,
		"mp ui: garage seeds its primary action")
	lobby._open_confirm("Leave?", "LEAVE", "STAY", func() -> void: pass)
	var safe := _focus_owner() as Button
	t.check(safe != null and safe.text == "STAY",
		"mp ui: garage confirm focuses the safe choice")
	lobby._close_confirm()
	await t.process_frame
	t.check(_focus_owner() == lobby._start_btn,
		"mp ui: closing confirm restores the prior garage focus")
	_free_ui(lobby)

func test_mp_pause_focuses_resume() -> void:
	var pause: CanvasLayer = (load("res://ui/mp_pause_overlay.tscn") as PackedScene).instantiate()
	t.root.add_child(pause)
	pause._set_open(true)
	t.check(_focus_owner() == pause._resume_btn,
		"mp ui: in-match pause focuses RESUME")
	pause._set_open(false)
	t.check(_focus_owner() != pause._resume_btn,
		"mp ui: closing in-match pause releases overlay focus")
	_free_ui(pause)

func test_mp_scoreboard_focuses_return() -> void:
	var scoreboard: Control = (load("res://ui/mp_scoreboard.tscn") as PackedScene).instantiate()
	t.root.add_child(scoreboard)
	t.check(_focus_owner() == scoreboard._primary_btn,
		"mp ui: scoreboard focuses its return action")
	_free_ui(scoreboard)
