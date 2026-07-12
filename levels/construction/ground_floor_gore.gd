extends "res://levels/combat_level.gd"
## Ground Floor Gore's level shell: the shared combat loop plus the rainy-dusk
## treatment — CanvasModulate tint, night_arena membership (explosions bloom,
## floodlights read), and a glow pool on the viewer's car in SP and MP alike.

const LightKit := preload("res://environment/light_kit.gd")

const DUSK_TINT := Color(0.62, 0.65, 0.78)
const GLOW_RADIUS := 320.0
const GLOW_ENERGY := 0.6
const GLOW_COLOR := Color(0.85, 0.9, 1.0)

var _glow: PointLight2D

func _ready() -> void:
	super()
	var tint := get_node_or_null(^"DuskTint") as CanvasModulate
	if tint:
		tint.color = DUSK_TINT
		tint.add_to_group(&"night_arena")
	if mp_managed:
		set_process(true)  # parent stood down; the lazy glow attach still runs

func _process(delta: float) -> void:
	super(delta)
	var viewer := _local_viewer()
	if viewer == null:
		return
	if _glow == null or not is_instance_valid(_glow) or _glow.get_parent() != viewer:
		_attach_glow(viewer)

## The car the glow belongs to: whichever combatant is marked as this
## screen's viewer (SP marks the solo player; the MP shell marks per peer).
func _local_viewer() -> Node2D:
	for node in get_tree().get_nodes_in_group(&"local_player"):
		if node is Node2D and is_instance_valid(node):
			return node
	return null

func _attach_glow(car: Node2D) -> void:
	if _glow and is_instance_valid(_glow):
		_glow.queue_free()
	_glow = LightKit.make_light(GLOW_RADIUS, GLOW_ENERGY, GLOW_COLOR)
	car.add_child(_glow)
