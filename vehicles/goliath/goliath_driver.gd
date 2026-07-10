extends Driver
## Goliath's brain. Phase 1 (trailered) is AVOIDANT by design: ride the
## authored waypoint ring at pace and let the trailer battery talk. A player
## inside APPROACH_TRIGGER provokes exactly one answer — in the front arc
## they get the grille (RAM: straight hunt, boost, MG), anywhere else they
## get the tail (JACKKNIFE: a committed hard steer away from their side so
## the trailer whips INTO them; the strike itself is the trailer's physics).
## Either way ends in a PARTING shot over the shoulder, then back to the
## loop with a re-engage cooldown — pressure comes in waves, not a smother.
## RECOVER is the big-rig unstick: real-velocity stuck trip, committed
## reverse-out, rejoin the ring at the nearest mark.
## Deliberately NOT EnemyDriver: no feelers (they'd see our own trailer),
## no archetype blend — the loop IS the archetype. Phase 2 lands in Batch D.

enum Mode { LOOP, RAM, JACKKNIFE, PARTING, RECOVER, LINE_UP, CHARGE, RETREAT }

static var LOOP_ARRIVE := 260.0     # waypoint advance radius — wide = smooth arcs
static var LOOP_STEER_GAIN := 2.2   # chase_driver's proven angle->steer gain
static var LOOP_THROTTLE := 0.85    # combat cruise on the ring
static var APPROACH_TRIGGER := 520.0    # player this close provokes a reaction
static var REENGAGE_COOLDOWN := 2.5     # post-parting grace before the next one
static var RAM_FRONT_ARC := deg_to_rad(45.0)  # front-arc half-angle -> grille
static var RAM_TIME := 1.4          # committed hunt window
static var RAM_FIRE_CONE := 0.35    # MG alignment during the hunt (rad)
static var JACKKNIFE_STEER := 1.0   # sway magnitude
static var JACKKNIFE_TIME := 1.1    # the full sway window
static var JACKKNIFE_SWAY_OUT := 0.35   # fraction of the window steering away
										# (the wind-up that loads the tail)
static var JACKKNIFE_SWAY_BACK := 0.75  # fraction where the counter-snap ends;
										# the rest straightens back onto course
static var JACKKNIFE_THROTTLE := 0.9  # speed keeps the tail's energy up
static var JACKKNIFE_COOLDOWN := 6.0  # the tail is an occasion, not a habit
static var JACKKNIFE_MIN_SPEED := 320.0  # real px/s — the maneuver NEEDS
									# momentum: attack, recover, resume course,
									# get back up to speed, THEN swing again
									# (otherwise it's a dog chasing its tail)
static var PARTING_SHOT_TIME := 0.8   # the over-the-shoulder goodbye
static var PARTING_FIRE_CONE := 0.5
# Phase 2 (bobtail): the charge cycle. LINE_UP squares on the player, the
# CHARGE is committed dead-straight (baitable BY DESIGN — no re-homing), a
# connect spins them out and buys a RETREAT lap on the ring, and a whiff
# into scenery is self-damage plus a sitting-duck stun: the fight's trick.
static var CHARGE_WINDUP := 0.7      # line-up beat before a commit is legal
static var CHARGE_ALIGN := 0.18      # rad: aim tightness required to commit
static var CHARGE_MAX_DIST := 850.0  # commit only near the screen edge — the
									 # player must get to SEE the tell (stacks
									 # belch + ram_warn) before the steel flies
static var CHARGE_SPEED := 1300.0    # forced velocity while committed
static var CHARGE_TIME := 0.9        # open-air whiffs expire here
static var CHARGE_SELF_DMG := 120.0  # the wall bill on a baited miss
static var CHARGE_STUN := 2.0        # the sitting-duck window (s)
static var CHARGE_HIT_KNOCKBACK := 1000.0  # a semi hurts way more than a kart
static var CHARGE_HIT_SPIN := deg_to_rad(140.0)
static var CHARGE_HIT_STUN := 0.7
static var RETREAT_TIME := 2.5       # the back-off lap after a connect
static var RETREAT_THROTTLE := 1.0
static var RAM_COOLDOWN := 45.0      # after ANY charge attempt: back to the
									 # track by default, lead-not-steel if
									 # crowded, pursuit when it expires — the
									 # rhythm the player counters around
