extends Control
## The fight card: SINGLE BATTLE's battleground picker, between difficulty
## select and car select. Lists the campaign tour in slot order, filtered to
## the fights — melee/duel arenas and the Route 666 chase are always available;
## miniboss and boss fights join only while Developer Mode is enabled. A chase
## run off the tour has no purse and nothing to rob: caught or wrecked, it
## skips the wheel and ends on the classic panel (buzzard_run.gd). Confirm
## stamps GameState.battle_level_index and rolls to car select; BACK and ESC
## return to difficulty select.
## Manual-highlight menu idiom cloned from title.gd — no focus system.

const AMBER := Color(1.0, 0.85, 0.2)
const DIM_TEXT := Color(0.55, 0.58, 0.62)

const BACK_BLURB := "back to the license window"

var _done := false
var _index := 0
var _rows: Array[Dictionary] = []  # listed_slots() rows + the BACK row
var _entries: Array[Label] = []

@onready var _menu: VBoxContainer = $Menu
@onready var _blurb: Label = $Blurb

func _ready() -> void:
	_build_rows()
	_highlight()

## Campaign slots that belong on the fight card, in tour order. Developer Mode
## adds boss encounters for playtesting; every omitted slot stays fully hidden.
## Static + campaign-injected so tests can probe the filter without a tree.
static func listed_slots(campaign: Array, include_bosses: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in campaign.size():
		var profile: Dictionary = campaign[i]
		var mode := StringName(profile.mode)
		var encounter := StringName(profile.encounter)
		var listed: bool = (mode == &"arena" and encounter in [&"melee", &"duel"]) \
			or (mode == &"specialty" and encounter == &"chase")
		listed = listed or (include_bosses and mode == &"arena" \
			and encounter in [&"miniboss", &"boss"])
		if listed:
			out.append({"campaign_index": i, "name": String(profile.name),
				"profile": profile})
	return out

func _build_rows() -> void:
	_rows = listed_slots(SceneFlow.CAMPAIGN, GameState.dev_mode)
	_rows.append({"campaign_index": -1, "name": "BACK"})
	for row in _rows:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_menu.add_child(lbl)
		_entries.append(lbl)
	_index = 0

func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	# ESC steps back one layer: the fight card -> the DMV.
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		UiSfx.back(self)
		_done = true
		SceneFlow.to_difficulty()
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
		_activate()

func _step(dir: int) -> void:
	_index = wrapi(_index + dir, 0, _rows.size())
	_highlight()

func _activate() -> void:
	var row: Dictionary = _rows[_index]
	if int(row.campaign_index) < 0:  # BACK
		UiSfx.back(self)
		_done = true
		SceneFlow.to_difficulty()
		return
	UiSfx.select(self)
	_done = true
	_commit_pick(row)
	SceneFlow.to_select()

## Split from the confirm so tests can assert the stamp without a scene swap.
func _commit_pick(row: Dictionary) -> void:
	GameState.battle_level_index = int(row.campaign_index)

func _highlight() -> void:
	for i in _rows.size():
		var title := String(_rows[i].name).to_upper()
		_entries[i].modulate = AMBER if i == _index else DIM_TEXT
		_entries[i].text = ("[ %s ]" if i == _index else "%s") % title
	if _blurb:
		_blurb.text = _blurb_for(_rows[_index])

## Row blurb off the live profile: size class + opposition count.
func _blurb_for(row: Dictionary) -> String:
	if int(row.campaign_index) < 0:
		return BACK_BLURB
	var profile: Dictionary = row.profile
	if StringName(profile.encounter) == &"chase":
		return "forced-scroll chase — outrun the horde for two minutes"
	if StringName(profile.encounter) == &"duel":
		return "%s arena — 1v1 duel" % String(profile.size_class)
	if StringName(profile.encounter) == &"miniboss":
		return "%s arena — miniboss fight" % String(profile.size_class)
	if StringName(profile.encounter) == &"boss":
		return "%s arena — boss fight" % String(profile.size_class)
	return "%s arena — %d rivals" % [String(profile.size_class),
		int(profile.target_cars) - 1]
