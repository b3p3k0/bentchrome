class_name PowerGenerator
extends StaticBody2D
## Ground Floor Gore's signature destructible. It is ordinary cover until the
## last quarter of its HP, then becomes a telegraphed, impartial floor-1 hazard.

const Floors := preload("res://game/floors.gd")
const ArenaState := preload("res://game/net/arena_state.gd")
const ArcScene := preload("res://environment/electric_arc_fx.tscn")
const ExplosionScene := preload("res://environment/explosion.tscn")
const ImpactScene := preload("res://weapons/impact_fx.tscn")

const SIZE := Vector2(256, 192)
const MAX_HP := 220.0
const ARM_HP := 55.0
const WARNING_SECONDS := 1.2
const ACTIVE_SECONDS := 2.0
const COOLDOWN_SECONDS := 60.0
const ARC_RANGE := 480.0
const ARC_DPS := 8.0
const INTERFERENCE := 0.5
const INTERFERENCE_TAIL := 0.4
const BLAST_RADIUS := 420.0
const BLAST_DAMAGE_NEAR := 50.0
const BLAST_DAMAGE_FAR := 15.0
const BLAST_SHOVE_NEAR := 420.0
const BLAST_SHOVE_FAR := 140.0
const ARC_ANCHOR := Vector2(76, -58)
const SOFT_TARGET_LAYER := 1 << 9
## Visual-only distress tiers (fractions of MAX_HP): first sparks tell the
## player the cabinet is damageable long before the 25% arming point.
const DISTRESS_LIGHT := 0.9
const DISTRESS_HEAVY := 0.75
const SPARK_GAP_LIGHT := Vector2(2.5, 5.0)
const SPARK_GAP_HEAVY := Vector2(0.9, 2.2)
const CAP_OFFSETS: Array[Vector2] = [Vector2(48, -58), Vector2(76, -58), Vector2(104, -58)]

enum Phase { SAFE, WARNING, ACTIVE, COOLDOWN, DEAD }

@export_range(1, 65535, 1) var arena_net_id := 1
@export var floor_index := 1
@export_enum("auto", "client", "authority") var authority_override := "auto"

var phase := Phase.SAFE
var phase_timer := 0.0
var _targets: Array[Node2D] = []
var _arc_fx: Dictionary = {}
var _dead := false
var _authority := true
var _base_collision_layer := 0
var _danger_col: CollisionShape2D
var _spark_timer := 0.0
var _distress_smoke: CPUParticles2D
var _distress_rng := RandomNumberGenerator.new()
@onready var _health: Health = $Health

func _ready() -> void:
	collision_layer = 4 | Floors.floor_bit(floor_index)
	collision_mask = 0
	_base_collision_layer = collision_layer
	add_to_group(&"arena_net_entities")
	_health.max_hp = MAX_HP
	_health.hp = MAX_HP
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_authority = _resolve_authority()
	_build_ai_danger()
	queue_redraw()

func _resolve_authority() -> bool:
	if authority_override == "authority":
		return true
	if authority_override == "client":
		return false
	var net := get_node_or_null(^"/root/Net")
	return net == null or not net.is_active() or net.is_host()

func _build_ai_danger() -> void:
	var danger := StaticBody2D.new()
	danger.name = "AIDanger"
	danger.collision_layer = 64
	danger.collision_mask = 0
	_danger_col = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = ARC_RANGE
	_danger_col.shape = shape
	_danger_col.disabled = true
	danger.add_child(_danger_col)
	add_child(danger)

func _physics_process(delta: float) -> void:
	if _authority:
		tick(delta)

