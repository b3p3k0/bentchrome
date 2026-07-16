class_name AIFightDirector
extends Node
## Scene-local arena coordinator. It gives one ordinary EnemyDriver (two in a
## large field) the player spotlight while the rest keep selling the free-for-
## all. Authority stays wherever simulation already lives: SP/custom arenas
## run it locally; Grand Melee attaches it on the host only.

static var FOCUS_REFRESH := 0.25
static var FOCUS_LEASE_TIME := 8.0
static var FOCUS_TWO_AT := 5

var arena_root: Node = null
var _clock := 0.0
var _refresh_t := 0.0
var _leases: Array[Dictionary] = []  # {car, driver, player, expires}
var _last_focus: Dictionary = {}     # driver instance id -> coordinator time

func setup(root: Node) -> void:
	arena_root = root

func _ready() -> void:
	if arena_root == null:
		arena_root = get_parent()
	refresh_now()

func _physics_process(delta: float) -> void:
	_clock += delta
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		refresh_now()

## Public deterministic seam for unit tests and arena setup.
func refresh_now() -> void:
	_refresh_t = FOCUS_REFRESH
	var players: Array[Node2D] = _players()
	var cars: Array[Node2D] = _ordinary_cars()
	_prune_leases(players, cars)
	var wanted := mini(2 if cars.size() >= FOCUS_TWO_AT else 1, cars.size())
	wanted = mini(wanted, players.size()) if players.size() > 1 else wanted
	while _leases.size() < wanted and not players.is_empty():
		var player: Node2D = _least_covered_player(players)
		var car: Node2D = _next_car(cars, player)
		if car == null:
			break
		var driver: Node = car.get_driver()
		_leases.append({
			"car": car,
			"driver": driver,
			"player": player,
			"expires": _clock + FOCUS_LEASE_TIME,
		})
		_last_focus[driver.get_instance_id()] = _clock
	_apply_assignments(cars)

func focus_count() -> int:
	return _leases.size()

func _players() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if arena_root == null or not is_instance_valid(arena_root):
		return out
	for node in arena_root.get_tree().get_nodes_in_group(&"player"):
		if node is Node2D and _in_arena(node) and _is_alive(node):
			out.append(node)
	return out

func _ordinary_cars() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if arena_root == null or not is_instance_valid(arena_root):
		return out
	for node in arena_root.get_tree().get_nodes_in_group(&"vehicles"):
		if not (node is Node2D) or node.is_in_group(&"player") or not _in_arena(node):
			continue
		if not _is_alive(node) or not node.has_method(&"get_driver"):
			continue
		var driver: Variant = node.get_driver()
		if driver == null or not driver.has_method(&"set_focus_assignment"):
			continue  # Goliath/Buzzard/other bespoke drivers are not ordinary mooks
		if bool(driver.get("relentless")) or bool(node.get("fixed_loadout")):
			continue  # Lackey and future fixed-loadout bosses keep their contract
		out.append(node)
	return out

func _managed_cars() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if arena_root == null or not is_instance_valid(arena_root):
		return out
	for node in arena_root.get_tree().get_nodes_in_group(&"vehicles"):
		if not (node is Node2D) or node.is_in_group(&"player") or not _in_arena(node):
			continue
		if node.has_method(&"get_driver"):
			var driver: Variant = node.get_driver()
			if driver != null and driver.has_method(&"set_focus_assignment"):
				out.append(node)
	return out

func _prune_leases(players: Array[Node2D], cars: Array[Node2D]) -> void:
	var kept: Array[Dictionary] = []
	for lease in _leases:
		var car: Variant = lease.get("car")
		var player: Variant = lease.get("player")
		if car == null or player == null or not is_instance_valid(car) or not is_instance_valid(player):
			continue
		if car not in cars or player not in players or float(lease.expires) <= _clock:
			continue
		kept.append(lease)
	_leases = kept

func _least_covered_player(players: Array[Node2D]) -> Node2D:
	var best: Node2D = players[0]
	var best_count := 999
	for player in players:
		var count := 0
		for lease in _leases:
			if lease.player == player:
				count += 1
		if count < best_count:
			best = player
			best_count = count
	return best

## Longest-idle rival wins; distance breaks equal-history ties. This makes a
## lease rotate instead of snapping back to the same nearby car forever.
func _next_car(cars: Array[Node2D], player: Node2D) -> Node2D:
	var leased: Array = _leases.map(func(lease: Dictionary): return lease.car)
	var best: Node2D = null
	var best_last := INF
	var best_dist := INF
	for car in cars:
		if car in leased:
			continue
		var driver: Node = car.get_driver()
		var last: float = float(_last_focus.get(driver.get_instance_id(), -INF))
		var dist: float = car.global_position.distance_squared_to(player.global_position)
		if last < best_last or (is_equal_approx(last, best_last) and dist < best_dist):
			best = car
			best_last = last
			best_dist = dist
	return best

func _apply_assignments(_cars: Array[Node2D]) -> void:
	var slots_filled := not _leases.is_empty()
	for car in _managed_cars():
		var driver: Node = car.get_driver()
		var target: Node2D = null
		for lease in _leases:
			if lease.car == car:
				target = lease.player
				break
		driver.set_focus_assignment(target, slots_filled)

func _in_arena(node: Node) -> bool:
	return node == arena_root or arena_root.is_ancestor_of(node)

func _is_alive(node: Node) -> bool:
	return not node.has_method(&"get_hp") or float(node.get_hp()) > 0.0
