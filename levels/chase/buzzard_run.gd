extends "res://levels/combat_level.gd"
## The Route 666 host: a 120-second survival clock over a seeded course, with
## a pack that rides in frame the whole way. Wires the course + streamer +
## horde wall + wave director + pace keeper around the player, suppresses the
## end screen's arena-style group win (runtime hordes would fake a cleared
## arena), and drives the timed win itself.
##
## NOBODY LOSES A LIFE HERE, and nobody respawns. combat_level's lives loop
## never runs (no super() in _process): the run ends the moment the pack
## catches the car OR the car is wrecked — same outcome either way. The pack
## swallows the car for a beat, then the ROBBERY takes something
## (game/robbery.gd) and the road goes on to the next stop. No retry: Route
## 666 is a one-shot gamble, which is what makes STAY ON ROUTE a real choice.
## Off the tour (no next stop to roll on to) the classic loss panel stands in.

const CourseScript := preload("res://levels/chase/chase_course.gd")
const StreamerScript := preload("res://levels/chase/course_streamer.gd")
const WallScript := preload("res://levels/chase/horde_wall.gd")
const DirectorScript := preload("res://levels/chase/chase_director.gd")
const KeeperScript := preload("res://levels/chase/pace_keeper.gd")
const SpeedBand := preload("res://levels/chase/speed_band.gd")
const Robbery := preload("res://game/robbery.gd")
const RobberyScreen := preload("res://ui/robbery_screen.gd")

static var RUN_SECONDS := 120.0
static var ROLL_SPEED := 300.0   # rolling-start fallback when the car has no controller
static var JACK_BEAT := 1.2      # seconds the pack swallows the car before the robbery card

signal jacked(cause: StringName)     # &"caught" | &"wrecked"
signal rolled_on(next_index: int)    # the robbery is done; the campaign advanced

var course = null
var clock := 0.0
var kills := 0   # director bumps this; the chase HUD reads it
## Suites that boot this scene to test something else stand the pack down so
## a slow fixture can't be jacked mid-test. Wrecks still end the run.
var catch_enabled := true
## Tests stop short of the scene change (nothing headless may reach
## SceneFlow.goto_scene); the campaign index still advances.
var auto_advance := true
var jack_cause: StringName = &""

var _wall = null
var _streamer = null
var _director = null
var _keeper = null
var _end_screen = null
var _robbery = null
var _won := false
var _jacked := false

func _ready() -> void:
	super()
	add_to_group(&"chase_host")
	if _player:
		_player.weapon_lock_exempt = true  # Route 666 self-limits fire in its drivers
		# The green flag drops on a ROLLING start (the level-start respawn in
		# super() zeroed velocity): the pack rides a short leash now, and a
		# standing launch would hand it the first hundred pixels for free.
		_player.velocity = Vector2(0.0, -_roll_speed())
	var seed_val := randi() & 0x7FFFFFFF
	course = CourseScript.new()
	course.pre_roll(seed_val)
	print("[chase] course seed %d, %d chunks" % [seed_val, course.plan.size()])
	_streamer = StreamerScript.new()
	_streamer.name = "CourseStreamer"
	_streamer.course = course
	_streamer.target = _player
	add_child(_streamer)
	_wall = WallScript.new()
	_wall.name = "HordeWall"
	_wall.target = _player
	_wall.course = course
	_wall.front_y = _player.global_position.y + WallScript.START_GAP
	add_child(_wall)
	_director = DirectorScript.new()
	_director.name = "ChaseDirector"
	_director.host = self
	_director.target = _player
	_director.wall = _wall
	add_child(_director)
	_keeper = KeeperScript.new()
	_keeper.name = "PaceKeeper"
	_keeper.target = _player
	_keeper.course = course
	add_child(_keeper)
	for child in get_children():
		if child is CanvasLayer and "suppress_group_win" in child:
			_end_screen = child
			child.suppress_group_win = true
			child.suppress_loss = true  # a wreck here is a robbery, and the host's call