## Visual-only distress FX, deliberately NOT authority-gated: host and LAN
## puppet both mirror _health.hp (the puppet via apply_arena_state), so tiered
## sparks/smoke converge with zero wire state and never touch the FSM.
func _process(delta: float) -> void:
	if _dead or _health == null:
		return
	var hp_f := clampf(_health.hp / MAX_HP, 0.0, 1.0)
	var heavy := hp_f <= DISTRESS_HEAVY
	_sync_distress_smoke(hp_f <= DISTRESS_LIGHT, heavy)
	if hp_f > DISTRESS_LIGHT:
		return
	_spark_timer -= delta
	if _spark_timer > 0.0:
		return
	var gap := SPARK_GAP_HEAVY if heavy else SPARK_GAP_LIGHT
	_spark_timer = _distress_rng.randf_range(gap.x, gap.y)
	var pops := 1
	if heavy and _distress_rng.randf() < 0.35:
		pops = _distress_rng.randi_range(2, 3)
	for i in pops:
		var cap: Vector2 = CAP_OFFSETS[_distress_rng.randi_range(0, CAP_OFFSETS.size() - 1)]
		var jitter := Vector2(_distress_rng.randf_range(-10.0, 10.0),
			_distress_rng.randf_range(-8.0, 4.0))
		_pop_spark(to_global(cap + jitter))

func _pop_spark(at: Vector2) -> void:
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	var spawner := get_node_or_null(^"/root/Spawner")
	var fx := (spawner.acquire(ImpactScene) if spawner else ImpactScene.instantiate()) as ImpactFX
	host.add_child(fx)
	fx.setup(at, ImpactFX.SPARK)

func _sync_distress_smoke(on: bool, heavy: bool) -> void:
	if not on:
		if _distress_smoke:
			_distress_smoke.emitting = false
		return
	if _distress_smoke == null:
		_distress_smoke = CPUParticles2D.new()
		_distress_smoke.lifetime = 2.2
		_distress_smoke.local_coords = false
		_distress_smoke.position = ARC_ANCHOR
		_distress_smoke.direction = Vector2(0, -1)
		_distress_smoke.spread = 24.0
		_distress_smoke.initial_velocity_min = 8.0
		_distress_smoke.initial_velocity_max = 22.0
		_distress_smoke.gravity = Vector2(4, -12)
		_distress_smoke.scale_amount_min = 3.0
		_distress_smoke.scale_amount_max = 7.0
		_distress_smoke.color = Color(0.10, 0.12, 0.15, 0.4)
		add_child(_distress_smoke)
	var want := 12 if heavy else 7
	if _distress_smoke.amount != want:
		_distress_smoke.amount = want
	_distress_smoke.emitting = true

func tick(delta: float) -> void:
	if _dead:
		return
	match phase:
		Phase.WARNING:
			phase_timer = maxf(phase_timer - delta, 0.0)
			if phase_timer <= 0.0:
				_set_phase(Phase.ACTIVE, ACTIVE_SECONDS)
		Phase.ACTIVE:
			_targets = _eligible_targets()
			_damage_targets(delta)
			_sync_arc_fx(_targets)
			phase_timer = maxf(phase_timer - delta, 0.0)
			if phase_timer <= 0.0:
				_targets.clear()
				_sync_arc_fx(_targets)
				_set_phase(Phase.COOLDOWN, COOLDOWN_SECONDS)
		Phase.COOLDOWN:
			phase_timer = maxf(phase_timer - delta, 0.0)
			if phase_timer <= 0.0:
				_set_phase(Phase.WARNING, WARNING_SECONDS)
	queue_redraw()

func _on_damaged(_amount: float, hp: float) -> void:
	if _authority and phase == Phase.SAFE and hp <= ARM_HP and hp > 0.0:
		_set_phase(Phase.WARNING, WARNING_SECONDS)
	queue_redraw()

func _set_phase(next: int, duration: float) -> void:
	phase = next
	phase_timer = duration
	if _danger_col:
		_danger_col.set_deferred(&"disabled", next not in [Phase.WARNING, Phase.ACTIVE])
	queue_redraw()

func _eligible_targets() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group(&"vehicles"):
		if not candidate is Node2D or not Floors.same_floor(self, candidate):
			continue
		if candidate.global_position.distance_to(global_position) > ARC_RANGE:
			continue
		if candidate.has_method(&"get_hp") and float(candidate.call(&"get_hp")) <= 0.0:
			continue
		if _line_clear(candidate):
			out.append(candidate)
	return out

