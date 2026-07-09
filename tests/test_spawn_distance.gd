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
]

var t

func _init(runner) -> void:
	t = runner

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
