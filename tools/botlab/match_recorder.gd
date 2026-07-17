extends Node
## Botlab telemetry recorder. Mounted in the arena by botlab_probe.gd; never
## part of a shipped scene. Connects each registered car's Health signals,
## arms and drains the NetEvents tap for shots-fired counting, and polls
## per-frame movement/heat/boost state. All timing is PHYSICS FRAMES, never
## Time.get_ticks_msec() — under --fixed-fps the wall clock lies.
##
## Attribution mirrors MatchDirector: a kill belongs to last_attacker only if
## the attacker's most recent stamped hit landed within ATTRIB_FRAMES (600 =
## 10 sim-seconds). Burn DoT is credited to the igniter but does NOT refresh
## the window — same as the shipped rules. Damage kind rides the bc_hit_kind
## meta breadcrumb (consumed and erased per event); unstamped damage is
## classified burn (active burn status) or environment (pit, fall, kill()).

const NetEvents := preload("res://game/net/net_events.gd")

const ATTRIB_FRAMES := 600      # 10 s at 60 ticks — mirrors ATTRIBUTION_MS
const HP_SAMPLE_EVERY := 30     # half-second HP timeline
const STATIONARY_SPEED := 30.0  # px/s — below this a frame counts as parked

var frame := 0
var first_blood := ""           # label of the first car to die (empty = none)
var kill_order: Array = []      # labels in death order

# One record per registered car, keyed by instance id. Cars queue_free on
# death, so everything a dead car contributed lives HERE, snapshotted at the
# synchronous died edge.
var _cars: Dictionary = {}
# shot_id -> shooter instance id (from the NetEvents projectile entries), so
# terminal wall impacts can be billed to their shooter.
var _shot_shooter: Dictionary = {}
var _was_armed := false

func _ready() -> void:
	_was_armed = NetEvents.armed
	NetEvents.armed = true

func _exit_tree() -> void:
	NetEvents.armed = _was_armed
	NetEvents.queue.clear()
	NetEvents.fx.clear()

## Probe calls this once per spawned car, after add_child. `label` is the
## unique entrant name (car id, suffixed on collision); `driver` describes who
## is at the wheel ("stock" or a bot script path).
func register_car(car: Node2D, label: String, car_id: String, driver: String) -> void:
	var rec := {
		"label": label,
		"car_id": car_id,
		"driver": driver,
		"node": car,
		"alive": true,
		"frames_alive": 0,
		"kills": 0,
		"killed_by": "",
		"death_cause": "",
		"damage_dealt": {},     # kind -> total
		"damage_taken": {},     # kind -> total
		"dealt_to": {},         # victim label -> total (pair matrix row)
		"shots_fired": 0,
		"vehicle_hits": 0,      # mg/weapon damage events authored on a car
		"terminal_impacts": 0,  # every terminal impact — vehicles AND scenery
		"engage_range_sum": 0.0,  # damage-weighted attacker<->victim distance
		"engage_range_weight": 0.0,
		"stationary_frames": 0,
		"distance": 0.0,
		"boost_frames": 0,
		"boost_fuel_spent": 0.0,
		"heal_gained": 0.0,
		"pickups": 0,
		"special_casts": 0,
		"secondary_shots": 0,
		"mg_lockouts": 0,
		"hp_timeline": [],
		# internals
		"_pos": car.global_position,
		"_hp": _hp_of(car),
		"_max_hp": _max_hp_of(car),
		"_attrib_frame": -ATTRIB_FRAMES,  # frame of the last stamped hit taken
		"_ammo": {},
		"_mg_locked": false,
		"_boost_fuel": 100.0,
	}
	_cars[car.get_instance_id()] = rec
	var health: Health = car.get_node_or_null(^"Health")
	if health:
		health.damaged.connect(_on_damaged.bind(car))
		health.died.connect(_on_died.bind(car))
	var rack = car.get_node_or_null(^"WeaponRack")
	if rack:
		for i in 7:
			rec._ammo[i] = rack.ammo(i)
		rack.ammo_changed.connect(_on_ammo_changed.bind(car))
	var ctrl = car.get_node_or_null(^"DrivingController")
	if ctrl:
		rec._boost_fuel = ctrl.boost_fuel

func alive_count() -> int:
	var n := 0
	for rec in _cars.values():
		if rec.alive:
			n += 1
	return n

func alive_labels() -> Array:
	var out: Array = []
	for rec in _cars.values():
		if rec.alive:
			out.append(rec.label)
	return out

# ------------------------------------------------------------------ events

