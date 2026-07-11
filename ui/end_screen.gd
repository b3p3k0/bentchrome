extends CanvasLayer
## Round-end screen: YOU WIN when every opponent is wrecked, YOU LOSE when the
## player dies (a same-frame tie counts as a loss — the wasteland is unfair).
## Poll-driven like the HUD: enemies via the "enemies" group (must be seen
## non-empty once, so it can't fire before the arena populates), player HP via
## the persisting player node. Freezes the tree on show; PROCESS_MODE_ALWAYS
## keeps the buttons alive. Instanced per-level next to the pause menu.

const AMBER := Color(1.0, 0.85, 0.2)    # win — HUD selected-weapon amber
const RED := Color(0.75, 0.2, 0.2)      # lose — HUD HP-bar red
const PANEL_BG := Color(0.07, 0.07, 0.09)

const INPUT_LOCK := 1.2  # seconds before buttons arm — combat fire mustn't click menus

## Chase mode: runtime-spawned hordes latch _seen_enemies, and a wiped wave
## between director spawns would read as "arena cleared" — a win at t=60. The
## chase host sets this and calls _show(true) itself when the clock runs out.
@export var suppress_group_win := false

## Victory-lap mode (the Coliseum): a WIN shows the card WITHOUT pausing the
## tree — the level keeps animating behind it (auto-lap, fireworks) and the
## dim veil thins so the show reads. Losses still freeze the world.
@export var win_keeps_rolling := false

var _seen_enemies := false
var _over := false
var _dim: ColorRect
var _center: CenterContainer
var _rolling_title: Label
var _rolling_hint: Label
var _claim_armed := false
var _title: Label
var _panel_style: StyleBoxFlat
var _trim_blocks: Array = []
var _restart_btn: Button
var _buttons: Array = []
var _hint: Label            # mid-campaign: "press any key to continue"
var _campaign_next := -1    # armed continue target (next level index)
var _continue_armed := false

func _ready() -> void:
	layer = 70  # above the pause menu's 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func _process(_delta: float) -> void:
	if _over or get_tree().paused:  # nothing ends while the world is frozen
		# (an unpaused rolling win still parks here — _over holds the state)
		return
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	if not enemies.is_empty():
		_seen_enemies = true
	var player = get_tree().get_first_node_in_group(&"player")
	var gs := get_node_or_null(^"/root/GameState")
	# The level's lives loop respawns the player while lives remain; the round
	# is only lost once the tank is empty (no GameState = old single-life rule).
	if player and player.get_hp() <= 0.0 and (gs == null or gs.lives <= 0):
		_show(false)
	elif _seen_enemies and enemies.is_empty() and not suppress_group_win:
		_show(true)

## Index of the next campaign level after this scene, or -1 (off-campaign /
## final level — those keep the full panel with buttons).
func _campaign_next_index() -> int:
	var flow := get_node_or_null(^"/root/SceneFlow")
	if get_node_or_null(^"/root/GameState") == null or flow == null:
		return -1
	var here: String = get_tree().current_scene.scene_file_path
	for i in flow.CAMPAIGN.size():
		if flow.CAMPAIGN[i].scene == here and i + 1 < flow.CAMPAIGN.size():
			return i + 1
	return -1

func _show(win: bool) -> void:
	_over = true
	if win and win_keeps_rolling:
		_show_rolling_win()
		return
	var next := _campaign_next_index() if win else -1
	var accent := AMBER if win else RED
	_title.text = "YOU WIN" if win else "YOU LOSE"
	_title.modulate = accent
	_panel_style.border_color = accent
	for i in _trim_blocks.size():
		_trim_blocks[i].color = accent if i % 2 == 0 else accent.darkened(0.55)
	get_tree().paused = true
	visible = true
	if next >= 0:
		# Mid-campaign win: a beat of glory instead of a hard cut — any key
		# (after the anti-spam lock) rolls the loading card, then the level.
		_campaign_next = next
		for b in _buttons:
			b.visible = false
		_hint.visible = true
		get_tree().create_timer(INPUT_LOCK, true).timeout.connect(_arm_continue, CONNECT_ONE_SHOT)
		return
	# Players are still hammering fire when the last car dies — held SPACE is
	# also ui_accept and would instantly press the focused button. Buttons stay
	# dead (and unfocused) for a beat; the timer runs through the pause.
	for b in _buttons:
		b.disabled = true
	get_tree().create_timer(INPUT_LOCK, true).timeout.connect(_arm_buttons, CONNECT_ONE_SHOT)

