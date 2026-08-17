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
const ConfirmScript := preload("res://levels/tutorial/exit_confirm.gd")

const AMBER := Color(1.0, 0.85, 0.2)

const CLOSING_TITLE := "CLASS DISMISSED"
const CLOSING_BODY := "That's it — tanks are topped off, guns are cocked, and the keys are in your hand. Continue to experiment here, and head North to the exit when you're ready."
const FREE_PLAY_HINT := "head NORTH to the EXIT when you're ready"

static var HOLD_MOVE := 0.25      # seconds each of W/S/A/D must accumulate
static var HOLD_CONTROL := 0.3    # seconds each of brake/handbrake/boost
static var ADVANCE_DELAY := 1.0   # savor beat: seconds between nailing a
								  # lesson and the next card, so the player
								  # actually SEES the brake/leap/boom land
static var DING_HP := 40.0        # lesson-4 fender ding (skipped on a hurt car)
static var JUMP_HEIGHT := 40.0    # airborne px that count as a real launch
static var JUMP_LANE := Rect2(346, -400, 460, 1300)  # pad + flight path; a
								  # ledge hop off the deck must never count
static var SMASH_COUNT := 3       # yard kills demanded (clamped to what's left)
								  # — a taste, not a chore; the rest is extra credit

const TERRAIN_SET: Array[StringName] = [&"grass", &"dirt", &"mud", &"snow", &"ice", &"water"]

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
		"body": "Press S against your momentum for service brakes. Hold LCTRL to cut the rear tires loose — the handbrake is your drift pedal. At speed, crank the wheel while you pull it to whip the nose a full one-eighty. SHIFT burns nitro for a straight-line shove (and snuffs a burning hull, if you ever find yourself on fire). Brake, handbrake, and boost once each.",
		"hint": "LESSON 2/8 — brake (S vs travel), handbrake (LCTRL), boost (SHIFT)",
	},
	{
		"id": &"weapons",
		"title": "LESSON 3 — THIS IS HOW YOU SHOOT",
		"body": "LMB runs the machine gun — infinite ammo, but sustained fire overheats her and locks the trigger until she cools. RMB fires the weapon bay; the MOUSE WHEEL (or /) cycles the rack, and your special recharges on its own. Warm up the MG, cycle the bay, and send one special downrange — the wrecks out west are past caring.",
		"hint": "LESSON 3/8 — fire MG (LMB), cycle bay (wheel), fire secondary (RMB)",
	},
	{
		"id": &"pickups",
		"title": "LESSON 4 — SCAVENGE OR STARVE",
		"body": "We dinged your fender on the way in. Sorry not sorry. The south row's crates refill missiles and mines — the letters say which. For the bodywork, hold still on the repair bay and let it do its thing. Grab any ammo crate, then get your hull back to full.",
		"hint": "LESSON 4/8 — collect an ammo crate, then heal up at the repair bay (south row)",
	},
	{
		"id": &"jump",
		"title": "LESSON 5 — LEAVING THE GROUND",
		"body": "JUMP PADS are the striped pyramids. Hit one with speed and you're airborne — pits, mines, and everything slow pass beneath you. Line up the dashed run-up east of center and hit the pad.",
		"hint": "LESSON 5/8 — hit the jump pad off the dashed run-up (east)",
	},
	{
		"id": &"floors",
		"title": "LESSON 6 — THE WORLD HAS LAYERS",
		"body": "Some ground is higher than other ground. RAMPS are driveable slopes between floors — take the northeast ramp up onto the deck. Driving off a ledge drops you one floor for free; two or more bills you a quarter of your hull, so look before you leap. Ramp up, then drive off the deck's open west edge.",
		"hint": "LESSON 6/8 — ramp onto the NE deck, then off its open west edge",
	},
	{
		"id": &"terrain",
		"title": "LESSON 7 — READ THE ROAD",
		"body": "The ground fights back. Grass drags, dirt slides, mud swallows, snow smothers, ice keeps your nose swinging long after the wheels quit gripping, and shallow water is somebody's idea of a joke. The northwest grid samples all of it — cross every patch and feel your car change.",
		"hint": "LESSON 7/8 — cross all six NW terrain patches",
	},
	{
		"id": &"smash",
		"title": "LESSON 8 — EVERYTHING BREAKS",
		"body": "Scenery is a suggestion. Crates pop, fences splinter, hydrants gush — and fuel barrels go up hard enough to chain. Put three things in the southeast smash yard in the dirt (a barrel among them) and you pass; guns or bumper, dealer's choice. Extra credit is between you and the yard.",
		"hint": "LESSON 8/8 — smash 3 things in the SE yard (incl. a barrel)",
	},
]

