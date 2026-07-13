extends CanvasLayer
## "Leave Driver's Ed?" — the exit-tunnel confirm. Keyboard YES/NO idiom
## cloned from title.gd's quit confirm: any nav key toggles, confirm
## activates, ESC backs out. Staying is the default — leaving takes intent.
## Freezes the tree while open (PROCESS_MODE_ALWAYS keeps its own input
## alive); the director owns what happens on either answer and the unpause.

signal confirmed   # hit the road: back to title
signal cancelled   # keep practicing

const AMBER := Color(1.0, 0.85, 0.2)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const PANEL_BG := Color(0.07, 0.07, 0.09)
const PROMPT := "LEAVE DRIVER'S ED?"
const OPTIONS := ["HIT THE ROAD", "KEEP PRACTICING"]

var _index := 1  # KEEP PRACTICING
var _entries: Array[Label] = []
var _done := false

func _init() -> void:
	layer = 62
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build_ui()
	_highlight()
	get_tree().paused = true

func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		UiSfx.back(self)
		_done = true
		cancelled.emit()
		return
	var toggle: bool = event.is_action_pressed(&"move_up") or event.is_action_pressed(&"move_down") \
		or event.is_action_pressed(&"move_left") or event.is_action_pressed(&"move_right") \
		or event.is_action_pressed(&"select_prev") or event.is_action_pressed(&"select_next")
	var confirm: bool = event.is_action_pressed(&"select_confirm") \
		or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
	if toggle:
		get_viewport().set_input_as_handled()
		_index = 1 - _index
		UiSfx.move(self)
		_highlight()
	elif confirm:
		get_viewport().set_input_as_handled()
		UiSfx.select(self)
		_done = true
		if _index == 0:
			confirmed.emit()
		else:
			cancelled.emit()

func _highlight() -> void:
	for i in _entries.size():
		_entries[i].modulate = AMBER if i == _index else DIM_TEXT
		_entries[i].text = ("[ %s ]" if i == _index else "%s") % OPTIONS[i]

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
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
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var caption := Label.new()
	caption.text = PROMPT
	caption.add_theme_font_size_override("font_size", 26)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.modulate = AMBER
	vbox.add_child(caption)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	vbox.add_child(row)
	_entries.clear()
	for option in OPTIONS:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 22)
		row.add_child(lbl)
		_entries.append(lbl)
