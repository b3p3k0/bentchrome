extends Node
## The Buzzard wave director: a 120-second pressure arc cut into short beats.
## Phases set the live cap, spawn cadence, class mix, and the pack's PACE — a
## fraction of the player's own top speed, so every ride feels the same
## squeeze. Two short breaths, then the pace climbs to 1.0 for the last mile
## while the spawns keep coming. Deaths bump the host's kill tally.

const BuzzardScene := preload("res://levels/chase/buzzard.tscn")
const TumbleScript := preload("res://levels/chase/death_tumble.gd")
const BikeStats := preload("res://data/vehicles/buzz_bike.tres")
const SedanStats := preload("res://data/vehicles/buzz_sedan.tres")
const TechnicalStats := preload("res://data/vehicles/buzz_technical.tres")

## The pressure arc. t = phase start (host clock seconds); pace = the pack's
## cruise as a fraction of the player's top speed (horde_wall.pack_speed).
## Green flag / first blood / breath / squeeze / breath / frenzy / all in /
## last mile — the finale keeps its weights: the spawns never stop.
static var PHASES := [
	{"t": 0.0,   "cap": 2, "interval": 4.0, "weights": {&"bike": 1.0},                "pace": 0.80},
	{"t": 8.0,   "cap": 4, "interval": 3.5, "weights": {&"bike": 0.7, &"sedan": 0.3}, "pace": 0.86},
	{"t": 25.0,  "cap": 3, "interval": 5.0, "weights": {&"bike": 1.0},                "pace": 0.84},
	{"t": 32.0,  "cap": 6, "interval": 3.0, "weights": {&"bike": 0.35, &"sedan": 0.35, &"technical": 0.15, &"blocker": 0.15}, "pace": 0.90},
	{"t": 55.0,  "cap": 4, "interval": 4.5, "weights": {&"sedan": 0.6, &"technical": 0.2, &"blocker": 0.2},                  "pace": 0.88},
	{"t": 62.0,  "cap": 8, "interval": 2.6, "weights": {&"bike": 0.35, &"sedan": 0.35, &"technical": 0.15, &"blocker": 0.15}, "pace": 0.96},
	{"t": 90.0,  "cap": 8, "interval": 2.2, "weights": {&"bike": 0.35, &"sedan": 0.35, &"technical": 0.15, &"blocker": 0.15}, "pace": 1.00},
	{"t": 110.0, "cap": 8, "interval": 2.0, "weights": {&"bike": 0.45, &"sedan": 0.30, &"technical": 0.10, &"blocker": 0.15}, "pace": 1.02},
]

static var EMERGE_DEPTH := 90.0     # px inside the dust crest where pursuers are born
static var ABSORB_DEPTH := 180.0    # px inside the crest where the pack takes one back
static var SPAWN_BEHIND := 1100.0   # wall-less fallback (bare fixtures): px behind the player
static var SPAWN_AHEAD := 1600.0    # technicals roll in from up the road
static var CULL_BEHIND := 2600.0    # wall-less fallback: matches the streamer's free line

## Per-class spawn tuning: StatCurves HP × hp_scale ⇒ bike ~14, sedan ~25,
## technical ~58, blocker ~48. The harassers are GLASS on purpose — a bike
## dies to one Homing Missile (15) or a half-second MG burst, a sedan to one
## Fire Missile (26): the sortie puts them in front of your guns, and
## getting the shot is the payoff. ahead = enters from the top of the screen
## and falls back through the field (the technical shoots, the blocker
## steals your lane); everyone else boils up out of the dust bank.
static var CLASS_TABLE := {
	&"bike": {"stats": null, "hp_scale": 0.2, "ahead": false},
	&"sedan": {"stats": null, "hp_scale": 0.32, "ahead": false},
	&"technical": {"stats": null, "hp_scale": 0.6, "ahead": true},
	&"blocker": {"stats": null, "hp_scale": 0.6, "ahead": true, "tint": Color(0.78, 0.46, 0.1)},
}

