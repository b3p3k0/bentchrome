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

var _seen_enemies := false
var _over := false
var _title: Label
var _panel_style: StyleBoxFlat
var _trim_blocks: Array = []
var _restart_btn: Button

func _ready() -> void:
	layer = 70  # above the pause menu's 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func _process(_delta: float) -> void:
	if _over or get_tree().paused:  # nothing ends while the world is frozen
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
	elif _seen_enemies and enemies.is_empty():
		_show(true)

## Mid-campaign win: advance the index and hand off to the interstitial
## instead of the YOU WIN panel. Returns false off-campaign (custom levels)
## and on the final level.
func _campaign_advance() -> bool:
	var gs := get_node_or_null(^"/root/GameState")
	var flow := get_node_or_null(^"/root/SceneFlow")
	if gs == null or flow == null:
		return false
	var here: String = get_tree().current_scene.scene_file_path
	var idx := -1
	for i in flow.CAMPAIGN.size():
		if flow.CAMPAIGN[i].scene == here:
			idx = i
	if idx < 0 or idx + 1 >= flow.CAMPAIGN.size():
		return false
	gs.level_index = idx + 1
	flow.to_interstitial()
	return true

func _show(win: bool) -> void:
	_over = true
	if win and _campaign_advance():
		return
	var accent := AMBER if win else RED
	_title.text = "YOU WIN" if win else "YOU LOSE"
	_title.modulate = accent
	_panel_style.border_color = accent
	for i in _trim_blocks.size():
		_trim_blocks[i].color = accent if i % 2 == 0 else accent.darkened(0.55)
	get_tree().paused = true
	visible = true
	if _restart_btn:
		_restart_btn.grab_focus()

func _leave(action: Callable) -> void:
	get_tree().paused = false  # paused survives scene changes — always release
	action.call()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = PANEL_BG
	for side in ["left", "right", "top", "bottom"]:
		_panel_style.set("border_width_" + side, 6)  # fat square border — blocky
	panel.add_theme_stylebox_override("panel", _panel_style)
	center.add_child(panel)

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
	return b
