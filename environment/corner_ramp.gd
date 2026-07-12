class_name CornerRamp
extends Node2D
## The diagonal facet between two cardinal grades. Local convention:
## (0,0) is the HIGH right-angle vertex; (leg,0) and (0,leg) form the LOW
## 45-degree hypotenuse. Rotate the node to place any terrace corner.

const FloorZoneScene := preload("res://environment/floor_zone.tscn")
const TERRAIN_PRIORITY := Ramp.TERRAIN_PRIORITY
const BANDS := 5
const EDGE := Color(0.55, 0.55, 0.62)

@export var low_floor := 2
@export var high_floor := 3
@export_range(64.0, 1024.0, 16.0) var leg_size := 240.0
@export_enum("road", "grass", "snow", "dirt", "ice", "water") \
	var terrain_type := "road"
@export var surface_color := Color(0.16, 0.16, 0.19)
@export_range(1.0, 600.0, 1.0) var downhill_pull := Ramp.DEFAULT_DOWNHILL_PULL

var _grade_area: Area2D = null

func _ready() -> void:
	_add_floor_zones()
	_add_terrain_override()
	_add_grade_area()
	set_physics_process(true)
	queue_redraw()

func footprint() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO, Vector2(leg_size, 0.0), Vector2(0.0, leg_size),
	])

func high_polygon() -> PackedVector2Array:
	var half := leg_size * 0.5
	return PackedVector2Array([Vector2.ZERO, Vector2(half, 0.0), Vector2(0.0, half)])

func low_polygon() -> PackedVector2Array:
	var half := leg_size * 0.5
	return PackedVector2Array([
		Vector2(half, 0.0), Vector2(leg_size, 0.0),
		Vector2(0.0, leg_size), Vector2(0.0, half),
	])

func _add_floor_zones() -> void:
	for cfg in [
		{"name": "HighFloor", "floor": high_floor, "polygon": high_polygon()},
		{"name": "LowFloor", "floor": low_floor, "polygon": low_polygon()},
	]:
		var zone := FloorZoneScene.instantiate() as FloorZone
		zone.name = cfg.name
		zone.floor_index = cfg.floor
		zone.ramp = true
		zone.polygon = cfg.polygon
		add_child(zone)

func _add_terrain_override() -> void:
	var holder := Node2D.new()
	holder.name = "TerrainOverride"
	var zone := TerrainZone.new()
	zone.name = "Terrain"
	zone.terrain_type = StringName(terrain_type)
	zone.terrain_priority = TERRAIN_PRIORITY
	zone.collision_layer = 128
	zone.collision_mask = 0
	var col := CollisionPolygon2D.new()
	col.name = "Col"
	col.polygon = footprint()
	zone.add_child(col)
	holder.add_child(zone)
	add_child(holder)

func _add_grade_area() -> void:
	var mechanics := Node2D.new()
	mechanics.name = "GradeMechanics"
	_grade_area = Area2D.new()
	_grade_area.name = "Area"
	_grade_area.collision_layer = 0
	_grade_area.collision_mask = 1
	var col := CollisionPolygon2D.new()
	col.name = "Col"
	col.polygon = footprint()
	_grade_area.add_child(col)
	mechanics.add_child(_grade_area)
	add_child(mechanics)

func _physics_process(delta: float) -> void:
	if _grade_area == null:
		return
	var impulse := downhill_vector(global_rotation) * downhill_pull * delta
	for body in _grade_area.get_overlapping_bodies():
		if body is CharacterBody2D and body.get("height") == 0.0:
			body.velocity += impulse

static func downhill_vector(world_rotation: float) -> Vector2:
	return Vector2(1.0, 1.0).normalized().rotated(world_rotation)

func _draw() -> void:
	draw_colored_polygon(footprint(), surface_color)
	for i in range(1, BANDS):
		var f := float(i) / float(BANDS)
		var a := Vector2(leg_size * f, 0.0)
		var b := Vector2(0.0, leg_size * f)
		draw_line(a, b, Color(1.0, 1.0, 1.0, 0.12 * (1.0 - f)), 2.0)
	draw_polyline(PackedVector2Array([
		Vector2.ZERO, Vector2(leg_size, 0.0), Vector2(0.0, leg_size), Vector2.ZERO,
	]), EDGE, 2.0)
