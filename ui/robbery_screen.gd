extends CanvasLayer
## The robbery card: what Route 666 shows instead of YOU LOSE. The pack ran
## you down (or picked over your wreck), took something, and left you on the
## shoulder — then any key limps you onward to the next stop. Freezes the
## tree on open like the end screen; PROCESS_MODE_ALWAYS keeps it alive.
## Built in code (no scene): the chase host instances it, calls open(), and
## waits for `finished`.

signal finished

const UiStyle := preload("res://ui/ui_style.gd")

const RED := Color(0.75, 0.2, 0.2)       # the end screen's lose accent
const INPUT_LOCK := 1.2  # players arrive here still hammering fire

const CAUSE_LINES := {
	&"caught": "THE PACK RAN YOU DOWN",
	&"wrecked": "THEY PICKED OVER THE WRECK",
}
const ROLL_ON_HINT := "press any key to limp onward"

var _armed := false
var _done := false
var _hint: Label

func _ready() -> void:
	layer = 72  # above the end screen's 70
	process_mode = Node.PROCESS_MODE_ALWAYS

## cause ∈ CAUSE_LINES keys; outcome = game/robbery.gd apply()'s return.
func open(cause: StringName, outcome: Dictionary) -> void:
	_build_ui(cause, outcome)
	get_tree().paused = true
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio:  # stingers ride the pause-immune pool — the freeze can't cut them
		audio.play(&"lose_sting")
	get_tree().create_timer(INPUT_LOCK, true).timeout.connect(_arm, CONNECT_ONE_SHOT)

func is_armed() -> bool:
	return _armed

func _arm() -> void:
	_armed = true
	if _hint:
		_hint.text = ROLL_ON_HINT
		_hint.modulate = UiStyle.AMBER

func _unhandled_input(event: InputEvent) -> void:
	if not _armed or _done:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	roll_on()

## The one exit (the key handler and the tests both land here): fires
## `finished` exactly once.
func roll_on() -> void:
	if _done:
		return
	_done = true
	finished.emit()

func _build_ui(cause: StringName, outcome: Dictionary) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := UiStyle.panel_style()
	style.border_color = RED
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := _line(vbox, "JACKED!", 52, RED)
	title.name = "Title"
	var cause_lbl := _line(vbox, String(CAUSE_LINES.get(cause, CAUSE_LINES[&"caught"])), 16, UiStyle.DIM_TEXT)
	cause_lbl.name = "Cause"

	var trim := HBoxContainer.new()
	trim.alignment = BoxContainer.ALIGNMENT_CENTER
	trim.add_theme_constant_override("separation", 8)
	for i in 9:
		var block := ColorRect.new()
		block.custom_minimum_size = Vector2(16, 16)
		block.color = RED if i % 2 == 0 else RED.darkened(0.55)
		trim.add_child(block)
	vbox.add_child(trim)

	var headline := _line(vbox, String(outcome.get("headline", "")), 26, UiStyle.AMBER)
	headline.name = "Headline"
	var detail := _line(vbox, String(outcome.get("detail", "")), 16, Color(0.8, 0.82, 0.86))
	detail.name = "Detail"

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)
	_hint = _line(vbox, "...", 14, UiStyle.DIM_TEXT)
	_hint.name = "Hint"

func _line(parent: Node, text: String, font_size: int, tone: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate = tone
	l.custom_minimum_size = Vector2(420, 0)
	parent.add_child(l)
	return l
