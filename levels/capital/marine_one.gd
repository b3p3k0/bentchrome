extends StaticBody2D
## Marine One — Capital City's signature destructible (docs/signature_destructibles.md).
## A VH-3 sits on the White House south lawn behind the wrought-iron ring.
## First fence breach (host-side census of &"wh_fence") starts the evacuation:
## a suited figure sprints from the residence, the rotor spools six seconds
## (the easy kill window), then the bird CLIMBS for the SE corner through
## three altitude stages that ride the floor system — stage 1 anyone hits it,
## stage 2 needs terrace height, stage 3 is rooftop reach — then "floor 4"
## is sky: collision off, gone. Kill it grounded for a lawn wreck; kill it
## climbing and it trails smoke, spirals, and slams into the authored crash
## site (SP freezes for the Goliath-style theatre; MP presents live) — the
## impact blast is environmental, and the site's dormant debris + weapon
## cache flip on. Any kill pays the mini_boss bounty to the attributed
## player. Netted per the contract: phase ladder in flags (ESCAPE finally
## has an owner), elapsed clock in timer_ms, position derived from the
## clock, tombstones never freed. Knobs: static vars.

enum Phase { PARKED, SPOOLING, CLIMBING, ESCAPED, DYING, DEAD }

static var MAX_HP := 260.0
static var SPOOL_SECONDS := 6.0
static var CLIMB_SECONDS := 12.0
static var SPIRAL_SECONDS := 2.2
static var MAX_LIFT := 96.0            # three storeys of visual altitude
static var CRASH_BLAST_RADIUS := 380.0
static var CRASH_DAMAGE_NEAR := 45.0
static var CRASH_DAMAGE_FAR := 12.0
static var CRASH_SHOVE_NEAR := 360.0
static var CRASH_SHOVE_FAR := 120.0
static var CINEMATIC_TAIL := 0.7       # beat on the burning site before play resumes

const BODY := Color(0.15, 0.24, 0.17)      # executive dark green
const BODY_DARK := Color(0.09, 0.15, 0.11)
const STRIPE := Color(0.9, 0.9, 0.88)
const GLASS := Color(0.55, 0.68, 0.75)
const ROTOR := Color(0.12, 0.12, 0.14)
const SHADOW := Color(0, 0, 0, 0.32)

const Floors := preload("res://game/floors.gd")
const ArenaState := preload("res://game/net/arena_state.gd")
const RemainsPaint := preload("res://environment/remains_paint.gd")
const LightKit := preload("res://environment/light_kit.gd")
const ExplosionScene := preload("res://environment/explosion.tscn")
const ActorScene := preload("res://environment/ambient_actor.tscn")

@export var exit_point := Vector2(2600, 1600)  # world point it flees toward (SE)
@export var door_point := Vector2.ZERO          # world point the figure sprints from
@export var crash_site_path: NodePath           # Node2D of dormant crash props
@export var fence_group: StringName = &"wh_fence"
@export var floor_index := 1
@export_range(0, 65535, 1) var arena_net_id := 0
@export_enum("auto", "client", "authority") var authority_override := "auto"

var phase := Phase.PARKED
var phase_elapsed := 0.0
var last_attacker: Node2D = null
var _authority := true
var _dead_air := false        # crashed mid-air (vs shot on the lawn)
var _start_pos := Vector2.ZERO
var _death_pos := Vector2.ZERO
var _death_lift := 0.0
var _rotor_angle := 0.0
var _figure: Node2D = null
var _light: PointLight2D = null
var _crash_restore: Array = []  # [node, layer, monitoring] rows
var _net_initialized := false

var _health: Health = null

func _ready() -> void:
	collision_layer = 4 | Floors.floor_bit(floor_index)
	collision_mask = 0
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(170, 70)
	col.shape = shape
	add_child(col)
	_health = Health.new()
	_health.name = "Health"
	_health.max_hp = MAX_HP
	_health.hp = MAX_HP
	_health.died.connect(_on_died)
	add_child(_health)
	_light = LightKit.make_light(220.0, 0.0, Color(0.95, 0.95, 0.85))
	add_child(_light)
	_start_pos = global_position
	if arena_net_id > 0:
		add_to_group(&"arena_net_entities")
	_disarm_crash_site()
	_authority = _resolve_authority()

