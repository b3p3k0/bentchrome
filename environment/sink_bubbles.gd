extends Node2D
## Rising bubbles over a sink point: a handful of seeded circles that wobble
## upward, shrink, and fade — they linger past the car's disappearance so the
## water reads as having swallowed something. Self-freeing.

const COUNT := 8
const LIFETIME := 1.8
const LINGER := 0.8  # spawn-delay headroom past LIFETIME before freeing

var _t := 0.0
var _bubbles: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(global_position.x * 7.0 + global_position.y * 13.0)) + 5
	for i in COUNT:
		_bubbles.append({
			"at": Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-10.0, 10.0)),
			"delay": rng.randf_range(0.0, LINGER),
			"speed": rng.randf_range(24.0, 46.0),
			"r": rng.randf_range(2.0, 4.5),
			"wobble": rng.randf_range(3.0, 7.0),
			"phase": rng.randf_range(0.0, TAU),
		})

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t > LIFETIME + LINGER:
		queue_free()

func _draw() -> void:
	for b in _bubbles:
		var age: float = _t - b.delay
		if age < 0.0 or age > LIFETIME:
			continue
		var f: float = age / LIFETIME
		var at: Vector2 = b.at + Vector2(sin(_t * 3.0 + b.phase) * b.wobble, -age * b.speed)
		var r: float = b.r * (1.0 - f * 0.5)
		draw_circle(at, r, Color(0.8, 0.92, 1.0, (1.0 - f) * 0.75))
		draw_circle(at - Vector2(r * 0.3, r * 0.3), r * 0.35, Color(0.95, 1.0, 1.0, (1.0 - f) * 0.55))
