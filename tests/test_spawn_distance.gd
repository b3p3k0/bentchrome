extends RefCounted
## Spawn hygiene: no campaign level may bake an enemy within MIN_DIST of the
## player's start — spawn ambushes are a bug, not a difficulty knob. Reads
## baked positions off instantiated (never tree-entered) scenes, so no physics,
## no re-roll, no _ready side effects.

const MIN_DIST := 700.0
const CAMPAIGN := [
	"res://levels/arena/arena.tscn",
	"res://levels/freeway/freeway.tscn",
	"res://levels/suburbs/suburbs.tscn",
	"res://levels/snowy/snowy.tscn",
	"res://levels/depot/depot.tscn",
	"res://levels/dock/dock.tscn",
	"res://levels/chase/buzzard_run.tscn",
	"res://levels/construction/ground_floor_gore.tscn",
	"res://levels/stadium/stadium.tscn",
	"res://levels/tutorial/drivers_ed.tscn",  # zero enemies — instantiate coverage
]

var t

class SpawnCar extends Node2D:
	var heading := 0.0
	var fixed_loadout := false

func _init(runner) -> void:
	t = runner

## Every combatant boots aimed at the fight: headings land on the spawn
## centroid, bosses keep their authored entrance, and sub-2-car scenes
## (Driver's Ed, the chase) stand down entirely.
func test_spawns_face_the_centroid() -> void:
	var CombatLevel := preload("res://levels/combat_level.gd")
	var west := SpawnCar.new()
	west.position = Vector2(-1000, 0)
	var east := SpawnCar.new()
	east.position = Vector2(1000, 0)
	east.heading = 1.0  # authored junk — must be overwritten
	var north := SpawnCar.new()
	north.position = Vector2(0, -1000)
	CombatLevel.face_spawns_inward([west, east, north])
	# centroid = (0, -333.3): west aims east-and-up, east aims west-and-up,
	# north aims straight down at it.
	t.check(absf(angle_difference(west.heading, Vector2(1000, -333.3333).angle())) < 0.01,
		"facing: west car aims at the centroid")
	t.check(absf(angle_difference(east.heading, Vector2(-1000, -333.3333).angle())) < 0.01,
		"facing: east car aims at the centroid")
	t.check(absf(angle_difference(north.heading, Vector2(0, 666.6667).angle())) < 0.01,
		"facing: north car aims back down at the fight")
	var boss := SpawnCar.new()
	boss.position = Vector2(500, 0)
	boss.fixed_loadout = true
	boss.heading = 2.5
	var challenger := SpawnCar.new()
	challenger.position = Vector2(-500, 0)
	CombatLevel.face_spawns_inward([boss, challenger])
	t.check(is_equal_approx(boss.heading, 2.5),
		"facing: fixed_loadout boss keeps its authored entrance")
	t.check(absf(angle_difference(challenger.heading, 0.0)) < 0.01,
		"facing: the challenger aims square at the boss duel centroid")
	var loner := SpawnCar.new()
	loner.heading = -PI / 2.0
	CombatLevel.face_spawns_inward([loner])
	t.check(is_equal_approx(loner.heading, -PI / 2.0),
		"facing: single-car scenes keep authored headings")
	for n in [west, east, north, boss, challenger, loner]:
		n.free()
	# The knob ships ON: inward facing is the routine default, and a specialty
	# level opts OUT in its design — never the other way around.
	var shell = CombatLevel.new()
	t.check(bool(shell.face_spawns), "facing: face_spawns defaults true on the shell")
	shell.free()

func test_no_enemy_spawns_on_the_player() -> void:
	for path in CAMPAIGN:
		var scene: Node = (load(path) as PackedScene).instantiate()
		var player: Node2D = scene.get_node_or_null("Vehicle")
		t.check(player != null, "%s has a Vehicle spawn" % path.get_file())
		if player == null:
			scene.free()
			continue
		for child in scene.get_children():
			if not (child is Node2D and String(child.name).begins_with("Enemy")):
				continue
			var d: float = child.position.distance_to(player.position)
			t.check(d >= MIN_DIST, "%s %s spawns %.0fpx from player (min %d)" %
				[path.get_file(), child.name, d, MIN_DIST])
		scene.free()