func _resolve_authority() -> bool:
	if authority_override == "authority":
		return true
	if authority_override == "client":
		return false
	var net := get_node_or_null(^"/root/Net")
	return net == null or not net.is_active() or net.is_host()

func _physics_process(delta: float) -> void:
	if _authority:
		tick(delta)

## Presentation runs BOTH sides (generator idiom): rotor spin, flight pose.
## Clients advance the clock between snapshots; rows re-anchor it.
func _process(delta: float) -> void:
	if not _authority and phase in [Phase.CLIMBING, Phase.DYING, Phase.SPOOLING]:
		phase_elapsed += delta
	if phase in [Phase.SPOOLING, Phase.CLIMBING, Phase.DYING]:
		_rotor_angle += delta * (28.0 if phase != Phase.SPOOLING
			else lerpf(4.0, 28.0, clampf(phase_elapsed / SPOOL_SECONDS, 0.0, 1.0)))
		queue_redraw()
	_apply_flight_pose()

## Public, delta-driven, test-callable.
func tick(delta: float) -> void:
	phase_elapsed += delta
	match phase:
		Phase.PARKED:
			if _fence_breached():
				_set_phase(Phase.SPOOLING)
		Phase.SPOOLING:
			if phase_elapsed >= SPOOL_SECONDS:
				_set_phase(Phase.CLIMBING)
		Phase.CLIMBING:
			var stage := climb_stage()
			var want := 4 | Floors.floor_bit(stage)
			if collision_layer != want:
				collision_layer = want  # altitude IS the floor bit — reach follows
			if flight_progress() >= 1.0:
				_set_phase(Phase.ESCAPED)
		Phase.DYING:
			if phase_elapsed >= SPIRAL_SECONDS:
				_set_phase(Phase.DEAD)
		_:
			pass

## Any live wh_fence member with its obstacle bit stripped = a breach (dead
## breakables flatten to collision_layer 0 — the radar's liveness rule).
func _fence_breached() -> bool:
	var members := get_tree().get_nodes_in_group(fence_group)
	if members.is_empty():
		return false
	for f in members:
		if f is StaticBody2D and (int(f.collision_layer) & 4) == 0:
			return true
	return false

func flight_progress() -> float:
	return clampf(phase_elapsed / CLIMB_SECONDS, 0.0, 1.0)

## Altitude stage 1..3 across the climb — each stage swaps the floor bit.
func climb_stage() -> int:
	return clampi(1 + int(flight_progress() * 3.0), 1, 3)

func current_lift() -> float:
	match phase:
		Phase.CLIMBING:
			return flight_progress() * MAX_LIFT
		Phase.DYING:
			return _death_lift * (1.0 - clampf(phase_elapsed / SPIRAL_SECONDS, 0.0, 1.0))
		_:
			return 0.0

## Position is derived from the phase clock — deterministic on host and
## client alike (arena rows carry no XY; the timer IS the position).
func _apply_flight_pose() -> void:
	match phase:
		Phase.CLIMBING:
			var p := flight_progress()
			global_position = _start_pos.lerp(exit_point, p * p)  # eases out of the hover
			rotation = (_start_pos.angle_to_point(exit_point)) * minf(p * 3.0, 1.0)
			z_index = 2  # above overhead paint, like airborne cars
		Phase.DYING:
			var p := clampf(phase_elapsed / SPIRAL_SECONDS, 0.0, 1.0)
			var spiral := Vector2(cos(p * TAU * 2.0), sin(p * TAU * 2.0)) * 60.0 * (1.0 - p)
			global_position = _death_pos.lerp(_crash_point(), p) + spiral
			rotation += 0.12
			z_index = 2
		_:
			pass

func _crash_point() -> Vector2:
	var site := get_node_or_null(crash_site_path)
	if site is Node2D:
		return (site as Node2D).global_position
	return _start_pos + Vector2(400, 400)  # headless fallback: crash short