## What a Buzzard's engine is worth, as a fraction of the PLAYER'S top speed —
## the pack is priced against the ride it chases, like the dust front. Bikes
## and sedans can always catch an honest car; a boost (1.5x) always shakes
## them; ahead-spawns are slow by design and fall back through the field.
## The .tres top_speed stats still shape acceleration and the garage card;
## this overrides the ceiling at spawn.
static var ROLE_PACE := {&"bike": 1.10, &"sedan": 1.04, &"technical": 0.62, &"blocker": 0.72}
## Shoot -> boost -> breathe: every Buzzard you WRECK siphons this much nitro
## into the tank (of 100; 5/s burn, so a kill is ~0.8s of boost — the birds
## are glass now, and a good run wrecks ten of them). Combat feeds the
## escape. Absorbed stragglers pay nothing — outrunning isn't killing.
static var KILL_NITRO := 4.0
const SpeedBand := preload("res://levels/chase/speed_band.gd")

var host = null            # buzzard_run host: clock, course, kills
var target: Node2D = null  # the player
var wall = null            # horde_wall: the phase pace lands here
var frozen := false        # finale/win: stop directing, let the field play out

var rng := RandomNumberGenerator.new()
var _spawn_cd := 3.0       # first contact a breath after launch
var _cull_t := 0.25
var _lane_flip := 1.0

func _ready() -> void:
	rng.randomize()
	CLASS_TABLE[&"bike"]["stats"] = BikeStats
	CLASS_TABLE[&"sedan"]["stats"] = SedanStats
	CLASS_TABLE[&"technical"]["stats"] = TechnicalStats
	CLASS_TABLE[&"blocker"]["stats"] = SedanStats  # a beater with a different job

static func phase_at(t: float) -> Dictionary:
	var current: Dictionary = PHASES[0]
	for ph in PHASES:
		if t >= ph["t"]:
			current = ph
	return current

func _physics_process(delta: float) -> void:
	if frozen or host == null or target == null or not is_instance_valid(target):
		return
	var ph := phase_at(host.clock)
	if wall != null:
		wall.pace_frac = ph["pace"]
	_cull_t -= delta
	if _cull_t <= 0.0:
		_cull_t = 0.25
		_absorb()
	_spawn_cd -= delta
	if _spawn_cd <= 0.0:
		_spawn_cd = ph["interval"]
		var weights: Dictionary = ph["weights"]
		var live := get_tree().get_nodes_in_group(&"enemies").size()
		if live < int(ph["cap"]) and not weights.is_empty():
			spawn(_roll_kind(weights))

func _roll_kind(weights: Dictionary) -> StringName:
	var total := 0.0
	for kind in weights:
		total += weights[kind]
	var roll := rng.randf() * total
	for kind in weights:
		roll -= weights[kind]
		if roll <= 0.0:
			return kind
	return weights.keys()[0]

