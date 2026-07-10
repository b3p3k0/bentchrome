extends Node
## Goliath's boss controller — a child node on the boss vehicle instance
## (depot pattern: boss = data on a stock enemy_vehicle; this node is the one
## addition). Batch B scope: own the trailer's lifecycle — spawn it beside
## the level, pin it to the cab, expose it to the driver. The two-pool phase
## machinery (PHASE1_HP depletion -> cutscene -> bobtail) lands in Batch C/D.
## Duck-typed toward the cab like everything trailer-side.

const TrailerScript := preload("res://vehicles/goliath/goliath_trailer.gd")

var trailer: Node2D = null
var phase := 1

func _ready() -> void:
	# The level root is still assembling during children's _ready — defer so
	# the trailer lands as a finished sibling of the boss, not a boot race.
	call_deferred("_spawn_trailer")

func _spawn_trailer() -> void:
	var cab := get_parent() as CharacterBody2D
	if cab == null:
		return
	var host := cab.get_parent()
	if host == null:
		return
	trailer = TrailerScript.new()
	trailer.name = "GoliathTrailer"
	host.add_child(trailer)
	trailer.attach(cab)
