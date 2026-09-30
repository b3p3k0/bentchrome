extends CanvasLayer
## The robbery: what Route 666 shows instead of YOU LOSE. Three beats, one
## key each:
##   1. THE WHEEL — JACKED!, the roulette spins down onto a wedge that was
##      rolled (and billed) before the card ever opened. A key skips the spin.
##   2. THE VERDICT — what they took, in the pack's own words.
##   3. THE SPLASH — the driver and their ride, left on the shoulder. Art is
##      a drop-in (assets/img/jacked/<car_id>.png); see art_path() for the
##      fallback ladder. No picture at all skips the beat.
## Then `finished`, and the host rolls the campaign on. Freezes the tree on
## open like the end screen; PROCESS_MODE_ALWAYS keeps it alive. Built in
## code (no scene): the chase host instances it and calls open().

signal finished

const UiStyle := preload("res://ui/ui_style.gd")
const CardFrame := preload("res://ui/card_frame.gd")
const WheelScript := preload("res://ui/robbery_wheel.gd")

const RED := Color(0.75, 0.2, 0.2)       # the end screen's lose accent
const INPUT_LOCK := 1.2   # players arrive here still hammering fire
const SPIN_DELAY := 0.7   # the wheel sits a beat before it turns
const ART_DIR := "res://assets/img/jacked"
const BIO_DIR := "res://assets/img/bios"
const GENERIC_ART := "_generic"

const CAUSE_LINES := {
	&"caught": "THE PACK RAN YOU DOWN",
	&"wrecked": "THEY PICKED OVER THE WRECK",
}
const SKIP_HINT := "press any key to stop the wheel"
const VERDICT_HINT := "press any key"
const ROLL_ON_HINT := "press any key to limp onward"

enum Stage { WHEEL, VERDICT, SPLASH, DONE }

var stage: int = Stage.WHEEL

var _armed := false
var _outcome: Dictionary = {}
var _car_id := ""
var _panel_root: Control = null
var _wheel: Control = null
var _headline: Label = null
var _detail: Label = null
var _hint: Label = null

func _ready() -> void:
	layer = 72  # above the end screen's 70
	process_mode = Node.PROCESS_MODE_ALWAYS

## The splash ladder for a roster id: the car's own jacked card, then the
## shared generic card, then the car's bio portrait (a stand-in until the art
## lands), else "" — no picture, no splash beat. Imported resources and raw
## drop-ins both count; nothing is loaded that isn't there.
static func art_path(car_id: String) -> String:
	var candidates: Array = []
	if car_id != "":
		candidates.append("%s/%s.png" % [ART_DIR, car_id])
	candidates.append("%s/%s.png" % [ART_DIR, GENERIC_ART])
	if car_id != "":
		candidates.append("%s/%s.png" % [BIO_DIR, car_id])
	for path in candidates:
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path
	return ""

## cause ∈ CAUSE_LINES keys; outcome = game/robbery.gd apply()'s return;
## wheel/landed = the slices and the pre-rolled wedge (empty = no spin, the
## verdict shows at once); car_id picks the splash.
func open(cause: StringName, outcome: Dictionary, wheel: Array = [], landed := -1,
		car_id := "") -> void:
	_outcome = outcome
	_car_id = car_id
	_build_panel(cause, wheel, landed)
	get_tree().paused = true
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio:  # stingers ride the pause-immune pool — the freeze can't cut them
		var own: bool = audio.has_method(&"has_asset") and audio.has_asset(&"jacked")
		audio.play(&"jacked" if own else &"lose_sting")
	if _wheel != null:
		stage = Stage.WHEEL
		_hint.text = "..."
		get_tree().create_timer(SPIN_DELAY, true).timeout.connect(_wheel.spin, CONNECT_ONE_SHOT)
		_arm_after(INPUT_LOCK, SKIP_HINT)
	else:
		_show_verdict()

func is_armed() -> bool:
	return _armed

func _arm_after(seconds: float, hint: String) -> void:
	_armed = false
	var at_stage := stage
	get_tree().create_timer(seconds, true).timeout.connect(func() -> void:
		if stage != at_stage:
			return  # the beat moved on (the wheel landed) — that beat arms itself
		_armed = true
		if _hint:
			_hint.text = hint
			_hint.modulate = UiStyle.AMBER, CONNECT_ONE_SHOT)

