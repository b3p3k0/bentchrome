extends "res://levels/combat_level.gd"
## Ground Floor Gore's level shell: the shared combat loop plus the rainy-dusk
## treatment — CanvasModulate tint, night_arena membership (explosions bloom,
## floodlights read), and HEADLIGHT BEAMS on every combatant, SP and MP alike.

const LightKit := preload("res://environment/light_kit.gd")

const DUSK_TINT := Color(0.62, 0.65, 0.78)
const BEAM_NOSE := 38.0
const BEAM_LENGTH := 460.0
const BEAM_SPREAD := 56.0
const BEAM_ENERGY := 0.7
const BEAM_VIEWER := Color(0.85, 0.9, 1.0)
const BEAM_OTHERS := Color(1.0, 0.9, 0.7)

func _ready() -> void:
	super()
	var tint := get_node_or_null(^"DuskTint") as CanvasModulate
	if tint:
		tint.color = DUSK_TINT
		tint.add_to_group(&"night_arena")
	if mp_managed:
		set_process(true)  # parent stood down; the lazy beam attach still runs

## Every car on the site drives with headlights; the viewer's burn cool-white
## so their ride reads instantly. Group-scan attach covers SP boot, the enemy
## re-roll, respawns, and MP shell spawns with one seam. The beam rides the
## car's Visual child — the node that carries the 16-step quantized heading
## (net puppets included); the car root never rotates.
func _process(delta: float) -> void:
	super(delta)
	for node in get_tree().get_nodes_in_group(&"vehicles"):
		if not node is Node2D:
			continue
		var car := node as Node2D
		var beam: PointLight2D = null
		if car.has_meta(&"gfg_beam"):
			beam = car.get_meta(&"gfg_beam") as PointLight2D
		if beam == null or not is_instance_valid(beam):
			beam = LightKit.make_beam(BEAM_LENGTH, BEAM_SPREAD, BEAM_ENERGY, BEAM_OTHERS)
			beam.position = Vector2(BEAM_NOSE + float(beam.get_meta(&"center_ahead")), 0.0)
			var visual := car.get_node_or_null(^"Visual")
			if visual:
				visual.add_child(beam)
			else:
				car.add_child(beam)
			car.set_meta(&"gfg_beam", beam)
		# Color refreshes every scan: the MP shell may mark local_player a beat
		# after the car spawns, and SP re-rolls keep the node.
		beam.color = BEAM_VIEWER if car.is_in_group(&"local_player") else BEAM_OTHERS
