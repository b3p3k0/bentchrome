extends Control
## The fight card: SINGLE BATTLE's battleground picker, between difficulty
## select and car select. Lists the campaign tour in slot order, filtered to
## the brawls — melee arenas are selectable, unbuilt placeholder slots hang
## greyed as coming attractions (they join the card automatically the day
## their CAMPAIGN entry becomes a real melee arena), and boss/chase slots
## stay campaign-exclusive. Confirm stamps GameState.battle_level_index and
## rolls to car select; BACK and ESC return to difficulty select.
## Manual-highlight menu idiom cloned from title.gd — no focus system.

const AMBER := Color(1.0, 0.85, 0.2)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const DISABLED_TEXT := Color(0.3, 0.32, 0.35)

const BACK_BLURB := "back to the license window"
const LOCKED_BLURB := "under construction — check back soon"

var _done := false
var _index := 0
var _rows: Array[Dictionary] = []  # listed_slots() rows + the BACK row
var _entries: Array[Label] = []

@onready var _menu: VBoxContainer = $Menu
@onready var _blurb: Label = $Blurb

func _ready() -> void:
	_build_rows()
	_highlight()

## Campaign slots that belong on the fight card, in tour order. Selectable =
## a real melee or duel arena; placeholders list greyed; boss/chase slots
## don't list. Static + campaign-injected so tests can probe the filter
## without a tree.
static func listed_slots(campaign: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in campaign.size():
		var profile: Dictionary = campaign[i]
		var mode := StringName(profile.mode)
		var enabled: bool = mode == &"arena" \
			and StringName(profile.encounter) in [&"melee", &"duel"]
		if enabled or mode == &"placeholder":
			out.append({"campaign_index": i, "name": String(profile.name),
				"enabled": enabled, "profile": profile})
	return out

func _build_rows() -> void:
	_rows = listed_slots(SceneFlow.CAMPAIGN)
	_rows.append({"campaign_index": -1, "name": "BACK", "enabled": true})
	for row in _rows:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_menu.add_child(lbl)
		_entries.append(lbl)
	_index = 0
	if not bool(_rows[0].enabled):  # never boot the cursor onto a greyed slot
		_step(1)

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

## Cursor motion that hops greyed-out rows (locked slots can never land).
func _step(dir: int) -> void:
	_index = wrapi(_index + dir, 0, _rows.size())
	while not bool(_rows[_index].enabled):
		_index = wrapi(_index + dir, 0, _rows.size())
	_highlight()

func _activate() -> void:
	var row: Dictionary = _rows[_index]
	if not bool(row.enabled):
		return  # unreachable via nav; forced cursors stay inert
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
		if not bool(_rows[i].enabled):
			_entries[i].modulate = DISABLED_TEXT
			_entries[i].text = title
		else:
			_entries[i].modulate = AMBER if i == _index else DIM_TEXT
			_entries[i].text = ("[ %s ]" if i == _index else "%s") % title
	if _blurb:
		_blurb.text = _blurb_for(_rows[_index])

## Row blurb off the live profile: size class + opposition count.
func _blurb_for(row: Dictionary) -> String:
	if int(row.campaign_index) < 0:
		return BACK_BLURB
	if not bool(row.enabled):
		return LOCKED_BLURB
	var profile: Dictionary = row.profile
	if StringName(profile.encounter) == &"duel":
		return "%s arena — 1v1 duel" % String(profile.size_class)
	return "%s arena — %d rivals" % [String(profile.size_class),
		int(profile.target_cars) - 1]
