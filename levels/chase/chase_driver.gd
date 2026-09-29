extends Driver
## The Buzzard brain — deliberately NOT EnemyDriver (the arena FSM is the
## wrong instinct for a forced chase). One script, role-tabled: bikes swoop in
## on the player and lay back out on a personal rhythm; sedans hold a wobbly
## station behind and lob lazy rockets at a STALE snapshot of where you were
## (aim_delay — the "poor driver" tell). Course-guided steering keeps them
## inside the embankments by construction; the pedal holds a STATION off the
## player through the shared speed band (speed_band.gd) — match the mark's
## pace, faster when behind the station, brake when ahead of it, never under
## the pace floor. Glass cannons: the fairness lives in the burst windows,
## not in aim assists.

const SpeedBand := preload("res://levels/chase/speed_band.gd")

## Per-role tuning (F2-era knobs — static var, not frozen const).
static var ROLES := {
	&"bike": {
		"hold_far": 190.0, "hold_near": -60.0,      # dy vs player (+ = behind)
		"swoop_period": 4.5, "swoop_frac": 0.45,
		"range": 420.0, "burst_len": 0.5, "burst_gap": 1.8,
		"aim_delay": 0.15, "wobble": 0.0, "use_secondary": false, "secondary_cd": 0.0,
		"yoyo": true,
	},
	&"sedan": {
		"hold_far": 430.0, "hold_near": 260.0,
		"swoop_period": 7.0, "swoop_frac": 0.35,
		"range": 760.0, "burst_len": 0.9, "burst_gap": 2.6,
		"aim_delay": 0.45, "wobble": 0.3, "use_secondary": true, "secondary_cd": 4.5,
		"yoyo": true,
	},
	# The technical never chases and never self-fires: it aims to hold a mark
	# far AHEAD, physics says no (top speed 2), and it falls back through the
	# field with the bed turret doing all the talking. No yo-yo — falling away
	# is the design.
	&"technical": {
		"hold_far": -900.0, "hold_near": -900.0,
		"swoop_period": 8.0, "swoop_frac": 0.0,
		"range": 0.0, "burst_len": 0.0, "burst_gap": 1.0,
		"aim_delay": 0.5, "wobble": 0.1, "use_secondary": false, "secondary_cd": 0.0,
		"yoyo": false,
	},
}

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
@export var phase := 0.0          # per-driver desync for swoop/burst rhythms
@export var hold_fire := false    # director's respawn grace

var _t := 0.0
var _aim_t := 0.0
var _aim_pos := Vector2.ZERO
var _missile_cd := 2.0            # first rocket never lands on spawn
var _host: Node = null
var _base_speed := -1.0           # honest StatCurves max_speed, captured once

func get_intent(vehicle, delta: float) -> Dictionary:
	var p: Dictionary = ROLES[role]
	_t += delta
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
	# Swoop rhythm: close in for a burst window, lay back out.
	var cycle_t: float = fmod(_t + phase, float(p["swoop_period"]))
	var swooping: bool = cycle_t < p["swoop_period"] * p["swoop_frac"]
	var hold_dy: float = p["hold_near"] if swooping else p["hold_far"]
	var target_x: float
	if swooping:
		target_x = _clamp_to_road(vehicle, own, _aim_pos.x)   # the swerve-in
	else:
		target_x = _road_target(vehicle, own, lane_offset)
	var target_y := hold_mark(player.global_position.y, hold_dy, _front_y(vehicle))
	if p.get("yoyo", false):
		_yoyo(vehicle, player, own, delta)
	var steer: float = _steer_to(vehicle, Vector2(target_x, own.y - LOOKAHEAD)) \
		+ p["wobble"] * sin(_t * 2.6 + phase)
	var throttle := _station_throttle(vehicle, player, own.y - target_y)
	var fire := false
	var fire_sec := false
	if not hold_fire:
		var dist := own.distance_to(player.global_position)
		var facing := Vector2.RIGHT.rotated(vehicle.heading)
		var toward: Vector2 = _aim_pos - own
		var aligned: bool = toward.length() > 1.0 and facing.dot(toward.normalized()) > 0.55
		var fcycle: float = p["burst_len"] + p["burst_gap"]
		fire = dist <= p["range"] and aligned \
			and fmod(_t + phase * 1.7, fcycle) < p["burst_len"]
		if p["use_secondary"]:
			_missile_cd -= delta
			if _missile_cd <= 0.0 and dist < 900.0:
				_missile_cd = p["secondary_cd"]
				fire_sec = true
	return {
		"throttle": throttle,
		"steer": clampf(steer, -1.0, 1.0),
		"fire_mg": fire,
		"fire_selected": fire_sec,
	}

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
