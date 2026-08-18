extends RefCounted
## Locks the driving-feel contract in numbers: time-to-top by mass class,
## brake stop times ("drastic, never instant"), and coast distance ordering
## (heavy coasts farther). Drives the real DrivingController against a stub —
## apply() only touches heading/velocity/current_terrain/get_speed_scale().

const CtrlScript := preload("res://vehicles/driving_controller.gd")

const DT := 1.0 / 60.0
const TOP := 520.0

var t

class StubVehicle:
	var heading := 0.0
	var velocity := Vector2.ZERO
	var current_terrain: StringName = &"road"
	func get_speed_scale() -> float:
		return 1.0

## Stub with the visual heading grid — enables the straighten heading snap.
class SteppedStub extends StubVehicle:
	var HEADING_STEPS := 16

func _init(runner) -> void:
	t = runner

func _ctrl(mass: float, accel: float):
	var c = CtrlScript.new()
	c.max_speed = TOP
	c.acceleration = accel
	c.mass = mass
	return c

func _fwd(stub: StubVehicle) -> float:
	return stub.velocity.dot(Vector2.RIGHT.rotated(stub.heading))

## Seconds of full throttle until forward speed reaches frac * TOP (cap 20s).
func _time_to(c, frac: float) -> float:
	var stub := StubVehicle.new()
	var intent := {"throttle": 1.0, "steer": 0.0}
	var elapsed := 0.0
	while _fwd(stub) < TOP * frac and elapsed < 20.0:
		c.apply(stub, intent, DT)
		elapsed += DT
	return elapsed

## Seconds of full brake from top speed until under frac * TOP (cap 20s).
func _brake_time(c, frac: float) -> float:
	var stub := StubVehicle.new()
	stub.velocity = Vector2.RIGHT * TOP
	var intent := {"throttle": -1.0, "steer": 0.0}
	var elapsed := 0.0
	while _fwd(stub) > TOP * frac and elapsed < 20.0:
		c.apply(stub, intent, DT)
		elapsed += DT
	return elapsed

## Coast distance from top speed until under 10% of TOP.
func _coast_dist(c) -> float:
	var stub := StubVehicle.new()
	stub.velocity = Vector2.RIGHT * TOP
	var intent := {"throttle": 0.0, "steer": 0.0}
	var dist := 0.0
	var elapsed := 0.0
	while _fwd(stub) > TOP * 0.1 and elapsed < 20.0:
		c.apply(stub, intent, DT)
		dist += stub.velocity.length() * DT
		elapsed += DT
	return dist

func test_time_to_top_by_mass_class() -> void:
	var bike = _ctrl(1.0, 300.0)    # ~accel stat 8, mass 1 (Mr. Ghastly)
	var mid = _ctrl(5.0, 207.0)     # accel stat 5, mass 5
	var heavy = _ctrl(8.0, 207.0)   # accel stat 5, mass 8 (Hammertoe)
	var t_bike := _time_to(bike, 0.95)
	var t_mid := _time_to(mid, 0.95)
	var t_heavy := _time_to(heavy, 0.95)
	t.check(t_bike <= 2.4, "accel: bike to 95%% top in <=2.4s (got %.2f)" % t_bike)
	t.check(t_mid >= 3.0 and t_mid <= 4.2, "accel: mid car in 3.0-4.2s (got %.2f)" % t_mid)
	t.check(t_heavy >= 5.0 and t_heavy <= 7.5, "accel: heavy in 5.0-7.5s (got %.2f)" % t_heavy)
	t.check(t_bike < t_mid and t_mid < t_heavy, "accel: strict light < mid < heavy ordering")
	bike.free()
	mid.free()
	heavy.free()

func test_launch_ordering() -> void:
	var bike = _ctrl(1.0, 207.0)
	var heavy = _ctrl(8.0, 207.0)
	var launch_bike := _time_to(bike, 0.3)
	var launch_heavy := _time_to(heavy, 0.3)
	t.check(launch_bike < launch_heavy, "launch: light off the line before heavy (%.2f vs %.2f)" % [launch_bike, launch_heavy])
	bike.free()
	heavy.free()