func _line_clear(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(to_global(ARC_ANCHOR), target.global_position,
		Floors.los_mask(floor_index))
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target

func _damage_targets(delta: float) -> void:
	for target in _targets:
		if not is_instance_valid(target):
			continue
		if "last_attacker" in target:
			target.last_attacker = null
		var health := target.get_node_or_null(^"Health") as Health
		if health:
			health.take_damage(ARC_DPS * delta)
		if target.has_method(&"apply_effect"):
			var slow := StatusEffectSpec.new()
			slow.kind = &"slow"
			slow.duration = INTERFERENCE_TAIL
			slow.magnitude = INTERFERENCE
			target.call(&"apply_effect", slow)

func _sync_arc_fx(targets: Array[Node2D]) -> void:
	var live := {}
	for target in targets:
		if not is_instance_valid(target):
			continue
		var id := target.get_instance_id()
		live[id] = true
		var fx: Node2D = _arc_fx.get(id)
		if fx == null or not is_instance_valid(fx):
			fx = ArcScene.instantiate() as Node2D
			var host := get_tree().current_scene
			if host == null:
				host = get_parent()
			if host:
				host.add_child(fx)
			_arc_fx[id] = fx
		if fx and fx.is_inside_tree():
			fx.set_arc(to_global(ARC_ANCHOR), target.global_position)
	for id in _arc_fx.keys():
		if not live.has(id):
			var fx: Node2D = _arc_fx[id]
			if is_instance_valid(fx):
				fx.queue_free()
			_arc_fx.erase(id)

func _on_died() -> void:
	if not _authority or _dead:
		return
	_present_death(true)
	call_deferred(&"_blast")

func _present_death(gameplay: bool) -> void:
	_dead = true
	phase = Phase.DEAD
	phase_timer = 0.0
	_targets.clear()
	_sync_arc_fx(_targets)
	collision_layer = 0
	collision_mask = 0
	if _danger_col:
		_danger_col.set_deferred(&"disabled", true)
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host:
		var boom := ExplosionScene.instantiate()
		boom.global_position = global_position
		boom.tint = Color(0.28, 0.62, 1.0)
		boom.size_scale = 4.4
		boom.allow_camera_shake = gameplay
		host.add_child(boom)
		_spawn_smoke(host)
	queue_redraw()

func _blast() -> void:
	var shape := CircleShape2D.new()
	shape.radius = BLAST_RADIUS
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 1 | 4 | Floors.floor_bit(floor_index) | SOFT_TARGET_LAYER
	params.collide_with_areas = true
	params.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(params, 64):
		var body: Node = hit.get("collider")
		if body == null or not Floors.same_floor(self, body):
			continue
		var distance := global_position.distance_to((body as Node2D).global_position)
		var f := clampf(distance / BLAST_RADIUS, 0.0, 1.0)
		if "last_attacker" in body:
			body.last_attacker = null
		for child in body.get_children():
			if child is Health:
				child.take_damage(lerpf(BLAST_DAMAGE_NEAR, BLAST_DAMAGE_FAR, f))
				break
		if body is CharacterBody2D:
			var away := ((body as Node2D).global_position - global_position).normalized()
			body.velocity += away * lerpf(BLAST_SHOVE_NEAR, BLAST_SHOVE_FAR, f)

func _spawn_smoke(host: Node) -> void:
	var smoke := CPUParticles2D.new()
	smoke.amount = 24
	smoke.lifetime = 1.6
	smoke.local_coords = false
	smoke.direction = Vector2(0, -1)
	smoke.spread = 35.0
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 65.0
	smoke.gravity = Vector2.ZERO
	smoke.scale_amount_min = 5.0
	smoke.scale_amount_max = 12.0
	smoke.color = Color(0.12, 0.15, 0.2, 0.5)
	host.add_child(smoke)
	smoke.global_position = global_position
	host.get_tree().create_timer(4.0).timeout.connect(smoke.queue_free, CONNECT_ONE_SHOT)

func capture_arena_state(actor_lookup: Array) -> Dictionary:
	var flags := 0 if _dead else ArenaState.ALIVE
	if phase != Phase.SAFE and phase != Phase.DEAD:
		flags |= ArenaState.ARMED
	if phase == Phase.WARNING:
		flags |= ArenaState.WARNING
	elif phase == Phase.ACTIVE:
		flags |= ArenaState.ACTIVE
	var mask := 0
	for target in _targets:
		var idx := actor_lookup.find(target)
		if idx >= 0 and idx < 8:
			mask |= 1 << idx
	return {"flags": flags, "hp": clampf(_health.hp / MAX_HP, 0.0, 1.0),
		"timer_ms": clampi(roundi(phase_timer * 1000.0), 0, 65535), "targets": mask}

func apply_arena_state(row: Dictionary, initial_state: bool) -> void:
	var flags := ArenaState.flags(row)
	var alive := (flags & ArenaState.ALIVE) != 0
	_health.hp = clampf(float(row.get("hp", 0.0)), 0.0, 1.0) * MAX_HP
	phase_timer = float(int(row.get("timer_ms", 0))) / 1000.0
	if not alive:
		if not _dead:
			if initial_state:
				_dead = true
				phase = Phase.DEAD
				collision_layer = 0
				collision_mask = 0
			else:
				_present_death(false)
		queue_redraw()
		return
	_dead = false
	collision_layer = _base_collision_layer
	if (flags & ArenaState.ACTIVE) != 0:
		phase = Phase.ACTIVE
	elif (flags & ArenaState.WARNING) != 0:
		phase = Phase.WARNING
	elif (flags & ArenaState.ARMED) != 0:
		phase = Phase.COOLDOWN
	else:
		phase = Phase.SAFE
	var actors: Array = row.get("_actors", [])
	var mask := int(row.get("targets", 0))
	var targets: Array[Node2D] = []
	for i in mini(actors.size(), 8):
		if (mask & (1 << i)) != 0 and is_instance_valid(actors[i]):
			targets.append(actors[i])
	_targets = targets
	_sync_arc_fx(_targets if phase == Phase.ACTIVE else [])
	if _danger_col:
		_danger_col.set_deferred(&"disabled", phase not in [Phase.WARNING, Phase.ACTIVE])
	queue_redraw()

func _draw() -> void:
	if _dead:
		draw_rect(Rect2(-SIZE * 0.5, SIZE), Color(0.08, 0.10, 0.12))
		for i in 9:
			var at := Vector2(-92 + (i * 37) % 180, -62 + (i * 53) % 120)
			draw_circle(at, 8.0 + float(i % 3) * 3.0, Color(0.03, 0.035, 0.04, 0.8))
		return
	var hp_f := clampf(_health.hp / MAX_HP, 0.0, 1.0)
	var shell := Color(0.08, 0.22, 0.40).lerp(Color(0.06, 0.08, 0.12), 1.0 - hp_f)
	draw_rect(Rect2(-SIZE * 0.5 + Vector2(12, 15), SIZE), Color(0, 0, 0, 0.34))
	draw_rect(Rect2(-SIZE * 0.5, SIZE), shell)
	draw_rect(Rect2(-SIZE * 0.5, SIZE), Color(0.02, 0.05, 0.09), false, 5.0)
	for y in [-54.0, -36.0, -18.0, 18.0, 36.0, 54.0]:
		draw_line(Vector2(-104, y), Vector2(-26, y), Color(0.03, 0.08, 0.14), 5.0)
	for x in [48.0, 76.0, 104.0]:
		draw_circle(Vector2(x, -58), 9.0, Color(0.72, 0.78, 0.82))
		draw_circle(Vector2(x, -58), 4.0, Color(0.18, 0.3, 0.38))
	# Red-bordered yellow electrical warning, pictogram only.
	var tri := PackedVector2Array([Vector2(20, 58), Vector2(88, 58), Vector2(54, -4)])
	draw_colored_polygon(tri, Color(0.96, 0.78, 0.12))
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.82, 0.12, 0.08), 5.0)
	var bolt := PackedVector2Array([Vector2(57, 8), Vector2(42, 34), Vector2(54, 34),
		Vector2(47, 52), Vector2(69, 27), Vector2(57, 27)])
	draw_colored_polygon(bolt, Color(0.45, 0.06, 0.04))
	if phase in [Phase.WARNING, Phase.ACTIVE]:
		var pulse := 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.018)
		draw_arc(Vector2.ZERO, ARC_RANGE, 0.0, TAU, 96, Color(0.35, 0.78, 1.0, pulse), 3.0)
	if phase == Phase.WARNING:
		draw_circle(ARC_ANCHOR, 18.0, Color(0.65, 0.9, 1.0, 0.32))
