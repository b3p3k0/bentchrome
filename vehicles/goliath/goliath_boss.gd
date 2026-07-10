extends Node
## Goliath's boss controller — a child node on the boss vehicle instance
## (depot pattern: boss = data on a stock enemy_vehicle; this node is the one
## addition). Owns the trailer's lifecycle and the TWO-POOL phase machinery:
## the cab's Health is overridden to PHASE1_HP, and when that pool depletes
## the damaged handler trips the gate INSIDE the same synchronous
## take_damage call — the sentinel refill lands before health.gd's hp<=0
## died check, so the boss never dies at the transition. god holds him
## immortal until Batch D's cutscene re-pools him for bobtail phase 2.
## Duck-typed toward the cab like everything trailer-side.

const TrailerScript := preload("res://vehicles/goliath/goliath_trailer.gd")

static var PHASE1_HP := 2200.0    # the trailered fortress pool
static var PHASE2_HP := 900.0     # the bobtail pool (consumed by Batch D)
static var PHASE1_END_HP := 1.0   # at-or-below trips the transition

var trailer: Node2D = null
var phase := 1

var _cab: CharacterBody2D = null
var _health: Health = null

func _ready() -> void:
	# The level root is still assembling during children's _ready — defer so
	# the trailer lands as a finished sibling of the boss, not a boot race.
	# (Deferral also means the pool override lands AFTER the cab's stats
	# apply, so armor-derived HP never overwrites it.)
	call_deferred("_setup")

func _setup() -> void:
	var cab := get_parent() as CharacterBody2D
	if cab == null:
		return
	var host := cab.get_parent()
	if host == null:
		return
	_cab = cab
	trailer = TrailerScript.new()
	trailer.name = "GoliathTrailer"
	host.add_child(trailer)
	trailer.attach(cab)
	_health = cab.get_node_or_null(^"Health") as Health
	if _health:
		_health.max_hp = PHASE1_HP
		_health.hp = PHASE1_HP
		_health.damaged.connect(_on_cab_damaged)

func _on_cab_damaged(_amount: float, hp: float) -> void:
	if phase != 1 or hp > PHASE1_END_HP:
		return
	phase = 2
	_health.god = true       # immortal while the transition pends
	_health.hp = PHASE1_HP   # sentinel: beats take_damage's died check
	# Batch D replaces this stub with the cutscene -> start_phase2 chain.
	print("[goliath] phase 1 depleted — transition pending (Batch D)")
