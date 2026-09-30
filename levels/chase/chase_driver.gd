extends Driver
## The Buzzard brain — deliberately NOT EnemyDriver (the arena FSM is the
## wrong instinct for a forced chase). One script, role-tabled.
##
## The harassers fly SORTIES out of the dust, and each class has its own
## playbook:
##
##   BIKES strafe. They come up your tail FAST, spraying and praying, zip
##   past on a flank, and leave — most of them off the top of the screen on
##   a burst of speed no honest engine has, the rest by swerving out to the
##   shoulder and dropping back into the pack. On the way out most cut
##   across your nose: that is your shot.
##
##   SEDANS bully. They pop their one rocket from behind, blaze the MG on
##   the way up, pass, and cut across to BOX you in. They are timid: a
##   weapon hit or a few MG rounds and they swerve to the shoulder and let
##   the pack take them back.
##
## The ahead-spawns are different animals: the TECHNICAL rolls in from the
## top with its bed gunner tracking you and FADES back through the field at
## a steady rate — a heavy, sluggish truck, on screen for a few seconds
## however you drive; the BLOCKER steals your lane and never fires.
##
## Birds PASS you, they never drive through you: behind your nose they keep
## to their flank, they only pull level once they're clear of it, a cut-in
## waits until their tail leads your nose, and a bird leaving swerves out of
## your lane BEFORE it lifts. Course-guided steering keeps everyone inside
## the embankments; the pedal keeps station through the shared speed band
## (speed_band.gd).

const SpeedBand := preload("res://levels/chase/speed_band.gd")

enum Stage { RUSH, PASS, BOX, EXIT, PEEL }

## Per-role tuning (F2-era knobs — static var, not frozen const).
##   tail_dy      px behind you the rush aims for
##   fire         the stages the MG may talk in (it still has to be pointed at you)
##   box          [min, max] seconds held ahead of you after the pass
##   exit_north   chance the bird leaves off the TOP of the screen (else: box, then the shoulder)
##   cross        chance it cuts across your nose on the way out — your shot
##   flinch       damage in one sortie that sends it to the shoulder (0 = committed)
##   sprint       of its honest ceiling while it moves up
##   rockets / rocket_delay   secondaries per sortie, and seconds before the first
##   fade         (ahead-spawns) px/s it falls back relative to you, however you drive
static var ROLES := {
	&"bike": {
		"sortie": true, "station_dy": 0.0, "tail_dy": 110.0,
		"fire": [Stage.RUSH, Stage.PASS], "range": 420.0, "burst_len": 0.7, "burst_gap": 0.4,
		"box": [0.35, 0.8], "exit_north": 0.6, "cross": 0.7, "flinch": 0.0, "sprint": 1.3,
		"aim_delay": 0.15, "wobble": 0.0, "rockets": 0, "rocket_delay": 0.0,
	},
	&"sedan": {
		"sortie": true, "station_dy": 0.0, "tail_dy": 170.0,
		"fire": [Stage.RUSH, Stage.PASS], "range": 620.0, "burst_len": 0.5, "burst_gap": 1.1,
		"box": [1.5, 2.5], "exit_north": 0.0, "cross": 1.0, "flinch": 6.0, "sprint": 1.25,
		"aim_delay": 0.45, "wobble": 0.3, "rockets": 1, "rocket_delay": 1.2,
	},
	# The technical never chases and never self-fires: it rolls in from far
	# AHEAD, and once it is inside its mark it gives ground at a steady `fade`
	# whatever you do with your pedal — the bed turret does all the talking
	# for the few seconds it is on screen.
	&"technical": {
		"sortie": false, "station_dy": -850.0, "fade": 240.0,
		"fire": [], "range": 0.0, "burst_len": 0.0, "burst_gap": 1.0,
		"aim_delay": 0.5, "wobble": 0.1, "rockets": 0, "rocket_delay": 0.0,
	},
	# The blocker rolls in from the top like the technical, but it isn't there
	# to shoot: it parks itself in YOUR lane and makes you lift, go around, or
	# go through it. It steers at where you WERE (a long stale snapshot), so a
	# late juke beats it every time. Never fires; once you're past, it gives up
	# the lane and fades back into the pack.
	&"blocker": {
		"sortie": false, "station_dy": -260.0, "block": true,
		"fire": [], "range": 0.0, "burst_len": 0.0, "burst_gap": 1.0,
		"aim_delay": 0.6, "wobble": 0.0, "rockets": 0, "rocket_delay": 0.0,
	},
}

