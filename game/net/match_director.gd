class_name MatchDirector
extends Node
## Host-only rules engine for MP matches. This card: the seat-car registry and
## the death -> respawn loop (farthest derived spawn, blink shield). Formats,
## caps, got-next rotation, kill attribution, and the scoreboard land in C9 —
## this node is where they will live.

static var RESPAWN_DELAY := 1.6
static var SHIELD_TIME := 2.0

var spawns: Array = []  # [{pos, heading, floor}] from the arena's baked cars
var cars := {}          # peer_id -> Vehicle (seated humans; AI runs itself)
var _pending := {}      # peer_id -> true while a respawn timer runs

func register_car(peer_id: int, car: Node) -> void:
	cars[peer_id] = car

func unregister_car(peer_id: int) -> void:
	cars.erase(peer_id)
	_pending.erase(peer_id)

func _physics_process(_delta: float) -> void:
	for id in cars:
		var car: Node = cars[id]
		if car == null or not is_instance_valid(car) or _pending.has(id):
			continue
		if car.get_hp() <= 0.0:
			_pending[id] = true
			get_tree().create_timer(RESPAWN_DELAY).timeout.connect(
				_respawn.bind(int(id)), CONNECT_ONE_SHOT)

func _respawn(id: int) -> void:
	_pending.erase(id)
	var car: Node = cars.get(id)
	if car == null or not is_instance_valid(car):
		return
	var spot := farthest_spawn()
	if spot.is_empty():
		return
	car.respawn(spot.pos, spot.heading, SHIELD_TIME)

## The locked respawn rule: the derived spawn farthest from every living
## combatant — no spawning into someone's crosshairs.
func farthest_spawn() -> Dictionary:
	if spawns.is_empty():
		return {}
	var living: Array = []
	for v in get_tree().get_nodes_in_group(&"vehicles"):
		if is_instance_valid(v) and v.get_hp() > 0.0:
			living.append(v)
	var best: Dictionary = spawns[0]
	var best_d := -1.0
	for spot in spawns:
		var nearest := INF
		for v in living:
			var d: float = (spot.pos as Vector2).distance_to(v.global_position)
			nearest = minf(nearest, d)
		if living.is_empty():
			nearest = 0.0
		if nearest > best_d:
			best_d = nearest
			best = spot
	return best