## The rolling win frames the shot on the 3x3: the parading car holds the
## center cell (the camera follows it), YOU WIN! rides the top-center cell,
## and the prize hint fades into the bottom-center cell after a beat. No
## panel, no freeze — the lap and the fireworks ARE the screen.
func _show_rolling_win() -> void:
	visible = true
	_dim.color.a = 0.15
	_center.visible = false  # the classic panel waits behind the stub
	_rolling_title = Label.new()
	_rolling_title.text = "YOU WIN!"
	_rolling_title.add_theme_font_size_override("font_size", 56)
	_rolling_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rolling_title.modulate = AMBER
	_rolling_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_rolling_title.offset_top = 84.0
	add_child(_rolling_title)
	_rolling_hint = Label.new()
	_rolling_hint.text = "Press any key to claim your prize..."
	_rolling_hint.add_theme_font_size_override("font_size", 20)
	_rolling_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rolling_hint.modulate = AMBER
	_rolling_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_rolling_hint.offset_top = -150.0
	_rolling_hint.visible = false  # the short beat before the ask
	add_child(_rolling_hint)
	get_tree().create_timer(INPUT_LOCK, true).timeout.connect(_arm_claim, CONNECT_ONE_SHOT)

func _arm_claim() -> void:
	_claim_armed = true
	if _rolling_hint:
		_rolling_hint.visible = true

## Close-sequence STUB: the real prize ceremony is still on the drawing
## board — reveal the classic panel so every road stays open.
func _claim_prize() -> void:
	print("[coliseum] prize sequence TBD — enjoy the fireworks")
	if _rolling_hint:
		_rolling_hint.visible = false
	_center.visible = true
	for b in _buttons:
		b.disabled = false
	if _restart_btn:
		_restart_btn.grab_focus()

func _arm_buttons() -> void:
	for b in _buttons:
		b.disabled = false
	if _restart_btn:
		_restart_btn.grab_focus()

func _arm_continue() -> void:
	_continue_armed = true
	_hint.text = "press any key to continue"
	_hint.modulate = AMBER

func _unhandled_input(event: InputEvent) -> void:
	if not _continue_armed and not _claim_armed:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	if _claim_armed:
		get_viewport().set_input_as_handled()
		_claim_armed = false
		_claim_prize()
		return
	get_viewport().set_input_as_handled()
	_continue_armed = false
	get_tree().paused = false
	var gs := get_node_or_null(^"/root/GameState")
	var flow := get_node_or_null(^"/root/SceneFlow")
	if gs and flow:
		gs.level_index = _campaign_next
		flow.to_interstitial()

func _leave(action: Callable) -> void:
	get_tree().paused = false  # paused survives scene changes — always release
	action.call()

func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_center)

	var panel := PanelContainer.new()
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = PANEL_BG
	for side in ["left", "right", "top", "bottom"]:
		_panel_style.set("border_width_" + side, 6)  # fat square border — blocky
	panel.add_theme_stylebox_override("panel", _panel_style)
	_center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_title = Label.new()
	_title.text = "YOU WIN"
	_title.add_theme_font_size_override("font_size", 48)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	var trim := HBoxContainer.new()
	trim.alignment = BoxContainer.ALIGNMENT_CENTER
	trim.add_theme_constant_override("separation", 8)
	for i in 9:
		var block := ColorRect.new()
		block.custom_minimum_size = Vector2(16, 16)
		trim.add_child(block)
		_trim_blocks.append(block)
	vbox.add_child(trim)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	_hint = Label.new()
	_hint.text = "..."
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(0.55, 0.58, 0.62)
	_hint.visible = false
	vbox.add_child(_hint)

	_restart_btn = _button(vbox, "Restart", func() -> void:
		_leave(func() -> void:
			# Campaign levels restart the whole run (full wipe, level 1, 3
			# lives); custom levels just reload themselves.
			var gs := get_node_or_null(^"/root/GameState")
			var flow := get_node_or_null(^"/root/SceneFlow")
			var here: String = get_tree().current_scene.scene_file_path
			var on_campaign := false
			if flow:
				for entry in flow.CAMPAIGN:
					if entry.scene == here:
						on_campaign = true
			if on_campaign and gs and flow:
				gs.reset_campaign()
				flow.to_level(0)
			else:
				get_tree().reload_current_scene()))
	_button(vbox, "Change Car", func() -> void:
		_leave(func() -> void:
			var flow := get_node_or_null(^"/root/SceneFlow")
			if flow:
				flow.to_select()))
	var gs := get_node_or_null(^"/root/GameState")
	if gs and gs.playtest_return_to_editor:
		_button(vbox, "Return to Editor", func() -> void:
			_leave(func() -> void:
				var flow := get_node_or_null(^"/root/SceneFlow")
				if flow:
					flow.goto_scene("res://editor/editor_main.tscn")))
	_button(vbox, "Quit to Title", func() -> void:
		_leave(func() -> void:
			var flow := get_node_or_null(^"/root/SceneFlow")
			if flow:
				flow.to_title()))
	_button(vbox, "Quit Desktop", func() -> void: get_tree().quit())

func _button(parent: Node, label: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(220, 0)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	_buttons.append(b)
	return b
