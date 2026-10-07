extends Node
## Brings the gallery's destructible cover back: every member of `watch_group`
## that speaks the arena-state seam (`apply_arena_state`) and carries a Health
## child is revived `delay` seconds after it dies — layer, paint, and HP
## restored through the same call LAN resurrection uses. Props outside the
## group are never touched. Collection is deferred one frame so every sibling
## has finished _ready and joined its groups.

@export var watch_group: StringName = &"gallery_reset"
@export var delay := 6.0

func _ready() -> void:
	_collect.call_deferred()

func _collect() -> void:
	if not is_inside_tree():
		return
	for prop in get_tree().get_nodes_in_group(watch_group):
		if not prop.has_method(&"apply_arena_state"):
			continue
		var health: Node = prop.get_node_or_null(^"Health")
		if health == null:
			continue
		health.died.connect(_on_prop_died.bind(prop))

func _on_prop_died(prop: Node) -> void:
	get_tree().create_timer(delay).timeout.connect(_revive.bind(prop))

## The prop may have left with its scene meanwhile — guard both ends.
func _revive(prop: Node) -> void:
	if not is_inside_tree() or not is_instance_valid(prop):
		return
	prop.apply_arena_state({"flags": 1, "hp": 1.0}, false)
