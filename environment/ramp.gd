class_name Ramp
extends Node2D
## The DRIVEABLE floor transition — jump pads launch, ramps CLIMB. One node
## builds the whole recipe at ready:
##   - two ramp-flagged FloorZone halves (low half tags low_floor, high half
##     high_floor): crossing the midline grades a car's floor over at ground
##     level, both directions — no hop, no fall damage;
##   - side rails along the HIGH half: thin statics carrying BOTH floors'
##     bits, so a street car can't sideswipe into elevation (smash-proof by
##     design — they're the geometry, not set dressing);
##   - slope shading painted over whatever sits under the strip. Surface FEEL
##     is composition: author a TerrainZone over the strip (grass = hill,
##     snow = slippery climb, bare asphalt = parking-garage grade).
## Local convention: the strip runs along local Y with the HIGH end at -y;
## rotate the node to orient. size = (width, length). Duck-typed only —
## never names Vehicle.

const Floors := preload("res://game/floors.gd")
const FloorZoneScene := preload("res://environment/floor_zone.tscn")
const EDGE := Color(0.55, 0.55, 0.62)
const CHEVRON := Color(0.95, 0.9, 0.6, 0.5)
const SHADE_STEPS := 6
const HILITE_A := 0.14  # extra light at the high end
const SHADOW_A := 0.16  # extra dark at the low end
const RAIL_W := 12.0

@export var low_floor := 2
@export var high_floor := 3
@export var size := Vector2(192, 448)  # width x length (length along local y)

func _ready() -> void:
	for cfg in [{"floor": high_floor, "y": -size.y * 0.25}, {"floor": low_floor, "y": size.y * 0.25}]:
		var zone := FloorZoneScene.instantiate()
		zone.floor_index = cfg.floor
		zone.ramp = true
		zone.size = Vector2(size.x, size.y * 0.5)
		zone.position = Vector2(0.0, cfg.y)
		add_child(zone)
	var rail_bits: int = 4 | Floors.floor_bit(low_floor) | Floors.floor_bit(high_floor)
	for s in [-1.0, 1.0]:
		var rail := StaticBody2D.new()
		rail.collision_layer = rail_bits
		rail.collision_mask = 0
		rail.position = Vector2(s * (size.x * 0.5 + RAIL_W * 0.5 + 2.0), -size.y * 0.25)
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(RAIL_W, size.y * 0.5)
		col.shape = shape
		rail.add_child(col)
		add_child(rail)
	queue_redraw()

func _draw() -> void:
	var half := size * 0.5
	var step_h := size.y / SHADE_STEPS
	for i in SHADE_STEPS:
		var t := float(i) / float(SHADE_STEPS - 1)  # 0 = high end, 1 = low end
		var band := Rect2(Vector2(-half.x, -half.y + i * step_h), Vector2(size.x, step_h + 1.0))
		draw_rect(band, Color(1.0, 1.0, 1.0, HILITE_A * (1.0 - t)))
		draw_rect(band, Color(0.0, 0.0, 0.0, SHADOW_A * t))
	# Rail faces along the high half (the painted side of the invisible statics).
	var rail_x := half.x + 2.0
	draw_rect(Rect2(Vector2(-rail_x - RAIL_W, -half.y), Vector2(RAIL_W, size.y * 0.5)), EDGE)
	draw_rect(Rect2(Vector2(rail_x, -half.y), Vector2(RAIL_W, size.y * 0.5)), EDGE)
	draw_rect(Rect2(-half, size), EDGE, false, 2.0)
	# Up-slope chevrons along the centerline.
	var chevrons := maxi(int(size.y / 112.0), 2)
	for i in chevrons:
		var cy := -half.y + size.y * (float(i) + 0.5) / chevrons
		draw_polyline(PackedVector2Array([
			Vector2(-11.0, cy + 7.0), Vector2(0.0, cy - 7.0), Vector2(11.0, cy + 7.0),
		]), CHEVRON, 3.0)
