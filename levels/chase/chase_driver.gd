extends Driver
## The Buzzard brain — deliberately NOT EnemyDriver (the arena FSM is the
## wrong instinct for a forced chase). One script, role-tabled.
##
## The harassers (bike, sedan) fly SORTIES, like timid hyenas: a bandit
## who wants to make a name for itself boils up out of the dust, RUSHES to a
## station beside or ahead of the player, HARASSES for a second or two —
## potshots at a STALE snapshot of where you were (aim_delay, the "poor
## driver" tell) — then PEELS off back into the relative safety of the pack,
## where the director absorbs it and sends the next one. Take real damage
## mid-sortie and it flinches and peels early. Their only real strength is
## their numbers, and the fire you take is metered by how many sorties the
## director keeps in the air, not by how long any one bird hangs around.
##
## The ahead-spawns are different animals: the technical holds a mark far up
## the road and lets its bed turret talk as it falls back through the field;
## the blocker steals your lane and never fires. Course-guided steering keeps
## everyone inside the embankments by construction; the pedal keeps station
## through the shared speed band (speed_band.gd) — match the mark's pace,
## faster when behind the station, brake when ahead of it, never under the
## pace floor.

const SpeedBand := preload("res://levels/chase/speed_band.gd")

enum Stage { RUSH, HARASS, PEEL }

## Per-role tuning (F2-era knobs — static var, not frozen const).
## sortie roles: station_dy = where they harass from (dy vs player, + =
## behind); harass = [min, max] seconds on station; the burst window and
## range only apply while harassing.
static var ROLES := {
	&"bike": {
		"sortie": true, "station_dy": -80.0, "harass": [1.4, 2.4],
		"range": 420.0, "burst_len": 0.4, "burst_gap": 1.1,
		"aim_delay": 0.15, "wobble": 0.0, "use_secondary": false, "secondary_cd": 0.0,
		"yoyo": true,
	},
	&"sedan": {
		"sortie": true, "station_dy": 40.0, "harass": [2.0, 3.0],
		"range": 760.0, "burst_len": 0.6, "burst_gap": 2.0,
		"aim_delay": 0.45, "wobble": 0.3, "use_secondary": true, "secondary_cd": 6.0,
		"yoyo": true,
	},
	# The technical never chases and never self-fires: it aims to hold a mark
	# far AHEAD, physics says no (top speed 2), and it falls back through the
	# field with the bed turret doing all the talking. No yo-yo — falling away
	# is the design.
	&"technical": {
		"sortie": false, "station_dy": -900.0, "harass": [0.0, 0.0],
		"range": 0.0, "burst_len": 0.0, "burst_gap": 1.0,
		"aim_delay": 0.5, "wobble": 0.1, "use_secondary": false, "secondary_cd": 0.0,
		"yoyo": false,
	},
	# The blocker rolls in from the top like the technical, but it isn't there
	# to shoot: it parks itself in YOUR lane and makes you lift, go around, or
	# go through it. It steers at where you WERE (a long stale snapshot), so a
	# late juke beats it every time. Never fires, never yo-yos; once you're
	# past, it gives up the lane and fades back into the pack.
	&"blocker": {
		"sortie": false, "station_dy": -260.0, "harass": [0.0, 0.0],
		"range": 0.0, "burst_len": 0.0, "burst_gap": 1.0,
		"aim_delay": 0.6, "wobble": 0.0, "use_secondary": false, "secondary_cd": 0.0,
		"yoyo": false, "block": true,
	},
}

## Sortie clocks: a rush that never arrives still gets its turn, and a peel
## drops the bird deep enough into the dust to be absorbed.
static var RUSH_TIMEOUT := 5.0    # seconds of rushing before harassing anyway
static var ARRIVE_DIST := 70.0    # px from station that counts as "there"
static var PEEL_DEPTH := 260.0    # px inside the crest the peel aims for (> ABSORB_DEPTH)
static var FLINCH_DAMAGE := 10.0  # damage taken in one sortie that sends a bird home early

const ROAD_MARGIN := 70.0   # stay this far inside the sampled road edge
const LOOKAHEAD := 240.0    # steer at a point this far up the road
const STEER_GAIN := 2.2
const CREST_CLEAR := 70.0   # a hold mark never sits closer than this to the dust crest