static var HARASS_THROTTLE := 0.8    # cooldown engagement pace
static var BOBTAIL_STEER_CAP := 0.6  # a semi needs speed and room — phase-2
									 # steering never gets the j-turn wrist

static var STUCK_SPEED := 40.0      # real px/s below this counts as pinned
static var STUCK_TRIP := 1.2        # seconds pinned before RECOVER (the rig
									# launches slowly — don't trip on takeoff)
static var RECOVER_REVERSE_TIME := 1.6

var _mode := Mode.LOOP
var _timer := 0.0
var _reengage := 0.0
var _jk_cd := 0.0
var _jk_steer := 0.0
var _charge_dir := Vector2.RIGHT
var _ram_cd := 0.0
var _stuck_t := 0.0
var _rev_steer := 1.0
var _points: PackedVector2Array = PackedVector2Array()
var _idx := 0
var _boss: Node = null

## Tests and bench rigs feed a ring directly; in the stadium the ring is the
## level's GoliathLoop markers, gathered on first intent.
func set_loop(points: PackedVector2Array) -> void:
	_points = points
	_idx = 0

func get_intent(vehicle, delta: float) -> Dictionary:
	if _points.is_empty():
		_gather_loop(vehicle)
		if _points.is_empty():
			return super.get_intent(vehicle, delta)  # no ring authored — park
	if _boss == null:
		_boss = vehicle.get_node_or_null(^"BossController")
	_timer -= delta
	_reengage = maxf(_reengage - delta, 0.0)
	_jk_cd = maxf(_jk_cd - delta, 0.0)
	_ram_cd = maxf(_ram_cd - delta, 0.0)
	var player := vehicle.get_tree().get_first_node_in_group(&"player") as Node2D
	if player != null and not is_instance_valid(player):
		player = null
	_update_stuck(vehicle, delta)

	# Committed states run their timers out, then hand back to the loop.
	if _mode == Mode.RECOVER:
		if _timer > 0.0:
			return {"throttle": -1.0, "steer": _rev_steer}
		_rejoin(vehicle)
	if _phase() == 2:
		return _phase2_intent(vehicle, player)
	if _mode == Mode.RAM and (_timer <= 0.0 or player == null):
		_enter_parting()
	elif _mode == Mode.JACKKNIFE and _timer <= 0.0:
		_enter_parting()
	elif _mode == Mode.PARTING and (_timer <= 0.0 or player == null):
		_reengage = REENGAGE_COOLDOWN
		_rejoin(vehicle)

	# The loop is home; a close player provokes the reaction (phase 1 only).
	if _mode == Mode.LOOP and player and _reengage <= 0.0 and _phase() == 1:
		if vehicle.global_position.distance_to(player.global_position) < APPROACH_TRIGGER:
			_react(vehicle, player)

	match _mode:
		Mode.RAM:
			return _hunt_intent(vehicle, player)
		Mode.JACKKNIFE:
			return {"throttle": JACKKNIFE_THROTTLE, "steer": _sway_steer()}
		Mode.PARTING:
			return _parting_intent(vehicle, player)
		_:
			return _loop_intent(vehicle)

## Duck-typed hook (vehicle.gd's dash-skip generalization): while CHARGING
## the vehicle bypasses its controller so the top-speed clamp doesn't eat
## the forced velocity — the obstacle mask stays ON, so walls CAN be hit.
func is_forcing() -> bool:
	return _mode == Mode.CHARGE