## ---- phase transitions (host sets, clients mirror through apply) ----------

func _set_phase(p: Phase) -> void:
	if phase == p:
		return
	phase = p
	phase_elapsed = 0.0
	_enter_phase(p, false)

func _enter_phase(p: Phase, initial_state: bool) -> void:
	match p:
		Phase.SPOOLING:
			if _light:
				_light.energy = 0.9  # the searchlight snaps on
			if not initial_state:
				_spawn_figure()
		Phase.CLIMBING:
			if _figure and is_instance_valid(_figure):
				_figure.queue_free()  # boarded
			_figure = null
		Phase.ESCAPED:
			collision_layer = 0
			collision_mask = 0
			visible = false  # gone SE — hidden, collisionless, never freed
		Phase.DYING:
			pass  # the spiral runs on the clock; smoke rides _draw
		Phase.DEAD:
			collision_layer = 0
			collision_mask = 0
			z_index = 0
			rotation = 0.0
			if _light:
				_light.energy = 0.0
			if _dead_air:
				global_position = _crash_point()
				if _authority:
					call_deferred(&"_crash_blast")
				_activate_crash_site()
			if not initial_state:
				_death_visual()
			queue_redraw()

## The residence empties: a one-shot suited runner breaks for the bird
## (porta-potty escape template — deterministic seed, pure presentation).
func _spawn_figure() -> void:
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	var actor: Node2D = ActorScene.instantiate()
	actor.kind = &"business_suit"
	actor.movement = 0  # WANDER — panic supplies the sprint
	actor.move_speed = 96.0
	actor.actor_seed = int(absf(_start_pos.x * 7.0 + _start_pos.y * 13.0)) + 77
	actor.floor_index = floor_index
	var from := door_point if door_point != Vector2.ZERO else _start_pos + Vector2(0, -160)
	host.add_child(actor)
	actor.global_position = from
	# Panic away from the mirror point = a dead sprint TOWARD the chopper.
	actor.panic_from(from * 2.0 - _start_pos, SPOOL_SECONDS)
	_figure = actor

func _on_died() -> void:
	if phase == Phase.DEAD or phase == Phase.DYING:
		return
	_pay_bounty()
	if phase == Phase.CLIMBING:
		_dead_air = true
		_death_pos = global_position
		_death_lift = current_lift()
		_set_phase(Phase.DYING)
		_maybe_cinematic()
	else:
		_dead_air = false
		_set_phase(Phase.DEAD)

## The unclaimed mini_boss tier (2,500, difficulty-scaled). Economy.enabled
## already silences MP and non-campaign lanes; attribution rides the same
## last_attacker guard the kill-bounty path uses.
func _pay_bounty() -> void:
	if last_attacker is Node2D and is_instance_valid(last_attacker) \
			and last_attacker.is_in_group(&"player"):
		preload("res://game/economy.gd").award_kill(&"mini_boss")

## SP theatre: freeze the world Goliath-style and watch the fall. Skipped
## when there is no live player to watch it, when something else holds the
## pause, or in any LAN session (MP presents the crash live, unpaused).
func _maybe_cinematic() -> void:
	var net := get_node_or_null(^"/root/Net")
	if net != null and net.is_active():
		return
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null or not (player is Node2D) or not player.has_method(&"get_hp"):
		return  # no real, watchable player — no theatre (headless fixtures included)
	if player.get_hp() <= 0.0:
		return
	if get_tree().paused:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var cam := Camera2D.new()
	cam.name = "CrashCam"
	var pcam: Camera2D = player.get_node_or_null(^"Camera2D")
	cam.zoom = pcam.zoom if pcam else Vector2(0.55, 0.55)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	add_child(cam)
	cam.make_current()
	_run_cinematic(pcam)

func _run_cinematic(pcam: Camera2D) -> void:
	# The spiral is clock-driven and this node processes through the pause,
	# so the camera just rides along until impact + a savoring beat.
	await get_tree().create_timer(SPIRAL_SECONDS + CINEMATIC_TAIL, true).timeout
	if pcam and is_instance_valid(pcam):
		pcam.make_current()
	var cam := get_node_or_null(^"CrashCam")
	if cam:
		cam.queue_free()
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_INHERIT

