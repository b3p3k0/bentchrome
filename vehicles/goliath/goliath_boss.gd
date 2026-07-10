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
const CutsceneScript := preload("res://vehicles/goliath/goliath_cutscene.gd")
const PH2_STATS := preload("res://data/vehicles/goliath_ph2.tres")

static var PHASE1_HP := 1400.0    # the trailered fortress pool — big enough
								  # to be a siege, small enough that every
								  # volley visibly moves the bar
static var PHASE2_HP := 900.0     # the fresh bobtail pool
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
	# The gate fires inside a physics callback (projectile signal) — the
	# theatrics wait for the flush before pausing the world.
	call_deferred("_begin_transition")

## The staged flip when there's someone to stage it FOR; a dead/respawning
## player skips the theatre and gets phase 2 hot when they come back.
func _begin_transition() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	var alive: bool = player != null and is_instance_valid(player) \
		and player.has_method(&"get_hp") and player.get_hp() > 0.0
	if alive and _cab and is_instance_valid(_cab):
		var director := CutsceneScript.new()
		director.name = "GoliathCutscene"
		_cab.get_parent().add_child(director)
		director.run(self, _cab, trailer)
	else:
		if trailer and is_instance_valid(trailer):
			trailer.queue_free()
		start_phase2()

## Bobtail: fresh pool, feel deck swapped on the CONTROLLER only (set_stats
## would repaint the body and reset HP from armor), immortality off. The HUD
## bar simply refills — it polls get_hp_fraction.
func start_phase2() -> void:
	phase = 2
	trailer = null  # the cutscene (or the instant path) already freed it
	if _health:
		_health.god = false
		_health.max_hp = PHASE2_HP
		_health.hp = PHASE2_HP
	if _cab and is_instance_valid(_cab) and _cab.has_method(&"get_controller"):
		var ctrl = _cab.get_controller()
		if ctrl:
			StatCurves.apply(PH2_STATS, ctrl, null)