## The host is the sole arbiter of how a run ends. A catch or a wreck beats
## the clock on a same-frame tie — the wasteland is unfair.
func _process(delta: float) -> void:
	if _won or _jacked or _player == null or not is_instance_valid(_player):
		return
	clock += delta
	var cause := loss_cause()
	if cause != &"":
		_get_jacked(cause)
	elif clock >= RUN_SECONDS and _end_screen != null:
		_won = true
		if _director:
			_director.stand_down()
		_end_screen._show(true)

## &"wrecked" (0 HP), &"caught" (the pack has the car), or &"" (still running).
func loss_cause() -> StringName:
	if _player.get_hp() <= 0.0:
		return &"wrecked"
	if catch_enabled and _wall != null and _wall.caught():
		return &"caught"
	return &""

func is_jacked() -> bool:
	return _jacked

## Duck-typed HUD/director surface (group &"chase_host").
func time_left() -> float:
	return maxf(RUN_SECONDS - clock, 0.0)

func wall_gap() -> float:
	return _wall.gap() if _wall else WallScript.MAX_GAP

## World y of the dust crest — Buzzard drivers keep their marks north of it.
func wall_front_y() -> float:
	return _wall.front_y if _wall else INF

## 0 = the pack at its farthest, 1 = contact (the HUD meter, the GPS band).
func pressure() -> float:
	return _wall.pressure() if _wall else 0.0

## Pack on the bumper.
func in_danger() -> bool:
	return _wall != null and _wall.in_danger()

## The pack's live pace as a fraction of the player's top (dev readout).
func pack_pace() -> float:
	return _wall.pace_frac if _wall else 0.0

## The run is lost. The pack comes off the trigger and rolls over the car
## (no mercy, no pace floor, and a caught driver's hands leave the wheel);
## a beat later the robbery card takes it from there.
func _get_jacked(cause: StringName) -> void:
	_jacked = true
	jack_cause = cause
	print("[chase] jacked (%s) at %.1fs" % [cause, clock])
	if _director:
		_director.stand_down()
	if _keeper:
		_keeper.enabled = false
	if _wall:
		_wall.no_mercy = true
	if cause == &"caught" and _player.has_method(&"set_driver"):
		_player.set_driver(Driver.new())  # base Driver = no pedals, no triggers
	jacked.emit(cause)
	get_tree().create_timer(JACK_BEAT).timeout.connect(_open_robbery, CONNECT_ONE_SHOT)

func _open_robbery() -> void:
	if not is_inside_tree() or _robbery != null:
		return
	var gs := get_node_or_null(^"/root/GameState")
	var next: int = _end_screen._campaign_next_index() if _end_screen != null else -1
	if gs == null or next < 0:
		# Off the tour: nothing to take and nowhere to roll on to.
		if _end_screen != null:
			_end_screen._show(false)
		return
	# The bay you had rides into the next stop, exactly as a win would carry
	# it — unless the robbery says otherwise.
	_end_screen._capture_ammo_carry(gs)
	var outcome: Dictionary = Robbery.apply(Robbery.placeholder_slice(), gs)
	_robbery = RobberyScreen.new()
	_robbery.name = "RobberyScreen"
	add_child(_robbery)
	_robbery.finished.connect(_roll_on.bind(next), CONNECT_ONE_SHOT)
	_robbery.open(jack_cause, outcome)

## Robbed, not beaten: the campaign advances past Route 666 either way.
func _roll_on(next: int) -> void:
	get_tree().paused = false  # paused survives scene changes — always release
	var gs := get_node_or_null(^"/root/GameState")
	var flow := get_node_or_null(^"/root/SceneFlow")
	if gs:
		gs.level_index = next
	rolled_on.emit(next)
	if auto_advance and flow:
		flow.to_interstitial()

## Rolling starts land at the player's own cruise — the speed the pedal would
## settle at hands-off, so the first input is a choice, not a rescue.
func _roll_speed() -> float:
	if _player != null and _player.has_method(&"get_controller"):
		var ctrl = _player.get_controller()
		if ctrl != null:
			return ctrl.max_speed * SpeedBand.CRUISE_FRAC
	return ROLL_SPEED
