extends Area2D
## A Buzzard's spike strip: a thin dark band bristling with steel that a
## rider on the verge tosses across the near lane (spike_thrower.gd calls
## `deploy`). It starts COILED at the rider's feet, skids out across the
## road over THROW_T seconds (position, a little spin, the coil unrolling),
## and then lies there. A grounded car crossing it is on a flat tire for a
## beat: the `slow` status, a heading wobble the lane wheel has to catch,
## sparks and the brake crunch. Airborne cars clear it; the pack's own
## birds pay the same (they drive on layer 1 too). Layer 0 / mask 1 — no
## feeler ever sees it, it bills nothing but a beat of pace, never HP.

const ImpactScene := preload("res://weapons/impact_fx.tscn")

static var LENGTH := 200.0     # across the lane
static var THICK := 12.0       # the painted band
static var SENSE_H := 34.0     # the sensing rect is taller: a car at 600 px/s crosses 10 px a frame
static var THROW_T := 0.5      # seconds from the rider's hand to lying flat
static var SLOW := 0.55        # the flat tire: speed factor ...
static var SLOW_T := 1.8       # ... for this long
static var WOBBLE := 0.22      # rad of heading kick, either way, on crossing
static var SPIKES := 11

var armed := false             # lying flat and live
var _coiled := true
var _t := 0.0
var _rest := Vector2.ZERO
var _target := Vector2.ZERO
var _spin := 1.0
var _unroll := 1.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(LENGTH, SENSE_H)
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)
	set_physics_process(false)
	queue_redraw()

## The throw: from where it sits (the coil at the rider's feet) to `to`,
## the lane it will lie across. Once only.
func deploy(to: Vector2) -> void:
	if not _coiled:
		return
	_coiled = false
	_rest = position
	_target = to
	_spin = 1.0 if to.x > position.x else -1.0
	_t = 0.0
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	_t += delta
	var f := clampf(_t / THROW_T, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - f, 2.0)   # thrown hard, skids to a stop
	position = _rest.lerp(_target, e)
	rotation = _spin * 0.7 * (1.0 - e)   # lands square across the lane
	_unroll = lerpf(0.2, 1.0, e)         # the coil unrolls as it flies (paint only: the body is never scaled)
	if f >= 1.0:
		_unroll = 1.0
		rotation = 0.0
		armed = true
		set_physics_process(false)
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if not armed or body == null:
		return
	var h: Variant = body.get("height")
	if h is float and float(h) > 0.0:
		return   # airborne: the spikes never touch the tires
	if body.has_method(&"apply_effect"):
		var spec := StatusEffectSpec.new()
		spec.kind = &"slow"
		spec.magnitude = SLOW
		spec.duration = SLOW_T
		body.call(&"apply_effect", spec)
	var heading: Variant = body.get("heading")
	if heading is float:
		body.set("heading", float(heading) + (WOBBLE if randf() < 0.5 else -WOBBLE))
	# Sparks off the rims, and the crunch.
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_parent()
	if host and body is Node2D:
		var spawner := get_node_or_null(^"/root/Spawner")
		var fx := (spawner.acquire(ImpactScene) if spawner else ImpactScene.instantiate()) as ImpactFX
		host.add_child(fx)
		fx.setup((body as Node2D).global_position, ImpactFX.SPARK)
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio:
		audio.play_at(&"brake", global_position)

func _draw() -> void:
	if _coiled:
		# The coil at the rider's feet: a dark spiral disc, spikes bristling.
		draw_circle(Vector2(3, 4), 13.0, Color(0, 0, 0, 0.3))
		draw_circle(Vector2.ZERO, 12.0, Color(0.1, 0.1, 0.11))
		draw_arc(Vector2.ZERO, 8.0, 0.0, TAU * 0.8, 14, Color(0.2, 0.2, 0.22), 2.0)
		draw_arc(Vector2.ZERO, 4.0, 0.5, TAU * 0.7, 10, Color(0.2, 0.2, 0.22), 2.0)
		for i in 8:
			var a := TAU * float(i) / 8.0
			draw_line(Vector2.RIGHT.rotated(a) * 11.0, Vector2.RIGHT.rotated(a) * 16.0, Color(0.85, 0.88, 0.9), 1.5)
		return
	var length := LENGTH * _unroll
	var hl := length * 0.5
	draw_rect(Rect2(-hl + 2.0, -THICK * 0.5 + 3.0, length, THICK), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-hl, -THICK * 0.5, length, THICK), Color(0.1, 0.1, 0.11))
	draw_line(Vector2(-hl, 0.0), Vector2(hl, 0.0), Color(0.22, 0.22, 0.25), 2.0)   # the hinge chain
	for i in SPIKES:
		var x := -hl + 10.0 * _unroll + (length - 20.0 * _unroll) * float(i) / float(SPIKES - 1)
		var up := i % 2 == 0
		var tip := Vector2(x, (-THICK * 0.5 - 9.0) if up else (THICK * 0.5 + 9.0))
		var base_y := -THICK * 0.5 if up else THICK * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3.0, base_y), Vector2(x + 3.0, base_y), tip]), Color(0.85, 0.88, 0.9))
		draw_line(Vector2(x, base_y), tip, Color(1.0, 1.0, 1.0, 0.7), 1.0)
	for i in 5:   # the hinge studs
		var x := -hl + length * float(i + 0.5) / 5.0
		draw_circle(Vector2(x, 0.0), 2.2, Color(0.5, 0.52, 0.55))