func test_brake_is_drastic_but_never_instant() -> void:
	var bike = _ctrl(1.0, 207.0)
	var mid = _ctrl(5.0, 207.0)
	var heavy = _ctrl(8.0, 207.0)
	var stop_mid := _brake_time(mid, 0.05)
	t.check(stop_mid >= 0.7 and stop_mid <= 1.1, "brake: mid car stops in 0.7-1.1s (got %.2f)" % stop_mid)
	# "not an instant halt": after 0.15s of full brake, still rolling above 60% top
	var stub := StubVehicle.new()
	stub.velocity = Vector2.RIGHT * TOP
	for i in 9:  # 0.15s
		mid.apply(stub, {"throttle": -1.0, "steer": 0.0}, DT)
	t.check(_fwd(stub) > TOP * 0.6, "brake: 0.15s tap leaves the car rolling fast")
	var stop_bike := _brake_time(bike, 0.05)
	var stop_heavy := _brake_time(heavy, 0.05)
	t.check(stop_bike < stop_mid and stop_mid < stop_heavy, "brake: light stops before heavy")
	bike.free()
	mid.free()
	heavy.free()

func test_handbrake_is_gentler_than_pedal() -> void:
	var mid = _ctrl(5.0, 207.0)
	# Handbrake stop takes clearly longer than the S pedal.
	var stub := StubVehicle.new()
	stub.velocity = Vector2.RIGHT * TOP
	var intent := {"throttle": 0.0, "steer": 0.0, "handbrake": true}
	var elapsed := 0.0
	while _fwd(stub) > TOP * 0.05 and elapsed < 20.0:
		mid.apply(stub, intent, DT)
		elapsed += DT
	var pedal := _brake_time(mid, 0.05)
	t.check(elapsed > pedal * 1.15, "handbrake: stops slower than the pedal (%.2f vs %.2f)" % [elapsed, pedal])
	mid.free()

func test_service_brake_state_tracks_opposing_travel() -> void:
	var c = _ctrl(5.0, 207.0)
	var stub := StubVehicle.new()
	stub.velocity = Vector2(200.0, 0.0)
	c.apply(stub, {"throttle": -1.0, "steer": 0.0}, DT)
	t.check(c.service_braking, "brake lights: S illuminates while rolling forward")
	stub.velocity = Vector2(-120.0, 0.0)
	c.apply(stub, {"throttle": 1.0, "steer": 0.0}, DT)
	t.check(c.service_braking, "brake lights: W illuminates while reversing")
	stub.velocity = Vector2(5.0, 0.0)
	c.apply(stub, {"throttle": -1.0, "steer": 0.0}, DT)
	t.check(not c.service_braking, "brake lights: dark at the forward-to-reverse crawl")
	stub.velocity = Vector2(200.0, 0.0)
	c.apply(stub, {"throttle": -1.0, "steer": 0.0, "handbrake": true}, DT)
	t.check(not c.service_braking, "brake lights: handbrake does not impersonate service brake")
	c.apply(stub, {"throttle": 1.0, "steer": 0.0}, DT)
	t.check(not c.service_braking, "brake lights: same-direction throttle stays dark")
	c.free()

func test_handbrake_kills_lateral_grip() -> void:
	var mid = _ctrl(5.0, 207.0)
	# Same sideways velocity, one tick: with the handbrake the lateral
	# component must survive far better (grip * 0.15).
	var gripped := StubVehicle.new()
	gripped.velocity = Vector2(0.0, 300.0)  # pure lateral (heading is +X)
	mid.apply(gripped, {"throttle": 0.0, "steer": 0.0}, DT)
	var sliding := StubVehicle.new()
	sliding.velocity = Vector2(0.0, 300.0)
	mid.apply(sliding, {"throttle": 0.0, "steer": 0.0, "handbrake": true}, DT)
	var kept_gripped: float = absf(sliding.velocity.y) - absf(gripped.velocity.y)
	t.check(kept_gripped > 0.0, "handbrake: lateral velocity survives better while sliding")
	t.check_approx(absf(sliding.velocity.y), 300.0 * (1.0 - 7.5 * 0.15 * DT), "handbrake: grip scaled by factor")
	mid.free()