## Phase 2, bobtail. The charge is committed the moment it launches: no
## re-homing, no steering — dodge it and it keeps the appointment with
## whatever was behind you. Every attempt (hit, bait, or whiff) arms the
## RAM_COOLDOWN: he returns to the track, answers crowding with lead, and
## only when it expires does the pursuit resume — the counterable rhythm.
func _phase2_intent(vehicle, player: Node2D) -> Dictionary:
	if _mode == Mode.CHARGE:
		var colliders := _slide_colliders(vehicle)
		var victim := _charge_hit_car(colliders)
		if victim != null:
			_strike(vehicle, victim)
			_enter_retreat(vehicle)
		elif _charge_hit_scenery(colliders):
			_self_stun(vehicle)
			_enter_retreat(vehicle)
		elif _timer > 0.0:
			vehicle.velocity = _charge_dir * CHARGE_SPEED
			vehicle.heading = _charge_dir.angle()
			return {}
		else:
			_mode = Mode.LOOP  # open-air whiff: the cooldown owns what's next
	if _mode == Mode.RETREAT:
		if _timer > 0.0:
			var intent := _loop_intent(vehicle)
			intent["throttle"] = RETREAT_THROTTLE
			return intent
		_mode = Mode.LOOP
	if _ram_cd > 0.0:
		# The breather lap: hold the ring; a crowding player draws fire, never
		# steel. The next charge is earned by the clock, not proximity.
		_mode = Mode.LOOP
		if player != null:
			var to_c: Vector2 = player.global_position - vehicle.global_position
			if to_c.length() < APPROACH_TRIGGER:
				var aim := angle_difference(vehicle.heading, to_c.angle())
				return _cap_steer({
					"throttle": HARASS_THROTTLE,
					"steer": clampf(aim * LOOP_STEER_GAIN, -1.0, 1.0),
					"fire_mg": absf(aim) < PARTING_FIRE_CONE,
				})
		return _cap_steer(_loop_intent(vehicle))
	if _mode != Mode.LINE_UP:
		_enter_lineup()  # cooldown clear (or fresh out of phase 1): square up
	if player == null:
		return _cap_steer(_loop_intent(vehicle))
	var to_p: Vector2 = player.global_position - vehicle.global_position
	var diff := angle_difference(vehicle.heading, to_p.angle())
	if _timer <= 0.0 and absf(diff) < CHARGE_ALIGN and to_p.length() < CHARGE_MAX_DIST:
		_mode = Mode.CHARGE
		_timer = CHARGE_TIME
		_ram_cd = RAM_COOLDOWN  # the attempt itself starts the clock
		_charge_dir = Vector2.RIGHT.rotated(vehicle.heading)  # commit: dead straight
		vehicle.velocity = _charge_dir * CHARGE_SPEED
		vehicle.heading = _charge_dir.angle()
		_ram_cue(vehicle)  # the tell: stacks belch, the horn hits
		return {}
	return _cap_steer({
		"throttle": 0.85,
		"steer": clampf(diff * LOOP_STEER_GAIN, -1.0, 1.0),
		"fire_mg": absf(diff) < RAM_FIRE_CONE,
	})

## Phase-2 steering never exceeds the bobtail cap: sixty feet of Detroit
## steel turns on speed and room, not a wrist flick.
func _cap_steer(intent: Dictionary) -> Dictionary:
	intent["steer"] = clampf(float(intent.get("steer", 0.0)),
		-BOBTAIL_STEER_CAP, BOBTAIL_STEER_CAP)
	return intent

## The commit tell: both exhaust stacks belch dark diesel and the ram_warn
## event fires positionally — paired with the tightened CHARGE_MAX_DIST so
## it happens where the player can see it.
func _ram_cue(vehicle) -> void:
	var audio: Node = vehicle.get_node_or_null(^"/root/AudioDirector")
	if audio and audio.has_method(&"play_at"):
		audio.play_at(&"ram_warn", vehicle.global_position)
	var visual: Node = vehicle.get_node_or_null(^"Visual")
	if visual == null:
		return
	for off in [Vector2(-10, -17.5), Vector2(-10, 17.5)]:  # stacks × fleet scale
		var smoke := CPUParticles2D.new()
		smoke.amount = 26
		smoke.lifetime = 0.6
		smoke.one_shot = true
		smoke.explosiveness = 0.8
		smoke.local_coords = false  # the belch hangs where it happened
		smoke.direction = Vector2(-1, 0)
		smoke.spread = 30.0
		smoke.initial_velocity_min = 80.0
		smoke.initial_velocity_max = 180.0
		smoke.scale_amount_min = 2.0
		smoke.scale_amount_max = 4.0
		smoke.gravity = Vector2.ZERO
		smoke.color = Color(0.18, 0.17, 0.16, 0.85)
		smoke.position = off as Vector2
		visual.add_child(smoke)
		smoke.emitting = true
		smoke.finished.connect(smoke.queue_free)

