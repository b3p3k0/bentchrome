extends CanvasLayer
## ESC pause menu: Resume / Restart / Quit to Title / Quit Desktop.
## Instanced per-level (arena.gd). Runs while the tree is paused
## (PROCESS_MODE_ALWAYS); everything else freezes on get_tree().paused.

const IR := preload("res://game/input_router.gd")  # consts, not the autoload —
												   # compiles under headless -s
const UiStyle := preload("res://ui/ui_style.gd")

var _resume_btn: Button

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	UiSfx.wire(self)  # buttons: pressed = select, focus arrival = move

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(IR.ACTION_PAUSE):
		if get_tree().paused and not visible:
			return  # something else (end screen) owns the pause — don't unfreeze
		get_viewport().set_input_as_handled()
		UiSfx.back(self)
		_set_paused(not visible)

func _set_paused(on: bool) -> void:
	get_tree().paused = on
	visible = on
	# Reveal the pointer while paused so the buttons are clickable; gameplay
	# hides it again on resume.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_HIDDEN)
	if on and _resume_btn:
		_resume_btn.grab_focus()

func _on_restart() -> void:
	_set_paused(false)
	# Reload whatever level is running — arena or a custom level (whose loader
	# re-reads GameState.pending_level_path on _ready).
	get_tree().reload_current_scene()

func _on_return_to_editor() -> void:
	_set_paused(false)
	var flow := get_node_or_null(^"/root/SceneFlow")
	if flow:
		flow.goto_scene("res://editor/editor_main.tscn")

func _on_quit_title() -> void:
	_set_paused(false)
	var flow := get_node_or_null(^"/root/SceneFlow")
	if flow:
		flow.to_title()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = UiStyle.AMBER
	vbox.add_child(title)

	_resume_btn = _button(vbox, "Resume", func() -> void: _set_paused(false))
	_button(vbox, "Restart", _on_restart)
	var gs := get_node_or_null(^"/root/GameState")
	if gs and gs.playtest_return_to_editor:
		_button(vbox, "Return to Editor", _on_return_to_editor)
	_button(vbox, "Quit to Title", _on_quit_title)
	_button(vbox, "Quit Desktop", _quit_desktop)

func _button(parent: Node, label: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(220, 0)
	UiStyle.theme_button(b)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b

## Menu quits route through SceneFlow's graceful exit (stops audio, waits one
## mix frame) so terminations leave a clean console; bare quit is the fallback
## for stripped fixtures.
func _quit_desktop() -> void:
	var flow := get_node_or_null(^"/root/SceneFlow")
	if flow and flow.has_method(&"quit_gracefully"):
		flow.quit_gracefully()
	else:
		get_tree().quit()