func _on_damaged(amount: float, hp: float, car: Node2D) -> void:
	var rec: Dictionary = _cars.get(car.get_instance_id(), {})
	if rec.is_empty():
		return
	var kind := _consume_kind(car)
	var attacker := _live_attacker(car)
	if kind != "":
		# A stamped hit landed this exact call — refresh the attribution window.
		rec._attrib_frame = frame
	if kind in ["mg", "weapon"]:
		var arec := _rec_of(attacker)
		if not arec.is_empty():
			arec.vehicle_hits += 1
	var final_kind := kind if kind != "" else _infer_kind(car, attacker)
	rec._last_taken_kind = final_kind
	_bucket(rec.damage_taken, final_kind, amount)
	if attacker != null and is_instance_valid(attacker) and attacker != car:
		var arec := _rec_of(attacker)
		if not arec.is_empty():
			_bucket(arec.damage_dealt, final_kind, amount)
			_bucket(arec.dealt_to, rec.label, amount)
			var d: float = attacker.global_position.distance_to(car.global_position)
			arec.engage_range_sum += d * amount
			arec.engage_range_weight += amount
	rec._hp = hp

func _on_died(car: Node2D) -> void:
	var rec: Dictionary = _cars.get(car.get_instance_id(), {})
	if rec.is_empty() or not rec.alive:
		return
	rec.alive = false
	rec.frames_alive = frame
	rec.node = null  # the vehicle frees itself — never touch it again
	# take_damage deaths emit damaged(amount, 0) first, so _hp is already 0 and
	# the last taken kind IS the killing blow. kill() deaths (pit, deep water)
	# skip damaged entirely, leaving _hp > 0 — those are environmental.
	rec.death_cause = String(rec.get("_last_taken_kind", "environment")) \
		if rec._hp <= 0.0 else "environment"
	var attacker := _live_attacker(car)
	var fresh: bool = frame - int(rec._attrib_frame) <= ATTRIB_FRAMES
	if attacker != null and is_instance_valid(attacker) and attacker != car and fresh:
		var arec := _rec_of(attacker)
		if not arec.is_empty():
			arec.kills += 1
			rec.killed_by = arec.label
		else:
			rec.killed_by = "world"
	else:
		rec.killed_by = "wasteland"
	if first_blood == "":
		first_blood = rec.label
	kill_order.append(rec.label)

func _on_ammo_changed(index: int, ammo: int, car: Node2D) -> void:
	var rec: Dictionary = _cars.get(car.get_instance_id(), {})
	if rec.is_empty() or not rec.alive:
		return
	var prev := int(rec._ammo.get(index, ammo))
	rec._ammo[index] = ammo
	if index == 0:
		# Slot 0 is the SPECIAL: rises are recharge ticks (not scavenging).
		if ammo < prev:
			rec.special_casts += 1
	elif ammo > prev:
		rec.pickups += 1  # crate grab
	else:
		rec.secondary_shots += 1

# ------------------------------------------------------------------ polling

func _physics_process(_delta: float) -> void:
	frame += 1
	_drain_net_events()
	for rec in _cars.values():
		if not rec.alive:
			continue
		var car: Node2D = rec.node
		if car == null or not is_instance_valid(car):
			continue
		rec.distance += car.global_position.distance_to(rec._pos)
		rec._pos = car.global_position
		if car.get_speed() < STATIONARY_SPEED:
			rec.stationary_frames += 1
		var ctrl = car.get_node_or_null(^"DrivingController")
		if ctrl:
			if ctrl.boosting:
				rec.boost_frames += 1
			if ctrl.boost_fuel < rec._boost_fuel:
				rec.boost_fuel_spent += rec._boost_fuel - ctrl.boost_fuel
			rec._boost_fuel = ctrl.boost_fuel
		var mg = car.get_node_or_null(^"MachineGunMount")
		if mg:
			var locked: bool = mg.is_locked()
			if locked and not rec._mg_locked:
				rec.mg_lockouts += 1
			rec._mg_locked = locked
		var hp := _hp_of(car)
		if hp > rec._hp:
			rec.heal_gained += hp - rec._hp
		rec._hp = hp
		if frame % HP_SAMPLE_EVERY == 0:
			rec.hp_timeline.append(snappedf(hp / maxf(rec._max_hp, 1.0), 0.001))

func _drain_net_events() -> void:
	for ev in NetEvents.queue:
		match ev.get("kind"):
			&"projectile":
				# Variant read: the shooter can die between firing and this
				# drain, leaving a freed instance in the queued event — a typed
				# Node assignment is a script error. Its round already deals 0
				# (Combat.scale posthumous rule), so the shot goes uncounted.
				var shooter: Variant = ev.get("shooter")
				if is_instance_valid(shooter) and shooter is Node2D:
					var arec := _rec_of(shooter)
					if not arec.is_empty():
						arec.shots_fired += 1
						_shot_shooter[ev.shot_id] = (shooter as Node2D).get_instance_id()
			&"impact":
				if ev.get("terminal", false) and _shot_shooter.has(ev.shot_id):
					var arec: Dictionary = _cars.get(_shot_shooter[ev.shot_id], {})
					if not arec.is_empty():
						arec.terminal_impacts += 1
					_shot_shooter.erase(ev.shot_id)
	NetEvents.queue.clear()
	NetEvents.fx.clear()