## Station keeping: the pedal asks for the player's own pace plus this much
## per px of station error, and never less than MIN_PACE of the Buzzard's top.
static var HOLD_GAIN := 1.2      # px/s of closing speed asked per px behind the mark
static var MIN_PACE := 0.35      # of own top: a Buzzard never parks

## Yo-yo catch-up: far behind, a Buzzard's engine finds a little extra to
## keep up (max_speed rides the player's + margin, capped at YOYO_CAP of its
## honest ceiling); back in the knife-fight range it honors its stats again —
## always relevant, never unshakeable: the cap sits under a boost's 1.5x.
static var YOYO_FAR := 380.0     # px behind the player where the cheat kicks in
static var YOYO_NEAR := 180.0    # px behind where honest stats resume
static var YOYO_MARGIN := 80.0   # px/s over the player's speed while catching up
static var YOYO_CAP := 1.15      # of the honest ceiling: the most the cheat may find

@export var role: StringName = &"bike"
@export var lane_offset := 0.0    # director deals lanes so the pack spreads
@export var phase := 0.0          # per-driver desync for burst rhythms
@export var hold_fire := false    # the director's stand-down: off the trigger

var stage: int = Stage.RUSH
var _t := 0.0
var _stage_t := 0.0               # seconds in the current stage
var _harass_time := 2.0
var _aim_t := 0.0
var _aim_pos := Vector2.ZERO
var _missile_cd := 2.0            # first rocket never lands on spawn
var _host: Node = null
var _base_speed := -1.0           # honest StatCurves max_speed, captured once
var _sortie_damage := 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(phase * 1000.0) + 17
	var span: Array = ROLES[role]["harass"]
	_harass_time = rng.randf_range(float(span[0]), float(span[1]))
	# Timid: the parent car's Health tells the brain when it's been hurt.
	var car := get_parent()
	if car != null:
		var health := car.get_node_or_null(^"Health")
		if health != null and health.has_signal(&"damaged"):
			health.damaged.connect(_on_hit)

func _on_hit(amount: float, _hp: float) -> void:
	if stage == Stage.PEEL:
		return
	_sortie_damage += amount
	if _sortie_damage >= FLINCH_DAMAGE:
		peel()

## Break off and head for the pack. Public for the director's stand-down and
## for tests; harmless on a bird that is already going home.
func peel() -> void:
	if stage != Stage.PEEL:
		stage = Stage.PEEL
		_stage_t = 0.0

## Straight to the potshots (tests, and a rush that ran out of road).
func begin_harass() -> void:
	if stage == Stage.RUSH:
		stage = Stage.HARASS
		_stage_t = 0.0

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
	var station_dy: float = p["station_dy"]
	var target_x: float
	var target_y: float
	var front := _front_y(vehicle)
	var blocking: bool = p.get("block", false) and own.y < player.global_position.y
	if sortie:
		_advance_sortie(own, player.global_position + Vector2(_lane_beside(), station_dy))
	if sortie and stage == Stage.PEEL:
		# Home to the pack: a mark inside the dust, and the pedal eases off.
		target_x = _road_target(vehicle, own, lane_offset)
		target_y = (front + PEEL_DEPTH) if front != INF else player.global_position.y + 900.0
	elif sortie and stage == Stage.HARASS:
		target_x = _clamp_to_road(vehicle, own, _aim_pos.x + _lane_beside() * 0.5)  # the swerve-in
		target_y = hold_mark(player.global_position.y, station_dy, front)
	elif blocking:
		target_x = _clamp_to_road(vehicle, own, _aim_pos.x)   # the lane steal
		target_y = hold_mark(player.global_position.y, station_dy, front)
	else:
		# RUSH (and the ahead-spawns): beside the player, on the way to station.
		target_x = _clamp_to_road(vehicle, own, player.global_position.x + _lane_beside()) if sortie \
			else _road_target(vehicle, own, lane_offset)
		target_y = hold_mark(player.global_position.y, station_dy, front)
	if p.get("yoyo", false):
		if stage == Stage.PEEL:
			_yoyo_home(vehicle, delta)  # the cheat is for catching up, not for leaving
		else:
			_yoyo(vehicle, player, own, delta)
	var steer: float = _steer_to(vehicle, Vector2(target_x, own.y - LOOKAHEAD)) \
		+ p["wobble"] * sin(_t * 2.6 + phase)
	var throttle := _station_throttle(vehicle, player, own.y - target_y)
	var fire := false
	var fire_sec := false
	var may_fire: bool = not hold_fire and (not sortie or stage == Stage.HARASS)
	if may_fire:
		var dist := own.distance_to(player.global_position)
		var facing := Vector2.RIGHT.rotated(vehicle.heading)
		var toward: Vector2 = _aim_pos - own
		var aligned: bool = toward.length() > 1.0 and facing.dot(toward.normalized()) > 0.55
		var fcycle: float = p["burst_len"] + p["burst_gap"]
		fire = dist <= p["range"] and aligned \
			and fmod(_t + phase * 1.7, fcycle) < p["burst_len"]
		if p["use_secondary"] and _missile_cd <= 0.0 and dist < 900.0:
			_missile_cd = p["secondary_cd"]
			fire_sec = true
	if p["use_secondary"]:
		_missile_cd -= delta
	return {
		"throttle": throttle,
		"steer": clampf(steer, -1.0, 1.0),
		"fire_mg": fire,
		"fire_selected": fire_sec,
	}

