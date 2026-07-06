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
	t.check_approx(mid.boost_fuel, 1.0 - mid.boost_burn_rate * 10.0, "boost: tank burns at burn_rate per second")
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