## ---- crash aftermath -------------------------------------------------------

## Impact blast: environmental — attribution cleared, nobody gets paid twice.
func _crash_blast() -> void:
	var shape := CircleShape2D.new()
	shape.radius = CRASH_BLAST_RADIUS
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 1 | 4 | Floors.floor_bit(floor_index) | (1 << 9)
	params.collide_with_areas = true
	params.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(params):
		var body: Node = hit["collider"]
		if not (body is Node2D) or not Floors.same_floor(self, body):
			continue
		var d: float = (body as Node2D).global_position.distance_to(global_position)
		var f := clampf(d / CRASH_BLAST_RADIUS, 0.0, 1.0)
		if "last_attacker" in body:
			body.last_attacker = null  # wreckage is the wasteland's kill
		if body.has_method(&"apply_impact"):
			var away: Vector2 = ((body as Node2D).global_position - global_position).normalized()
			body.apply_impact(away * lerpf(CRASH_SHOVE_NEAR, CRASH_SHOVE_FAR, f),
				lerpf(CRASH_DAMAGE_NEAR, CRASH_DAMAGE_FAR, f), 0.0, 0.0)
			continue
		for child in body.get_children():
			if child is Health:
				child.take_damage(lerpf(CRASH_DAMAGE_NEAR, CRASH_DAMAGE_FAR, f))
				break

## Dormant crash-site props: hidden and inert at boot, flipped exactly once
## by the crash (pre-baked, so LAN late joiners converge — nothing runtime-
## spawned ever enters the net index).
func _disarm_crash_site() -> void:
	var site := get_node_or_null(crash_site_path)
	if site == null:
		return
	for child in site.get_children():
		var row: Array = [child, 0, false]
		if child is CollisionObject2D:
			row[1] = (child as CollisionObject2D).collision_layer
			(child as CollisionObject2D).collision_layer = 0
		if child is Area2D:
			row[2] = (child as Area2D).monitoring
			(child as Area2D).set_deferred("monitoring", false)
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		child.process_mode = Node.PROCESS_MODE_DISABLED
		_crash_restore.append(row)

func _activate_crash_site() -> void:
	for row in _crash_restore:
		var node: Node = row[0]
		if not is_instance_valid(node):
			continue
		node.process_mode = Node.PROCESS_MODE_INHERIT
		if node is CollisionObject2D:
			(node as CollisionObject2D).collision_layer = row[1]
		if node is Area2D:
			(node as Area2D).set_deferred("monitoring", row[2])
		if node is CanvasItem:
			(node as CanvasItem).visible = true
	_crash_restore.clear()

func _death_visual() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_parent()
	if scene == null:
		return
	var boom: Node2D = ExplosionScene.instantiate()
	boom.global_position = global_position
	if "size_scale" in boom:
		boom.size_scale = 3.6
	if "tint" in boom:
		boom.tint = Color(1.0, 0.5, 0.18)
	scene.add_child(boom)

## ---- net rows (docs/signature_destructibles.md) ----------------------------

func capture_arena_state(_actor_lookup: Array) -> Dictionary:
	var flags := 0
	match phase:
		Phase.PARKED:
			flags = ArenaState.ALIVE
		Phase.SPOOLING:
			flags = ArenaState.ALIVE | ArenaState.ARMED
		Phase.CLIMBING:
			flags = ArenaState.ALIVE | ArenaState.ARMED | ArenaState.ACTIVE
		Phase.ESCAPED:
			flags = ArenaState.ALIVE | ArenaState.ESCAPE
		Phase.DYING:
			flags = ArenaState.ALIVE | ArenaState.WARNING
		Phase.DEAD:
			flags = ArenaState.WARNING if _dead_air else 0  # WARNING marks the air crash
	return {"flags": flags,
		"hp": clampf(_health.hp / MAX_HP, 0.0, 1.0),
		"timer_ms": clampi(roundi(phase_elapsed * 1000.0), 0, 65535),
		"targets": 0}

