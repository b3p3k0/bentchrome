extends Node2D
## The Buzzardz' pressure line: a rolling wall of dust, headlights and bad
## intentions that owns the south edge of the run. Its speed is priced against
## the PLAYER'S OWN CAR — the director's pace is a fraction of that ride's top
## speed, plus a surge that grows with every px the gap runs past the leash —
## so a land-yacht and an open-wheeler feel the same squeeze.
##
## THE GAP IS THE HEALTH BAR, and it lives ON SCREEN: the leash is short
## enough that clean flat-out driving holds the dust crest just inside the
## bottom edge of the view, and every lift, crash, or verge excursion visibly
## costs ground. The rubberband pulls both ways — a boost only buys a couple
## of seconds before the surge drags the pack back into frame (MAX_GAP), and
## inside MERCY_GAP the closing speed is capped so the last stretch always
## takes a beat: close calls last long enough to be escaped. The mercy
## stretch is sized so ONE dead-stop crash is survivable in every car at every
## beat of the arc (the heavy rides re-accelerate slowest) — and leaves the
## pack on the bumper, so the second one isn't.
##
## The wall never touches Health. It only REPORTS the catch (caught()); the
## host decides what a catch costs — on Route 666 that's a robbery, not a
## life. Nothing here blocks the road either: the pedal has no reverse and the
## pace keeper owns the floor, so the old backstop has nothing left to stop.

static var MAX_GAP := 760.0       # px the pack trails at best — off screen only briefly
static var START_GAP := 600.0     # where the pack sits at the green flag
static var CATCH_MARGIN := 50.0   # gap at which the swarm has you
static var LEASH_GAP := 210.0     # the rubberband pivot: past this, the horde surges
static var SURGE_PER_PX := 0.0008 # extra pace (fraction of top) per px past the leash
static var DANGER_GAP := 180.0    # pack on the bumper: rumble, HUD alarm
static var MERCY_GAP := 200.0     # inside this the closing speed is capped...
static var MERCY_CLOSE := 30.0    # ...to this many px/s: the last 150px take >= 5s

const BAND_DEPTH := 500.0         # painted dust depth behind the front
const ROAD_FALLBACK := 640.0      # half-width painted when no course is set
const DUST_AMOUNT := 140          # particle budget: one system, under 200
const SpeedBand := preload("res://levels/chase/speed_band.gd")
const FALLBACK_TOP := SpeedBand.FALLBACK_TOP  # bare fixtures, freed targets

var target: Node2D = null   # the player, set by the host
var course = null           # chase_course.gd, set by the host (centers the band)
var pace_frac := 0.80       # fraction of the target's top; the director's phase drives this
var front_y := 0.0          # world y of the dust crest
var no_mercy := false       # the host sets this once the run is lost: swallow the car

var _dust: CPUParticles2D = null

func _ready() -> void:
	z_index = 1  # the dust looms over cars it swallows
	# The rolling dust bank (snowfall-pattern CPUParticles; world-space so the
	# cloud trails as the front advances).
	_dust = CPUParticles2D.new()
	_dust.name = "Dust"
	_dust.amount = DUST_AMOUNT
	_dust.lifetime = 2.6
	_dust.local_coords = false
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(950, 170)
	_dust.position = Vector2(0, 230)
	_dust.direction = Vector2(0, -1)
	_dust.spread = 34.0
	_dust.initial_velocity_min = 60.0
	_dust.initial_velocity_max = 170.0
	_dust.gravity = Vector2(0, -22)
	_dust.scale_amount_min = 3.0
	_dust.scale_amount_max = 7.5
	_dust.color = Color(0.52, 0.42, 0.31, 0.32)
	_dust.preprocess = 2.0
	add_child(_dust)

func gap() -> float:
	if target == null or not is_instance_valid(target):
		return MAX_GAP
	return front_y - target.global_position.y

## The pack's speed in px/s: the phase pace plus the leash surge, both priced
## in fractions of the chased car's top. Flat-out equilibrium lands at
## LEASH_GAP + (1 - pace) / SURGE_PER_PX whatever the car — only the clock
## it takes to get there scales with the ride.
static func pack_speed(top: float, pace: float, gap_px: float) -> float:
	return top * (pace + SURGE_PER_PX * maxf(gap_px - LEASH_GAP, 0.0))

