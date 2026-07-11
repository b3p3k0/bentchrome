extends Driver
## The winner's parade: after Goliath falls, this driver takes the player's
## wheel and laps the stadium ring behind the YOU WIN card — Mario Kart knew
## what it was doing. Loop-follow only: no combat, no input, no drama. Seated
## by levels/stadium/stadium.gd via Vehicle.set_driver.

static var LAP_THROTTLE := 0.8
static var LAP_ARRIVE := 260.0
static var LAP_STEER_GAIN := 2.2

var _points: PackedVector2Array = PackedVector2Array()
var _idx := 0

## Tests feed a ring directly; in the stadium it's the GoliathLoop markers.
func set_loop(points: PackedVector2Array) -> void:
	_points = points
	_idx = 0

func get_intent(vehicle, delta: float) -> Dictionary:
	if _points.is_empty():
		_gather_loop(vehicle)
		if _points.is_empty():
			return super.get_intent(vehicle, delta)  # no ring — coast out
	var own: Vector2 = vehicle.global_position
	if own.distance_to(_points[_idx]) < LAP_ARRIVE:
		_idx = (_idx + 1) % _points.size()
	var want := (_points[_idx] - own).angle()
	return {
		"throttle": LAP_THROTTLE,
		"steer": clampf(angle_difference(vehicle.heading, want) * LAP_STEER_GAIN, -1.0, 1.0),
		"fire_mg": false,
		"fire_selected": false,
	}

func _gather_loop(vehicle) -> void:
	var root: Node = vehicle.get_parent()
	if root == null:
		return
	var ring := root.get_node_or_null(^"GoliathLoop")
	if ring == null:
		return
	var pts := PackedVector2Array()
	for child in ring.get_children():
		if child is Node2D:
			pts.append((child as Node2D).global_position)
	if pts.is_empty():
		return
	_points = pts
	var best := 0
	var best_d := INF
	var own: Vector2 = vehicle.global_position
	for i in pts.size():
		var d := own.distance_squared_to(pts[i])
		if d < best_d:
			best_d = d
			best = i
	_idx = best