## Sortie geometry (px, relative to the player; + dy = behind).
static var LOITER_DX := 50.0      # off your line during the rush (your rear quarter, never your bumper)
static var BESIDE_DX := 125.0     # to the side a bird rides while it passes
static var PASS_CLEAR := 80.0     # sideways room that counts as "clear of your flank"
static var QUARTER_DY := 110.0    # behind: where a bird that isn't clear yet hangs back
static var PASS_LEAD := 130.0     # ahead: the mark a passing bird drives for
static var CUT_IN_CLEAR := 75.0   # its tail must lead your nose by this before it cuts across
static var BOX_DY := -120.0       # the box station: in your lane, in your sights
static var ON_STATION := 60.0     # along-the-road error inside which the box clock runs
static var SHOULDER_OUT := 30.0   # past the road edge: where a leaving bird rides the verge
static var SPRINT_SLACK := 30.0   # behind the mark before the sprint is asked for

## Sortie clocks: nobody hangs around forever.
static var RUSH_TIMEOUT := 5.0    # seconds of rushing before it goes for the pass anyway
static var ARRIVE_DIST := 70.0    # px from the tail mark that counts as "there"
static var PASS_TIMEOUT := 4.0    # seconds trying to get by before it gives up and goes home
static var TRANSIT_TIMEOUT := 3.0 # seconds past its box hold it chases a box it can't reach
static var EXIT_TIMEOUT := 6.0    # seconds a breakaway runs before it goes home instead
static var PEEL_DEPTH := 260.0    # px inside the crest the peel aims for (> ABSORB_DEPTH)
static var BREAKAWAY := 260.0     # px/s over YOUR speed a bird leaving off the top finds

const ROAD_MARGIN := 70.0   # stay this far inside the sampled road edge
const LOOKAHEAD := 240.0    # steer at a point this far up the road
const STEER_GAIN := 2.2
const CREST_CLEAR := 70.0   # a hold mark never sits closer than this to the dust crest

## Station keeping: the pedal asks for the player's own pace plus this much
## per px of station error, and never less than MIN_PACE of the Buzzard's top.
static var HOLD_GAIN := 1.2      # px/s of closing speed asked per px behind the mark
static var MIN_PACE := 0.35      # of own top: a Buzzard never parks

@export var role: StringName = &"bike"
@export var lane_offset := 0.0    # director deals lanes so the pack spreads
@export var phase := 0.0          # per-driver desync for burst rhythms and the dealt plan
@export var hold_fire := false    # the director's stand-down: off the trigger

var stage: int = Stage.RUSH
var exit_north := false           # dealt: this bird leaves off the top of the screen
var cross := true                 # dealt: it cuts across your nose on the way out
var _t := 0.0
var _stage_t := 0.0               # seconds in the current stage
var _on_t := 0.0                  # seconds ON the box station (the hold clock)
var _side := 1.0                  # which flank this bird works (+ = the player's right)
var _box_hold := 1.0              # dealt: seconds it holds the box
var _rockets := 0
var _rocket_cd := 0.0
var _aim_t := 0.0
var _aim_pos := Vector2.ZERO
var _host: Node = null
var _base_speed := -1.0           # the ceiling the director priced, captured once
var _sortie_damage := 0.0

