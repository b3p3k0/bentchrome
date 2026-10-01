extends Node2D
## The Buzzard on the verge with the spike strip: a rider standing beside
## his parked bike (the bike is a derelict_car the builder parks next to
## this node), a coil of spikes at his feet, and a TRIGGER across the road
## REACH px south of him. The first human car that drives into the trigger
## gets the throw — the arm swings, the coil (spike_strip.gd, a child) goes
## skidding across the near lane and lies there. Paint and a sensor only:
## he is not in the `enemies` group, never shoots, and nothing here collides.
## One throw per rider; the tell is the bike, the figure, and the arm.

const StripScript := preload("res://levels/chase/spike_strip.gd")

static var REACH := 700.0        # px of road south of the rider that trips the throw
static var RELEASE_T := 0.14     # seconds into the swing the coil leaves his hand
static var SWING_T := 0.45       # the whole arm swing

@export var side := 1.0          # which verge he stands on (the throw goes -side, onto the road)
@export var road_x := 0.0        # the road's centreline x at his station (chunk-local = world x)
@export var road_half := 360.0
@export var lane_x := 240.0      # where the strip's centre lands (world x)

var thrown := false
var _swing := -1.0               # <0 idle; 0..SWING_T swinging; then a held follow-through
var _strip: Area2D = null

func _ready() -> void:
	_strip = Area2D.new()
	_strip.set_script(StripScript)
	_strip.name = "Strip"
	_strip.position = Vector2(side * 12.0, 14.0)   # the coil at his feet, verge side
	add_child(_strip)
	var trigger := Area2D.new()
	trigger.name = "Trigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	trigger.monitorable = false
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(road_half * 2.0 + 180.0, REACH)
	col.shape = shape
	col.position = Vector2(road_x - position.x, REACH * 0.5)   # the road south of him
	trigger.add_child(col)
	trigger.body_entered.connect(_on_trigger)
	add_child(trigger)
	set_physics_process(false)
	queue_redraw()

func _on_trigger(body: Node) -> void:
	if body and body.is_in_group(&"player"):
		throw()

## The throw. Public so a test (or a director) can pull it without a car.
func throw() -> void:
	if thrown:
		return
	thrown = true
	_swing = 0.0
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	var was: float = _swing
	_swing += delta
	if was < RELEASE_T and _swing >= RELEASE_T:
		_strip.deploy(Vector2(lane_x - position.x, 0.0))
	if _swing >= SWING_T:
		set_physics_process(false)
	queue_redraw()

func strip() -> Area2D:
	return _strip

## The rider from above, facing the road: boots, a dark vest over rust
## sleeves, a helmet. Idle he stands with the throwing arm back; the swing
## sweeps it across his body toward the road and holds there after.
func _draw() -> void:
	var toward := -side   # the road is this way
	draw_circle(Vector2(3.0, 5.0), 11.0, Color(0, 0, 0, 0.3))
	# Boots, then the vest (shoulders a little wider than the hips).
	draw_rect(Rect2(-5.0, 4.0, 4.0, 7.0), Color(0.12, 0.1, 0.09))
	draw_rect(Rect2(1.0, 4.0, 4.0, 7.0), Color(0.12, 0.1, 0.09))
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -6), Vector2(9, -6), Vector2(7, 7), Vector2(-7, 7)]), Color(0.2, 0.17, 0.15))
	draw_rect(Rect2(-9.0, -6.0, 18.0, 4.0), Color(0.42, 0.26, 0.14))   # the shoulders, rust sleeves
	# The arms: the off arm resting, the throwing arm swinging toward the road.
	draw_line(Vector2(-toward * 8.0, -4.0), Vector2(-toward * 11.0, 6.0), Color(0.42, 0.26, 0.14), 3.0)
	var f := 0.0 if _swing < 0.0 else clampf(_swing / SWING_T, 0.0, 1.0)
	var back := Vector2(-toward, 0.6).normalized()    # cocked: away from the road, a little south
	var fore := Vector2(toward, -0.3).normalized()    # released: at the road
	var shoulder := Vector2(toward * 8.0, -4.0)
	var hand := shoulder + back.slerp(fore, f) * 13.0
	draw_line(shoulder, hand, Color(0.42, 0.26, 0.14), 3.0)
	draw_circle(hand, 2.2, Color(0.72, 0.56, 0.42))
	# The helmet, a dark dome with a visor glint on the road side.
	draw_circle(Vector2(0.0, -2.0), 6.0, Color(0.1, 0.1, 0.11))
	draw_arc(Vector2(0.0, -2.0), 4.2, (PI if toward < 0.0 else 0.0) - 0.7, (PI if toward < 0.0 else 0.0) + 0.7, 8, Color(0.6, 0.7, 0.8, 0.8), 1.5)
