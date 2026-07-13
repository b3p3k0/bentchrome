extends Node
## Driver's Ed lesson flow: a fixed syllabus, each lesson a paused text card
## (tutorial_card) followed by a live objective hint, advanced by POLLING the
## player's actual vehicle/controller state — you graduate by doing, not by
## reading. Test drives (game_mode &"test_drive") run the same director
## pre-completed: no cards, no hints, gate open — the director always exists
## because it owns the exit-tunnel confirm. The director itself stays
## pausable, so a lesson can never complete while a card, the pause menu, or
## the end screen holds the world.
##
## Lesson copy in LESSONS is content (const); every timing/threshold knob is
## a static var. Check logic is one match on the lesson id — greppable and
## drivable from tests via Input.action_press and real physics frames.

const IR := preload("res://game/input_router.gd")
const CardScript := preload("res://levels/tutorial/tutorial_card.gd")

const AMBER := Color(1.0, 0.85, 0.2)

static var HOLD_MOVE := 0.25      # seconds each of W/S/A/D must accumulate
static var HOLD_CONTROL := 0.3    # seconds each of brake/handbrake/boost

const LESSONS := [
	{
		"id": &"movement",
		"title": "LESSON 1 — THIS IS HOW YOU DRIVE",
		"body": "W accelerates, S brakes and reverses, A and D steer. The yard is yours — nobody shoots back in here. Roll all four directions and feel your ride's weight.",
		"hint": "LESSON 1/8 — drive: hold W, S, A and D",
	},
	{
		"id": &"control",
		"title": "LESSON 2 — STOPPING IS A SKILL TOO",
		"body": "Press S against your momentum for service brakes. Hold LCTRL to cut the rear tires loose — the handbrake is your drift pedal. SHIFT burns nitro for a straight-line shove (and snuffs a burning hull, if you ever find yourself on fire). Brake, handbrake, and boost once each.",
		"hint": "LESSON 2/8 — brake (S vs travel), handbrake (LCTRL), boost (SHIFT)",
	},
	{
		"id": &"weapons",
		"title": "LESSON 3 — THIS IS HOW YOU SHOOT",
		"body": "LMB runs the machine gun — infinite ammo, but sustained fire overheats her and locks the trigger until she cools. RMB fires the weapon bay; the MOUSE WHEEL (or /) cycles the rack, and your special recharges on its own. Warm up the MG, cycle the bay, and send one special downrange — the dummies out west are paid to take it.",
		"hint": "LESSON 3/8 — fire MG (LMB), cycle bay (wheel), fire secondary (RMB)",
	},
	{
		"id": &"pickups",
		"title": "LESSON 4 — SCAVENGE OR STARVE",
		"body": "We dinged your fender on the way in. Sorry not sorry. The south row's crates refill missiles and mines — the letters say which. Drive over the cross for a quick patch, or hold still on the repair bay and let it work. Grab any ammo crate, then get your hull back to full.",
		"hint": "LESSON 4/8 — collect an ammo crate, then heal to full (south row)",
	},
	{
		"id": &"floors",
		"title": "LESSON 5 — THE WORLD HAS LAYERS",
		"body": "Some ground is higher than other ground. RAMPS are driveable slopes between floors — take the northeast ramp up onto the deck. Driving off a ledge drops you one floor for free; two or more bills you a quarter of your hull, so look before you leap. Ramp up, then drive off the deck's open west edge.",
		"hint": "LESSON 5/8 — ramp onto the NE deck, then off its open west edge",
	},
	{
		"id": &"jump",
		"title": "LESSON 6 — LEAVING THE GROUND",
		"body": "JUMP PADS are the striped pyramids. Hit one with speed and you're airborne — pits, mines, and everything slow pass beneath you. Line up the dashed run-up east of center and hit the pad.",
		"hint": "LESSON 6/8 — hit the jump pad off the dashed run-up (east)",
	},
	{
		"id": &"terrain",
		"title": "LESSON 7 — READ THE ROAD",
		"body": "The ground fights back. Grass drags, dirt slides, mud swallows, snow smothers, ice keeps your nose swinging long after the wheels quit gripping, and shallow water is somebody's idea of a joke. The northwest lanes sample all of it — drive every one and feel your car change.",
		"hint": "LESSON 7/8 — drive all six NW terrain lanes",
	},
	{
		"id": &"smash",
		"title": "LESSON 8 — EVERYTHING BREAKS",
		"body": "Scenery is a suggestion. Crates pop, fences splinter, hydrants gush — and fuel barrels go up hard enough to chain. Clear out the southeast smash yard; guns or bumper, dealer's choice. Mind the barrels. Or don't.",
		"hint": "LESSON 8/8 — wreck the SE smash yard",
	},
]