func _ready() -> void:
	var p: Dictionary = ROLES[role]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(phase * 1000.0) + 17
	_side = -1.0 if lane_offset < 0.0 else 1.0
	if p.get("sortie", false):
		var span: Array = p["box"]
		_box_hold = rng.randf_range(float(span[0]), float(span[1]))
		exit_north = rng.randf() < float(p["exit_north"])
		cross = rng.randf() < float(p["cross"])
	_rockets = int(p["rockets"])
	_rocket_cd = float(p["rocket_delay"])
	# Timid: the parent car's Health tells the brain when it's been hurt.
	var car := get_parent()
	if car != null:
		var health := car.get_node_or_null(^"Health")
		if health != null and health.has_signal(&"damaged"):
			health.damaged.connect(_on_hit)

func _on_hit(amount: float, _hp: float) -> void:
	var nerve: float = float(ROLES[role].get("flinch", 0.0))
	if stage == Stage.PEEL or nerve <= 0.0:
		return
	# The pack's own stray lead doesn't scare it — only what YOU land does
	# (or the road: a barrel has no attacker).
	var who: Variant = get_parent().get("last_attacker") if get_parent() != null else null
	if who is Node and is_instance_valid(who) and not (who as Node).is_in_group(&"player"):
		return
	_sortie_damage += amount
	if _sortie_damage >= nerve:
		peel()

## Break off and head for the pack. Public for the director's stand-down and
## for tests; harmless on a bird that is already going home.
func peel() -> void:
	if stage != Stage.PEEL:
		_enter(Stage.PEEL)

## Jump the sortie ahead (tests). Only ever forward.
func skip_to(target: int) -> void:
	if target > stage:
		_enter(target)

## Seconds this bird holds the box (tests read the clock it was dealt).
func box_seconds() -> float:
	return _box_hold

## True once a breakaway is running for the top of the screen: the director
## frees it when it is out of sight (no wreck, no bounty — it got away).
func breaking_away() -> bool:
	return stage == Stage.EXIT

func _enter(next: int) -> void:
	stage = next
	_stage_t = 0.0
	_on_t = 0.0

func get_intent(vehicle, delta: float) -> Dictionary:
	var p: Dictionary = ROLES[role]
	_t += delta
	_stage_t += delta
	var own: Vector2 = vehicle.global_position
	var player := vehicle.get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null or not is_instance_valid(player):
		# Nobody to chase — hold the road at cruise.
		var cruise := Vector2(_road_target(vehicle, own, 0.0), own.y - LOOKAHEAD)
		return {"throttle": 0.8, "steer": _steer_to(vehicle, cruise)}
	# Poor drivers aim at where you WERE (refreshed every aim_delay).
	_aim_t -= delta
	if _aim_t <= 0.0:
		_aim_t = p["aim_delay"]
		_aim_pos = player.global_position
	var sortie: bool = p.get("sortie", false)
	var front := _front_y(vehicle)
	var pp: Vector2 = player.global_position
	var target_x: float
	var target_y: float
	var throttle: float
	if sortie:
		if stage == Stage.RUSH:
			_pick_side(vehicle, own, pp)
		_advance_sortie(vehicle, own, pp, front, delta)
		var mark := _sortie_mark(vehicle, own, pp, front)
		target_x = mark.x
		target_y = mark.y
		match stage:
			Stage.PEEL:
				_ease_home(vehicle, delta)   # whatever the engine found, it gives back
			Stage.EXIT:
				_breakaway(vehicle, player, delta)
			_:
				_sprint(vehicle, own.y - target_y, delta)
		throttle = _station_throttle(vehicle, player, own.y - target_y)
	else:
		var station_dy: float = p["station_dy"]
		if p.get("block", false) and own.y < pp.y:
			target_x = _clamp_to_road(vehicle, own, _aim_pos.x)   # the lane steal
		else:
			target_x = _road_target(vehicle, own, lane_offset)     # hold the dealt lane
		target_y = hold_mark(pp.y, station_dy, front)
		throttle = _station_throttle(vehicle, player, own.y - target_y, float(p.get("fade", 0.0)))
	var steer: float = _steer_to(vehicle, Vector2(target_x, own.y - LOOKAHEAD)) \
		+ p["wobble"] * sin(_t * 2.6 + phase)
	var fire := false
	var fire_sec := false
	if _rockets > 0:
		_rocket_cd -= delta
	if not hold_fire and stage in p["fire"]:
		var dist := own.distance_to(pp)
		var facing := Vector2.RIGHT.rotated(vehicle.heading)
		var toward: Vector2 = _aim_pos - own
		var aligned: bool = toward.length() > 1.0 and facing.dot(toward.normalized()) > 0.55
		var fcycle: float = p["burst_len"] + p["burst_gap"]
		fire = dist <= p["range"] and aligned \
			and fmod(_t + phase * 1.7, fcycle) < p["burst_len"]
		# The rocket leaves from BEHIND you, early: pop it, then come up and box.
		if _rockets > 0 and _rocket_cd <= 0.0 and dist < 900.0 and own.y > pp.y + 40.0:
			_rockets -= 1
			fire_sec = true
	return {
		"throttle": throttle,
		"steer": clampf(steer, -1.0, 1.0),
		"fire_mg": fire,
		"fire_selected": fire_sec,
	}

