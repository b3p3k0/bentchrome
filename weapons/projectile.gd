class_name Projectile
extends Area2D
## Straight or homing projectile. Damages the first Health-bearing body except
## its own shooter (free-for-all), then applies any on_hit_effects to that
## body's StatusReceiver. A homing projectile vectors toward its target only
## while the target stays within a forward cone — "simple" missiles: the first
## time they whiff a pass they commit to a straight line. No U-turns.

const HOMING_CONE := deg_to_rad(90.0)
const Combat := preload("res://game/combat.gd")  # NEVER name Vehicle here — load cycle
const NetEvents := preload("res://game/net/net_events.gd")  # host-armed tap, leaf like Combat
# Every weapons/*.tscn projectile authors collision_mask = 7 (ground|wall|
# obstacle); per-fire stamps (cover-pierce, floor masks) are applied by the
# mount after acquire, so pool_reset restores this baseline between shooters.
const BASE_MASK := 7
const SOFT_TARGET_LAYER := 1 << 9

@export var spin_deg := 0.0  # visual spin of the Vis child (thrown weapons);
							  # the node itself keeps facing travel for homing

var velocity := Vector2.ZERO
var damage := 2.0
var lifetime := 1.2
var turn_rate := 0.0   # radians/sec; 0 = straight
var target: Node2D = null
var shooter: Node = null
var on_hit_effects: Array = []
var hit_sfx: StringName = &"hit_weapon"  # stamped by the mount (hit_mg for MG fire)
var _homing := false
var _age := 0.0
var _spent := false   # hit landed or lifetime up — inert until reset/setup
var _vis: Node2D = null
var harms_ambient := true  # false for deliberately harmless cosmetic rounds

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
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
	_age = 0.0
	_spent = false
	if harms_ambient:
		collision_mask |= SOFT_TARGET_LAYER
	if NetEvents.armed and p_damage > 0.0:
		# Every live shot passes through here (mounts, specials, turrets) — the
		# one tap the MP host needs. Visual-only client shots carry damage 0,
		# so a mirror can never echo. pool_key = the Spawner's scene path.
		NetEvents.projectile_spawned(String(get_meta(&"pool_key", scene_file_path)),
			p_pos, p_dir, p_speed, p_lifetime, p_turn_rate, p_target)

func _physics_process(delta: float) -> void:
	if _spent:
		return
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
		_despawn()

func _on_body_entered(body: Node) -> void:
	if _spent or body == shooter:
		return
	# A multi-body rig (Goliath) stamps its parts with meta "part_of" -> the
	# owning vehicle's path: the rig's own fire sails over its trailer the same
	# way it skips its shooter — everyone else's shots land on the plating.
	if body.has_meta(&"part_of") and is_instance_valid(shooter) \
			and body.get_meta(&"part_of") == shooter.get_path():
		return
	var health := _find_health(body)
	if health:
		if body.is_in_group(&"player"):
			var audio := get_node_or_null(^"/root/AudioDirector")
			if audio:
				audio.play(hit_sfx)
		var hit := damage * Combat.scale(shooter, body)
		# Rear weak spot (bosses): a shot traveling roughly the way the victim
		# faces arrived from behind — thin plating back there.
		if "rear_weakspot" in body and body.rear_weakspot > 1.0:
			var facing := Vector2.RIGHT.rotated(body.heading)
			if facing.dot(velocity.normalized()) > 0.4:
				hit *= body.rear_weakspot
		# Stamp BEFORE Health emits damaged: vehicle feedback and the MP hit tap
		# must see the trigger in the same synchronous call. Multi-body rigs point
		# their plates at the owning cab through part_of; remain duck-typed here.
		_stamp_attacker(body)
		health.take_damage(hit)
		var status := _find_status(body)
		if status:
			for spec in on_hit_effects:
				status.apply(spec)
	_despawn()

## Soft targets are atmosphere, never cover: a real projectile pops them but
## continues on its original flight. Client mirror shots carry damage 0 yet
## still present the local cosmetic hit; harmless police rounds opt out.
func _on_area_entered(area: Area2D) -> void:
	if _spent or not harms_ambient or area == shooter \
			or area.collision_layer & SOFT_TARGET_LAYER == 0:
		return
	var Floors := preload("res://game/floors.gd")
	if not Floors.same_floor(shooter, area):
		return
	var health := _find_health(area)
	if health:
		health.take_damage(1.0)

## Return to the Spawner pool when it exists; queue_free otherwise (headless
## fixtures, pool disabled). _spent freezes the shot for its removal frame.
func _despawn() -> void:
	if _spent:
		return
	_spent = true
	var spawner := get_node_or_null(^"/root/Spawner")
	if spawner and spawner.has_method(&"release"):
		spawner.release(self)
	else:
		queue_free()

## Spawner callback on pool return: shed the per-fire stamps so the next
## shooter starts pristine. The mask restore matters most — a leaked pierce or
## floor mask changes what the next shooter's round can hit.
func pool_reset() -> void:
	_spent = false
	_age = 0.0
	_homing = false
	velocity = Vector2.ZERO
	target = null
	shooter = null
	on_hit_effects = []
	modulate = Color.WHITE
	hit_sfx = &"hit_weapon"
	harms_ambient = true
	collision_mask = BASE_MASK

func _find_health(body: Node) -> Health:
	for child in body.get_children():
		if child is Health:
			return child
	return null

func _stamp_attacker(body: Node) -> void:
	if not is_instance_valid(shooter) or not shooter is Node2D:
		return
	var victim: Node = body
	if body.has_meta(&"part_of"):
		var owner_path: NodePath = body.get_meta(&"part_of")
		var owner: Node = body.get_node_or_null(owner_path)
		if owner:
			victim = owner
	if "last_attacker" in victim:
		victim.last_attacker = shooter

func _find_status(body: Node) -> StatusReceiver:
	for child in body.get_children():
		if child is StatusReceiver:
			return child
	return null
