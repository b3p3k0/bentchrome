class_name TargetDesignator
extends Node
## Per-vehicle ownership of the opponent that locks and presentation agree on.
## Drivers may publish a committed preference; otherwise the current nearest
## living opponent is held until a challenger is meaningfully closer.

const Targeting := preload("res://game/targeting.gd")

# Roughly two car lengths: enough to stop distance-tie chatter while still
# making a clearly closer opponent take ownership promptly.
const SWITCH_DISTANCE_MARGIN := 96.0

var _target: Variant = null  # may briefly hold a freed instance; validate first

func _physics_process(_delta: float) -> void:
	_refresh()

func get_target() -> Node2D:
	# Callers can ask between physics ticks (including immediately after a kill).
	return _refresh()

func _refresh() -> Node2D:
	var vehicle := get_parent() as Node2D
	if vehicle == null or not vehicle.is_inside_tree():
		_target = null
		return null

	var driver := vehicle.get_node_or_null(^"Driver")
	var preferred: Variant = null
	if driver != null and driver.has_method(&"get_target_preference"):
		preferred = driver.get_target_preference(vehicle)
	if Targeting.is_live_other(vehicle, preferred):
		_target = preferred
		return _target as Node2D

	var nearest := _nearest_live(vehicle)
	if not Targeting.is_live_other(vehicle, _target):
		_target = nearest
		return nearest
	if nearest == null or nearest == _target:
		return _target as Node2D

	var current := _target as Node2D
	var current_distance := vehicle.global_position.distance_to(current.global_position)
	var nearest_distance := vehicle.global_position.distance_to(nearest.global_position)
	if nearest_distance + SWITCH_DISTANCE_MARGIN < current_distance:
		_target = nearest
	return _target as Node2D

func _nearest_live(vehicle: Node2D) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for candidate in vehicle.get_tree().get_nodes_in_group(&"vehicles"):
		if not Targeting.is_live_other(vehicle, candidate):
			continue
		var distance: float = vehicle.global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
