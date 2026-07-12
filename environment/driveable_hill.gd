@tool
class_name DriveableHill
extends Node2D
## One authoring root for the project's eight-faced hill language. A hill owns
## one continuous clipped-octagon skin, one summit floor/terrain plate, four
## paintless cardinal grades, four derived corner grades, and paired AI routes.
## `grade_length` is the sole slope-depth input: corner legs are ALWAYS half of
## it, eliminating the oversized-corner failure mode.

const FloorZoneScript := preload("res://environment/floor_zone.gd")
const RampScript := preload("res://environment/ramp.gd")
const CornerRampScript := preload("res://environment/corner_ramp.gd")
const ConnectorScript := preload("res://environment/floor_connector.gd")
const TerrainZoneScript := preload("res://environment/terrain_zone.gd")

const GENERATED_NAME := &"_Generated"
const APPROACH_LENGTH := 220.0
const DEFAULT_HILL_PULL := 180.0
const DEFAULT_EDGE := Color(0.38, 0.43, 0.53, 0.5)

@export var summit_size := Vector2(896, 896)
@export_range(64.0, 1024.0, 8.0) var grade_length := 240.0
@export var low_floor := 2
@export var high_floor := 3
@export_enum("road", "grass", "snow", "dirt", "ice", "water") \
	var terrain_type := "road"
@export_range(1.0, 600.0, 1.0) var downhill_pull := DEFAULT_HILL_PULL
@export var substrate_material: Material
@export var terrain_material: Material
@export_range(0.0, 0.4, 0.01) var relief_strength := 0.22
@export_range(1.0, 2.0, 0.01) var projection_compression := 1.55
@export_range(0.0, 0.2, 0.01) var slope_darkening := 0.06
@export var light_direction := Vector2(-1, -1)
@export var shadow_offset := Vector2(12, 14)
@export_range(0.0, 0.4, 0.01) var shadow_alpha := 0.20
@export_range(0.0, 0.2, 0.01) var crest_highlight := 0.10
@export_range(1.0, 64.0, 1.0) var crest_width := 18.0
@export_range(0.0, 0.2, 0.01) var foot_darkening := 0.12
@export_range(1.0, 64.0, 1.0) var foot_width := 20.0
@export_range(0.0, 8.0, 0.5) var edge_width := 2.5
@export var edge_color := DEFAULT_EDGE

var _last_signature := ""

func _ready() -> void:
	_rebuild()
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and _signature() != _last_signature:
		_rebuild()

func corner_leg() -> float:
	return grade_length * 0.5

func outer_size() -> Vector2:
	return summit_size + Vector2.ONE * grade_length

func outer_polygon() -> PackedVector2Array:
	var h := summit_size * 0.5
	var g := corner_leg()
	return PackedVector2Array([
		Vector2(-h.x, -h.y - g), Vector2(h.x, -h.y - g),
		Vector2(h.x + g, -h.y), Vector2(h.x + g, h.y),
		Vector2(h.x, h.y + g), Vector2(-h.x, h.y + g),
		Vector2(-h.x - g, h.y), Vector2(-h.x - g, -h.y),
	])

func _signature() -> String:
	return str([summit_size, grade_length, low_floor, high_floor, terrain_type,
		downhill_pull, substrate_material, terrain_material, relief_strength,
		projection_compression, slope_darkening, light_direction, shadow_offset,
		shadow_alpha, crest_highlight, crest_width, foot_darkening, foot_width,
		edge_width, edge_color])

func _rebuild() -> void:
	if not is_inside_tree():
		return
	var old := get_node_or_null(NodePath(String(GENERATED_NAME)))
	if old:
		remove_child(old)
		old.free()
	var generated := Node2D.new()
	generated.name = GENERATED_NAME
	add_child(generated)
	move_child(generated, 0)  # skin before authored summit content
	_build_visuals(generated)
	_build_summit(generated)
	_build_grades(generated)
	_build_connectors(generated)
	_last_signature = _signature()

func _build_visuals(parent: Node2D) -> void:
	var poly := outer_polygon()
	var shadow := Polygon2D.new()
	shadow.name = "ContactShadow"
	shadow.position = shadow_offset
	shadow.polygon = poly
	shadow.color = Color(0, 0, 0, shadow_alpha)
	parent.add_child(shadow)

	var substrate := Polygon2D.new()
	substrate.name = "Substrate"
	substrate.polygon = poly
	substrate.material = _material_copy(substrate_material, false)
	parent.add_child(substrate)

	var surface := Polygon2D.new()
	surface.name = "Surface"
	surface.polygon = poly
	surface.material = _material_copy(terrain_material, true)
	parent.add_child(surface)

	if edge_width > 0.0:
		var edge := Line2D.new()
		edge.name = "Edge"
		edge.points = poly + PackedVector2Array([poly[0]])
		edge.width = edge_width
		edge.default_color = edge_color
		parent.add_child(edge)