func test_coast_heavy_rolls_farther() -> void:
	var bike = _ctrl(1.0, 207.0)
	var mid = _ctrl(5.0, 207.0)
	var heavy = _ctrl(8.0, 207.0)
	var d_bike := _coast_dist(bike)
	var d_mid := _coast_dist(mid)
	var d_heavy := _coast_dist(heavy)
	t.check(d_mid >= 400.0, "coast: mid car rolls at least 400px (got %.0f)" % d_mid)
	t.check(d_bike < d_mid and d_mid < d_heavy, "coast: light < mid < heavy distance (%.0f / %.0f / %.0f)" % [d_bike, d_mid, d_heavy])
	bike.free()
	mid.free()
	heavy.free()

func test_boost_raises_top_and_burns_fuel() -> void:
	var mid = _ctrl(5.0, 207.0)
	var stub := StubVehicle.new()
	var intent := {"throttle": 1.0, "steer": 0.0, "boost": true}
	# 10s of held boost: past normal top, tank down by burn_rate * time.
	for i in 600:
		mid.apply(stub, intent, DT)
	t.check(_fwd(stub) > TOP * 1.05, "boost: exceeds normal top speed (got %.0f)" % _fwd(stub))
	t.check_approx(mid.boost_fuel, 100.0 - mid.boost_burn_rate * 10.0, "boost: tank burns at burn_rate per second")
	mid.free()

func test_boost_empty_tank_is_inert() -> void:
	var mid = _ctrl(5.0, 207.0)
	mid.boost_fuel = 0.0
	var stub := StubVehicle.new()
	var intent := {"throttle": 1.0, "steer": 0.0, "boost": true}
	for i in 1200:  # plenty of time to reach whatever cap applies
		mid.apply(stub, intent, DT)
	t.check(_fwd(stub) <= TOP + 1.0, "boost: empty tank means normal top speed (got %.0f)" % _fwd(stub))
	t.check(mid.boost_fuel == 0.0, "boost: tank never goes negative")
	mid.free()

func test_straighten_assist_boosts_grip_after_delay() -> void:
	# Unprimed single tick: base lateral decay.
	var base = _ctrl(5.0, 207.0)
	var fresh := StubVehicle.new()
	fresh.velocity = Vector2(200.0, 300.0)  # forward + lateral (heading +X)
	base.apply(fresh, {"throttle": 0.0, "steer": 0.0}, DT)
	var base_decay := 300.0 - absf(fresh.velocity.y)
	# Primed past the delay (hands off the wheel): boosted decay.
	var assisted = _ctrl(5.0, 207.0)
	var stub := StubVehicle.new()
	stub.velocity = Vector2(200.0, 0.0)
	for i in 30:  # 0.5s of no-steer forward travel arms the assist
		assisted.apply(stub, {"throttle": 0.5, "steer": 0.0}, DT)
	stub.velocity.y = 300.0
	var fwd_before: float = stub.velocity.x
	assisted.apply(stub, {"throttle": 0.0, "steer": 0.0}, DT)
	var boosted_decay := 300.0 - absf(stub.velocity.y)
	t.check(boosted_decay > base_decay * 2.0,
		"straighten: primed lateral decay well above base (%.1f vs %.1f)" % [boosted_decay, base_decay])
	t.check(fwd_before > 30.0, "straighten: fixture kept forward speed above the gate")
	# Any steer input resets the grace period.
	assisted.apply(stub, {"throttle": 0.0, "steer": 1.0}, DT)
	stub.velocity = Vector2(200.0, 300.0)
	assisted.apply(stub, {"throttle": 0.0, "steer": 0.0}, DT)
	var reset_decay := 300.0 - absf(stub.velocity.y)
	t.check(reset_decay < boosted_decay * 0.6,
		"straighten: steering resets the assist (%.1f after reset)" % reset_decay)
	base.free()
	assisted.free()

