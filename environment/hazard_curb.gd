extends StaticBody2D
## An AI-only "don't drive here" rail for lethal rims (pits, deep water).
## Lives on the hazard_edge layer (64), which no vehicle or projectile mask
## contains — cars and shots pass through freely; only the AI's obstacle
## feelers carry bit 64, so drivers steer off edges they used to lemming
## over. Invisible at runtime by design: the hazard paints itself, the curb
## is just the driver's guardian angel.

@export var size := Vector2(256, 24)

func _ready() -> void:
	collision_layer = 64
	collision_mask = 0
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	add_child(col)
