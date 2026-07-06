extends StaticBody2D
## A destructible obstacle: block semantics (layer 4 — airborne cars and
## cover-piercing shots ignore it) plus Health, so weapons fire and ramming
## can break it open. Frees itself on death. Size and HP are per-instance
## exports so one scene serves park kiosks, alley crates, and wall segments.

const BASE_COLOR := Color(0.45, 0.38, 0.28)     # crate-brown vs the cold gray of solid blocks
const WRECKED_COLOR := Color(0.22, 0.18, 0.14)  # battered toward rubble as HP falls

@export var size := Vector2(96, 96)
@export var max_hp := 80.0

@onready var _health: Health = $Health
@onready var _vis: Polygon2D = $Vis

func _ready() -> void:
	var half := size * 0.5
	_vis.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	_vis.color = BASE_COLOR
	var shape := RectangleShape2D.new()
	shape.size = size
	($Col as CollisionShape2D).shape = shape
	# Health (child) readies before this node — set hp along with max_hp.
	_health.max_hp = max_hp
	_health.hp = max_hp
	_health.damaged.connect(_on_damaged)
	_health.died.connect(queue_free)

func _on_damaged(_amount: float, hp: float) -> void:
	_vis.color = BASE_COLOR.lerp(WRECKED_COLOR, 1.0 - hp / max_hp)
