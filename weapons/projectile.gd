class_name Projectile
extends Area2D
## Straight or homing projectile. Damages the first Health-bearing body except
## its own shooter (free-for-all), then applies any on_hit_effects to that
## body's StatusReceiver. A homing projectile vectors toward its target only
## while the target stays within a forward cone — "simple" missiles: the first
## time they whiff a pass they commit to a straight line. No U-turns.

const HOMING_CONE := deg_to_rad(90.0)
const Combat := preload("res://game/combat.gd")  # NEVER name Vehicle here — load cycle

@export var spin_deg := 0.0  # visual spin of the Vis child (thrown weapons);
							  # the node itself keeps facing travel for homing

var velocity := Vector2.ZERO
var damage := 2.0
var lifetime := 1.2
var turn_rate := 0.0   # radians/sec; 0 = straight
var target: Node2D = null
var shooter: Node = null
var on_hit_effects: Array = []
var _homing := false
var _age := 0.0
var _vis: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_vis = get_node_or_null(^"Vis")

func setup(p_pos: Vector2, p_dir: Vector2, p_speed: float, p_damage: float, p_lifetime: float, p_shooter: Node, p_turn_rate := 0.0, p_target: Node2D = null) -> void:
	global_position = p_pos
	velocity = p_dir * p_speed
	rotation = p_dir.angle()
	damage = p_damage
	lifetime = p_lifetime
	turn_rate = p_turn_rate
	shooter = p_shooter
	target = p_target
	_homing = p_turn_rate > 0.0 and p_target != null

func _physics_process(delta: float) -> void:
	if _homing:
		if is_instance_valid(target):
			var aim := (target.global_position - global_position).angle()
			var off := absf(wrapf(aim - velocity.angle(), -PI, PI))
			if off <= HOMING_CONE:
				var new_angle := rotate_toward(velocity.angle(), aim, turn_rate * delta)
				velocity = Vector2.RIGHT.rotated(new_angle) * velocity.length()
				rotation = new_angle
			else:
				_homing = false   # whiffed the pass — commit to a straight line
		else:
			_homing = false       # target gone — fly straight
	if spin_deg != 0.0 and _vis:
		_vis.rotation += deg_to_rad(spin_deg) * delta
	global_position += velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	var health := _find_health(body)
	if health:
		var hit := damage * Combat.scale(shooter, body)
		# Rear weak spot (bosses): a shot traveling roughly the way the victim
		# faces arrived from behind — thin plating back there.
		if "rear_weakspot" in body and body.rear_weakspot > 1.0:
			var facing := Vector2.RIGHT.rotated(body.heading)
			if facing.dot(velocity.normalized()) > 0.4:
				hit *= body.rear_weakspot
		health.take_damage(hit)
		# Validity first: the shooter can die while this shot is in flight, and
		# stamping a freed instance into a typed property is a script error.
		if is_instance_valid(shooter) and shooter is Node2D and "last_attacker" in body:
			body.last_attacker = shooter  # AI holds a grudge against the trigger
		var status := _find_status(body)
		if status:
			for spec in on_hit_effects:
				status.apply(spec)
	queue_free()

func _find_health(body: Node) -> Health:
	for child in body.get_children():
		if child is Health:
			return child
	return null

func _find_status(body: Node) -> StatusReceiver:
	for child in body.get_children():
		if child is StatusReceiver:
			return child
	return null
