extends Area2D
## Deep water: the pit's saltier cousin. A grounded vehicle that strays in
## sinks — shrink + splash + rising bubbles, then dead (no explosion; you were
## swallowed, you didn't pop). Airborne cars (ramp jumps, ledge hops) sail
## straight over, so pier gaps stay jumpable. The kill rect is inset from the
## painted edge — clipping the rim is forgiven, same as pits.
## Paint is a uniform dark fill + seeded wave chop and NO border, so several
## rects compose seamlessly around piers; the water-line foam belongs to the
## quay/pier paint, not the water.

const DEEP := Color(0.07, 0.16, 0.28)
const WAVE := Color(0.35, 0.55, 0.7, 0.5)
const KILL_INSET := 48.0

@export var size := Vector2(256, 256)

var is_deep_water := true  # minimap duck-type marker (deliberately NOT is_pit)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	add_to_group(&"lethal_hazards")
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = (size - Vector2(KILL_INSET, KILL_INSET)).max(Vector2(32, 32))
	col.shape = shape
	add_child(col)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.has_method(&"sink_into_water") and body.get("height") == 0.0:
			# Area2D's overlap cache can retain a body for one physics frame
			# after respawn teleports it away; trust the shape for normal entry
			# but reject a cached body already outside the water (pit parity).
			var body_2d := body as Node2D
			if body_2d and _contains_current_position(body_2d.global_position):
				body.sink_into_water()

func _contains_current_position(world_position: Vector2) -> bool:
	var local_position: Vector2 = to_local(world_position)
	var outer_half: Vector2 = size * 0.5
	return absf(local_position.x) <= outer_half.x \
		and absf(local_position.y) <= outer_half.y

func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), DEEP)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x * 7.0 + position.y * 13.0)) + 29
	var chop := int(size.x * size.y / 26000.0) + 3
	for i in chop:
		var at := Vector2(rng.randf_range(-half.x + 24, half.x - 24),
			rng.randf_range(-half.y + 24, half.y - 24))
		var w := rng.randf_range(14.0, 34.0)
		draw_line(at, at + Vector2(w, 0), WAVE, 2.0)
		draw_line(at + Vector2(w * 0.3, 4), at + Vector2(w * 0.8, 4), WAVE * Color(1, 1, 1, 0.6), 1.5)