func _enter_lineup() -> void:
	_mode = Mode.LINE_UP
	_timer = CHARGE_WINDUP

func _enter_retreat(vehicle) -> void:
	_mode = Mode.RETREAT
	_timer = RETREAT_TIME
	_idx = _nearest_idx(vehicle)  # the ring IS the back-off route

## The connect: the ram loop already billed the collision damage — this adds
## the semi treatment (fling, spin, dead stick) on top.
func _strike(vehicle, victim: Node) -> void:
	if victim.has_method(&"apply_impact"):
		victim.apply_impact(vehicle.global_position, 0.0,
			CHARGE_HIT_KNOCKBACK, CHARGE_HIT_SPIN, CHARGE_HIT_STUN)

## The bait window: a charge that found scenery instead of a car bills the
## boss pool and sits him down — hit him while the stars circle.
func _self_stun(vehicle) -> void:
	var health = vehicle.get_node_or_null(^"Health")
	if health and health.has_method(&"take_damage"):
		health.take_damage(CHARGE_SELF_DMG)
	if vehicle.has_method(&"apply_effect"):
		var spec := StatusEffectSpec.new()
		spec.kind = &"stun"
		spec.duration = CHARGE_STUN
		vehicle.apply_effect(spec)

## Last frame's move_and_slide contacts (the dash-read idiom: one frame late,
## no vehicle.gd changes needed). Bare fixtures without the API read empty.
func _slide_colliders(vehicle) -> Array:
	var out: Array = []
	if not vehicle.has_method(&"get_slide_collision_count"):
		return out
	for i in vehicle.get_slide_collision_count():
		var col = vehicle.get_slide_collision(i)
		if col:
			out.append(col.get_collider())
	return out

func _charge_hit_car(colliders: Array) -> Node:
	for c in colliders:
		if c != null and c is CharacterBody2D and c.has_method(&"apply_impact"):
			return c
	return null

func _charge_hit_scenery(colliders: Array) -> bool:
	for c in colliders:
		if c != null and not (c is CharacterBody2D):
			return true
	return false

## Front arc gets the grille; everyone else gets the tail — IF the tail is
## earned: off cooldown and back up to speed. A slow or spent rig holds its
## course and accelerates instead (the loop builds the next swing's momentum).
func _react(vehicle, player: Node2D) -> void:
	var to_p: Vector2 = player.global_position - vehicle.global_position
	if absf(angle_difference(vehicle.heading, to_p.angle())) < RAM_FRONT_ARC:
		_mode = Mode.RAM
		_timer = RAM_TIME
	elif _jk_cd <= 0.0 and _real_speed(vehicle) >= JACKKNIFE_MIN_SPEED:
		_mode = Mode.JACKKNIFE
		_timer = JACKKNIFE_TIME
		_jk_cd = JACKKNIFE_COOLDOWN
		var fwd := Vector2.RIGHT.rotated(vehicle.heading)
		_jk_steer = -signf(fwd.cross(to_p)) * JACKKNIFE_STEER
		if _jk_steer == 0.0:
			_jk_steer = JACKKNIFE_STEER

func _real_speed(vehicle) -> float:
	if vehicle.has_method(&"get_real_velocity"):
		return vehicle.get_real_velocity().length()
	return 0.0

func _enter_parting() -> void:
	_mode = Mode.PARTING
	_timer = PARTING_SHOT_TIME

