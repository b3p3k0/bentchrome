extends "res://levels/combat_level.gd"
## The Route 666 host: a 120-second survival clock over a seeded course, with
## a pack that rides in frame the whole way. Wires the course + streamer +
## horde wall + wave director + pace keeper around the player, suppresses the
## end screen's arena-style group win (runtime hordes would fake a cleared
## arena), and drives the timed win itself.
##
## NOBODY RESPAWNS HERE. combat_level's lives loop never runs (no super() in
## _process): the run ends the moment the pack catches the car OR the car is
## wrecked — same outcome either way. The pack swallows the car for a beat,
## then the ROBBERY spins its wheel — bolts, parts, or blood
## (game/robbery.gd; one slice in ten costs a life, never the last one) — and
## the road goes on to the next stop. No retry: Route 666 is a one-shot
## gamble, which is what makes STAY ON ROUTE a real choice. Off the tour (no
## next stop to roll on to) the classic loss panel stands in.

const CourseScript := preload("res://levels/chase/chase_course.gd")
const StreamerScript := preload("res://levels/chase/course_streamer.gd")
const WallScript := preload("res://levels/chase/horde_wall.gd")
const DirectorScript := preload("res://levels/chase/chase_director.gd")
const KeeperScript := preload("res://levels/chase/pace_keeper.gd")
const SpeedBand := preload("res://levels/chase/speed_band.gd")
const Robbery := preload("res://game/robbery.gd")
const RobberyScreen := preload("res://ui/robbery_screen.gd")
const GarageItems := preload("res://ui/garage/garage_catalog.gd")
const FinaleScript := preload("res://levels/chase/finale_director.gd")
const ChunkDefs := preload("res://levels/chase/chunk_defs.gd")

static var RUN_SECONDS := 120.0
static var ROLL_SPEED := 300.0   # rolling-start fallback when the car has no controller
static var JACK_BEAT := 1.2      # seconds the pack swallows the car before the robbery card
## The other side of the gamble: what making it out pays. The purse is flat;
## the DAREDEVIL bonus accrues for every second spent with the pack on the
## bumper (the danger zone) and is only paid if you survive to collect it.
static var PURSE := 3000
static var DAREDEVIL_RATE := 100.0   # bolts per second in the danger zone
static var DAREDEVIL_CAP := 2000
## Ordnance in the dust: a mine or a missile of YOURS that ends up this far
## inside the crest goes off under the pack and makes it flinch
## (horde_wall.flinch). The poll is the fuse — a mine dropped early pops
## when the crest rolls over it.
static var FLINCH_INSET := 40.0
static var MISSILE_CUT := 0.18       # a missile's flinch is lighter than a mine's

signal jacked(cause: StringName)     # &"caught" | &"wrecked"
signal rolled_on(next_index: int)    # the robbery is done; the campaign advanced

var course = null
var clock := 0.0
var kills := 0   # director bumps this; the chase HUD reads it
var flinches := 0   # bangs in the dust that backed the pack off (the probe reads it)
var daredevil := 0.0   # bolts accrued living dangerously; paid at the line
## Suites that boot this scene to test something else stand the pack down so
## a slow fixture can't be jacked mid-test. Wrecks still end the run.
var catch_enabled := true
## Tests stop short of the scene change (nothing headless may reach
## SceneFlow.goto_scene); the campaign index still advances.
var auto_advance := true
## The clock-out plays the bridge-is-out show before the card (finale_director);
## suites about "the line pays" turn it off and get the old instant win.
var finale_enabled := true
var jack_cause: StringName = &""
## The wheel's dice. Tests seed it; play randomizes it at boot.
var robbery_rng := RandomNumberGenerator.new()

var _wall = null
var _streamer = null
var _director = null
var _keeper = null
var _end_screen = null
var _robbery = null
var _finale = null
var _won := false
var _jacked := false

func _ready() -> void:
	super()
	add_to_group(&"chase_host")
	robbery_rng.randomize()
	var seed_val := randi() & 0x7FFFFFFF
	course = CourseScript.new()
	course.pre_roll(seed_val)
	print("[chase] course seed %d, %d chunks" % [seed_val, course.plan.size()])
	if _player == null or not is_instance_valid(_player):
		# No car to chase (mp_managed strips the baked cars — the level-shot
		# probe boots scenes that way): the plan is rolled, the run stands down.
		set_process(false)
		return
	# The PLAYER keeps the ordinary 2s non-MG bay lock (Vehicle.WEAPON_LOCK):
	# only the Buzzardz opt out (chase_director spawn), because their pacing
	# lives in chase_driver. Exempting the player here turned a tap of RMB
	# into a full-auto missile hose — funny, and very much not the game.
	# The green flag drops on a ROLLING start (the level-start respawn in
	# super() zeroed velocity): the pack rides a short leash now, and a
	# standing launch would hand it the first hundred pixels for free.
	_player.velocity = Vector2(0.0, -_roll_speed())
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
		if finale_enabled:
			if _finale == null:
				_start_finale()
		else:
			_finish_run()
	elif in_danger():
		daredevil = minf(daredevil + DAREDEVIL_RATE * delta, float(DAREDEVIL_CAP))