var player = null        # the Vehicle — duck-typed, injected by drivers_ed
var gate: Node = null    # ExitGate StaticBody2D (card 8 opens it)
var exit_zone: Node = null

var lesson_index := -1
var completed := false
var _advance_wait := 0.0  # >0 = lesson nailed, holding the moment

var _card = null         # tutorial_card CanvasLayer
var _confirm = null      # exit_confirm CanvasLayer while the dialog is up
var _latch := {}         # per-lesson accumulators/flags; cleared on advance
var _hint_label: Label = null
var _ammo_seen := {}     # rack ammo per slot, last observed — drop = a shot
						 # left the bay, rise = a crate landed
# The smash lesson's baseline is the UNTOUCHED yard, captured once at boot so
# anything the player flattens during earlier free play still counts toward the
# quota. It lives outside _latch (which clears every advance). -1 = uncaptured.
var _smash_base := -1
var _smash_barrel_base := -1

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
	# The rack has no "fired" signal — selection_changed covers the cycle
	# latch, and an ammo delta against the last-seen count tells shot from
	# crate. Player is injected before add_child, so the hookup lands here.
	if player:
		var rack: Node = player.get_node_or_null("WeaponRack")
		if rack:
			for i in 7:
				_ammo_seen[i] = rack.ammo(i)
			rack.selection_changed.connect(_on_rack_selection)
			rack.ammo_changed.connect(_on_rack_ammo)
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_zone_entered)
	# Baseline the smash yard now, before the player can touch anything, so
	# free-play vandalism counts once the smash lesson finally goes live.
	_snapshot_smash()

func _on_rack_selection(_index: int) -> void:
	_latch[&"cycled"] = 1.0

func _on_rack_ammo(index: int, ammo: int) -> void:
	var seen: int = int(_ammo_seen.get(index, ammo))
	if ammo < seen:
		_latch[&"fired_secondary"] = 1.0
	elif ammo > seen:
		_latch[&"crate"] = 1.0
	_ammo_seen[index] = ammo

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
	if _advance_wait > 0.0:
		_advance_wait -= delta
		if _advance_wait <= 0.0:
			_advance()
		return
	if _lesson_done(LESSONS[lesson_index]["id"], delta):
		# Don't snap to the next card — let the skid finish, the car land,
		# the barrels burn. The hint flips to a check so the pass registers.
		_advance_wait = ADVANCE_DELAY
		_hint_label.text = "✓ " + String(LESSONS[lesson_index]["hint"])
		_hint_label.modulate = Color(0.85, 1.0, 0.85)

func _advance() -> void:
	lesson_index += 1
	_latch.clear()
	_advance_wait = 0.0
	_hint_label.modulate = AMBER  # undo the savor-beat flourish
	if lesson_index >= LESSONS.size():
		_finish()
		return
	_hint_label.text = ""
	_card.show_card(LESSONS[lesson_index]["title"], LESSONS[lesson_index]["body"])

func _on_card_dismissed() -> void:
	# The dismiss key is also fire — re-arm the player's release gate so the
	# press that closed the card can't bleed a round into the yard on unpause.
	var drv: Node = player.get_driver() if player else null
	if drv and drv.has_method(&"arm_fire_gate"):
		drv.arm_fire_gate()
	# The closing card: gate opens only once it's read — the tunnel stays
	# visibly barred through the whole syllabus.
	if completed and lesson_index >= LESSONS.size():
		_hint_label.text = FREE_PLAY_HINT
		_open_gate()
		return
	if lesson_index < 0 or lesson_index >= LESSONS.size():
		return
	_hint_label.text = LESSONS[lesson_index]["hint"]
	# "We dinged your fender on the way in" — the heal half of lesson 4 needs
	# a damaged hull and nobody here shoots. A car already hurting (barrels,
	# fall bills) keeps its dents instead of stacking the ding.
	if LESSONS[lesson_index]["id"] == &"pickups" and player != null:
		var health: Node = player.get_node_or_null("Health")
		if health and player.get_hp() > DING_HP + 15.0:
			health.take_damage(DING_HP)

