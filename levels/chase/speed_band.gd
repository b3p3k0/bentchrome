extends RefCounted
## The chase pedal: a governor that turns "how fast do I want to go" into the
## throttle DrivingController understands. The controller's throttle is an
## acceleration scalar with no drag under power (any positive throttle still
## climbs to top speed) and any negative throttle is the FULL brake, then
## reverse gear — so a speed BAND has to be governed from the driver's seat.
## Route 666 runs on it: you can speed up or slow down, never stop, never
## back up. Shared by the player's pedal and the Buzzard brain; pure statics,
## dependency-free, preloaded by path.

static var CRUISE_FRAC := 0.80   # hands off: the car settles at this fraction of top
static var FLOOR_FRAC := 0.55    # S held: eases down to this fraction and holds
static var BAND := 40.0          # px/s under a target over which throttle ramps to full
static var BRAKE_MARGIN := 12.0  # px/s over a target before the brake bites
const REVERSE_GUARD := 10.0      # the controller's crawl threshold: brake below it = reverse gear

## Throttle that carries fwd_speed (signed, along the nose) up to target_speed
## and holds it there. The brake only ever bites while the car rolls FORWARD
## well over the target — below the crawl threshold a negative throttle is
## reverse gear, and mid backward-slide it chops the slide to the reverse cap.
static func toward(fwd_speed: float, target_speed: float, allow_brake: bool) -> float:
	if fwd_speed < target_speed:
		return clampf((target_speed - fwd_speed) / BAND, 0.0, 1.0)
	if allow_brake and fwd_speed > target_speed + BRAKE_MARGIN and fwd_speed > REVERSE_GUARD:
		return -1.0
	return 0.0

## The speed the pedal asks for: W leans from cruise up to top, S from cruise
## down to the floor (analog sticks land in between; keys hit the ends).
static func band_target(want: float, top: float) -> float:
	if want >= 0.0:
		return top * lerpf(CRUISE_FRAC, 1.0, clampf(want, 0.0, 1.0))
	return top * lerpf(CRUISE_FRAC, FLOOR_FRAC, clampf(-want, 0.0, 1.0))

## The player's pedal. want = the raw throttle axis (-1 = S .. +1 = W).
## Flat out (and any live boost) is plain full throttle — the controller owns
## the ceiling, boost headroom included. Hands-off or S during a backward
## slide (post-whip) coasts: no gas was asked for, and the brake would be
## reverse gear.
static func pedal(want: float, fwd_speed: float, top: float, boosting: bool) -> float:
	if boosting or want > 0.95:
		return 1.0
	if want <= 0.05 and fwd_speed < 0.0:
		return 0.0
	return toward(fwd_speed, band_target(want, top), want < -0.05)