## The mercy cap: inside MERCY_GAP the pack may close no faster than
## MERCY_CLOSE over the chased car's own northward speed — a pinned or
## crawling car still gets its beat to find a way out.
static func mercy_cap(speed: float, gap_px: float, target_vn: float) -> float:
	if gap_px >= MERCY_GAP:
		return speed
	return minf(speed, target_vn + MERCY_CLOSE)

## 0 = the pack at its farthest, 1 = contact. The HUD meter and the GPS band.
static func pressure_at(gap_px: float) -> float:
	return clampf(1.0 - (gap_px - CATCH_MARGIN) / (MAX_GAP - CATCH_MARGIN), 0.0, 1.0)

func pressure() -> float:
	return pressure_at(gap())

## Pack on the bumper — the rumble, the HUD alarm, the GPS pulse.
func in_danger() -> bool:
	return gap() < DANGER_GAP

## The swarm has the car. Reported, never enforced: the host owns the cost.
func caught() -> bool:
	return target != null and is_instance_valid(target) and gap() <= CATCH_MARGIN

## The chased car's honest top speed on asphalt (SpeedBand.road_top), read
## live and duck-typed so bare test fixtures ride the fallback.
func base_top() -> float:
	return SpeedBand.road_top(target)

## The chased car's speed up the road (north = +), 0 for bare fixtures.
func _target_vn() -> float:
	var v: Variant = target.get("velocity")
	return -v.y if v is Vector2 else 0.0

## A wrecked car gets no mercy — the pack rolls straight over the wreck.
func _target_alive() -> bool:
	var health := target.get_node_or_null(^"Health")
	return health == null or health.hp > 0.0

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var player_y: float = target.global_position.y
	# Rubberband: cruise inside the leash, surge harder the farther it trails
	# — no car outruns the horde globally; skill holds it at arm's length.
	var gap_now := front_y - player_y
	var speed := pack_speed(base_top(), pace_frac, gap_now)
	if not no_mercy and _target_alive():
		speed = mercy_cap(speed, gap_now, _target_vn())
	front_y -= speed * delta                         # north is -y
	front_y = minf(front_y, player_y + MAX_GAP)      # never out of the mirrors
	var road_x := 0.0
	if course != null:
		var s: Dictionary = course.sample(-front_y)
		road_x = s["x"]
	else:
		road_x = target.global_position.x
	global_position = Vector2(road_x, front_y)
	# Ground shudder once the pack is on the bumper — a sub-pixel rumble that
	# grows to a rattle at contact range (screen_shake toggle respected inside
	# add_shake). The pack rides in frame all run; only DANGER shakes.
	var g := front_y - player_y
	if g < DANGER_GAP and target.has_method(&"add_shake"):
		target.add_shake(minf((DANGER_GAP - g) * 0.006, 0.9))
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
	var tms := Time.get_ticks_msec() * 0.001
	# Silhouettes first — hulking shapes lurching in the murk, lights on top.
	var rng := RandomNumberGenerator.new()
	rng.seed = 977
	for i in 5:
		var sx := rng.randf_range(-half * 0.9, half * 0.9)
		var sy := rng.randf_range(120.0, BAND_DEPTH * 0.9)
		var rate := rng.randf_range(1.5, 3.0)
		var bob := sin(tms * rate + float(i) * 1.7) * 6.0
		var lurch := sin(tms * 0.7 + float(i) * 2.3) * 16.0
		draw_rect(Rect2(sx - 34.0 + lurch, sy - 20.0 + bob, 68.0, 40.0),
			Color(0.12, 0.1, 0.09, 0.75))
		draw_rect(Rect2(sx - 18.0 + lurch, sy - 32.0 + bob, 36.0, 14.0),
			Color(0.1, 0.09, 0.08, 0.7))
	# Headlight pairs flickering in the dust (time-seeded jitter, no state).
	rng.seed = int(Time.get_ticks_msec() / 140)
	for i in 6:
		var hx := rng.randf_range(-half * 0.85, half * 0.85)
		var hy := rng.randf_range(60.0, BAND_DEPTH * 0.8)
		var glow := Color(1.0, 0.9, 0.55, rng.randf_range(0.5, 0.95))
		var halo := Color(1.0, 0.85, 0.5, 0.16)
		draw_circle(Vector2(hx - 11.0, hy), 10.0, halo)
		draw_circle(Vector2(hx + 11.0, hy), 10.0, halo)
		draw_circle(Vector2(hx - 11.0, hy), 5.0, glow)
		draw_circle(Vector2(hx + 11.0, hy), 5.0, glow)