## Graduation: the closing card takes the stage; its dismissal drops the gate.
func _finish() -> void:
	completed = true
	_card.show_card(CLOSING_TITLE, CLOSING_BODY)

## The exit tunnel. Zone entry is physically gated on the (now open) gate;
## the completed check is a belt for weird geometry. Backing out and driving
## in again re-prompts — the zone refires on re-entry.
func _on_exit_zone_entered(body: Node) -> void:
	if not completed or _confirm != null:
		return
	if not body.is_in_group(&"player"):
		return
	_confirm = ConfirmScript.new()
	_confirm.name = "ExitConfirm"
	_confirm.confirmed.connect(_leave_yard)
	_confirm.cancelled.connect(_close_confirm)
	add_child(_confirm)  # its _ready freezes the tree

func _leave_yard() -> void:
	# Pause survives scene swaps — every path OUT of the yard unpauses first.
	get_tree().paused = false
	var flow := get_node_or_null(^"/root/SceneFlow")
	if flow:
		flow.to_title()

func _close_confirm() -> void:
	get_tree().paused = false
	if _confirm:
		_confirm.queue_free()
		_confirm = null

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
		&"weapons":
			if player == null:
				return false
			var mount: Node = player.get_node_or_null("MachineGunMount")
			if mount and float(mount.heat) > 0.0:
				_latch[&"mg"] = 1.0  # heat is the proof a burst actually left
			return _latch.has(&"mg") and _latch.has(&"cycled") \
				and _latch.has(&"fired_secondary")
		&"pickups":
			if player == null:
				return false
			return _latch.has(&"crate") \
				and player.get_hp() >= player.get_max_hp() - 0.01
		&"floors":
			if player == null:
				return false
			if player.floor_index == 2:
				_latch[&"deck_up"] = 1.0
			elif _latch.has(&"deck_up") and player.floor_index == 1:
				_latch[&"deck_down"] = 1.0  # only a descent AFTER the climb
			return _latch.has(&"deck_up") and _latch.has(&"deck_down")
		&"jump":
			if player == null:
				return false
			if float(player.height) > JUMP_HEIGHT \
					and JUMP_LANE.has_point(player.global_position):
				_latch[&"jumped"] = 1.0
			return _latch.has(&"jumped")
		&"terrain":
			if player == null:
				return false
			var surface: StringName = player.current_terrain
			if surface in TERRAIN_SET:
				_latch[surface] = 1.0
			for s in TERRAIN_SET:
				if not _latch.has(s):
					return false
			return true
		&"smash":
			if _smash_base < 0:
				_snapshot_smash()  # boot somehow missed it (safety net)
			var live: Array[int] = _smash_counts()
			# Delta from the boot baseline — so kills BEFORE the lesson count too.
			var destroyed: int = _smash_base - live[0]
			var barrels_gone: int = _smash_barrel_base - live[1]
			# A pre-flattened yard owes nothing; otherwise the quota clamps to
			# what was standing at boot and at least one barrel has to go up.
			return destroyed >= mini(SMASH_COUNT, _smash_base) \
				and (barrels_gone > 0 or _smash_barrel_base == 0)
	return false

func _snapshot_smash() -> void:
	var counts: Array[int] = _smash_counts()
	_smash_base = counts[0]
	_smash_barrel_base = counts[1]

func _smash_counts() -> Array[int]:
	var members := 0
	var barrels := 0
	for node in get_tree().get_nodes_in_group(&"tutorial_smash"):
		if not is_instance_valid(node):
			continue
		members += 1
		if node.get("deco") == &"barrel":
			barrels += 1
	return [members, barrels]

func _hold(key: StringName, on: bool, delta: float) -> void:
	if on:
		_latch[key] = float(_latch.get(key, 0.0)) + delta

func _held(key: StringName, need: float) -> bool:
	return float(_latch.get(key, 0.0)) >= need
