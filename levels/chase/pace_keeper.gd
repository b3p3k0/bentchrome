extends Node
## The road never lets you stop. Route 666's pedal can't go below its floor
## (speed_band.gd), but physics can: a pillar, a wreck, a handbrake whip. The
## pace keeper is the level-side guarantee — an environment velocity bias in
## the ramp.gd downhill-pull idiom, applied from outside the car so
## driving_controller.gd's test-locked feel bands never move. It only ever
## pushes NORTH (up the course), only below its floor, and only as hard as
## KEEP_PUSH allows: a shove, not a teleport, well under the bounce and
## crash-audio thresholds per tick.
##
## Pinned dead against something solid, the shove alone goes nowhere. After
## PIN_TIME of that the keeper leans the car toward the free side, so a
## head-on pillar costs gap instead of the run.

static var KEEP_FRAC := 0.45     # of the car's top: the floor physics may not go under
static var KEEP_PUSH := 1400.0   # px/s^2 northward while under the floor
static var PIN_TIME := 0.25      # seconds of no real progress before the side lean
static var PIN_FRAC := 0.25      # "no real progress" = under this fraction of the floor
static var NUDGE_PUSH := 900.0   # px/s^2 sideways while pinned
static var NUDGE_MAX := 220.0    # px/s sideways ceiling from the lean

const FALLBACK_TOP := 484.0      # bare fixtures with no controller

var target = null     # the player's car, set by the host
var course = null     # chase_course.gd, set by the host (picks the wide side)
var enabled := true   # the host drops this when the run is over

var _last_y := 0.0
var _have_last := false
var _blocked_t := 0.0
var _nudge_dir := 0.0

## The floor rule, pure: north is -y. Returns the velocity after one tick.
static func keep(velocity: Vector2, floor_speed: float, push: float, delta: float) -> Vector2:
	var vn := -velocity.y
	if vn >= floor_speed:
		return velocity
	return Vector2(velocity.x, -minf(vn + push * delta, floor_speed))

## Which way is out: away from whatever the nose is buried in, else toward
## the wider side of the road, else right.
static func free_side(hit_dx: float, road_offset: float) -> float:
	if absf(hit_dx) > 4.0:
		return -signf(hit_dx)
	if absf(road_offset) > 1.0:
		return -signf(road_offset)
	return 1.0

func floor_speed() -> float:
	var top := FALLBACK_TOP
	if target != null and is_instance_valid(target) and target.has_method(&"get_controller"):
		var ctrl = target.get_controller()
		if ctrl != null:
			top = ctrl.max_speed
	return top * KEEP_FRAC

func is_pinned() -> bool:
	return _blocked_t >= PIN_TIME

func _physics_process(delta: float) -> void:
	if not enabled or target == null or not is_instance_valid(target) or delta <= 0.0:
		_have_last = false
		return
	if not _rides(target):
		_have_last = false
		_blocked_t = 0.0
		return
	var want := floor_speed()
	var y: float = target.global_position.y
	# Real progress since the last tick — velocity lies when the nose is
	# buried in a pillar (the slide zeroes it after the fact).
	var made := want
	if _have_last:
		made = (_last_y - y) / delta
	_last_y = y
	_have_last = true
	var under: bool = -target.velocity.y < want
	if under and made < want * PIN_FRAC:
		if _blocked_t <= 0.0:
			_nudge_dir = 0.0
		_blocked_t += delta
	else:
		_blocked_t = 0.0
	target.velocity = keep(target.velocity, want, KEEP_PUSH, delta)
	if is_pinned():
		if _nudge_dir == 0.0:
			_nudge_dir = free_side(_hit_dx(target), _road_offset(target))
		target.velocity.x = move_toward(target.velocity.x, _nudge_dir * NUDGE_MAX, NUDGE_PUSH * delta)

## Cars the road has a grip on: alive, on the ground, under their own power.
func _rides(car) -> bool:
	if car.has_method(&"get_hp") and car.get_hp() <= 0.0:
		return false
	if car.get("height") != null and float(car.get("height")) != 0.0:
		return false  # airborne: the jump owns the arc
	if car.has_method(&"is_dashing") and car.is_dashing():
		return false
	if car.has_method(&"is_repairing") and car.is_repairing():
		return false
	return true

## Summed x offset of whatever is pushing back south on the nose.
func _hit_dx(car) -> float:
	if not car.has_method(&"get_slide_collision_count"):
		return 0.0
	var dx := 0.0
	for i in car.get_slide_collision_count():
		var hit = car.get_slide_collision(i)
		if hit != null and hit.get_normal().y > 0.3:
			dx += hit.get_position().x - car.global_position.x
	return dx

func _road_offset(car) -> float:
	if course == null:
		return 0.0
	var s: Dictionary = course.sample(-car.global_position.y)
	return car.global_position.x - float(s["x"])
