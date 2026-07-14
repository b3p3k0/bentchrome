extends Control
## The DMV window: pick a license class before picking a ride. Sits between
## mode select (ROAD TRIP) and car select; the tier is run state (difficulty.gd static),
## fixed for the whole campaign — the end screen's Restart never comes back
## here, only Quit to Title does. Cursor lands on the current tier: choosing
## ROAD TRIP initializes it to ROAD RAGING COMMUTER, while backing up from car
## select preserves an explicit pick. Manual-highlight menu idiom cloned from
## title.gd — no focus system.

const Difficulty := preload("res://game/difficulty.gd")

const AMBER := Color(1.0, 0.85, 0.2)
const DIM_TEXT := Color(0.55, 0.58, 0.62)

# Top-to-bottom menu order: escalation. Blurb copy is placeholder — Kevin's to word.
const ORDER := [Difficulty.Tier.EASY, Difficulty.Tier.MEDIUM, Difficulty.Tier.HARD]
const BLURBS := {
	Difficulty.Tier.EASY: "soft hits, lazy triggers, patient bosses",
	Difficulty.Tier.MEDIUM: "they mean it, but they let you breathe",
	Difficulty.Tier.HARD: "the ride as intended",
}

var _done := false
var _index := 0

@onready var _entries: Array[Label] = [$Menu/Easy, $Menu/Medium, $Menu/Hard]
@onready var _blurb: Label = $Blurb

func _ready() -> void:
	_index = ORDER.find(Difficulty.tier)
	if _index < 0:
		_index = ORDER.size() - 1
	_highlight()

func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	# ESC steps back one layer: the DMV -> mode select.
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		UiSfx.back(self)
		_done = true
		SceneFlow.to_mode_select()
		return
	var up: bool = event.is_action_pressed(&"move_up") or event.is_action_pressed(&"select_prev")
	var down: bool = event.is_action_pressed(&"move_down") or event.is_action_pressed(&"select_next")
	var confirm: bool = event.is_action_pressed(&"select_confirm") \
		or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
	if up:
		_index = wrapi(_index - 1, 0, _entries.size())
		UiSfx.move(self)
		_highlight()
	elif down:
		_index = wrapi(_index + 1, 0, _entries.size())
		UiSfx.move(self)
		_highlight()
	elif confirm:
		UiSfx.select(self)
		_done = true
		Difficulty.tier = ORDER[_index]
		SceneFlow.to_select()

func _highlight() -> void:
	for i in _entries.size():
		var title: String = Difficulty.NAMES[ORDER[i]]
		_entries[i].modulate = AMBER if i == _index else DIM_TEXT
		_entries[i].text = ("[ %s ]" if i == _index else "%s") % title
	if _blurb:
		_blurb.text = BLURBS[ORDER[_index]]