func _unhandled_input(event: InputEvent) -> void:
	if not _armed or stage == Stage.DONE:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	advance()

## One step forward, whatever the beat (the key handler and the tests both
## land here): stop the wheel, leave the verdict, leave the splash.
func advance() -> void:
	match stage:
		Stage.WHEEL:
			if _wheel != null:
				_wheel.finish_now()  # lands -> _on_landed -> the verdict
		Stage.VERDICT:
			if not _show_splash():
				roll_on()
		Stage.SPLASH:
			roll_on()

## The one exit: fires `finished` exactly once, from any beat.
func roll_on() -> void:
	if stage == Stage.DONE:
		return
	stage = Stage.DONE
	_armed = false
	finished.emit()

func _on_landed(_index: int) -> void:
	if stage == Stage.WHEEL:
		_show_verdict()

func _show_verdict() -> void:
	stage = Stage.VERDICT
	if _headline:
		_headline.text = String(_outcome.get("headline", ""))
		_headline.visible = true
	if _detail:
		_detail.text = String(_outcome.get("detail", ""))
		_detail.visible = true
	if _hint:
		_hint.text = "..."
		_hint.modulate = UiStyle.DIM_TEXT
	UiSfx.select(self)
	_arm_after(INPUT_LOCK, VERDICT_HINT if art_path(_car_id) != "" else ROLL_ON_HINT)

## Swaps the panel for the splash card. False = no picture to show.
func _show_splash() -> bool:
	var path := art_path(_car_id)
	if path == "":
		return false
	var tex := TextureLoader.load_texture(path)
	if tex == null:
		return false
	stage = Stage.SPLASH
	if _panel_root:
		_panel_root.queue_free()
		_panel_root = null
		_wheel = null
	var card := Control.new()
	card.name = "Splash"
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(card)
	var caption := "%s  —  %s" % [String(_outcome.get("headline", "")), String(_outcome.get("detail", ""))]
	_hint = CardFrame.build(card, tex, caption, UiStyle.AMBER)
	if path.begins_with(BIO_DIR):
		# The stand-in portrait is the driver on a GOOD day: bruise it so the
		# card still reads as the morning after.
		var art := card.get_node_or_null(CardFrame.ART_NAME) as CanvasItem
		if art:
			art.modulate = Color(0.78, 0.52, 0.5)
	_arm_after(INPUT_LOCK, ROLL_ON_HINT)
	return true

func _build_panel(cause: StringName, wheel: Array, landed: int) -> void:
	_panel_root = Control.new()
	_panel_root.name = "Panel"
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.add_child(center)

	var panel := PanelContainer.new()
	var style := UiStyle.panel_style()
	style.border_color = RED
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_line(vbox, "JACKED!", 48, RED).name = "Title"
	_line(vbox, String(CAUSE_LINES.get(cause, CAUSE_LINES[&"caught"])), 16, UiStyle.DIM_TEXT).name = "Cause"

	if not wheel.is_empty() and landed >= 0:
		_line(vbox, "BOLTS, PARTS, OR BLOOD", 14, UiStyle.DIM_TEXT).name = "Motto"
		_wheel = WheelScript.new()
		_wheel.name = "Wheel"
		_wheel.setup(wheel, landed)
		_wheel.landed.connect(_on_landed)
		vbox.add_child(_wheel)
	else:
		var trim := HBoxContainer.new()
		trim.alignment = BoxContainer.ALIGNMENT_CENTER
		trim.add_theme_constant_override("separation", 8)
		for i in 9:
			var block := ColorRect.new()
			block.custom_minimum_size = Vector2(16, 16)
			block.color = RED if i % 2 == 0 else RED.darkened(0.55)
			trim.add_child(block)
		vbox.add_child(trim)

	_headline = _line(vbox, " ", 26, UiStyle.AMBER)
	_headline.name = "Headline"
	_detail = _line(vbox, " ", 16, Color(0.8, 0.82, 0.86))
	_detail.name = "Detail"
	_hint = _line(vbox, "...", 14, UiStyle.DIM_TEXT)
	_hint.name = "Hint"

func _line(parent: Node, text: String, font_size: int, tone: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate = tone
	l.custom_minimum_size = Vector2(440, 0)
	parent.add_child(l)
	return l