## The sortie clock: RUSH until on station (or out of patience), HARASS for
## this bird's allotted seconds, then PEEL for good.
func _advance_sortie(own: Vector2, station: Vector2) -> void:
	match stage:
		Stage.RUSH:
			if own.distance_to(station) <= ARRIVE_DIST or _stage_t >= RUSH_TIMEOUT:
				stage = Stage.HARASS
				_stage_t = 0.0
		Stage.HARASS:
			if _stage_t >= _harass_time:
				peel()

## Which side of the player this bird works: the director's dealt lane, as a
## sideways offset from the CAR rather than from the road's centreline.
func _lane_beside() -> float:
	return lane_offset if lane_offset != 0.0 else 140.0

## The speed a station asks for: the mark's own pace, plus closing speed for
## every px behind the station (negative error = ahead of it = slower).
static func station_speed(mark_vn: float, behind_px: float, own_top: float) -> float:
	return maxf(mark_vn + behind_px * HOLD_GAIN, own_top * MIN_PACE)

## Pace-hold through the speed band: gas when under the asked speed, a real
## brake when well over it (they can finally fall back), never under the floor.
func _station_throttle(vehicle, player: Node2D, behind_px: float) -> float:
	var pv: Variant = player.get("velocity")
	var mark_vn: float = -pv.y if pv is Vector2 else 0.0
	var own_top := 500.0
	if vehicle.has_method(&"get_controller") and vehicle.get_controller() != null:
		own_top = vehicle.get_controller().max_speed
	var vv: Variant = vehicle.get("velocity")
	var fwd_speed := 0.0
	if vv is Vector2:
		fwd_speed = vv.dot(Vector2.RIGHT.rotated(vehicle.heading))
	return SpeedBand.toward(fwd_speed, station_speed(mark_vn, behind_px, own_top), true)

func _yoyo(vehicle, player: Node2D, own: Vector2, delta: float) -> void:
	if not vehicle.has_method(&"get_controller"):
		return  # bare test fixtures
	var ctrl = vehicle.get_controller()
	if ctrl == null:
		return
	if _base_speed < 0.0:
		_base_speed = ctrl.max_speed
	var behind: float = own.y - player.global_position.y  # + = trailing
	var pv: Variant = player.get("velocity")
	var pspeed: float = pv.length() if pv is Vector2 else 0.0
	var want: float = _base_speed
	if behind > YOYO_FAR:
		want = clampf(pspeed + YOYO_MARGIN, _base_speed, _base_speed * YOYO_CAP)
	elif behind > YOYO_NEAR:
		return  # hysteresis band — hold whatever it's doing
	ctrl.max_speed = lerpf(ctrl.max_speed, want, minf(delta * 2.0, 1.0))

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

## Peeling: whatever the engine found on the way up, it gives back.
func _yoyo_home(vehicle, delta: float) -> void:
	if _base_speed < 0.0 or not vehicle.has_method(&"get_controller"):
		return
	var ctrl = vehicle.get_controller()
	if ctrl != null:
		ctrl.max_speed = lerpf(ctrl.max_speed, _base_speed, minf(delta * 2.0, 1.0))

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
