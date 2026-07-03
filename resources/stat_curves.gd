class_name StatCurves
extends RefCounted
## Maps 1-10 design stats to engine units — the single place to retune global
## feel. A mid car lands near the hand-tuned baseline; cars scale around it.
## handling drives both turn rate and grip; armor drives HP.

static func _scale(v: int, lo: float, hi: float) -> float:
	return lerpf(lo, hi, clampf((float(v) - 1.0) / 9.0, 0.0, 1.0))

static func apply(stats: VehicleStats, controller, health) -> void:
	controller.max_speed = _scale(stats.top_speed, 360.0, 640.0)
	controller.acceleration = _scale(stats.acceleration, 450.0, 1300.0)
	controller.turn_rate_deg = _scale(stats.handling, 130.0, 250.0)
	controller.lateral_grip = _scale(stats.handling, 4.5, 10.0)
	controller.mass = float(stats.mass)
	if health:
		var hp := _scale(stats.armor, 70.0, 180.0)
		health.max_hp = hp
		health.hp = hp