## The runtime spawn recipe (LevelLoader precedent): stats and driver exports
## land BEFORE add_child; _ready wires groups/paint/HP from there.
func spawn(kind: StringName) -> Node:
	var row: Dictionary = CLASS_TABLE[kind]
	var b = BuzzardScene.instantiate()
	var stats: VehicleStats = row["stats"].duplicate()
	# Tatty pack palette: every Buzzard wears its own shade of neglect.
	var rust := stats.primary_color
	stats.primary_color = rust.lerp(Color(0.42, 0.4, 0.38), rng.randf_range(0.0, 0.55)) \
		.darkened(rng.randf_range(0.0, 0.2))
	stats.accent_color = stats.accent_color.darkened(rng.randf_range(0.0, 0.3))
	if row.has("tint"):  # a class that must be told apart at a glance wears its colour
		stats.primary_color = (row["tint"] as Color).darkened(rng.randf_range(0.0, 0.15))
	b.stats = stats
	b.hp_scale = row["hp_scale"]
	b.weapon_lock_exempt = true  # chase pacing lives in chase_driver, not the bay lock
	var driver = b.get_node(^"Driver")
	driver.role = kind
	driver.lane_offset = _lane_flip * rng.randf_range(80.0, 240.0)
	_lane_flip = -_lane_flip
	driver.phase = rng.randf_range(0.0, 6.0)
	var ahead: bool = row.get("ahead", false)
	var spawn_y: float = target.global_position.y - SPAWN_AHEAD if ahead else _emerge_y()
	var road_x := 0.0
	var half := 300.0
	if host != null and host.course != null:
		var s: Dictionary = host.course.sample(-spawn_y)
		road_x = s["x"]
		half = s["half_w"]
	# Ahead-spawns hug a lane edge — never a dead-center surprise at 600 px/s.
	var x_range := Vector2(-half + 90.0, half - 90.0)
	var spawn_x: float = road_x + (signf(driver.lane_offset) * (half - 130.0) if ahead \
		else rng.randf_range(x_range.x, x_range.y))
	b.global_position = Vector2(spawn_x, spawn_y)
	var entry_speed: float = target.velocity.length() * 0.4 if ahead \
		else target.velocity.length() + 60.0
	b.velocity = Vector2(0.0, -entry_speed)  # pace-matched entry
	var health = b.get_node(^"Health")
	health.died.connect(func() -> void:
		if host == null or not is_instance_valid(host):
			return
		host.kills += 1
		# Buzzard bounty: chase kills pay the small rate (Economy's valve keeps
		# non-campaign lanes free; attribution rides the tally — chase combat
		# is player-vs-horde by construction).
		preload("res://game/economy.gd").award_kill(&"chase")
		_siphon_nitro()
		if is_instance_valid(b):
			_tumble(b))
	host.add_child(b)
	# _ready applied the stat curves; now the ceiling is re-priced against the
	# chased car (before the first tick, so the driver's yo-yo captures it).
	if b.has_method(&"get_controller") and b.get_controller() != null:
		b.get_controller().max_speed = _player_top() * float(ROLE_PACE.get(kind, 1.0))
	return b

## The chased car's honest top speed on asphalt — the same number the dust
## front prices itself against.
func _player_top() -> float:
	return SpeedBand.road_top(target)

## A wreck's nitro goes into the player's tank, capped at full.
func _siphon_nitro() -> void:
	if target == null or not is_instance_valid(target) or not target.has_method(&"get_controller"):
		return
	var ctrl = target.get_controller()
	if ctrl != null and "boost_fuel" in ctrl:
		ctrl.boost_fuel = minf(ctrl.boost_fuel + KILL_NITRO, 100.0)

## The kill read: a dark hull spinning off with the wreck's momentum while the
## explosion pops. Director-side — arenas keep their untouched death path.
func _tumble(b: Node) -> void:
	if host == null or not is_instance_valid(host):
		return
	var hull := Vector2(30.0, 16.0)
	var paint = b.get_node_or_null(^"Visual/Body")
	if paint != null and paint.has_method(&"metrics"):
		var m: Dictionary = paint.metrics()
		hull = Vector2(m["half_len"], m["half_wid"])
	var tint := Color(0.4, 0.32, 0.25)
	var stats = b.get("stats")
	if stats != null:
		tint = stats.primary_color
	var tumble := TumbleScript.new()
	tumble.z_index = 1
	host.add_child(tumble)
	tumble.setup(b.global_position, b.velocity * 0.7, hull, tint)

## The run is over (caught, wrecked, or won): no more spawns, no more
## absorbing, and every live Buzzard comes off the trigger — they have what
## they came for. Nobody respawns on Route 666, so this never lifts.
func stand_down() -> void:
	frozen = true
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		var driver = enemy.get_node_or_null(^"Driver")
		if driver != null and "hold_fire" in driver:
			driver.hold_fire = true

## Where a pursuer is born: just inside the dust crest, so it boils up out of
## the pack in plain sight instead of arriving from nowhere.
func _emerge_y() -> float:
	if wall != null and is_instance_valid(wall):
		return wall.front_y + EMERGE_DEPTH
	return target.global_position.y + SPAWN_BEHIND

## The line a straggler crosses to be taken back by the pack.
func _absorb_y() -> float:
	if wall != null and is_instance_valid(wall):
		return wall.front_y + ABSORB_DEPTH
	return target.global_position.y + CULL_BEHIND

## Outrun a Buzzard and it fades back into the dust: freed quietly, no wreck,
## no bounty, no bell — the kill tally only counts what you actually killed.
func _absorb() -> void:
	var line := _absorb_y()
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy is Node2D and enemy.global_position.y > line:
			enemy.queue_free()