## The sortie clock. RUSH up your tail (or run out of patience) → PASS on the
## flank until its tail leads your nose → then the dealt way out: EXIT off
## the top of the screen, or BOX for its dealt seconds and PEEL to the
## shoulder. A bird that can't get by, can't reach its box, or can't shake
## you on the way out goes home instead.
func _advance_sortie(vehicle, own: Vector2, pp: Vector2, front: float, delta: float) -> void:
	match stage:
		Stage.RUSH:
			if own.distance_to(_sortie_mark(vehicle, own, pp, front)) <= ARRIVE_DIST or _stage_t >= RUSH_TIMEOUT:
				_enter(Stage.PASS)
		Stage.PASS:
			if own.y < pp.y - CUT_IN_CLEAR:
				_enter(Stage.EXIT if exit_north else Stage.BOX)
			elif _stage_t >= PASS_TIMEOUT:
				peel()
		Stage.BOX:
			if absf(own.y - hold_mark(pp.y, BOX_DY, front)) <= ON_STATION:
				_on_t += delta
			if _on_t >= _box_hold or _stage_t >= _box_hold + TRANSIT_TIMEOUT:
				peel()
		Stage.EXIT:
			if _stage_t >= EXIT_TIMEOUT:
				peel()

## Where a sortie bird wants to be right now (world px).
func _sortie_mark(vehicle, own: Vector2, pp: Vector2, front: float) -> Vector2:
	var p: Dictionary = ROLES[role]
	var side_x := _clamp_to_road(vehicle, own, pp.x + _side * BESIDE_DX)
	var leads: bool = own.y < pp.y - CUT_IN_CLEAR
	match stage:
		Stage.RUSH:
			# Up your tail, a little off your line, leaning at where you WERE.
			return Vector2(_clamp_to_road(vehicle, own, _aim_pos.x + _side * LOITER_DX),
				hold_mark(pp.y, float(p["tail_dy"]), front))
		Stage.PASS:
			# Out onto the flank and by. Not clear of your flank yet: hang off
			# your quarter until the lane is open — never through you.
			var dy := -PASS_LEAD
			if own.y > pp.y and absf(own.x - pp.x) < PASS_CLEAR:
				dy = QUARTER_DY
			return Vector2(side_x, hold_mark(pp.y, dy, front))
		Stage.BOX:
			# The cut-in, swerving at a stale read of your lane.
			var box_x := _clamp_to_road(vehicle, own, _aim_pos.x) if (cross and leads) else side_x
			return Vector2(box_x, hold_mark(pp.y, BOX_DY, front))
		Stage.EXIT:
			# Gone: up the road and out of sight, across your nose if it's cocky.
			var out_x := _clamp_to_road(vehicle, own, _aim_pos.x) if (cross and leads) else side_x
			return Vector2(out_x, pp.y - 2000.0)
	# PEEL: swerve out to the shoulder first — never a brake check — then
	# straight back down the verge to the pack.
	var shoulder := _shoulder_x(vehicle, own, pp)
	if own.y < pp.y + PASS_CLEAR and absf(own.x - pp.x) < PASS_CLEAR:
		return Vector2(shoulder, own.y)
	var home: float = (front + PEEL_DEPTH) if front != INF else pp.y + 900.0
	return Vector2(shoulder, home)

