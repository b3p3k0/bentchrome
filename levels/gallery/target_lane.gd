extends Node2D
## A shooting-gallery target lane: spawns one non-hostile roster car as ITS
## OWN child (never the level's — combat_level's face_spawns_inward only sees
## direct Vehicle children), laps it round the authored Marker2D children on
## the victory-lap driver, floats an HP label over it, and re-instantiates it
## `respawn_seconds` after it dies. No markers = a parked target. The markers
## are the single source of loop coordinates: _draw paints them as a dashed
## closed loop so the authored ring and the driven ring can never disagree.
## Never names Vehicle — the car is duck-typed like every projectile-side
## script, so this stays loadable anywhere.
##
## LANES ARE ALWAYS AUTHORED UNROTATED. vehicle.gd assumes an unrotated parent
## (it seats `heading = rotation; rotation = 0` and paints/aims/skids in
## car-local space at `heading`), so a rotated lane would skew the body, the
## muzzle, the marks and the label past the heading math. A parked car's
## facing comes from `facing_deg`; a looping car faces its second marker.

const TargetScene := preload("res://vehicles/target_vehicle.tscn")
const HpLabel := preload("res://environment/hp_label.gd")

static var LOOP_COLOR := Color(0.92, 0.92, 0.88, 0.45)  # road-paint white, faint
static var LOOP_WIDTH := 3.0
static var LOOP_DASH := 18.0

@export var car_id: StringName = &""
@export var throttle := 0.6          # lap pedal; 0 holds still even with a loop
@export var respawn_seconds := 3.0
@export var label_y := -70.0         # HP label top edge, car-relative
@export var facing_deg := 0.0        # parked nose direction (0 = +x/east, 180 = west);
	# ignored when ≥ 2 markers aim the car along the loop

var _points: PackedVector2Array = PackedVector2Array()  # GLOBAL loop positions
var _car: Node = null

func _ready() -> void:
	if not is_zero_approx(rotation):
		push_warning("target_lane '%s': lanes must be authored unrotated (rotation %.2f) — "
			% [name, rotation] + "use facing_deg for a parked car; the loop aims a lapping one")
	for child in get_children():
		if child is Marker2D:
			_points.append((child as Marker2D).global_position)
	_spawn()
	queue_redraw()

## The live target car, or null between a death and the respawn.
func target() -> Node:
	if _car != null and is_instance_valid(_car):
		return _car
	return null

## Stats and driver props land BEFORE add_child (chase_director precedent): a
## non-player car with no stats paints blank, and Vehicle._ready seats
## `heading = rotation` (then zeroes rotation), so the facing is set here too —
## as the car's own rotation, never the lane's.
func _spawn() -> void:
	var path := "res://data/vehicles/%s.tres" % car_id
	if not ResourceLoader.exists(path):
		push_error("target_lane: no vehicle stats at %s (car_id '%s')" % [path, car_id])
		return
	var car: Node2D = TargetScene.instantiate()
	car.set(&"stats", load(path))
	var driver: Node = car.get_node(^"Driver")
	driver.throttle = throttle
	if _points.size() >= 2:
		driver.set_loop(_points)
		car.position = to_local(_points[0])
		car.rotation = (_points[1] - _points[0]).angle()
	else:
		car.position = Vector2.ZERO   # parked on the lane's origin
		car.rotation = deg_to_rad(facing_deg)
	add_child(car)
	var health: Node = car.get_node(^"Health")
	HpLabel.attach(car, health, label_y)
	health.died.connect(_on_target_died)
	_car = car

## The car frees itself on death (Vehicle._on_died); the lane only owes the
## next one. The timer may outlive a scene swap — hence the tree guard.
func _on_target_died() -> void:
	_car = null
	get_tree().create_timer(respawn_seconds).timeout.connect(_respawn)

func _respawn() -> void:
	if not is_inside_tree():
		return
	_spawn()

func _draw() -> void:
	if _points.size() < 2:
		return
	for i in _points.size():
		var a := to_local(_points[i])
		var b := to_local(_points[(i + 1) % _points.size()])
		draw_dashed_line(a, b, LOOP_COLOR, LOOP_WIDTH, LOOP_DASH)
