class_name FloorZone
extends Area2D
## Tags a terraced region with its floor number (1 = sea level, 2 = street/
## dock, 3 = rooftops). Pure metadata: no paint, no physics response — the
## vehicle's FloorSensor reads floor_index; ground art is authored separately.
## Exported size builds the rect at ready (pit_zone pattern) so one scene
## serves any region; the radar reads the RectangleShape2D for floor plates.

@export var floor_index := 1
@export var size := Vector2(512, 512)

func _ready() -> void:
	collision_layer = 256  # floor_tag channel — only FloorSensors listen
	collision_mask = 0
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	add_child(col)
