extends Control
## The garage door: what kind of driving today? Sits between title SINGLE
## PLAYER and the rest of the SP chain. DRIVER'S ED opens the sign-up
## sub-dialog (full lesson plan vs free-roam test drive — both route through
## car select into the practice yard); ROAD TRIP is the campaign (difficulty
## select -> car select); SINGLE BATTLE is a greyed placeholder until that
## mode exists. Manual-highlight menu idiom cloned from title.gd — no focus
## system. ESC steps back to title; ESC inside the sub-dialog closes it.

const AMBER := Color(1.0, 0.85, 0.2)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const DISABLED_TEXT := Color(0.3, 0.32, 0.35)

const ENTRY_NAMES := ["DRIVER'S ED", "ROAD TRIP", "SINGLE BATTLE"]
const DISABLED := {2: true}  # SINGLE BATTLE — placeholder, cursor skips it
# Blurb copy is placeholder — Kevin's to word.
const BLURBS := [
	"learn the ropes — nobody shoots back",
	"the campaign: downtown to the coliseum",
	"coming soon",
]

const SUB_PROMPT := "WELCOME TO DRIVER'S ED"
const SUB_OPTIONS := ["FIRST TIME DRIVER", "JUST HERE FOR A TEST DRIVE"]
const SUB_MODES: Array[StringName] = [&"tutorial", &"test_drive"]

var _done := false
var _index := 0
var _sub: Control
var _sub_index := 0
var _sub_entries: Array[Label] = []

@onready var _entries: Array[Label] = [$Menu/DriversEd, $Menu/RoadTrip, $Menu/SingleBattle]
@onready var _blurb: Label = $Blurb

func _ready() -> void:
	_highlight()

func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if _sub:
		_sub_input(event)
		return
	# ESC steps back one layer: the garage door -> title.
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		UiSfx.back(self)
		_done = true
		SceneFlow.to_title()
		return
	var up: bool = event.is_action_pressed(&"move_up") or event.is_action_pressed(&"select_prev")
	var down: bool = event.is_action_pressed(&"move_down") or event.is_action_pressed(&"select_next")
	var confirm: bool = event.is_action_pressed(&"select_confirm") \
		or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
	if up:
		UiSfx.move(self)
		_step(-1)
	elif down:
		UiSfx.move(self)
		_step(1)
	elif confirm:
		UiSfx.select(self)
		_activate()

## Cursor motion that hops greyed-out rows (DISABLED indices can never land).
func _step(dir: int) -> void:
	_index = wrapi(_index + dir, 0, _entries.size())
	while DISABLED.has(_index):
		_index = wrapi(_index + dir, 0, _entries.size())
	_highlight()

func _highlight() -> void:
	for i in _entries.size():
		if DISABLED.has(i):
			_entries[i].modulate = DISABLED_TEXT
			_entries[i].text = ENTRY_NAMES[i]
		else:
			_entries[i].modulate = AMBER if i == _index else DIM_TEXT
			_entries[i].text = ("[ %s ]" if i == _index else "%s") % ENTRY_NAMES[i]
	if _blurb:
		_blurb.text = BLURBS[_index]

func _activate() -> void:
	match _index:
		0:
			_open_sub()
		1:
			_done = true
			GameState.game_mode = &"campaign"
			SceneFlow.to_difficulty()
		_:
			pass  # disabled rows are unreachable, but confirm stays inert anyway

## The Driver's Ed sign-up window: lessons or just the yard?
func _sub_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		UiSfx.back(self)
		_close_sub()
		return
	var toggle: bool = event.is_action_pressed(&"move_up") or event.is_action_pressed(&"move_down") \
		or event.is_action_pressed(&"select_prev") or event.is_action_pressed(&"select_next")
	var confirm: bool = event.is_action_pressed(&"select_confirm") \
		or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
	if toggle:
		get_viewport().set_input_as_handled()
		_sub_index = 1 - _sub_index
		UiSfx.move(self)
		_sub_highlight()
	elif confirm:
		get_viewport().set_input_as_handled()
		UiSfx.select(self)
		_done = true
		_commit_sub_choice()
		SceneFlow.to_select()

## Split from the confirm so tests can assert the mode stamp without
## triggering a live scene change.
func _commit_sub_choice() -> void:
	GameState.game_mode = SUB_MODES[_sub_index]

func _open_sub() -> void:
	_sub = Control.new()
	_sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_sub)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub.add_child(center)

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
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var caption := Label.new()
	caption.text = SUB_PROMPT
	caption.add_theme_font_size_override("font_size", 26)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.modulate = AMBER
	vbox.add_child(caption)

	_sub_entries.clear()
	for option in SUB_OPTIONS:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)
		_sub_entries.append(lbl)
	_sub_index = 0  # first-timers are who this screen is for
	_sub_highlight()

func _sub_highlight() -> void:
	for i in _sub_entries.size():
		_sub_entries[i].modulate = AMBER if i == _sub_index else DIM_TEXT
		_sub_entries[i].text = ("[ %s ]" if i == _sub_index else "%s") % SUB_OPTIONS[i]

func _close_sub() -> void:
	if _sub:
		_sub.queue_free()
		_sub = null
