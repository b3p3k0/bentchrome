extends CanvasLayer
## One lesson card: freezes the world, shows an interstitial-style bordered
## panel (title + body copy), and waits for any key. The 1.2s input lock is
## the interstitial's — players arrive mid-drive still hammering fire. The
## director owns WHAT to show and WHEN; this owns the look and the input.
## Layer 61 sits above pause/end (60) so a lesson can never be buried;
## pause_menu's courtesy guard already yields while the tree is paused.

signal dismissed

const AMBER := Color(1.0, 0.85, 0.2)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const PANEL_BG := Color(0.07, 0.07, 0.09)

static var INPUT_LOCK := 1.2

var _armed := false
var _title: Label
var _body: Label
var _hint: Label

func _init() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build_ui()
	visible = false

## Pauses the tree for the read; dismissal unpauses. Every show re-arms the
## input lock so a held key can't blow through a fresh card.
func show_card(title: String, body: String) -> void:
	_title.text = title
	_body.text = body
	_hint.text = "..."
	_hint.modulate = DIM_TEXT
	_armed = false
	visible = true
	get_tree().paused = true
	get_tree().create_timer(INPUT_LOCK).timeout.connect(_arm, CONNECT_ONE_SHOT)

func _arm() -> void:
	if not visible:
		return  # dismissed-by-test or hidden before the lock ran out
	_armed = true
	_hint.text = "press any key"
	_hint.modulate = AMBER

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _armed:
		return
	var pressed: bool = (event is InputEventKey and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	visible = false
	get_tree().paused = false
	dismissed.emit()

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
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.modulate = AMBER
	vbox.add_child(_title)

	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 18)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(560, 0)
	_body.modulate = Color(0.85, 0.87, 0.9)
	vbox.add_child(_body)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = DIM_TEXT
	vbox.add_child(_hint)
