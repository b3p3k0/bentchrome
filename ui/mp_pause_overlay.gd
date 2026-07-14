extends CanvasLayer
## The MP-match ESC menu. The tree NEVER pauses — the host's simulation keeps
## every other player alive, and a client freezing itself would only drift —
## so this is a plain overlay: RESUME closes it, LEAVE MATCH hangs up the
## session and heads for the front door.

const IR := preload("res://game/input_router.gd")  # consts, not the autoload
const UiStyle := preload("res://ui/ui_style.gd")

const AMBER := Color(1.0, 0.85, 0.2)
const DIM_TEXT := Color(0.55, 0.58, 0.62)

var _panel: Control
var _resume_btn: Button

func _ready() -> void:
	layer = 20  # above the arena HUD
	_panel = _build()
	_panel.visible = false
	add_child(_panel)
	UiSfx.wire(self)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(IR.ACTION_PAUSE):
		return
	get_viewport().set_input_as_handled()
	UiSfx.back(self)
	_set_open(not _panel.visible)

func _set_open(open: bool) -> void:
	_panel.visible = open
	# Reveal the pointer while the overlay is up (buttons are clickable); the
	# match view runs cursor-hidden otherwise.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_HIDDEN)
	if open and _resume_btn:
		_resume_btn.grab_focus()
	elif not open:
		var focused := get_viewport().gui_get_focus_owner()
		if focused and _panel.is_ancestor_of(focused):
			focused.release_focus()

func _build() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09)
	style.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 6)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)
	var head := Label.new()
	head.text = "STILL ROLLING"
	head.add_theme_font_size_override("font_size", 24)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.modulate = AMBER
	vbox.add_child(head)
	var hint := Label.new()
	hint.text = "the wasteland does not pause for you"
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = DIM_TEXT
	vbox.add_child(hint)
	_resume_btn = _button("RESUME", func() -> void: _set_open(false))
	vbox.add_child(_resume_btn)
	var net := get_node(^"/root/Net")
	if net and net.is_host():
		# Capless brawls need an exit; the shell owns the director.
		vbox.add_child(_button("END MATCH", _end_match))
	vbox.add_child(_button("LEAVE MATCH", _leave))
	return root

func _end_match() -> void:
	var shell := get_parent()
	if shell and shell.has_method(&"host_force_end"):
		shell.host_force_end()

func _leave() -> void:
	# Autoloads by path: this script rides mp_match's preload chain into the
	# test runner, where -s compilation can't bind autoload identifiers.
	get_node(^"/root/Net").leave()
	get_node(^"/root/SceneFlow").to_mp_menu()

func _button(caption: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.add_theme_font_size_override("font_size", 18)
	UiStyle.theme_button(btn)
	btn.pressed.connect(action)
	return btn