## The shoulder a leaving bird swerves for: the verge on whichever side of
## you it is already on (its own flank when it is dead ahead) — or the other
## one, if you are hugging that edge yourself. No course in the tree (bare
## fixtures) = a wide lane on that side.
func _shoulder_x(vehicle, own: Vector2, pp: Vector2) -> float:
	var away := _side if absf(own.x - pp.x) < 8.0 else signf(own.x - pp.x)
	var c = _course(vehicle)
	if c == null:
		return pp.x + away * BESIDE_DX * 2.0
	var s: Dictionary = c.sample(-own.y)
	var reach: float = float(s["half_w"]) + SHOULDER_OUT
	var x: float = float(s["x"]) + away * reach
	if absf(x - pp.x) < PASS_CLEAR:
		x = float(s["x"]) - away * reach
	return x

## The flank a bird works is the director's dealt lane — unless the road has
## no room there (you're hugging that verge): then it takes the other. Decided
## during the rush, while it is still behind you; once it moves up, it is
## committed.
func _pick_side(vehicle, own: Vector2, pp: Vector2) -> void:
	var room := absf(_clamp_to_road(vehicle, own, pp.x + _side * BESIDE_DX) - pp.x)
	if room < BESIDE_DX * 0.7:
		var other := absf(_clamp_to_road(vehicle, own, pp.x - _side * BESIDE_DX) - pp.x)
		if other > room:
			_side = -_side

## Moving up, a bird finds a little extra: its role's `sprint` of the ceiling
## the director priced — still under a boost's 1.5x, so nitro always shakes
## it. On its mark it gives it back.
func _sprint(vehicle, behind_px: float, delta: float) -> void:
	var ctrl = _controller(vehicle)
	if ctrl == null:
		return
	var want: float = _base_speed
	if behind_px > SPRINT_SLACK:
		want *= float(ROLES[role].get("sprint", 1.0))
	# Found at once, given back gently: a newborn keeps the speed it emerged
	# with instead of being dragged down to its honest ceiling first.
	ctrl.max_speed = want if want > ctrl.max_speed else lerpf(ctrl.max_speed, want, minf(delta * 4.0, 1.0))

## Leaving off the top: the one honest cheat in the pack. The engine finds
## BREAKAWAY px/s over whatever YOU are doing — boost included — so the bird
## really does go, and the director frees it once it is out of sight.
func _breakaway(vehicle, player: Node2D, delta: float) -> void:
	var ctrl = _controller(vehicle)
	if ctrl == null:
		return
	var pv: Variant = player.get("velocity")
	var pspeed: float = pv.length() if pv is Vector2 else 0.0
	var want := maxf(_base_speed * float(ROLES[role].get("sprint", 1.0)), pspeed + BREAKAWAY)
	ctrl.max_speed = lerpf(ctrl.max_speed, want, minf(delta * 4.0, 1.0))

