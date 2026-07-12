extends RefCounted
## Shared drive-under fade seam for overhead paint (scaffold decks, crane
## jibs): one home for the alpha/speed so decks and deco can never drift.
## The z compare mirrors what actually renders — a body drawn beneath the
## overhead art is exactly the body that should see through it.

const ALPHA := 0.42
const SPEED := 6.0

static func build_area(size: Vector2, offset := Vector2.ZERO) -> Area2D:
	var area := Area2D.new()
	area.name = "Underpass"
	area.collision_layer = 0
	area.collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	col.position = offset
	area.add_child(col)
	return area

static func target_alpha(area: Area2D, over_z: int) -> float:
	for body in area.get_overlapping_bodies():
		if body is CanvasItem and (body as CanvasItem).z_index < over_z:
			return ALPHA
	return 1.0
