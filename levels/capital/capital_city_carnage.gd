extends "res://levels/combat_level.gd"
## Capital City Carnage's level shell: the shared combat loop plus the
## thunderstorm treatment. The StormDirector scene node owns the tint and
## the strike cycle (its StormTint joins night_arena, so explosions bloom
## and the monument floods read); this subclass only adds HEADLIGHT BEAMS
## on every combatant, SP and MP alike — storm-dark streets demand them.

const LightKit := preload("res://environment/light_kit.gd")

const BEAM_NOSE := 38.0
const BEAM_LENGTH := 460.0
const BEAM_SPREAD := 56.0
const BEAM_ENERGY := 0.7
const BEAM_VIEWER := Color(0.85, 0.9, 1.0)
const BEAM_OTHERS := Color(1.0, 0.9, 0.7)

func _ready() -> void:
	super()
	if mp_managed:
		set_process(true)  # parent stood down; the lazy beam attach still runs

## The GFG beam seam verbatim: group-scan attach covers SP boot, the enemy
## re-roll, respawns, and MP shell spawns; the beam rides the car's Visual
## (the 16-step quantized heading carrier — the root never rotates).
func _process(delta: float) -> void:
	super(delta)
	for node in get_tree().get_nodes_in_group(&"vehicles"):
		if not node is Node2D:
			continue
		var car := node as Node2D
		var beam: PointLight2D = null
		if car.has_meta(&"cap_beam"):
			beam = car.get_meta(&"cap_beam") as PointLight2D
		if beam == null or not is_instance_valid(beam):
			beam = LightKit.make_beam(BEAM_LENGTH, BEAM_SPREAD, BEAM_ENERGY, BEAM_OTHERS)
			beam.position = Vector2(BEAM_NOSE + float(beam.get_meta(&"center_ahead")), 0.0)
			var visual := car.get_node_or_null(^"Visual")
			if visual:
				visual.add_child(beam)
			else:
				car.add_child(beam)
			car.set_meta(&"cap_beam", beam)
		beam.color = BEAM_VIEWER if car.is_in_group(&"local_player") else BEAM_OTHERS
