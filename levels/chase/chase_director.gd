extends Node
## The Buzzard wave director: a 180-second pressure arc. Phases set the live
## cap, spawn cadence, class mix, and the horde wall's cruise speed — warm-up,
## waves, two breathers, a crescendo, and a finale sprint where the spawns
## stop and the wall surges. Spawns arrive pace-matched just off-screen
## behind; stragglers cull far south. Deaths bump the host's kill tally.

const BuzzardScene := preload("res://levels/chase/buzzard.tscn")
const TumbleScript := preload("res://levels/chase/death_tumble.gd")
const BikeStats := preload("res://data/vehicles/buzz_bike.tres")
const SedanStats := preload("res://data/vehicles/buzz_sedan.tres")
const TechnicalStats := preload("res://data/vehicles/buzz_technical.tres")

## The pressure arc. t = phase start (host clock seconds).
static var PHASES := [
	{"t": 0.0,   "cap": 2, "interval": 5.0, "weights": {&"bike": 1.0},                "wall": 300.0},
	{"t": 15.0,  "cap": 4, "interval": 4.0, "weights": {&"bike": 0.7, &"sedan": 0.3}, "wall": 330.0},
	{"t": 50.0,  "cap": 3, "interval": 6.0, "weights": {&"bike": 1.0},                "wall": 320.0},
	{"t": 65.0,  "cap": 6, "interval": 3.5, "weights": {&"bike": 0.4, &"sedan": 0.4, &"technical": 0.2}, "wall": 350.0},
	{"t": 110.0, "cap": 4, "interval": 5.0, "weights": {&"sedan": 0.7, &"technical": 0.3},              "wall": 340.0},
	{"t": 125.0, "cap": 8, "interval": 2.8, "weights": {&"bike": 0.4, &"sedan": 0.4, &"technical": 0.2}, "wall": 380.0},
	{"t": 168.0, "cap": 8, "interval": 999.0, "weights": {},                          "wall": 420.0},
]

static var SPAWN_BEHIND := 1100.0   # off-screen even at the 0.42 overview zoom
static var SPAWN_AHEAD := 1600.0    # technicals roll in from up the road
static var CULL_BEHIND := 2600.0    # matches the streamer's free line
static var RESPAWN_GRACE := 2.5     # seconds of held fire after a player death

## Per-class spawn tuning: StatCurves HP × hp_scale ⇒ bike ~38, sedan ~70,
## technical ~90. ahead = enters from the top of the screen, falls back.
static var CLASS_TABLE := {
	&"bike": {"stats": null, "hp_scale": 0.55, "ahead": false},
	&"sedan": {"stats": null, "hp_scale": 0.85, "ahead": false},
	&"technical": {"stats": null, "hp_scale": 0.95, "ahead": true},
}

var host = null            # buzzard_run host: clock, course, kills
var target: Node2D = null  # the player
var wall = null            # horde_wall: phase cruise speed lands here
var frozen := false        # finale/win: stop directing, let the field play out

var rng := RandomNumberGenerator.new()
var _spawn_cd := 3.0       # first contact a breath after launch
var _cull_t := 0.5
var _lane_flip := 1.0

func _ready() -> void:
	rng.randomize()
	CLASS_TABLE[&"bike"]["stats"] = BikeStats
	CLASS_TABLE[&"sedan"]["stats"] = SedanStats
	CLASS_TABLE[&"technical"]["stats"] = TechnicalStats

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
		wall.wall_speed = ph["wall"]
	_cull_t -= delta
	if _cull_t <= 0.0:
		_cull_t = 0.5
		_cull()
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
	b.stats = stats
	b.hp_scale = row["hp_scale"]
	b.weapon_lock_exempt = true  # chase pacing lives in chase_driver, not the bay lock
	var driver = b.get_node(^"Driver")
	driver.role = kind
	driver.lane_offset = _lane_flip * rng.randf_range(80.0, 240.0)
	_lane_flip = -_lane_flip
	driver.phase = rng.randf_range(0.0, 6.0)
	var ahead: bool = row.get("ahead", false)
	var spawn_y: float = target.global_position.y + (-SPAWN_AHEAD if ahead else SPAWN_BEHIND)
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
		if is_instance_valid(b):
			_tumble(b))
	host.add_child(b)
	return b

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

## Player respawned: the pack breaks off the trigger for a beat.
func on_player_respawn() -> void:
	_spawn_cd = maxf(_spawn_cd, RESPAWN_GRACE)
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		var driver = enemy.get_node_or_null(^"Driver")
		if driver != null and "hold_fire" in driver:
			driver.hold_fire = true
	get_tree().create_timer(RESPAWN_GRACE).timeout.connect(_release_grace, CONNECT_ONE_SHOT)

func _release_grace() -> void:
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		var driver = enemy.get_node_or_null(^"Driver")
		if driver != null and "hold_fire" in driver:
			driver.hold_fire = false

func _cull() -> void:
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy is Node2D and enemy.global_position.y > target.global_position.y + CULL_BEHIND:
			enemy.queue_free()
