extends StaticBody2D
## A stationary target with Health, for combat testing. Shows its HP and frees
## itself on death. Faction "enemies" so the player damages it and enemy fire
## passes through.

@export var faction: StringName = &"enemies"

@onready var _health: Health = $Health
@onready var _label: Label = $Label

func _ready() -> void:
	_health.damaged.connect(_on_changed)
	_health.died.connect(queue_free)
	_refresh()

func _on_changed(_amount: float, _hp: float) -> void:
	_refresh()

func _refresh() -> void:
	_label.text = "%d" % roundi(_health.hp)