func test_straighten_snaps_heading_to_grid() -> void:
	var c = _ctrl(5.0, 207.0)
	var stub := SteppedStub.new()
	stub.heading = 0.1  # between the 0 and TAU/16 (0.3927) steps
	stub.velocity = Vector2.RIGHT.rotated(stub.heading) * 200.0
	for i in 60:  # 1s hands-off: assist armed, heading eases to the grid
		c.apply(stub, {"throttle": 0.5, "steer": 0.0}, DT)
	t.check(absf(stub.heading) < 0.01,
		"straighten: heading settles onto the 16-step grid (%.3f rad)" % stub.heading)
	# A plain stub (no HEADING_STEPS) never snaps.
	var c2 = _ctrl(5.0, 207.0)
	var plain := StubVehicle.new()
	plain.heading = 0.1
	plain.velocity = Vector2.RIGHT.rotated(plain.heading) * 200.0
	for i in 60:
		c2.apply(plain, {"throttle": 0.5, "steer": 0.0}, DT)
	t.check(absf(plain.heading - 0.1) < 0.001, "straighten: no grid on the vehicle, no snap")
	c.free()
	c2.free()

## --- The whip (handbrake 180) — signature slide move ------------------------

## Steps a full-lock handbrake whip from `entry` px/s until the heading crosses
## PI (or the cap): [seconds, speed_at_crossing, fwd_at_crossing].
func _whip_to_pi(c, entry: float) -> Array:
	var stub := SteppedStub.new()
	stub.velocity = Vector2.RIGHT * entry
	var intent := {"throttle": 0.0, "steer": 1.0, "handbrake": true}
	var elapsed := 0.0
	while stub.heading < PI and elapsed < 4.0:
		c.apply(stub, intent, DT)
		elapsed += DT
	return [elapsed, stub.velocity.length(), _fwd(stub)]

func test_whip_lands_180_with_slide_surviving() -> void:
	var c = _ctrl(5.0, 207.0)
	var stub := SteppedStub.new()
	stub.velocity = Vector2.RIGHT * 420.0
	var intent := {"throttle": 0.0, "steer": 1.0, "handbrake": true}
	var elapsed := 0.0
	while stub.heading < PI and elapsed < 4.0:
		c.apply(stub, intent, DT)
		elapsed += DT
	t.check(elapsed >= 0.35 and elapsed <= 0.70,
		"whip: mid car lands the 180 in [0.35, 0.70]s (%.2f)" % elapsed)
	t.check(stub.velocity.length() >= 150.0,
		"whip: the slide survives the rotation (%.0f px/s)" % stub.velocity.length())
	t.check(_fwd(stub) < 0.0, "whip: facing backward while still traveling — fire away")
	# Held past the crossing, the nose keeps advancing: the dir_sign pin.
	# Without it the flipped travel sign counter-steers and the heading stalls.
	var before: float = stub.heading
	for i in 18:  # 0.3s more
		c.apply(stub, intent, DT)
		t.check(stub.heading >= before, "whip: heading never counter-steers while held")
		before = stub.heading
	c.free()

func test_whip_mass_ordering() -> void:
	var light = _ctrl(2.0, 207.0)
	var mid = _ctrl(5.0, 207.0)
	var heavy = _ctrl(8.0, 207.0)
	var t2: float = _whip_to_pi(light, 420.0)[0]
	var t5: float = _whip_to_pi(mid, 420.0)[0]
	var t8: float = _whip_to_pi(heavy, 420.0)[0]
	t.check(t2 >= 0.25 and t2 <= 0.55, "whip: light car in [0.25, 0.55]s (%.2f)" % t2)
	t.check(t5 >= 0.35 and t5 <= 0.70, "whip: mid car in [0.35, 0.70]s (%.2f)" % t5)
	t.check(t8 >= 0.45 and t8 <= 0.95, "whip: heavy car in [0.45, 0.95]s (%.2f)" % t8)
	t.check(t2 < t5 and t5 < t8, "whip: sporty whips quicker, heavies swing slower")
	light.free()
	mid.free()
	heavy.free()

