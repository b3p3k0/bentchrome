extends StaticBody2D
## Roadside clutter — trash piles, dry scrub, suburb bushes, snow drifts.
## Block semantics (layer 4) so shots connect, but 1 HP: any hit or ram pops
## it with a quiet scatter puff (no ring, no shake — this is set dressing,
## not an explosion). Too small for the radar (ui/radar.gd size-gates it).
## Paint is a seeded lumpy blob cluster; kind picks the palette.

const KINDS := {
	&"trash": {"base": Color(0.34, 0.32, 0.28), "dark": Color(0.22, 0.2, 0.18), "fleck": Color(0.5, 0.46, 0.38)},
	&"brush": {"base": Color(0.45, 0.42, 0.22), "dark": Color(0.3, 0.28, 0.14), "fleck": Color(0.6, 0.54, 0.3)},
	&"bush": {"base": Color(0.22, 0.38, 0.18), "dark": Color(0.13, 0.24, 0.1), "fleck": Color(0.34, 0.52, 0.26)},
	&"drift": {"base": Color(0.82, 0.85, 0.92), "dark": Color(0.62, 0.68, 0.8), "fleck": Color(0.95, 0.97, 1.0)},
}

@export var kind: StringName = &"trash"
@export var footprint := 40.0  # collision square; paint spills a little past it

@onready var _health: Health = $Health

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(footprint, footprint)
	($Col as CollisionShape2D).shape = shape
	# Health (child) readies before this node — set hp along with max_hp.
	_health.max_hp = 1.0
	_health.hp = 1.0
	_health.died.connect(_pop)
	queue_redraw()

func _pop() -> void:
	var scene := get_tree().current_scene
	if scene:  # headless fixtures may not set one
		var palette: Dictionary = KINDS.get(kind, KINDS[&"trash"])
		var puff := CPUParticles2D.new()
		puff.one_shot = true
		puff.emitting = true
		puff.amount = 12
		puff.lifetime = 0.5
		puff.explosiveness = 1.0
		puff.spread = 180.0
		puff.initial_velocity_min = 120.0
		puff.initial_velocity_max = 260.0
		puff.damping_min = 150.0
		puff.damping_max = 300.0
		puff.scale_amount_min = 2.0
		puff.scale_amount_max = 4.0
		puff.gravity = Vector2.ZERO
		puff.color = palette.base
		puff.finished.connect(puff.queue_free)
		puff.global_position = global_position
		scene.add_child(puff)
	queue_free()

func _draw() -> void:
	var palette: Dictionary = KINDS.get(kind, KINDS[&"trash"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x * 7.0 + position.y * 13.0))
	var reach := footprint * 0.55
	for i in 5 + rng.randi() % 3:
		var at := Vector2(rng.randf_range(-reach, reach), rng.randf_range(-reach, reach)) * 0.8
		var r := rng.randf_range(footprint * 0.2, footprint * 0.38)
		draw_circle(at, r, palette.dark if rng.randf() < 0.4 else palette.base)
	for i in 4 + rng.randi() % 4:
		var p := Vector2(rng.randf_range(-reach, reach), rng.randf_range(-reach, reach))
		draw_rect(Rect2(p, Vector2(3, 3)), palette.fleck)