## The line is crossed: the bridge-is-out show (finale_director) — nothing
## can catch or hurt the car from here, the pack is told where the bank is,
## and the card comes after the last splash.
func _start_finale() -> void:
	catch_enabled = false
	if _keeper:
		_keeper.enabled = false   # the finale driver owns the velocity
	var health = _player.get_node_or_null(^"Health")
	if health != null:
		health.god = true
	if _player.has_method(&"get_controller") and _player.get_controller() != null:
		_player.get_controller().boost_fuel = 100.0   # the flame stays lit to the brink
	_finale = FinaleScript.new()
	_finale.name = "Finale"
	_finale.host = self
	_finale.player = _player
	_finale.course = course
	_finale.wall = _wall
	_finale.director = _director
	_finale.streamer = _streamer
	_finale.finished.connect(_finish_run, CONNECT_ONE_SHOT)
	add_child(_finale)
	_finale.start()

## The win proper: the purse, and the card.
func _finish_run() -> void:
	if _won or _jacked:
		return
	_won = true
	if _director:
		_director.stand_down()
	_pay_out()
	if _end_screen != null:
		_end_screen._show(true)

func finale_running() -> bool:
	return _finale != null and _finale.running

## Off the road on a cutoff's trail: the chunk under the car has one, the
## car is inside the trail's reach along the road and out past the shoulder
## on the trail's side — through the mouth, that is. The pack loses sight
## of you there (horde_wall.lost_sight).
func on_trail() -> bool:
	if course == null or _player == null or not is_instance_valid(_player):
		return false
	var d: float = -_player.global_position.y
	var entry: Dictionary = course.plan[course.chunk_index_at(d)]
	var def: Dictionary = entry["def"]
	if not def.has("cutoff"):
		return false
	var cf: Dictionary = def["cutoff"]
	var local: float = d - float(entry["start_d"])
	var pts: Array = cf["trail"]
	if local < float(pts[0][0]) or local > float(pts[pts.size() - 1][0]):
		return false
	var s: Dictionary = course.sample(d)
	var side: float = cf["side"]
	return side * (_player.global_position.x - float(s["x"])) > float(s["half_w"]) + 90.0

## The dust has no body, so nothing you throw at it can hit it — the host
## watches instead: every physics tick, any live mine you dropped or missile
## you fired that is inside the crest goes off there and the pack flinches.
func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _wall == null or _jacked:
		return
	_wall.lost_sight = on_trail()
	var line: float = _wall.front_y + FLINCH_INSET
	for child in get_children():
		if not (child is Node2D) or child.is_queued_for_deletion() or child.global_position.y <= line:
			continue
		if child.get("dropper") == _player and child.has_method(&"blow"):
			child.blow()
			_wall.flinch()
			flinches += 1
		elif child.get("shooter") == _player and child.has_method(&"_despawn") \
				and child.get("_spent") == false and child.get("hit_sfx") != &"hit_mg":
			var boom := preload("res://environment/explosion.tscn").instantiate()
			boom.global_position = child.global_position
			boom.size_scale = 0.45
			boom.tint = Color(0.5, 0.75, 0.95)
			add_child(boom)
			child._despawn()
			_wall.flinch(MISSILE_CUT)
			flinches += 1

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
	return _wall.tier_pace() if _wall else 0.0

## Whole bolts of daredevil bonus on the table (the HUD ticker).
func daredevil_bonus() -> int:
	return int(daredevil)

## The line is crossed: the purse and whatever the driver dared to earn go in
## the wallet (Economy's valve and reward scale apply — off the tour it pays
## nothing), and the win card says what for.
func _pay_out() -> void:
	var purse: int = Economy.award_flat(PURSE)
	var dared: int = Economy.award_flat(daredevil_bonus())
	if Economy.enabled and _end_screen != null:
		_end_screen.win_note = "PURSE +%d     DAREDEVIL +%d" % [purse, dared]

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
		# Off the tour (SINGLE BATTLE, a direct launch) there is nothing to
		# take and nowhere to roll on to: no wheel, straight to the classic
		# loss panel, whose Restart re-runs the slot.
		if _end_screen != null:
			_end_screen._show(false)
		return
	# The bay you had rides into the next stop, exactly as a win would carry
	# it — unless the wheel says otherwise.
	_end_screen._capture_ammo_carry(gs)
	# Bolts, parts, or blood: the wheel is rigged to what this driver owns,
	# the landing is rolled up front, and the bill is settled before the
	# card ever shows — the spin is theatre, the robbery already happened.
	var items: Array = GarageItems.load_catalog()
	var wheel: Array = Robbery.build_wheel(Robbery.state_of(gs, items))
	var landed: int = Robbery.spin(wheel, robbery_rng)
	var outcome: Dictionary = Robbery.apply(wheel[landed], gs, items, robbery_rng)
	print("[chase] robbed: %s (%s)" % [outcome["headline"], outcome["detail"]])
	_robbery = RobberyScreen.new()
	_robbery.name = "RobberyScreen"
	add_child(_robbery)
	_robbery.finished.connect(_roll_on.bind(next), CONNECT_ONE_SHOT)
	_robbery.open(jack_cause, outcome, wheel, landed,
		player_car_id(_player.stats, gs.selected_vehicle_id))

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
	return SpeedBand.road_top(_player, ROLL_SPEED / SpeedBand.CRUISE_FRAC) * SpeedBand.CRUISE_FRAC