func test_whip_needs_speed_and_handbrake() -> void:
	# Below the entry gate the handbrake steers at the plain rate (and the
	# bleeding slide loses authority) — no parking-lot whips.
	var slow = _ctrl(5.0, 207.0)
	var slow_stub := SteppedStub.new()
	slow_stub.velocity = Vector2.RIGHT * 150.0
	var fast = _ctrl(5.0, 207.0)
	var fast_stub := SteppedStub.new()
	fast_stub.velocity = Vector2.RIGHT * 420.0
	var intent := {"throttle": 0.0, "steer": 1.0, "handbrake": true}
	for i in 24:  # 0.4s
		slow.apply(slow_stub, intent, DT)
		fast.apply(fast_stub, intent, DT)
	t.check(fast_stub.heading >= slow_stub.heading * 1.5,
		"whip: only a FAST handbrake whips (%.2f vs %.2f rad)"
		% [fast_stub.heading, slow_stub.heading])
	# Steer without the handbrake stays at the base rate — the ice-feel regime
	# (steer-only tests) is untouched by the whip.
	var plain = _ctrl(5.0, 207.0)
	var plain_stub := SteppedStub.new()
	plain_stub.velocity = Vector2.RIGHT * 420.0
	for i in 24:
		plain.apply(plain_stub, {"throttle": 0.0, "steer": 1.0}, DT)
	t.check(plain_stub.heading <= deg_to_rad(190.0 * 0.4 * 1.05),
		"whip: no handbrake, no whip — base steer rate holds")
	slow.free()
	fast.free()
	plain.free()

func test_reverse_cap_prices_powered_reverse_only() -> void:
	# A backward-facing slide keeps its momentum and coasts down gently.
	var c = _ctrl(5.0, 207.0)
	var stub := StubVehicle.new()
	stub.velocity = Vector2.LEFT * 400.0  # heading 0, traveling backward
	c.apply(stub, {"throttle": 0.0, "steer": 0.0}, DT)
	t.check(_fwd(stub) < -350.0,
		"reverse cap: a slide is never chopped to the reverse gear (%.0f)" % _fwd(stub))
	for i in 30:  # 0.5s of coasting
		c.apply(stub, {"throttle": 0.0, "steer": 0.0}, DT)
	t.check(_fwd(stub) < -180.0 and _fwd(stub) > -400.0,
		"reverse cap: the slide decays through coast, not a chop (%.0f)" % _fwd(stub))
	# The handbrake never chops either — it eases along the nose.
	var hb = _ctrl(5.0, 207.0)
	var hb_stub := StubVehicle.new()
	hb_stub.velocity = Vector2.LEFT * 400.0
	hb.apply(hb_stub, {"throttle": 0.0, "steer": 0.0, "handbrake": true}, DT)
	t.check(_fwd(hb_stub) < -350.0, "reverse cap: handbrake slides keep their speed")
	# POWERED reverse (the S gear) still pays the reverse cap immediately.
	var pw = _ctrl(5.0, 207.0)
	var pw_stub := StubVehicle.new()
	pw_stub.velocity = Vector2.LEFT * 400.0
	pw.apply(pw_stub, {"throttle": -1.0, "steer": 0.0}, DT)
	t.check(absf(_fwd(pw_stub) + 180.0) < 1.0,
		"reverse cap: the S gear is still priced at reverse_max_speed (%.0f)" % _fwd(pw_stub))
	c.free()
	hb.free()
	pw.free()
