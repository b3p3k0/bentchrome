extends Node2D
## The Buzzardz' pressure line: a rolling wall of dust, headlights and bad
## intentions that owns the south edge of the run. It advances north at the
## director's cruise speed, never falls farther back than MAX_GAP, and eats a
## life on contact (through Health, so the respawn blink-shield and DEVGOD are
## respected). A road-spanning backstop rides 250px inside it — you cannot
## reverse through the horde. Batch A visual is a painted dust band + drifting
## headlight pairs; the full FX stack lands in Batch B.

static var MAX_GAP := 2400.0      # px the wall trails at best (never irrelevant)
static var KILL_MARGIN := 50.0    # gap at which the swarm takes you
static var RESPAWN_GAP := 1400.0  # reset distance after a death
static var COMFORT_GAP := 900.0   # the yo-yo pivot: past this, the horde surges
static var CATCHUP_RATE := 0.35   # extra px/s of closure per px of excess gap

const BAND_DEPTH := 500.0         # painted dust depth behind the front
const ROAD_FALLBACK := 640.0      # half-width painted when no course is set

var target: Node2D = null   # the player, set by the host
var course = null           # chase_course.gd, set by the host (centers the band)
var wall_speed := 330.0     # px/s north; the director's phase drives this
var front_y := 0.0          # world y of the kill line

var _backstop: StaticBody2D = null

func _ready() -> void:
	z_index = 1  # the dust looms over cars it swallows
	_backstop = StaticBody2D.new()
	_backstop.name = "Backstop"
	_backstop.collision_layer = 2
	_backstop.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(3600.0, 60.0)
	col.shape = shape
	col.position = Vector2(0.0, 250.0)
	_backstop.add_child(col)
	add_child(_backstop)

func gap() -> float:
	if target == null or not is_instance_valid(target):
		return MAX_GAP
	return front_y - target.global_position.y

## Death reset: the swarm regroups a fair distance back (maxf — if it was
## already trailing farther, it doesn't leap forward to punish the respawn).
func reset_behind(y: float) -> void:
	front_y = maxf(front_y, y)

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var player_y: float = target.global_position.y
	# Rubberband: cruise inside COMFORT_GAP, surge harder the farther it trails
	# — no car outruns the horde globally; skill holds it at arm's length.
	var pressure := maxf(front_y - player_y - COMFORT_GAP, 0.0) * CATCHUP_RATE
	front_y -= (wall_speed + pressure) * delta       # north is -y
	front_y = minf(front_y, player_y + MAX_GAP)      # never out of the mirrors
	var road_x := 0.0
	if course != null:
		var s: Dictionary = course.sample(-front_y)
		road_x = s["x"]
	else:
		road_x = target.global_position.x
	global_position = Vector2(road_x, front_y)
	if front_y - player_y <= KILL_MARGIN:
		var health := target.get_node_or_null(^"Health")
		if health and health.hp > 0.0:
			health.take_damage(100000.0)  # shield/DEVGOD respected — Health decides
	queue_redraw()

func _draw() -> void:
	var half := ROAD_FALLBACK
	if course != null:
		var s: Dictionary = course.sample(-front_y)
		half = s["half_w"] + 220.0
	# Dust: dense at the front line, thinning south into the haze.
	for i in 4:
		var t := float(i) / 4.0
		var col := Color(0.45, 0.36, 0.28, 0.55 - t * 0.11)
		draw_rect(Rect2(-half, BAND_DEPTH * t, half * 2.0, BAND_DEPTH * 0.28), col)
	# Crest line — the hard edge you're actually racing.
	draw_rect(Rect2(-half, -6.0, half * 2.0, 10.0), Color(0.55, 0.42, 0.3, 0.85))
	# Headlight pairs flickering in the murk (time-seeded jitter, no state).
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_msec() / 140)
	for i in 6:
		var hx := rng.randf_range(-half * 0.85, half * 0.85)
		var hy := rng.randf_range(60.0, BAND_DEPTH * 0.8)
		var glow := Color(1.0, 0.9, 0.55, rng.randf_range(0.5, 0.95))
		draw_circle(Vector2(hx - 11.0, hy), 5.0, glow)
		draw_circle(Vector2(hx + 11.0, hy), 5.0, glow)
	# Silhouette humps — the shapes behind the lights.
	rng.seed = 977
	for i in 5:
		var sx := rng.randf_range(-half * 0.9, half * 0.9)
		var sy := rng.randf_range(120.0, BAND_DEPTH * 0.9)
		draw_rect(Rect2(sx - 34.0, sy - 20.0, 68.0, 40.0), Color(0.12, 0.1, 0.09, 0.7))