func _material_copy(source: Material, relief: bool) -> Material:
	if source == null:
		return null
	var copy := source.duplicate() as Material
	if copy is ShaderMaterial:
		var shader_mat := copy as ShaderMaterial
		shader_mat.set_shader_parameter("relief_enabled", relief)
		if relief:
			shader_mat.set_shader_parameter("relief_summit_half", summit_size * 0.5)
			shader_mat.set_shader_parameter("relief_grade_half", corner_leg())
			shader_mat.set_shader_parameter("relief_strength", relief_strength)
			shader_mat.set_shader_parameter("relief_projection", projection_compression)
			shader_mat.set_shader_parameter("relief_slope_darkening", slope_darkening)
			shader_mat.set_shader_parameter("relief_light_dir",
				light_direction.normalized() if light_direction != Vector2.ZERO else Vector2(-1, -1).normalized())
			shader_mat.set_shader_parameter("relief_crest", crest_highlight)
			shader_mat.set_shader_parameter("relief_crest_width", crest_width)
			shader_mat.set_shader_parameter("relief_foot", foot_darkening)
			shader_mat.set_shader_parameter("relief_foot_width", foot_width)
	return copy

func _build_summit(parent: Node2D) -> void:
	var floor_zone := FloorZoneScript.new() as FloorZone
	floor_zone.name = "SummitFloor"
	floor_zone.floor_index = high_floor
	floor_zone.size = summit_size
	parent.add_child(floor_zone)

	var terrain := TerrainZoneScript.new() as TerrainZone
	terrain.name = "SummitTerrain"
	terrain.terrain_type = StringName(terrain_type)
	terrain.terrain_priority = Ramp.TERRAIN_PRIORITY
	terrain.collision_layer = 128
	terrain.collision_mask = 0
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = summit_size
	col.shape = shape
	terrain.add_child(col)
	parent.add_child(terrain)

func _build_grades(parent: Node2D) -> void:
	var h := summit_size * 0.5
	_add_ramp(parent, "RampNorth", Vector2(0, -h.y), PI, summit_size.x)
	_add_ramp(parent, "RampSouth", Vector2(0, h.y), 0.0, summit_size.x)
	_add_ramp(parent, "RampWest", Vector2(-h.x, 0), PI * 0.5, summit_size.y)
	_add_ramp(parent, "RampEast", Vector2(h.x, 0), -PI * 0.5, summit_size.y)
	_add_corner(parent, "CornerNW", Vector2(-h.x, -h.y), PI)
	_add_corner(parent, "CornerNE", Vector2(h.x, -h.y), -PI * 0.5)
	_add_corner(parent, "CornerSE", Vector2(h.x, h.y), 0.0)
	_add_corner(parent, "CornerSW", Vector2(-h.x, h.y), PI * 0.5)

func _add_ramp(parent: Node2D, node_name: String, pos: Vector2,
		rot: float, width: float) -> void:
	var ramp := RampScript.new() as Ramp
	ramp.name = node_name
	ramp.position = pos
	ramp.rotation = rot
	ramp.low_floor = low_floor
	ramp.high_floor = high_floor
	ramp.size = Vector2(width, grade_length)
	ramp.surface_paint = false
	ramp.rails = false
	ramp.terrain_type = terrain_type
	ramp.downhill_pull = downhill_pull
	parent.add_child(ramp)

func _add_corner(parent: Node2D, node_name: String, pos: Vector2, rot: float) -> void:
	var corner := CornerRampScript.new() as CornerRamp
	corner.name = node_name
	corner.position = pos
	corner.rotation = rot
	corner.low_floor = low_floor
	corner.high_floor = high_floor
	corner.leg_size = corner_leg()
	corner.terrain_type = terrain_type
	corner.surface_paint = false
	corner.downhill_pull = downhill_pull
	parent.add_child(corner)

func _build_connectors(parent: Node2D) -> void:
	var h := summit_size * 0.5
	var corners := [
		["North", Vector2(0, -h.y), Vector2.DOWN],
		["South", Vector2(0, h.y), Vector2.UP],
		["West", Vector2(-h.x, 0), Vector2.RIGHT],
		["East", Vector2(h.x, 0), Vector2.LEFT],
	]
	for spec in corners:
		_add_connector_pair(parent, spec[0], spec[1], spec[2])
	var seam := corner_leg() * 0.25
	var diagonals := [
		["NW", Vector2(-h.x - seam, -h.y - seam), Vector2(1, 1).normalized()],
		["NE", Vector2(h.x + seam, -h.y - seam), Vector2(-1, 1).normalized()],
		["SE", Vector2(h.x + seam, h.y + seam), Vector2(-1, -1).normalized()],
		["SW", Vector2(-h.x - seam, h.y + seam), Vector2(1, -1).normalized()],
	]
	for spec in diagonals:
		_add_connector_pair(parent, spec[0], spec[1], spec[2])

func _add_connector_pair(parent: Node2D, label: String, pos: Vector2,
		up_dir: Vector2) -> void:
	_add_connector(parent, "Con%sGradeUp" % label, pos, low_floor, high_floor, up_dir)
	_add_connector(parent, "Con%sGradeDown" % label, pos, high_floor, low_floor, -up_dir)

func _add_connector(parent: Node2D, node_name: String, pos: Vector2,
		from: int, to: int, approach: Vector2) -> void:
	var connector := ConnectorScript.new() as FloorConnector
	connector.name = node_name
	connector.position = pos
	connector.from_floor = from
	connector.to_floor = to
	connector.approach_dir = approach
	connector.kind = &"grade"
	parent.add_child(connector)
