extends Label
## The one floating HP readout: a Label bound to a Health that rewrites itself
## on every hit. Target dummies carry it in their scene; the shooting gallery's
## target lanes attach one per spawned car. Preload by path — no class_name.

var _health: Node = null

## Follow this Health: refresh now and on every `damaged` tick. Rebinding to
## the same Health is harmless (no duplicate connections).
func bind(health: Node) -> void:
	_health = health
	if not health.damaged.is_connected(_on_changed):
		health.damaged.connect(_on_changed)
	refresh()

func refresh() -> void:
	if _health == null:
		return
	text = "%d" % roundi(_health.hp)

func _on_changed(_amount: float, _hp: float) -> void:
	refresh()

## Build a label above `parent` (text centered on its origin, top edge at `y`),
## bind it to `health`, parent it, and hand it back. Zero-width rect + grow
## BOTH keeps the text centered however many digits it shows.
static func attach(parent: Node, health: Node, y: float) -> Label:
	var script: Script = load("res://environment/hp_label.gd")
	var label: Label = script.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = y
	parent.add_child(label)
	label.bind(health)
	return label
