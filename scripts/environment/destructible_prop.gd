extends Area2D

@export var max_hits: int = 3
@export var collision_damage_override: Variant = null
@export var blocker_collision_layer: int = 1
@export var blocker_collision_mask: int = 0
@export var outline_color: Color = Color(0.24, 0.12, 0.04, 1)
@export var outline_width: float = 6.0

var current_hits: int
var blocker: StaticBody2D
var blocker_shape: CollisionShape2D
var outline: Line2D

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var polygon: Polygon2D = get_node_or_null("Polygon2D")

func _ready():
	add_to_group("destructible")
	current_hits = max_hits
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_ensure_blocker()
	_ensure_outline()

func _ensure_blocker():
	if has_node("Blocker"):
		blocker = get_node("Blocker")
	else:
		blocker = StaticBody2D.new()
		blocker.name = "Blocker"
		blocker.collision_layer = blocker_collision_layer
		blocker.collision_mask = blocker_collision_mask
		add_child(blocker, false, Node.INTERNAL_MODE_BACK)

	blocker_shape = blocker.get_node_or_null("CollisionShape2D")
	if blocker_shape == null:
		blocker_shape = CollisionShape2D.new()
		blocker_shape.name = "CollisionShape2D"
		blocker.add_child(blocker_shape)

	if collision_shape and blocker_shape:
		blocker_shape.shape = collision_shape.shape
		blocker_shape.position = collision_shape.position
		blocker_shape.rotation = collision_shape.rotation
		blocker_shape.disabled = false

func _ensure_outline():
	outline = get_node_or_null("Outline")
	if outline == null:
		outline = Line2D.new()
		outline.name = "Outline"
		outline.closed = true
		outline.joint_mode = Line2D.JOIN_BEVEL
		outline.begin_cap_mode = Line2D.LINE_CAP_BOX
		outline.end_cap_mode = Line2D.LINE_CAP_BOX
		add_child(outline)

	_update_outline()

func _update_outline():
	if outline == null:
		return

	outline.width = outline_width
	outline.default_color = outline_color
	var points := PackedVector2Array()

	if collision_shape and collision_shape.shape is RectangleShape2D:
		var extents: Vector2 = collision_shape.shape.extents
		points.push_back(Vector2(-extents.x, -extents.y))
		points.push_back(Vector2(extents.x, -extents.y))
		points.push_back(Vector2(extents.x, extents.y))
		points.push_back(Vector2(-extents.x, extents.y))
		outline.position = collision_shape.position
		outline.rotation = collision_shape.rotation
	elif polygon:
		points = polygon.polygon
		outline.position = polygon.position
		outline.rotation = polygon.rotation

	if points.size() > 0:
		outline.points = points
		outline.z_index = max(outline.z_index, 1)

func apply_damage(amount: int = 1) -> bool:
	if amount <= 0 or current_hits <= 0:
		return false

	current_hits -= amount
	if current_hits <= 0:
		_destroy()
		return true
	return false

func apply_collision_damage(amount: int = 1) -> bool:
	var damage = collision_damage_override if collision_damage_override != null else amount
	return apply_damage(damage)

func _destroy():
	if blocker_shape:
		blocker_shape.set_deferred("disabled", true)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	queue_free()

func _on_body_entered(body):
	if body.is_in_group("destructible"):
		return
	apply_collision_damage()

func _on_area_entered(area):
	if area.is_in_group("destructible"):
		return
	apply_collision_damage()
