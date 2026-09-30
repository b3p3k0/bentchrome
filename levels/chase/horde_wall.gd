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
static var MERCY_CLOSE := 45.0    # ...to this many px/s: the last 150px take >= 3.3s
static var HALT_BRAKE := 320.0    # px before a halt line over which the pack's speed ramps to zero
static var HALT_ROAR_FADE := 1.5  # seconds for the engines to die once the pack has stopped
static var HALT_CREEP := 40.0     # px/s the braking pack keeps until it is on the line
static var FLINCH_CUT := 0.25     # the pack's pace loses this fraction while flinching...
static var FLINCH_SECONDS := 1.5  # ...for this long after ordnance goes off in the dust
static var LOST_SIGHT_CUT := 0.3  # the pace lost while the car is off the road (a cutoff trail)

const ROAD_FALLBACK := 640.0      # half-width painted when no course is set
const DecoScript := preload("res://levels/chase/horde_deco.gd")
const ROAR_FLOOR := 0.22          # the engines at their farthest: never silent
const HORN_COOLDOWN := 6.0        # seconds between war-horn blasts, at least
const SpeedBand := preload("res://levels/chase/speed_band.gd")
const Difficulty := preload("res://game/difficulty.gd")
const FALLBACK_TOP := SpeedBand.FALLBACK_TOP  # bare fixtures, freed targets

var target: Node2D = null   # the player, set by the host
var course = null           # chase_course.gd, set by the host (centers the band)
var pace_frac := 0.80       # fraction of the target's top; the director's phase drives this
var front_y := 0.0          # world y of the dust crest
var no_mercy := false       # the host sets this once the run is lost: swallow the car
var halt_y := INF           # a world y the crest never passes (the finale's river bank)
var lost_sight := false     # the host sets this while the car is off the road: the pack slows and looks
var _flinch_t := 0.0        # seconds of flinch left
var _flinch_cut := 0.0      # the cut the current flinch runs at
var halted := false         # the pack has reached its halt line and stopped
var _halt_gain := 1.0       # the engines' fade once halted

var _deco: Node2D = null
var _roaring := false
var _was_danger := false
var _horn_t := 0.0

func _ready() -> void:
	z_index = 1  # the dust looms over cars it swallows
	# The picture (horde_deco.gd): riders, billows, lights, tracers, particles.
	_deco = DecoScript.new()
	_deco.name = "Deco"
	_deco.half = road_half()
	add_child(_deco)

## The road's reach at the crest, plus the verge the dust spills over.
func road_half() -> float:
	if course != null:
		var s: Dictionary = course.sample(-front_y)
		return float(s["half_w"]) + 220.0
	return ROAD_FALLBACK

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

## The engines' gain for a given pressure: a floor so the pack is always
## audible, swelling to full at contact.
static func roar_gain(pressure_now: float) -> float:
	return lerpf(ROAR_FLOOR, 1.0, clampf(pressure_now, 0.0, 1.0))

## The war horn sounds on the EDGE into the danger zone, and never more often
## than HORN_COOLDOWN — hovering on the line can't machine-gun it.
static func horn_due(danger: bool, was_danger: bool, cooldown_left: float) -> bool:
	return danger and not was_danger and cooldown_left <= 0.0

## The swarm has the car. Reported, never enforced: the host owns the cost.
func caught() -> bool:
	return target != null and is_instance_valid(target) and gap() <= CATCH_MARGIN

## Ordnance went off in the dust: the pack backs off — its pace loses `cut`
## for `seconds` (a second bang refreshes the clock and takes the bigger
## cut; nothing ever compounds) and the riders recoil.
func flinch(cut := FLINCH_CUT, seconds := FLINCH_SECONDS) -> void:
	_flinch_cut = maxf(_flinch_cut, cut) if _flinch_t > 0.0 else cut
	_flinch_t = maxf(_flinch_t, seconds)
	if _deco != null and _deco.has_method(&"flinch"):
		_deco.flinch()

func flinching() -> bool:
	return _flinch_t > 0.0

## What the pack's pace is multiplied by, pure: a flinch and a lost car
## both slow it, and they stack (a mine while they're looking around).
static func pace_mult(flinch_cut: float, flinch_left: float, lost: bool) -> float:
	var m := 1.0
	if flinch_left > 0.0:
		m *= 1.0 - flinch_cut
	if lost:
		m *= 1.0 - LOST_SIGHT_CUT
	return m