# ------------------------------------------------------------------ output

func to_dict() -> Dictionary:
	var cars: Array = []
	for rec in _cars.values():
		var shots := int(rec.shots_fired)
		cars.append({
			"label": rec.label,
			"car": rec.car_id,
			"driver": rec.driver,
			"alive": rec.alive,
			"frames_alive": rec.frames_alive if not rec.alive else frame,
			"hp_frac": snappedf(rec._hp / maxf(rec._max_hp, 1.0), 0.001),
			"kills": rec.kills,
			"killed_by": rec.killed_by,
			"death_cause": rec.death_cause,
			"damage_dealt": _rounded(rec.damage_dealt),
			"damage_taken": _rounded(rec.damage_taken),
			"dealt_to": _rounded(rec.dealt_to),
			"shots_fired": shots,
			"vehicle_hits": rec.vehicle_hits,
			# Terminal impacts include vehicle hits; the remainder ate scenery.
			# shots - terminal_impacts = clean whiffs (lifetime despawns).
			"wall_hits": maxi(int(rec.terminal_impacts) - int(rec.vehicle_hits), 0),
			"accuracy": snappedf(float(rec.vehicle_hits) / shots, 0.001) if shots > 0 else 0.0,
			"avg_engage_range": snappedf(rec.engage_range_sum / rec.engage_range_weight, 0.1) \
				if rec.engage_range_weight > 0.0 else 0.0,
			"stationary_frames": rec.stationary_frames,
			"distance": snappedf(rec.distance, 0.1),
			"boost_frames": rec.boost_frames,
			"boost_fuel_spent": snappedf(rec.boost_fuel_spent, 0.1),
			"heal_gained": snappedf(rec.heal_gained, 0.1),
			"pickups": rec.pickups,
			"special_casts": rec.special_casts,
			"secondary_shots": rec.secondary_shots,
			"mg_lockouts": rec.mg_lockouts,
			"hp_timeline": rec.hp_timeline,
		})
	return {
		"frames": frame,
		"first_blood": first_blood,
		"kill_order": kill_order,
		"cars": cars,
	}

# ------------------------------------------------------------------ helpers

func _rec_of(node: Node) -> Dictionary:
	if node == null or not is_instance_valid(node):
		return {}
	return _cars.get(node.get_instance_id(), {})

## Variant-safe last_attacker read: a freed killer leaves the property
## dangling, and assigning that straight to a typed Node2D is a script error
## (the same trap enemy_driver's grudge read documents).
func _live_attacker(car: Node2D) -> Node2D:
	var v: Variant = car.get("last_attacker")
	if v != null and is_instance_valid(v) and v is Node2D:
		return v
	return null

## Reads and erases the damage-kind breadcrumb the hit site stamped just
## before take_damage. Empty string = no stamp landed this event.
func _consume_kind(car: Node2D) -> String:
	if not car.has_meta(&"bc_hit_kind"):
		return ""
	var raw := String(car.get_meta(&"bc_hit_kind"))
	car.remove_meta(&"bc_hit_kind")
	match raw:
		"hit_mg":
			return "mg"
		"hit_weapon":
			return "weapon"
		_:
			return raw

## Unstamped damage: an active burn is the igniter's DoT; anything else is the
## world (fall damage, pits, deep water — kill() paths never emit damaged, but
## the death-cause fallback also lands here via _last_taken_kind staying empty).
func _infer_kind(car: Node2D, attacker: Node2D) -> String:
	var status = car.get_node_or_null(^"Status")
	if status and status.has_effect(&"burn") and attacker != null and is_instance_valid(attacker):
		return "burn"
	return "environment"

func _bucket(dict: Dictionary, key: String, amount: float) -> void:
	dict[key] = float(dict.get(key, 0.0)) + amount

func _rounded(dict: Dictionary) -> Dictionary:
	var out := {}
	for k in dict:
		out[k] = snappedf(float(dict[k]), 0.1)
	return out

func _hp_of(car: Node2D) -> float:
	var h: Health = car.get_node_or_null(^"Health")
	return h.hp if h else 0.0

func _max_hp_of(car: Node2D) -> float:
	var h: Health = car.get_node_or_null(^"Health")
	return h.max_hp if h else 1.0
