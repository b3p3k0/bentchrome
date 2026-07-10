extends Driver
## Goliath's brain — bench build (Batch B): ride the authored waypoint ring
## around the stadium track at a cruise pace, joining at the nearest point.
## Deliberately NOT EnemyDriver (the arena FSM is the wrong instinct for a
## trailered rig — no feelers, they'd see our own trailer as a wall). The
## phase-1 combat states (ram / jackknife / parting shot / recovery) and the
## phase-2 charge cycle land in Batches C and D on top of this loop.

static var LOOP_LOOKAHEAD := 340.0  # reserved for C (approach shaping)
static var LOOP_ARRIVE := 260.0     # waypoint advance radius — wide = smooth arcs
static var LOOP_STEER_GAIN := 2.2   # chase_driver's proven angle->steer gain
static var LOOP_THROTTLE := 0.55    # bench cruise; combat paces arrive in C

var _points: PackedVector2Array = PackedVector2Array()
var _idx := 0

## Tests and bench rigs feed a ring directly; in the stadium the ring is the
## level's GoliathLoop markers, gathered on first intent.
func set_loop(points: PackedVector2Array) -> void:
	_points = points
	_idx = 0

func get_intent(vehicle, delta: float) -> Dictionary:
	if _points.is_empty():
		_gather_loop(vehicle)
		if _points.is_empty():
			return super.get_intent(vehicle, delta)  # no ring authored — park
	var own: Vector2 = vehicle.global_position
	if own.distance_to(_points[_idx]) < LOOP_ARRIVE:
		_idx = (_idx + 1) % _points.size()
	var want := (_points[_idx] - own).angle()
	return {
		"throttle": LOOP_THROTTLE,
		"steer": clampf(angle_difference(vehicle.heading, want) * LOOP_STEER_GAIN, -1.0, 1.0),
		"fire_mg": false,
		"fire_selected": false,
	}

## The ring is a plain container of Marker2Ds beside the vehicles (no groups —
## the loop belongs to this one level). Join at the nearest point so a corner
## spawn merges onto the track instead of cutting across the field.
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