## Stop the pack at a world y (north is -y): the finale's river bank. From
## HALT_BRAKE px out the speed ramps down, the crest never crosses the line,
## and the MAX_GAP drag stops pulling it north after the escaping car.
func halt_at(y: float) -> void:
	halt_y = y

## The braking ramp, pure: full speed HALT_BRAKE px from the line, zero on it,
## and never under a creep in between so the pack actually arrives.
static func halt_speed(speed: float, front: float, line: float, brake: float) -> float:
	if line == INF:
		return speed
	var left := front - line
	if left <= 0.0:
		return 0.0
	return maxf(speed * clampf(left / maxf(brake, 1.0), 0.0, 1.0), minf(speed, HALT_CREEP))

## The phase pace as THIS tier runs it: easier tiers slow the whole pack
## (HARD is x1.0 — the arc as authored). The surge and the mercy are untouched.
func tier_pace() -> float:
	return pace_frac * Difficulty.knob(&"chase_pace")

## cos of the road's bend at course distance d: 1 on a straight, less on a
## sweeper (chase_course.sample slope over a short reach). 1 without a course.
static func road_cos(course_ref, d: float) -> float:
	if course_ref == null:
		return 1.0
	var a: Dictionary = course_ref.sample(d - 60.0)
	var b: Dictionary = course_ref.sample(d + 60.0)
	var slope: float = (float(b["x"]) - float(a["x"])) / 120.0
	return 1.0 / sqrt(1.0 + slope * slope)

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
	# The curve tax: the front advances up the y axis, but the road it rides
	# bends — through a sweeper the pack, like the car, covers less north per
	# second of speed. Without it the pack quietly gains on every curve.
	var speed := pack_speed(base_top(), tier_pace(), gap_now) * road_cos(course, -front_y)
	speed *= pace_mult(_flinch_cut, _flinch_t, lost_sight)
	_flinch_t = maxf(_flinch_t - delta, 0.0)
	if not no_mercy and _target_alive():
		speed = mercy_cap(speed, gap_now, _target_vn())
	speed = halt_speed(speed, front_y, halt_y, HALT_BRAKE)
	front_y -= speed * delta                         # north is -y
	if halt_y == INF:
		front_y = minf(front_y, player_y + MAX_GAP)  # never out of the mirrors
	else:
		front_y = maxf(front_y, halt_y)              # the bank: this far and no farther
		if not halted and front_y <= halt_y + 0.5:
			front_y = halt_y
			_halt()
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
	_voice(delta, g)
	if _deco != null:
		_deco.half = road_half()
		_deco.pressure = pressure_at(g)

## The brink: the crest stops dead, the riders lock up, the engines die.
func _halt() -> void:
	halted = true
	if _deco != null:
		_deco.halted = true
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null and audio.has_method(&"play_at"):
		for i in 3:
			var at := global_position + Vector2(road_half() * (-0.5 + 0.5 * float(i)), 40.0 * float(i))
			get_tree().create_timer(0.12 * float(i)).timeout.connect(
				func() -> void: audio.play_at(&"brake", at), CONNECT_ONE_SHOT)

## The pack's voice: engines whose gain rides the gap, and a war horn on the
## edge into the danger zone. Drop-in assets — silent no-ops until they land.
func _voice(delta: float, gap_px: float) -> void:
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio == null or not audio.has_method(&"loop_gain"):
		return
	if not _roaring:
		audio.loop_set(&"horde_roar", true)
		_roaring = true
	if halted:
		# Stopped at the brink: the engines die away, and no horn — they lost.
		_halt_gain = move_toward(_halt_gain, 0.0, delta / HALT_ROAR_FADE)
		audio.loop_gain(&"horde_roar", roar_gain(pressure_at(gap_px)) * _halt_gain)
		return
	var gain := roar_gain(pressure_at(gap_px))
	if _flinch_t > 0.0:
		gain *= 0.5    # the bang took the wind out of them
	if lost_sight:
		gain *= 0.35   # radios down, looking around
	audio.loop_gain(&"horde_roar", gain)
	_horn_t = maxf(_horn_t - delta, 0.0)
	var danger := gap_px < DANGER_GAP
	if horn_due(danger, _was_danger, _horn_t):
		audio.play(&"horde_horn")
		_horn_t = HORN_COOLDOWN
	_was_danger = danger

## Loopers live on the autoload and outlive the scene — always hang up.
func _exit_tree() -> void:
	if not _roaring:
		return
	_roaring = false
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null:
		audio.loop_set(&"horde_roar", false)
