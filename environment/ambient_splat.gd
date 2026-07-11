class_name AmbientSplat
extends Node2D
## Short-lived, cosmetic-only aftermath for a soft target. Card 4 adds the
## tire-transfer sensor; the base stain never affects physics or targeting.

const LIFETIME := 5.0
const FADE_TIME := 1.0

var floor_index := -1
var age := 0.0
var seed := 0

func _ready() -> void:
	seed = int(absf(global_position.x * 17.0 + global_position.y * 31.0))
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	if age > LIFETIME - FADE_TIME:
		modulate.a = 1.0 - (age - (LIFETIME - FADE_TIME)) / FADE_TIME

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	draw_circle(Vector2.ZERO, 7.0, Color(0.34, 0.015, 0.02, 0.82))
	for i in 7:
		var at := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(4.0, 13.0)
		draw_circle(at, rng.randf_range(1.5, 4.0), Color(0.42, 0.02, 0.025, 0.76))
