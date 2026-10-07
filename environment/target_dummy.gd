extends StaticBody2D
## A stationary target with Health, for combat testing. Shows its HP and frees
## itself on death — or, with respawn_seconds > 0, drops out of the world for
## that long and comes back at full HP (the shooting gallery). Free-for-all,
## so anyone's fire damages it.

const HpLabel := preload("res://environment/hp_label.gd")

@export var respawn_seconds := 0.0  # 0 = freed on death (classic); >0 = hide, wait, come back

@onready var _health: Health = $Health
@onready var _label: HpLabel = $Label
@onready var _col: CollisionShape2D = $Col

func _ready() -> void:
	add_to_group(&"dummies")  # radar shows them as faint practice contacts
	_label.bind(_health)
	if respawn_seconds > 0.0:
		_health.died.connect(_on_died)
	else:
		_health.died.connect(queue_free)

## Death with a respawn: vanish from sight, physics, and the radar group, then
## come back whole after the delay. The timer fires through a scene swap, so
## the callback checks it still has a world to return to.
func _on_died() -> void:
	hide()
	_col.set_deferred("disabled", true)
	remove_from_group(&"dummies")
	get_tree().create_timer(respawn_seconds).timeout.connect(_respawn)

func _respawn() -> void:
	if not is_inside_tree():
		return
	_health.hp = _health.max_hp
	_col.set_deferred("disabled", false)
	show()
	add_to_group(&"dummies")
	_label.refresh()