## The whip-crack, NOT a U-turn: a quick out / snap-back / straighten sway —
## the cab roughly holds its line while the trailer loads up one way and
## cracks back across the other. The strike is still the trailer's physics.
func _sway_steer() -> float:
	var t := 1.0 - clampf(_timer / JACKKNIFE_TIME, 0.0, 1.0)
	if t < JACKKNIFE_SWAY_OUT:
		return _jk_steer      # wind-up: load the tail away from them
	if t < JACKKNIFE_SWAY_BACK:
		return -_jk_steer     # the crack: whip it back across
	return 0.0                # straighten and let the assist settle it

func _hunt_intent(vehicle, player: Node2D) -> Dictionary:
	if player == null:
		return _loop_intent(vehicle)
	var diff := angle_difference(vehicle.heading,
		(player.global_position - vehicle.global_position).angle())
	return {
		"throttle": 1.0,
		"steer": clampf(diff * LOOP_STEER_GAIN, -1.0, 1.0),
		"boost": true,
		"fire_mg": absf(diff) < RAM_FIRE_CONE,
	}

func _parting_intent(vehicle, player: Node2D) -> Dictionary:
	if player == null:
		return {"throttle": 0.3, "steer": 0.0}
	var diff := angle_difference(vehicle.heading,
		(player.global_position - vehicle.global_position).angle())
	return {
		"throttle": 0.35,
		"steer": clampf(diff * LOOP_STEER_GAIN, -1.0, 1.0),
		"fire_mg": absf(diff) < PARTING_FIRE_CONE,
	}

func _loop_intent(vehicle) -> Dictionary:
	var own: Vector2 = vehicle.global_position
	if own.distance_to(_points[_idx]) < LOOP_ARRIVE:
		_idx = (_idx + 1) % _points.size()
	var want := (_points[_idx] - own).angle()
	return {
		"throttle": LOOP_THROTTLE,
		"steer": clampf(angle_difference(vehicle.heading, want) * LOOP_STEER_GAIN, -1.0, 1.0),
		"fire_mg": false,
		"fire_selected": false,
	}

## The big-rig unstick: wedged cars fake velocity, so the trip reads REAL
## displacement (enemy_driver's lesson). Commit a reverse swing, then rejoin.
## Charges and stuns are exempt — one is deliberately fast, the other is
## deliberately parked (the bait window must never turn into a reverse-out).
func _update_stuck(vehicle, delta: float) -> void:
	if _mode == Mode.RECOVER or _mode == Mode.CHARGE \
			or not vehicle.has_method(&"get_real_velocity"):
		return
	var status = vehicle.get_node_or_null(^"Status")
	if status and status.has_method(&"is_stunned") and status.is_stunned():
		_stuck_t = 0.0
		return
	var real: Vector2 = vehicle.get_real_velocity()
	_stuck_t = _stuck_t + delta if real.length() < STUCK_SPEED else 0.0
	if _stuck_t >= STUCK_TRIP:
		_stuck_t = 0.0
		_mode = Mode.RECOVER
		_timer = RECOVER_REVERSE_TIME
		_rev_steer = 1.0 if randf() < 0.5 else -1.0

func _rejoin(vehicle) -> void:
	_mode = Mode.LOOP
	_idx = _nearest_idx(vehicle)

## The ring is a plain container of Marker2Ds beside the vehicles (no groups —
## the loop belongs to this one level). Join at the nearest point so a corner
## spawn merges onto the track instead of cutting across the field.
func _gather_loop(vehicle) -> void:
	var root: Node = vehicle.get_parent()
	if root == null:
		return
	var ring := root.get_node_or_null(^"GoliathLoop")
	if ring == null:
		return
	var pts := PackedVector2Array()
	for child in ring.get_children():
		if child is Node2D:
			pts.append((child as Node2D).global_position)
	if pts.is_empty():
		return
	_points = pts
	_idx = _nearest_idx(vehicle)

func _nearest_idx(vehicle) -> int:
	var best := 0
	var best_d := INF
	var own: Vector2 = vehicle.global_position
	for i in _points.size():
		var d := own.distance_squared_to(_points[i])
		if d < best_d:
			best_d = d
			best = i
	return best

func _phase() -> int:
	return int(_boss.phase) if _boss != null else 1
