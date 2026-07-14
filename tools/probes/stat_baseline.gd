extends SceneTree
## Stat baseline probe: prints every data/vehicles/*.tres ride's engine values
## (StatCurves output), its terrain modifier table verbatim, and two measured
## feel numbers on road — 0-60 mph (time to 400 px/s) and time to 95% of its
## effective top — by driving the real DrivingController against a stub.
## Run: godot --headless --path . -s res://tools/probes/stat_baseline.gd
## Diff the output across a stats rebase: numbers must not move.

const CtrlScript := preload("res://vehicles/driving_controller.gd")
const Curves := preload("res://resources/stat_curves.gd")

const MPH_PER_PXS := 0.15          # ui/hud.gd display anchor
const SIXTY_MPH_PXS := 400.0       # 60 mph / 0.15
const DT := 1.0 / 60.0

class HealthStub:
	var max_hp := 0.0
	var hp := 0.0

class RideStub:
	var heading := 0.0
	var velocity := Vector2.ZERO
	var current_terrain: StringName = &"road"
	var stats = null
	func get_speed_scale() -> float:
		return 1.0

func _init() -> void:
	var dir := DirAccess.open("res://data/vehicles")
	if dir == null:
		printerr("stat_baseline: cannot open data/vehicles")
		quit(1)
		return
	var files: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".tres"):
			files.append(f)
	files.sort()
	for f in files:
		_report(f)
	quit(0)

func _report(file: String) -> void:
	var stats = load("res://data/vehicles/" + file)
	if stats == null:
		printerr("stat_baseline: failed to load " + file)
		return
	var ctrl = CtrlScript.new()
	var health := HealthStub.new()
	Curves.apply(stats, ctrl, health)
	var road_top: float = ctrl.max_speed * _factor(stats, &"road", &"top")
	var t060 := _time_to_speed(ctrl, stats, SIXTY_MPH_PXS)
	ctrl.free()
	ctrl = CtrlScript.new()
	Curves.apply(stats, ctrl, null)
	var t95 := _time_to_speed(ctrl, stats, road_top * 0.95)
	ctrl.free()
	print("%s top=%.6fpx/s (%.1fmph) accel=%.6f turn=%.6f grip=%.6f hp=%.6f mass=%.2f 0-60=%.3fs t95=%.3fs" % [
		file.get_basename().rpad(15), _slot_engine(stats, "max_speed"), _slot_engine(stats, "max_speed") * MPH_PER_PXS,
		_slot_engine(stats, "acceleration"), _slot_engine(stats, "turn_rate_deg"),
		_slot_engine(stats, "lateral_grip"), health.max_hp, _slot_engine(stats, "mass"), t060, t95])
	for m in stats.terrain_modifiers:
		if m == null:
			continue
		print("    terrain %s: accel=%.10f top=%.10f grip=%.10f steer=%.10f dash=%.10f" % [
			str(m.terrain).rpad(6), m.accel, m.top, m.grip, m.steer, m.dash_damage])

## Re-derives one engine value through StatCurves on a scratch controller so the
## printed numbers always reflect the live curve seam (not this probe's math).
func _slot_engine(stats, prop: String) -> float:
	var ctrl = CtrlScript.new()
	Curves.apply(stats, ctrl, null)
	var v: float = ctrl.get(prop)
	ctrl.free()
	return v

func _factor(stats, surface: StringName, prop: StringName) -> float:
	if stats.has_method("terrain_factor"):
		return stats.terrain_factor(surface, prop)
	return 1.0

## Seconds of full throttle from rest on road until forward speed reaches
## target px/s (cap 30s; -1 = unreachable, e.g. target above effective top).
func _time_to_speed(ctrl, stats, target: float) -> float:
	var stub := RideStub.new()
	stub.stats = stats
	var intent := {"throttle": 1.0, "steer": 0.0}
	var elapsed := 0.0
	while stub.velocity.dot(Vector2.RIGHT.rotated(stub.heading)) < target:
		if elapsed >= 30.0:
			return -1.0
		ctrl.apply(stub, intent, DT)
		elapsed += DT
	return elapsed