var player = null        # the Vehicle — duck-typed, injected by drivers_ed
var gate: Node = null    # ExitGate StaticBody2D (card 8 opens it)
var exit_zone: Node = null

var lesson_index := -1
var completed := false

var _card = null         # tutorial_card CanvasLayer
var _latch := {}         # per-lesson accumulators; cleared on advance
var _hint_label: Label = null

func _ready() -> void:
	_card = CardScript.new()
	_card.name = "LessonCard"
	_card.dismissed.connect(_on_card_dismissed)
	add_child(_card)
	var hint_layer := CanvasLayer.new()
	hint_layer.name = "HintLayer"
	hint_layer.layer = 55
	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_label.offset_top = 76.0
	_hint_label.offset_bottom = 110.0
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.modulate = AMBER
	hint_layer.add_child(_hint_label)
	add_child(hint_layer)

## Entry point, called by drivers_ed after injection. lessons=false is the
## test-drive boot: same yard, syllabus already stamped complete.
func begin(lessons: bool) -> void:
	if lessons:
		_advance()
	else:
		lesson_index = LESSONS.size()
		completed = true
		_hint_label.visible = false
		_open_gate()

func _physics_process(delta: float) -> void:
	if completed or lesson_index < 0 or lesson_index >= LESSONS.size():
		return
	if _card and _card.visible:
		return  # reading — the tree is paused anyway; belt and suspenders
	if _lesson_done(LESSONS[lesson_index]["id"], delta):
		_advance()

func _advance() -> void:
	lesson_index += 1
	_latch.clear()
	if lesson_index >= LESSONS.size():
		_finish()
		return
	_hint_label.text = ""
	_card.show_card(LESSONS[lesson_index]["title"], LESSONS[lesson_index]["body"])

func _on_card_dismissed() -> void:
	if lesson_index < 0 or lesson_index >= LESSONS.size():
		return
	_hint_label.text = LESSONS[lesson_index]["hint"]

## Graduation: card 8 adds the closing dialog + exit confirm; the gate opens
## here so free play and test drives share one path.
func _finish() -> void:
	completed = true
	_hint_label.text = "head NORTH to the EXIT when you're ready"
	_open_gate()

func _open_gate() -> void:
	if gate == null:
		return
	gate.visible = false
	var col: CollisionShape2D = gate.get_node_or_null("Col")
	if col:
		col.set_deferred("disabled", true)

## One match, one lesson, polled every physics tick while the world runs.
func _lesson_done(id: StringName, delta: float) -> bool:
	match id:
		&"movement":
			_hold(&"up", Input.is_action_pressed(IR.ACTION_MOVE_UP), delta)
			_hold(&"down", Input.is_action_pressed(IR.ACTION_MOVE_DOWN), delta)
			_hold(&"left", Input.is_action_pressed(IR.ACTION_MOVE_LEFT), delta)
			_hold(&"right", Input.is_action_pressed(IR.ACTION_MOVE_RIGHT), delta)
			return _held(&"up", HOLD_MOVE) and _held(&"down", HOLD_MOVE) \
				and _held(&"left", HOLD_MOVE) and _held(&"right", HOLD_MOVE)
		&"control":
			if player == null:
				return false
			var ctl: Object = player.get_controller()
			if ctl == null:
				return false
			_hold(&"brake", ctl.service_braking, delta)
			_hold(&"handbrake", ctl.handbraking, delta)
			_hold(&"boost", ctl.boosting, delta)
			return _held(&"brake", HOLD_CONTROL) and _held(&"handbrake", HOLD_CONTROL) \
				and _held(&"boost", HOLD_CONTROL)
	return false  # lessons 3-8 land in the next cards

func _hold(key: StringName, on: bool, delta: float) -> void:
	if on:
		_latch[key] = float(_latch.get(key, 0.0)) + delta

func _held(key: StringName, need: float) -> bool:
	return float(_latch.get(key, 0.0)) >= need