## Going home: whatever the engine found on the way up, it gives back.
func _ease_home(vehicle, delta: float) -> void:
	var ctrl = _controller(vehicle)
	if ctrl != null:
		ctrl.max_speed = lerpf(ctrl.max_speed, _base_speed, minf(delta * 2.0, 1.0))

## The car's controller, with the director's priced ceiling captured on first
## touch. Null on bare test fixtures.
func _controller(vehicle):
	if not vehicle.has_method(&"get_controller"):
		return null
	var ctrl = vehicle.get_controller()
	if ctrl != null and _base_speed < 0.0:
		_base_speed = ctrl.max_speed
	return ctrl

## The speed a station asks for: the mark's own pace, plus closing speed for
## every px behind the station (negative error = ahead of it = slower).
static func station_speed(mark_vn: float, behind_px: float, own_top: float) -> float:
	return maxf(mark_vn + behind_px * HOLD_GAIN, own_top * MIN_PACE)

## Pace-hold through the speed band: gas when under the asked speed, a real
## brake when well over it (they can finally fall back), never under the floor.
## `fade` > 0 is the technical's pedal: inside its mark it never tries to hold
## station — it asks for YOUR pace minus the fade, so it gives ground at the
## same steady rate whether you are flat out or on the brakes.
func _station_throttle(vehicle, player: Node2D, behind_px: float, fade := 0.0) -> float:
	var pv: Variant = player.get("velocity")
	var mark_vn: float = -pv.y if pv is Vector2 else 0.0
	var own_top := 500.0
	if vehicle.has_method(&"get_controller") and vehicle.get_controller() != null:
		own_top = vehicle.get_controller().max_speed
	var vv: Variant = vehicle.get("velocity")
	var fwd_speed := 0.0
	if vv is Vector2:
		fwd_speed = vv.dot(Vector2.RIGHT.rotated(vehicle.heading))
	var ask := station_speed(mark_vn, behind_px, own_top)
	if fade > 0.0:
		ask = station_speed(mark_vn - fade, minf(behind_px, 0.0), own_top)
	return SpeedBand.toward(fwd_speed, ask, true)

## The world y a Buzzard tries to hold: its role's station off the player,
## pulled north of the dust crest — a mark inside the pack is a Buzzard that
## parks in the murk and gets absorbed for it.
static func hold_mark(player_y: float, hold_dy: float, front_y: float) -> float:
	return minf(player_y + hold_dy, front_y - CREST_CLEAR)

## Dust crest world y, duck-typed off the chase host (INF = no wall to mind).
func _front_y(vehicle) -> float:
	_course(vehicle)  # refreshes the cached host
	if _host != null and _host.has_method(&"wall_front_y"):
		return _host.wall_front_y()
	return INF

func _steer_to(vehicle, point: Vector2) -> float:
	var own: Vector2 = vehicle.global_position
	var want := (point - own).angle()
	return clampf(angle_difference(vehicle.heading, want) * STEER_GAIN, -1.0, 1.0)

## Course centerline + lane, clamped inside the embankments. No course in the
## tree (bare fixtures) = hold the current line.
func _road_target(vehicle, own: Vector2, lane: float) -> float:
	return _clamp_to_road(vehicle, own, _course_x(vehicle, own) + lane)

func _course_x(vehicle, own: Vector2) -> float:
	var c = _course(vehicle)
	if c == null:
		return own.x
	var s: Dictionary = c.sample(-own.y)
	return s["x"]

func _clamp_to_road(vehicle, own: Vector2, x: float) -> float:
	var c = _course(vehicle)
	if c == null:
		return x
	var s: Dictionary = c.sample(-own.y)
	var road_x: float = s["x"]
	var half: float = s["half_w"]
	return clampf(x, road_x - half + ROAD_MARGIN, road_x + half - ROAD_MARGIN)

func _course(vehicle):
	if _host == null or not is_instance_valid(_host):
		_host = vehicle.get_tree().get_first_node_in_group(&"chase_host")
	return _host.course if _host != null else null
