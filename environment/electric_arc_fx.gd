class_name ElectricArcFX
extends Node2D
## Shared Taser/generator presentation: faint electric-blue glow, narrow white
## core, and restrained latch sparks. Gameplay owners supply endpoints.

const BOLT_SEG := 45.0
const BOLT_JAG := 14.0

var glow: Line2D
var core: Line2D
var sparks: CPUParticles2D

func _ready() -> void:
	glow = Line2D.new()
	glow.name = "Glow"
	glow.width = 7.0
	glow.default_color = Color(0.35, 0.75, 1.0, 0.25)
	add_child(glow)
	core = Line2D.new()
	core.name = "Core"
	core.width = 2.5
	core.default_color = Color(0.75, 0.95, 1.0, 0.95)
	add_child(core)
	sparks = CPUParticles2D.new()
	sparks.name = "Sparks"
	sparks.amount = 10
	sparks.lifetime = 0.25
	sparks.local_coords = false
	sparks.spread = 180.0
	sparks.initial_velocity_min = 60.0
	sparks.initial_velocity_max = 160.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 2.5
	sparks.gravity = Vector2.ZERO
	sparks.color = Color(0.7, 0.92, 1.0, 0.9)
	add_child(sparks)

func set_arc(from: Vector2, to: Vector2, crackle_seed := -1) -> void:
	var points := bolt_points(from, to, crackle_seed)
	core.points = points
	glow.points = points
	sparks.global_position = to
	sparks.emitting = true

func clear() -> void:
	if core:
		core.points = PackedVector2Array()
	if glow:
		glow.points = PackedVector2Array()
	if sparks:
		sparks.emitting = false

static func bolt_points(from: Vector2, to: Vector2, crackle_seed := -1) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var span := to - from
	var segs := maxi(int(span.length() / BOLT_SEG), 2)
	var perp := span.normalized().orthogonal() if span.length_squared() > 0.001 else Vector2.UP
	var rng := RandomNumberGenerator.new()
	if crackle_seed >= 0:
		rng.seed = crackle_seed
	else:
		rng.randomize()
	pts.append(from)
	for i in range(1, segs):
		var f := float(i) / float(segs)
		var envelope := sin(f * PI)
		pts.append(from + span * f + perp * rng.randf_range(-BOLT_JAG, BOLT_JAG) * envelope)
	pts.append(to)
	return pts