func apply_arena_state(row: Dictionary, initial_state: bool) -> void:
	var flags := int(row.get("flags", 0))
	var alive := (flags & ArenaState.ALIVE) != 0
	var want := Phase.PARKED
	if not alive:
		want = Phase.DEAD
		_dead_air = (flags & ArenaState.WARNING) != 0
	elif flags & ArenaState.ESCAPE:
		want = Phase.ESCAPED
	elif flags & ArenaState.WARNING:
		want = Phase.DYING
	elif flags & ArenaState.ACTIVE:
		want = Phase.CLIMBING
	elif flags & ArenaState.ARMED:
		want = Phase.SPOOLING
	if _health:
		_health.hp = clampf(float(row.get("hp", 0.0)), 0.0, 1.0) * MAX_HP
	var elapsed := float(int(row.get("timer_ms", 0))) / 1000.0
	if want != phase:
		if want == Phase.DYING and _death_pos == Vector2.ZERO:
			_death_pos = global_position
			_death_lift = current_lift()
		phase = want
		phase_elapsed = elapsed
		_enter_phase(want, initial_state)
	else:
		phase_elapsed = elapsed
	_net_initialized = true

## ---- paint -----------------------------------------------------------------

func _draw() -> void:
	if phase == Phase.DEAD:
		RemainsPaint.draw_marks(self, RemainsPaint.generate(Vector2(110, 60), &"scorch",
			BODY_DARK, Color(0.06, 0.06, 0.06), RemainsPaint.remains_seed(position)))
		return
	if not visible:
		return
	var lift := current_lift()
	# Ground shadow: detaches and thins with real altitude (vehicle recipe).
	var s := clampf(1.0 - lift * 0.004, 0.45, 1.0)
	draw_set_transform(Vector2(10, 14 + lift * 0.4), 0.0, Vector2(s, s))
	draw_rect(Rect2(-85, -28, 170, 56), Color(0, 0, 0, SHADOW.a * clampf(1.0 - lift * 0.006, 0.3, 1.0)))
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
	# Fuselage: green hull, white cabin stripe, cockpit, tail boom + rotor.
	draw_rect(Rect2(-52, -26, 96, 52), _hull(BODY))
	draw_circle(Vector2(44, 0), 24.0, _hull(BODY))
	draw_rect(Rect2(-50, -9, 96, 18), _hull(STRIPE))
	draw_circle(Vector2(52, 0), 12.0, _hull(GLASS))
	draw_rect(Rect2(-85, -6, 36, 12), _hull(BODY_DARK))         # tail boom
	draw_rect(Rect2(-88, -16, 8, 32), _hull(BODY_DARK))         # tail fin
	draw_circle(Vector2(-84, -16), 7.0, _hull(ROTOR))           # tail rotor
	draw_rect(Rect2(-14, -4, 20, 8), _hull(Color(0.2, 0.3, 0.6)))  # flag band
	if phase == Phase.DYING:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(phase_elapsed * 30.0)
		for i in 4:  # smoke gulps trailing the spiral
			var back := Vector2(-60 - i * 26 - rng.randf() * 12, rng.randf_range(-14, 14))
			draw_circle(back, 10.0 + i * 4.0, Color(0.2, 0.2, 0.2, 0.5 - i * 0.1))
	# Main rotor: blades while slow, a translucent disc once it screams.
	var spun := phase != Phase.PARKED
	if spun:
		draw_circle(Vector2.ZERO, 92.0, Color(0.75, 0.78, 0.8, 0.10))
	for i in 4:
		var a := _rotor_angle + TAU * i / 4.0
		draw_line(Vector2.ZERO, Vector2(90, 0).rotated(a), ROTOR, 5.0 if not spun else 2.5)
	draw_circle(Vector2.ZERO, 8.0, ROTOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _hull(c: Color) -> Color:
	return c.lerp(Color(0.25, 0.22, 0.2), 1.0 - clampf(_health.hp / MAX_HP, 0.0, 1.0) * 0.6) \
		if _health else c
