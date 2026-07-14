class_name Vehicle
extends CharacterBody2D
## The one vehicle. A Driver supplies intent; a DrivingController turns it into
## motion. Player and AI both instance this scene — only the Driver, faction, and
## stats differ. If a VehicleStats resource is assigned, StatCurves configures the
## controller + health from its 1-20 design stats, then per-car handling_overrides
## (from the dev dashboard) win. The body stays axis-aligned (so a child Camera2D
## never spins); only the Visual rotates. Combat is free-for-all: faction is
## identity only, not damage immunity.
##
## Collision layers: 1 = ground (vehicles, dummies), 2 = walls/barriers,
## 4 = obstacles (blocks/cover). While airborne the car keeps only the wall bit,
## so jump-pad launches clear obstacles but can't leave the arena.
##
## Multi-floor levels (terraced: floors.gd) tag regions with FloorZones; the
## FloorSensor reads them and the car carries floor_index (-1 = legacy level,
## masks identical to the classic values above). On a floor, cars collide via
## their floor bit instead of the plain ground/obstacle bits, so cross-floor
## cars and other floors' walls don't exist physically. All grounded layer/mask
## decisions live in _apply_ground_collision() — the single mask authority.

const LAYER_GROUND := 1
const LAYER_WALL := 2
const LAYER_OBSTACLE := 4
const DEFAULT_SHIELD_SECONDS := 2.0
const CRASH_HARD_SPEED := 420.0  # impact px/s into the surface: >= this = totaled
	# sound, below (but over the 2x bounce gate) = fender-bender
const SPLASH_MIN_SPEED := 200.0  # min speed entering water terrain to cue a splash
const HEADING_STEPS := 16  # quantize the visual to N compass steps (retro
							# directional-sprite feel); 0 = smooth rotation
const FLOOR_SCALE_TWEEN := 0.25  # size-cue tween on floor change (visuals only)
const FLOOR_LIFT := 32.0  # px of visual lift per floor above the baseline (2) —
						  # the jump-cue held: body up, shadow grounded, so an
						  # elevated car reads elevated even overlapping a low one
const Combat := preload("res://game/combat.gd")  # AI-vs-AI governor/mercy rules
const Difficulty := preload("res://game/difficulty.gd")  # tier knob table (leaf)
const Floors := preload("res://game/floors.gd")  # terraced-floor math (dependency-free)
const ExplosionScene := preload("res://environment/explosion.tscn")
const SinkBubbles := preload("res://environment/sink_bubbles.gd")
const TurretScript := preload("res://weapons/turret.gd")
const NetEvents := preload("res://game/net/net_events.gd")

signal combat_hit(attacker: Node2D)

@export_group("Identity")
@export var stats: VehicleStats
@export var faction: StringName = &"player"
@export var body_color := Color(0.85, 0.2, 0.3)
@export var ai_cooldown_scale := 3.0  # AI mounts fire at 1/3 player rate
@export var fixed_loadout := false    # bosses: the level's car re-roll skips this vehicle
@export var rear_weakspot := 1.0      # >1 amplifies projectile hits that arrive from behind
@export var body_scale := 1.0         # bosses: scales visuals + collision RADIUS — never
									  # the body node (scaled physics bodies jam move_and_slide)
@export var hp_scale := 1.0           # bosses: multiplies StatCurves HP
@export var launch_immune := false    # too heavy to flip: jump pads roll under it,
									  # jump mines pop for nothing, land mines can't
									  # spin it (mine.gd checks this flag too)
@export var mine_weakness := 1.0      # >1 amplifies land-mine damage — Goliath's
									  # soft underbelly (all that armor had to be
									  # paid for somewhere; mine.gd reads this)

@export_group("Depth")
@export var gravity_z := 1300.0
@export var jump_launch := 760.0
@export var min_launch_speed := 120.0
@export var fall_damage_frac := 0.25  # of max HP, landing 2+ floors below takeoff
@export var start_floor := -1  # authored spawn terrace — a roof spawn must never
							   # boot with the legacy mask inside its warehouse

@export_group("Ram")
@export var ram_damage_scale := 0.06
@export var ram_min_speed := 220.0
@export var ram_cooldown := 0.3
@export var punch_hp_ref := 200.0     # punch-through keep-scale reference:
@export var punch_keep_min := 0.55    # ram-killing a prop restores entry speed
@export var punch_keep_max := 0.95    # scaled by its heft — debris flies, cover costs

@export_group("Bounce")
@export var bounce_factor := 0.35     # fraction of the into-surface speed reflected
@export var bounce_min_speed := 100.0  # below this, grinding along walls stays smooth

var heading: float = 0.0  # radians; the direction the nose points
var current_terrain: StringName = &"road"
var _prev_terrain: StringName = &"road"  # splash edge-detect (water entry SFX)
var height: float = 0.0   # fake vertical offset (px); 0 = on the ground
var vz: float = 0.0       # vertical velocity (px/s)
var floor_index := -1     # terrace we drive on; -1 = legacy single-plane level
var _takeoff_floor := -1  # floor at the moment we went airborne (fall bookkeeping)
var _floor_tween: Tween = null
var _shield_tween: Tween = null
var _floor_lift := 0.0    # visual elevation for upper terraces (see FLOOR_LIFT)
var _grade_visuals: Array[Node] = []  # duck-typed visual_floor_at providers;
	# derived locally from world position, including network puppets
var _floor_vis := 1.0:    # size cue — composes into the VISUALS only, never radii
	set(v):
		_floor_vis = v
		if _visual:
			_visual.scale = Vector2.ONE * body_scale * v
var _ram_cd := 0.0        # cooldown between ram hits
var _shake := 0.0         # camera shake energy (player only)
var _falling := false     # mid pit-fall (shrinking); suppresses the explosion
var _fire_lock := false   # selection changed while fire held — release to re-arm
						   # (a dry slot auto-cycles mid-click; without this the
						   # same press instantly fires the next weapon)
var _mg_alt := 0          # staggered multi-barrel MG: which barrel fires next
var _repairing := false
var _repair_anchor := Vector2.ZERO
var _repair_saved_velocity := Vector2.ZERO
var _repair_saved_heading := 0.0
const REPAIR_IMMUNITY := &"health_station"
# Whoever hurt us last — AI holds a grudge, and the MP MatchDirector bills
# kills against it within a recency window (pit-shoves count; ancient grudges
# don't). The setter stamps the clock on every hit, whoever assigns it.
var last_attacker: Node2D = null:
	set(v):
		last_attacker = v
		last_attacker_ms = Time.get_ticks_msec()
var last_attacker_ms := 0

# Chilblain encasement: a frozen car loses all intent while its momentum
# skates down to a dead stop under this damping (px/s^2).
static var FREEZE_DECEL := 900.0

# --- Network puppet (LAN clients render EVERY car through this; the host runs
# the real sim). The whole _physics_process body is bypassed; state arrives as
# snapshot slices and the puppet interpolates between the two newest, then
# runs the same visual tail as the sim (16-step snap, shadow, depth paint).
var net_puppet := false
static var NET_INTERP_MS := 50.0  # render-behind buffer; the MP shell syncs
								  # this from NetProtocol.interp_delay_ms
var _net_a := {}          # older sample {t, pos, vel, heading, height}
var _net_b := {}          # newer sample
var _net_prev_hp := -1.0  # local hit feedback: flash/shake on streamed drops
var _net_alive := true    # edge-detected: falling = boom + hide, rising = show
var _net_shield := false  # streamed blink-shield flag (visual pulse only)
var _net_repairing := false
var _net_repair_station: Node = null

@onready var _controller: DrivingController = $DrivingController
@onready var _driver: Driver = $Driver
@onready var _visual: Node2D = $Visual
@onready var _shadow: Node2D = $Shadow
@onready var _paint: Node2D = $Visual/Body
@onready var _terrain_sensor: TerrainSensor = $TerrainSensor
@onready var _floor_sensor: FloorSensor = $FloorSensor
@onready var _mg_mount: WeaponMount = $MachineGunMount
@onready var _special: SpecialController = $SpecialController
@onready var _muzzle: Marker2D = $Visual/Muzzle
@onready var _rear_muzzle: Marker2D = $Visual/RearMuzzle
@onready var _health: Health = $Health
@onready var _status: StatusReceiver = $Status
@onready var _rack: WeaponRack = $WeaponRack

func _ready() -> void:
	if stats == null and faction == &"player":
		# Player car comes from the picker (GameState); fall back to Ghost so a
		# direct/dev arena launch still works. Autoload fetched by path so this
		# script compiles in headless -s test runs (no autoloads there).
		var gs := get_node_or_null(^"/root/GameState")
		var id: StringName = gs.selected_vehicle_id if gs else &""
		var path := "res://data/vehicles/ghost.tres"
		if id != &"":
			path = "res://data/vehicles/%s.tres" % id
		stats = load(path)
	if stats:
		_apply_stats()
	else:
		_paint.apply(&"", body_color, Color(1, 0.85, 0.2))
		_sync_body_metrics()
	if body_scale != 1.0:
		_visual.scale = Vector2.ONE * body_scale
	add_to_group(faction)        # "player" or "enemies" — identity
	add_to_group(&"vehicles")    # every combatant, for free-for-all targeting
	if start_floor >= 1:
		_adopt_floor(start_floor)  # deferred masks land before the first physics tick
	if faction != &"player":
		# Same loadout as the player, a third of the trigger speed — slower
		# still on the easier tiers (difficulty knob is 1.0 on hard).
		var trigger_scale := ai_cooldown_scale * Difficulty.knob(&"ai_fire_cooldown")
		if _mg_mount:
			_mg_mount.cooldown_scale = trigger_scale
		var secondary := get_node_or_null(^"SecondaryMount") as WeaponMount
		if secondary:
			secondary.cooldown_scale = trigger_scale
	if _rack and _special:
		# Selection drives what the special/secondary path fires next. The lock
		# forces a trigger release before the newly selected slot can fire.
		_rack.selection_changed.connect(func(_i: int) -> void:
			_special.set_weapon(_rack.selected_def())
			_fire_lock = true)
	if _health:
		_health.died.connect(_on_died)
		_health.damaged.connect(_on_damaged)
	heading = rotation
	rotation = 0.0
	call_deferred("_cache_grade_visuals")
	# DEVGOD (settings): player-only — damage-immune, one of everything, firing
	# never depletes. Pits still kill; the level's lives loop comps the life.
	# INERT in a live LAN session (duck-typed off the Net autoload; Mode.OFF
	# is 0) — nobody gods up a lobby.
	var god_gs := get_node_or_null(^"/root/GameState")
	var net_live := get_node_or_null(^"/root/Net")
	var in_mp: bool = net_live != null and int(net_live.get("mode")) != 0
	if faction == &"player" and god_gs and god_gs.is_devgod_enabled() and not in_mp:
		if _health:
			_health.god = true
		if _rack:
			_rack.god = true
			_rack.arm_all_once()
	# Player camera boots straight at the persisted zoom (no pull-in from the
	# scene's authored value on every level start).
	var boot_cam := get_node_or_null(^"Camera2D") as Camera2D
	var boot_gs := get_node_or_null(^"/root/GameState")
	if boot_cam and boot_cam.enabled and boot_gs:
		boot_cam.zoom = Vector2.ONE * (boot_gs.zoom_overview if boot_gs.overview else boot_gs.zoom_combat)

func _exit_tree() -> void:
	_set_net_repairing(false, global_position)
	end_repair_hold(false)

## Hit feedback: brief white pulse (skipped for sub-1 DoT ticks, which would
## strobe), plus camera shake when it's the player taking it.
func _on_damaged(amount: float, _hp: float) -> void:
	if amount < 1.0:
		return
	if not net_puppet and is_instance_valid(last_attacker):
		combat_hit.emit(last_attacker)
		NetEvents.hit_landed(last_attacker, self)
	if _visual:
		_visual.modulate = Color(2.2, 2.2, 2.2)
		var tween := create_tween()
		tween.tween_property(_visual, "modulate", Color.WHITE, 0.12)
	if is_in_group(&"player"):
		add_shake(minf(amount * 0.4, 8.0))

func add_shake(amount: float) -> void:
	var gs := get_node_or_null(^"/root/GameState")
	if gs and not gs.screen_shake:
		return  # accessibility toggle: steady camera
	_shake = minf(_shake + amount, 12.0)

func _process(delta: float) -> void:
	var camera := get_node_or_null(^"Camera2D") as Camera2D
	if camera == null or not camera.enabled:
		return
	if _shake > 0.05:
		_shake = maxf(_shake - 30.0 * delta, 0.0)
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO
	# Zoom toggle: combat close-up vs overview pull-back. State + values live on
	# GameState (proto-settings; persists across levels/respawns); the lerp makes
	# it read as a camera move. Vector art keeps both ends pixel-crisp.
	var gs := get_node_or_null(^"/root/GameState")
	if gs == null:
		return
	if Input.is_action_just_pressed(&"zoom_toggle"):
		gs.overview = not gs.overview
	var target: float = gs.zoom_overview if gs.overview else gs.zoom_combat
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target, minf(6.0 * delta, 1.0))

## Applies the current stats to the controller/health/visuals. Re-callable live
## (the dev dashboard's car switcher uses set_stats()).
func _apply_stats() -> void:
	StatCurves.apply(stats, _controller, _health)
	if _health and hp_scale != 1.0:
		_health.max_hp *= hp_scale
		_health.hp = _health.max_hp
	for k in stats.handling_overrides:
		_controller.set(k, stats.handling_overrides[k])
	body_color = stats.primary_color
	_paint.apply(stats.id, stats.primary_color, stats.accent_color)
	_sync_body_metrics()
	if _rack:
		_rack.configure(stats.special, stats.special_ammo_cap, stats.special_recharge_seconds,
			stats.special_b, stats.no_mines)
	if stats.special and _special:
		_special.set_weapon(_rack.selected_def() if _rack else stats.special)
	if _special:
		_special.set_twin(stats.special_b)
	# Boss turret: an autonomous auto-aiming barrel riding the hull (data-driven —
	# any car whose stats carry a turret def grows one; fixed_loadout bosses never
	# re-roll, and the name guard keeps live re-stats from stacking barrels).
	if stats.turret and _visual and _visual.get_node_or_null(^"Turret") == null:
		var turret := TurretScript.new()
		turret.name = "Turret"
		turret.position = Vector2(2.5, 0)  # the painted cannon ring (2,0 × fleet)
		_visual.add_child(turret)
		turret.set_weapon(stats.turret)

func set_stats(new_stats: VehicleStats) -> void:
	if new_stats == null:
		return
	stats = new_stats
	_apply_stats()

## Pushes the paint style's footprint into everything that must agree with it:
## shadow silhouette, muzzle nose, collision radius. Radius is set absolutely
## from the style (× body_scale) so repeated re-rolls never compound.
func _sync_body_metrics() -> void:
	if _paint == null or not _paint.has_method("metrics"):
		return
	var m: Dictionary = _paint.metrics()
	if _shadow is Polygon2D:
		(_shadow as Polygon2D).polygon = _paint.shadow_polygon()
	if _muzzle:
		_muzzle.position = Vector2(float(m.half_len) + 4.0, 0.0)
	if _rear_muzzle:
		_rear_muzzle.position = Vector2(-float(m.half_len) - 4.0, 0.0)
	var col := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if col and col.shape is CircleShape2D:
		var shape: CircleShape2D = col.shape.duplicate()  # never resize the shared resource
		shape.radius = float(m.radius) * body_scale
		col.shape = shape

## Per-style footprint/contact metrics for FX (skids, flames, mounts).
func body_metrics() -> Dictionary:
	if _paint and _paint.has_method("metrics"):
		return _paint.metrics()
	return {}

func get_controller() -> DrivingController:
	return _controller

func get_driver() -> Driver:
	return _driver

## Runtime driver swap (the victory lap): frees the seated driver, seats the
## new one, and re-points the cached reference — @onready never re-runs.
func set_driver(driver: Driver) -> void:
	if _driver and is_instance_valid(_driver):
		_driver.queue_free()
	driver.name = "Driver"
	add_child(driver)
	_driver = driver

## Projectile secondaries choose their authored bumper and bearing here. Keeping
## the decision on the vehicle lets every ordinary weapon stay pure data while
## the mount continues to receive the same origin/direction pair it always has.
func secondary_launch(def: WeaponDef) -> Dictionary:
	var forward := Vector2.RIGHT.rotated(heading)
	if def and def.launch_side == WeaponDef.LaunchSide.REAR and _rear_muzzle:
		return {"origin": _rear_muzzle.global_position, "direction": -forward}
	return {"origin": _muzzle.global_position if _muzzle else global_position,
		"direction": forward}

func _physics_process(delta: float) -> void:
	if net_puppet:
		_puppet_physics(delta)
		return
	if _terrain_sensor:
		current_terrain = _terrain_sensor.current_terrain
	if current_terrain != _prev_terrain:
		if current_terrain == &"water" and get_speed() > SPLASH_MIN_SPEED:
			var audio_w := get_node_or_null(^"/root/AudioDirector")
			if audio_w:
				if is_in_group(&"player"):
					audio_w.play(&"splash")
				else:
					audio_w.play_at(&"splash", global_position)
		_prev_terrain = current_terrain
	if current_terrain == &"water" and _status and _status.has_effect(&"burn"):
		_status.clear_kind(&"burn")  # shallow water douses hull fire on contact
	_update_floor()
	if _repairing:
		# Remain a solid obstacle, but never ask move_and_slide to resolve the
		# body away from the bay. Child cooldown/recharge/status ticks continue.
		global_position = _repair_anchor
		velocity = Vector2.ZERO
		heading = _repair_saved_heading
		if _controller:
			_controller.boosting = false
			_controller.handbraking = false
			_controller.service_braking = false
		_sync_brake_lights()
		var held_heading := heading if HEADING_STEPS <= 0 else snappedf(heading, TAU / HEADING_STEPS)
		_visual.rotation = held_heading
		if _shadow:
			_shadow.rotation = held_heading
		_update_depth(delta)
		return
	var intent: Dictionary = _driver.get_intent(self, delta) if _driver else {}
	if _status and _status.has_effect(&"freeze"):
		intent = {}  # encased in ice: no pedals, no triggers
		velocity = velocity.move_toward(Vector2.ZERO, FREEZE_DECEL * delta)
	elif _status and _status.is_stunned():
		intent = {}  # stunned: hands off the wheel — friction owns the car
	elif _status and _status.has_effect(&"disarm"):
		intent.erase("fire_mg")  # disarmed: pedals work, triggers don't
		intent.erase("fire_selected")
	if _special and _special.is_spinning() and intent.has("steer"):
		# Tornado Alley: rear wheels are off the ground — mostly a passenger.
		intent["steer"] = float(intent["steer"]) * SpecialController.TORNADO_STEER
	if _controller and not (_special and _special.is_dashing()) \
			and not (_driver and _driver.has_method(&"is_forcing") and _driver.is_forcing()):
		# Normal driving; skipped mid-Leap (and mid-charge for drivers that
		# force velocity, duck-typed) so the controller's top-speed clamp
		# doesn't eat the dash velocity.
		_controller.apply(self, intent, delta)
		if _controller.boosting and _status:
			_status.clear_kind(&"burn")  # nitro wind blows the fire out
	elif _controller:
		_controller.service_braking = false
	_sync_brake_lights()
	# Captured before move_and_slide: a head-on hit on a static body zeroes
	# velocity during the slide, so post-slide speed under-reads the impact.
	var pre_slide_vel := velocity
	move_and_slide()
	_apply_bounce(pre_slide_vel)
	_update_ram(delta, pre_slide_vel)
	var visual_heading := heading if HEADING_STEPS <= 0 else snappedf(heading, TAU / HEADING_STEPS)
	if _special and _special.is_spinning():
		visual_heading = _special.tornado_visual_angle()  # whirl past the quantizer
	_visual.rotation = visual_heading
	if _shadow:
		_shadow.rotation = visual_heading
	_update_depth(delta)
	var aim := Vector2.RIGHT.rotated(heading)
	if _mg_mount and _muzzle and intent.get("fire_mg", false):
		if _mg_mount.try_fire(_mg_origin(), aim, self):
			_mg_alt += 1  # staggered multi-barrel styles alternate on real shots
	if _rack:
		if intent.get("weapon_prev", false):
			_rack.select_prev()
		if intent.get("weapon_next", false):
			_rack.select_next()
	if _special and _muzzle:
		var pressed: bool = intent.get("fire_selected", false)
		if not pressed:
			_fire_lock = false
		var wants_fire := pressed and not _fire_lock
		if _rack:
			wants_fire = wants_fire and _rack.can_consume()
		# Def captured BEFORE the shot: consume() can auto-cycle the selection.
		var firing_def: WeaponDef = _rack.selected_def() if _rack else null
		var launch: Dictionary = secondary_launch(firing_def)
		if _special.activate(wants_fire, launch.origin, launch.direction, self) and _rack:
			_rack.consume()
			# Mines announce the drop; projectile fire is voiced by the mount.
			if is_in_group(&"player") and firing_def and firing_def.kind == WeaponDef.Kind.DROP:
				var audio_m := get_node_or_null(^"/root/AudioDirector")
				if audio_m:
					audio_m.play(&"mine_drop")

func _update_depth(delta: float) -> void:
	if height > 0.0 or vz != 0.0:
		vz -= gravity_z * delta
		height += vz * delta
		if height <= 0.0:
			height = 0.0
			vz = 0.0
			_resolve_landing_floor()
			_set_airborne(false)
	_paint_depth()

## The height/lift paint, physics-free — the sim integrates then paints; a
## network puppet paints its STREAMED height directly (never integrates).
func _paint_depth() -> void:
	var grounded_lift := _floor_lift
	var grounded_scale := _floor_vis
	var grade_floor := _grade_visual_floor()
	if grade_floor > -INF:
		grounded_lift = FLOOR_LIFT * maxf(0.0, grade_floor - 2.0)
		grounded_scale = _visual_scale_at_floor(grade_floor)
	_visual.position.y = -(height + grounded_lift)
	_visual.scale = Vector2.ONE * body_scale * grounded_scale
	if _shadow:
		# The shadow RIDES the terrace lift (tight under a driving car) and only
		# detaches/shrinks with real airtime — floating is for jumps, not roofs.
		_shadow.position.y = -grounded_lift
		var s := clampf(1.0 - height * 0.0012, 0.5, 1.0) * body_scale * grounded_scale
		_shadow.scale = Vector2(s, s)
		_shadow.modulate.a = clampf(1.0 - height * 0.0016, 0.4, 1.0)

func _cache_grade_visuals() -> void:
	_grade_visuals.clear()
	if is_inside_tree():
		for grade in get_tree().get_nodes_in_group(&"driveable_grades"):
			if grade.has_method(&"visual_floor_at"):
				_grade_visuals.append(grade)

func _grade_visual_floor() -> float:
	if _grade_visuals.is_empty() and is_inside_tree():
		_cache_grade_visuals()  # absorbs authoring order and runtime hill builds
	var best := -INF
	for grade in _grade_visuals:
		if not is_instance_valid(grade) or not grade.is_inside_tree():
			continue
		var value := float(grade.visual_floor_at(global_position))
		if value > -INF:
			best = maxf(best, value)
	return best

func _visual_scale_at_floor(value: float) -> float:
	var low := int(floorf(value))
	var high := int(ceilf(value))
	var low_scale := float(Floors.VISUAL_SCALE.get(low, 1.0))
	var high_scale := float(Floors.VISUAL_SCALE.get(high, low_scale))
	return lerpf(low_scale, high_scale, value - float(low))

# ------------------------------------------------------------ network puppet

## Flips this car between simulated and mirrored. Puppets are visual-only:
## collision drops to nothing (snapshot positions are wall-valid — the host
## simulated them against real geometry) and every host-authoritative
## subsystem stops ticking locally (heat, ammo recharge, status DoT, special
## beams — their state arrives in slices instead).
func set_net_puppet(on: bool) -> void:
	net_puppet = on
	var secondary := get_node_or_null(^"SecondaryMount")
	for node in [_mg_mount, secondary, _rack, _special, _status]:
		if node:
			(node as Node).set_physics_process(not on)
	if on:
		collision_layer = 0
		collision_mask = 0
		_net_a = {}
		_net_b = {}
		_net_prev_hp = get_hp()
		_net_alive = true
		_net_shield = false
	else:
		_set_net_repairing(false, global_position)
		_apply_ground_collision()

## One snapshot slice for this car. Motion fields buffer for interpolation;
## authoritative fields land immediately — hp straight onto Health (never
## take_damage: a mirror must not re-run death/damage side effects), status
## and control FLAGS driving the existing cosmetics (boost flame, skids, burn
## licks). The viewer's own car keeps its hit feedback via _on_damaged.
func apply_net_state(slice: Dictionary) -> void:
	if not net_puppet:
		return
	_net_a = _net_b
	_net_b = {
		"t": int(slice.get("t", Time.get_ticks_msec())),
		"pos": slice.get("pos", global_position),
		"vel": slice.get("vel", Vector2.ZERO),
		"heading": float(slice.get("heading", heading)),
		"height": float(slice.get("height", 0.0)),
	}
	if slice.has("floor"):
		var f := int(slice.floor)
		if f >= 1 and f != floor_index:
			_adopt_floor(f)  # the existing tween carries the lift/size cue
	if _health and slice.has("hp"):
		var new_hp := float(slice.hp)
		if _net_prev_hp >= 0.0 and new_hp < _net_prev_hp - 0.5:
			_on_damaged(_net_prev_hp - new_hp, new_hp)  # flash (+shake if viewer's)
		_health.hp = new_hp
		_net_prev_hp = new_hp
	if _controller:
		_controller.boosting = bool(slice.get("boost", _controller.boosting))
		_controller.handbraking = bool(slice.get("handbrake", _controller.handbraking))
		_controller.service_braking = bool(slice.get("brake", _controller.service_braking))
	_sync_brake_lights()
	if _status and slice.has("burn"):
		_status.set_cosmetic(&"burn", bool(slice.burn))
	if _status and slice.has("disarm"):
		# Marker + HUD dim read is_disarmed() — the host owns the actual gate.
		_status.set_cosmetic(&"disarm", bool(slice.disarm))
	if _status and slice.has("freeze"):
		# Frost marker reads is_frozen(); streamed pos/vel already carry the stop.
		_status.set_cosmetic(&"freeze", bool(slice.freeze))
	if _special:
		# Sustained special cosmetics (protocol 9): the flag IS the lifecycle.
		if slice.has("flame"):
			_special.mirror_flame(bool(slice.flame))
		if slice.has("tornado"):
			_special.mirror_tornado(bool(slice.tornado))
		if slice.has("armed_trigger"):
			_special.mirror_armed(bool(slice.armed_trigger))
	if slice.has("alive"):
		var alive: bool = slice.alive
		if _net_alive and not alive:
			_spawn_explosion()  # the mirror's boom — the host already billed it
			visible = false
		elif alive and not _net_alive:
			visible = true
			_net_a = {}  # a respawn teleports; never lerp across the map
		_net_alive = alive
	if slice.has("shield"):
		_net_shield = bool(slice.shield)
		if not _net_shield and _visual and _net_alive:
			_visual.modulate.a = 1.0
	if slice.has("repairing"):
		_set_net_repairing(bool(slice.repairing), slice.get("pos", global_position))
	# HUD mirrors: the viewer's dash reads its puppet like a live car.
	if _mg_mount and slice.has("heat"):
		_mg_mount.net_mirror_heat(float(slice.heat), bool(slice.get("mg_locked", false)))
	if _controller and slice.has("boost_fuel"):
		_controller.boost_fuel = float(slice.boost_fuel)
	if _rack and slice.has("ammo"):
		_rack.net_mirror(int(slice.get("slot", 0)), slice.ammo,
			float(slice.get("recharge", 1.0)))

func _sync_brake_lights() -> void:
	if _paint and _paint.has_method(&"set_service_braking"):
		_paint.set_service_braking(_controller != null and _controller.service_braking)

## The puppet's whole physics tick: interpolate the two newest samples at
## (now - NET_INTERP_MS), then the sim's visual tail — identical read.
func _puppet_physics(delta: float) -> void:
	if not _net_b.is_empty():
		if _net_a.is_empty() or int(_net_b.t) <= int(_net_a.t):
			global_position = _net_b.pos
			velocity = _net_b.vel
			heading = float(_net_b.heading)
			height = float(_net_b.height)
		else:
			var render_t := float(Time.get_ticks_msec()) - NET_INTERP_MS
			var span := float(int(_net_b.t) - int(_net_a.t))
			# Up to 1.25 samples of extrapolation rides out one dropped packet
			# without freezing; anything staler holds the last known state.
			var f := clampf((render_t - float(int(_net_a.t))) / span, 0.0, 1.25)
			global_position = (_net_a.pos as Vector2).lerp(_net_b.pos, f)
			velocity = (_net_a.vel as Vector2).lerp(_net_b.vel, f)
			heading = lerp_angle(float(_net_a.heading), float(_net_b.heading), f)
			height = lerpf(float(_net_a.height), float(_net_b.height), f)
	if _special:
		_special.mirror_tick(delta)  # flame flicker / whirl on mirrored FX
	var visual_heading := heading if HEADING_STEPS <= 0 else snappedf(heading, TAU / HEADING_STEPS)
	if _special and _special.is_spinning():
		visual_heading = _special.tornado_visual_angle()  # same seam as the sim
	_visual.rotation = visual_heading
	if _shadow:
		_shadow.rotation = visual_heading
	_paint_depth()
	_update_draw_order(height > 0.0)
	if _net_shield and _visual and _net_alive:
		# The respawn blink, mirrored: same 200ms cadence as the SP tween.
		_visual.modulate.a = 0.35 if (Time.get_ticks_msec() / 100) % 2 == 0 else 1.0

## Grounded floor bookkeeping. Adopting happens on first zone contact; driving
## past a lower zone's edge is a ledge hop down (floor resolves at touchdown).
## A HIGHER sensed floor while grounded is deliberately ignored — walls own the
## up-boundaries; you climb by landing there, never by grinding a seam.
func _update_floor() -> void:
	if _floor_sensor == null or height > 0.0 or vz != 0.0 or _falling:
		return
	var sensed: int = _floor_sensor.current_floor
	if sensed < 1:
		return
	if floor_index < 0:
		_adopt_floor(sensed)
	elif _floor_sensor.on_ramp and sensed != floor_index:
		_adopt_floor(sensed)  # driveable ramp: grade over BOTH ways — no hop,
							  # no fall bill; the slope carries you
	elif sensed < floor_index:
		pop_airborne(Floors.DROP_POP_VZ * float(floor_index - sensed))

## Touchdown: the floor tag under the car becomes its floor; dropping 2+
## floors from takeoff costs a slice of max HP (blink shield / DEVGOD apply).
func _resolve_landing_floor() -> void:
	var from := _takeoff_floor
	_takeoff_floor = -1
	if _floor_sensor == null:
		return
	var sensed: int = _floor_sensor.current_floor
	if sensed < 1:
		return
	if sensed != floor_index:
		_adopt_floor(sensed)
	if from >= 1 and from - sensed > Floors.FALL_FREE_FLOORS and _health:
		_health.take_damage(_health.max_hp * fall_damage_frac)
		add_shake(6.0)

func _adopt_floor(f: int) -> void:
	floor_index = f
	_apply_ground_collision()
	_update_draw_order(height > 0.0)
	var target: float = float(Floors.VISUAL_SCALE.get(f, 1.0))
	var lift_target := FLOOR_LIFT * maxf(0.0, float(f) - 2.0)
	if _floor_tween:
		_floor_tween.kill()
	_floor_tween = create_tween()
	_floor_tween.set_parallel(true)
	_floor_tween.tween_property(self, "_floor_vis", target, FLOOR_SCALE_TWEEN)
	_floor_tween.tween_property(self, "_floor_lift", lift_target, FLOOR_SCALE_TWEEN)

## Draw order carries the depth read: airborne cars and top-terrace cars draw
## ABOVE overhead paint (bridges and crane booms live at z 1); everyone else
## stays at the classic z 0 under it. Legacy levels never leave 0.
func _update_draw_order(airborne: bool) -> void:
	z_index = 2 if (airborne or floor_index >= 3) else 0

## The single authority for grounded collision values (legacy -1 = the classic
## 1 / ground|wall|obstacle). SpecialController's dash-end restore duck-types
## current_ground_mask() — keep the signature.
func current_ground_mask() -> int:
	return Floors.ground_mask(floor_index)

func _apply_ground_collision() -> void:
	set_deferred("collision_layer", Floors.ground_layer(floor_index))
	set_deferred("collision_mask", current_ground_mask())

func _set_airborne(on: bool) -> void:
	# Airborne: keep the wall bit (stay in the arena), drop ground + obstacles
	# (clear other cars and blocks — jump launches sail over cover). Every launch
	# stamps the takeoff floor so landings can bill the fall.
	if on:
		_takeoff_floor = floor_index
		set_deferred("collision_mask", LAYER_WALL)
	else:
		_apply_ground_collision()
	_update_draw_order(on)

## Smaller pop than a jump pad (jump mines) — airborne physics from any height kick.
func pop_airborne(vz_speed: float) -> void:
	if _repairing or height > 0.0 or launch_immune:
		return
	vz = vz_speed
	_set_airborne(true)

## AI stuck-escape: a jump-mine-style hop — re-aim, launch, sail over whatever
## we're wedged against (airborne already drops car+obstacle collision bits).
## Reads as the established jump mechanic, not noclip. Driver-called, AI only.
const ESCAPE_HOP_SPEED := 420.0
const ESCAPE_HOP_VZ := 430.0

func escape_hop(direction: Vector2) -> void:
	if _repairing or height > 0.0 or direction == Vector2.ZERO:
		return
	heading = direction.angle()
	velocity = direction * ESCAPE_HOP_SPEED
	pop_airborne(ESCAPE_HOP_VZ)

## A heavyweight collision reaction (Goliath's jackknife tail, the phase-2 ram
## charge): momentum dies into a hard fling from the impact point, the heading
## spins off, and a stun cuts the controls while physics carries the car.
## dmg 0 = the caller already billed damage elsewhere (charge hits ride the
## normal ram loop; the tail bills its own).
func apply_impact(from: Vector2, dmg: float, knockback: float, spin: float, stun_t: float) -> void:
	if _repairing:
		return
	var dir := (global_position - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(heading)
	velocity = dir * knockback
	heading += spin if randf() < 0.5 else -spin
	if dmg > 0.0 and _health:
		_health.take_damage(dmg)
	if _status and stun_t > 0.0:
		var spec := StatusEffectSpec.new()
		spec.kind = &"stun"
		spec.duration = stun_t
		_status.apply(spec)
	add_shake(8.0)

## Jump pads call this; needs speed and ground. (Driveable RAMPS never launch —
## they grade the floor over via ramp-flagged FloorZones.)
func launch_from_jump() -> void:
	if _repairing or height > 0.0 or launch_immune or velocity.length() < min_launch_speed:
		return
	vz = jump_launch
	var audio_j := get_node_or_null(^"/root/AudioDirector")
	if audio_j:
		if is_in_group(&"player"):
			audio_j.play(&"jump_pad")
		else:
			audio_j.play_at(&"jump_pad", global_position)
	_set_airborne(true)

## Over the edge: kill physics and collisions, shrink into the void, then die
## for real. The fall suppresses the explosion — you fell, you didn't pop.
func fall_into_pit() -> void:
	if _falling or height > 0.0 or (_health and _health.hp <= 0.0):
		return
	_falling = true
	var audio_p := get_node_or_null(^"/root/AudioDirector")
	if audio_p:
		if is_in_group(&"player"):
			audio_p.play(&"pit_fall")
		else:
			audio_p.play_at(&"pit_fall", global_position)
	set_physics_process(false)
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var tween := create_tween()
	if _visual:
		tween.tween_property(_visual, "scale", Vector2(0.05, 0.05), 0.7)
	if _shadow:
		tween.parallel().tween_property(_shadow, "scale", Vector2(0.05, 0.05), 0.7)
	tween.tween_callback(func() -> void:
		if _health:
			_health.kill()
		_falling = false)

## Into the drink: the pit's diminishing-car exit, but wetter — a splash ring
## at entry, a slightly slower shrink darkening toward the water, and rising
## bubbles that outlive the car. _falling suppresses the explosion here too.
func sink_into_water() -> void:
	if _falling or height > 0.0 or (_health and _health.hp <= 0.0):
		return
	_falling = true
	var audio_k := get_node_or_null(^"/root/AudioDirector")
	if audio_k:
		if is_in_group(&"player"):
			audio_k.play(&"sink")
		else:
			audio_k.play_at(&"sink", global_position)
	set_physics_process(false)
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var scene := get_tree().current_scene
	if scene:  # headless fixtures may not set one
		var splash := ExplosionScene.instantiate()
		splash.global_position = global_position
		splash.tint = Color(0.55, 0.75, 0.95)
		splash.size_scale = 0.5
		scene.add_child(splash)
		var bubbles := SinkBubbles.new()
		bubbles.global_position = global_position
		scene.add_child(bubbles)
	var tween := create_tween()
	if _visual:
		tween.tween_property(_visual, "scale", Vector2(0.05, 0.05), 0.8)
		tween.parallel().tween_property(_visual, "modulate", Color(0.25, 0.35, 0.45), 0.8)
	if _shadow:
		tween.parallel().tween_property(_shadow, "scale", Vector2(0.05, 0.05), 0.8)
	tween.tween_callback(func() -> void:
		if _health:
			_health.kill()
		_falling = false)

func _on_died() -> void:
	end_repair_hold(false)
	if _special:
		_special.cancel_dash()
	var drive_fx := get_node_or_null(^"DriveFX")
	if drive_fx and drive_fx.has_method(&"clear_splat_tracks"):
		drive_fx.clear_splat_tracks()
	if not _falling:
		_spawn_explosion()
	# Pit/water deaths already cued their own sound (pit_fall/sink) at fall
	# start — an explosion boom with no explosion visual would read wrong.
	var audio_d := get_node_or_null(^"/root/AudioDirector")
	if is_in_group(&"player"):
		if audio_d and not _falling:
			audio_d.play(&"player_death")
		set_physics_process(false)
		print("[player] destroyed")
	else:
		if audio_d and not _falling:
			audio_d.play_at(&"npc_death", global_position)
		queue_free()

func _spawn_explosion() -> void:
	var scene := get_tree().current_scene
	if scene == null:  # headless fixtures may not set one
		return
	var boom := ExplosionScene.instantiate()
	boom.global_position = global_position
	boom.tint = body_color
	scene.add_child(boom)

func get_speed() -> float:
	return velocity.length()

func get_hp() -> float:
	return _health.hp if _health else 0.0

func get_max_hp() -> float:
	return _health.max_hp if _health else 0.0

func get_hp_fraction() -> float:
	return _health.hp / _health.max_hp if _health and _health.max_hp > 0.0 else 1.0

func get_rack() -> WeaponRack:
	return _rack

func get_mg_mount() -> WeaponMount:
	return _mg_mount

func get_speed_scale() -> float:
	return _status.speed_scale() if _status else 1.0

## Health stations own the refill clock; Vehicle owns the physics/control
## contract. The saved velocity is the complete world vector so reverse and
## drift leave the bay exactly as they entered it.
func begin_repair_hold(anchor: Vector2) -> bool:
	if net_puppet or _repairing or height > 0.0 or vz != 0.0 \
			or _health == null or _health.hp <= 0.0:
		return false
	_repair_saved_velocity = velocity
	_repair_saved_heading = heading
	_repair_anchor = anchor
	_repairing = true
	global_position = anchor
	velocity = Vector2.ZERO
	if _controller:
		_controller.boosting = false
		_controller.handbraking = false
		_controller.service_braking = false
	if _special:
		_special.cancel_for_interaction()
	_health.set_immunity(REPAIR_IMMUNITY, true)
	return true

func end_repair_hold(restore_momentum := true, grant_exit_shield := false) -> void:
	if not _repairing:
		return
	# Lay down the status shield before releasing the bay's named immunity hold:
	# successful treatment has no one-frame damage seam for station campers.
	if grant_exit_shield:
		grant_spawn_shield()
	_repairing = false
	if _health:
		_health.set_immunity(REPAIR_IMMUNITY, false)
	if restore_momentum and _health and _health.hp > 0.0 and is_inside_tree():
		heading = _repair_saved_heading
		velocity = _repair_saved_velocity
	else:
		velocity = Vector2.ZERO

func is_repairing() -> bool:
	return _repairing

func _set_net_repairing(on: bool, at: Vector2) -> void:
	if on == _net_repairing:
		return
	_net_repairing = on
	if not on:
		if is_instance_valid(_net_repair_station) \
				and _net_repair_station.has_method(&"present_remote_treatment"):
			_net_repair_station.call(&"present_remote_treatment", self, false)
		_net_repair_station = null
		return
	var nearest: Node = null
	var nearest_d2 := 96.0 * 96.0
	for station_v in get_tree().get_nodes_in_group(&"health_stations"):
		var station := station_v as Node2D
		if station == null or not station.has_method(&"present_remote_treatment"):
			continue
		if not Floors.same_floor(self, station):
			continue
		var d2 := station.global_position.distance_squared_to(at)
		if d2 <= nearest_d2:
			nearest_d2 = d2
			nearest = station
	_net_repair_station = nearest
	if nearest:
		nearest.call(&"present_remote_treatment", self, true)

## Generic surface-profile lookup for vehicle-side systems beyond driving
## (currently DASH impact). Callers never need roster ids or resource internals.
func terrain_factor(property: StringName, surface: StringName = current_terrain) -> float:
	return stats.terrain_factor(surface, property) if stats else 1.0

func apply_effect(spec: StatusEffectSpec) -> void:
	if _status:
		_status.apply(spec)

func is_burning() -> bool:
	return _status != null and _status.has_effect(&"burn")

func is_disarmed() -> bool:
	return _status != null and _status.has_effect(&"disarm")

func is_frozen() -> bool:
	return _status != null and _status.has_effect(&"freeze")

## MG launch point. Styles with authored mg_points (Hubcap's twin barrels)
## alternate between them — same mount, same rate and heat, the rounds just
## leave staggered. Everything else keeps the classic nose muzzle.
func _mg_origin() -> Vector2:
	var m: Dictionary = body_metrics()
	var guns: Array = m.get("mg_points", [])
	if guns.is_empty():
		return _muzzle.global_position
	var p: Vector2 = guns[_mg_alt % guns.size()]
	return global_position + p.rotated(heading)

func is_shielded() -> bool:
	return _status != null and _status.has_effect(&"invuln")

# Sustained-special state, for the MP host's snapshot rows (protocol 9).
func is_flame_active() -> bool:
	return _special != null and _special.flame_active()

func is_tornado_active() -> bool:
	return _special != null and _special.tornado_active()

func is_trigger_armed() -> bool:
	return _special != null and _special.trigger_armed()

## Shared respawn/repair protection. Re-applying StatusReceiver's same-kind
## effect refreshes it to at least the full requested duration; one owned tween
## keeps the blink cadence from stacking when a shield is refreshed.
func grant_spawn_shield(seconds := DEFAULT_SHIELD_SECONDS) -> void:
	if seconds <= 0.0 or _status == null:
		return
	var shield := StatusEffectSpec.new()
	shield.kind = &"invuln"
	shield.duration = seconds
	apply_effect(shield)
	# StatusReceiver normally re-syncs this on its next physics tick. A bay
	# releases its named hold in this same call, so bridge that frame explicitly.
	if _health:
		_health.invulnerable = true
	if _shield_tween:
		_shield_tween.kill()
	if _visual:
		_visual.modulate.a = 1.0
		_shield_tween = create_tween()
		_shield_tween.set_loops(maxi(1, int(ceilf(seconds / 0.2))))
		_shield_tween.tween_property(_visual, "modulate:a", 0.35, 0.1)
		_shield_tween.tween_property(_visual, "modulate:a", 1.0, 0.1)

## Campaign respawn: back to a spawn point, full tank, physics on, and a brief
## invuln blink-shield so spawn-camping hunters can't chain-kill.
func respawn(at: Vector2, new_heading: float, shield_seconds := DEFAULT_SHIELD_SECONDS) -> void:
	end_repair_hold(false)
	if _special:
		_special.cancel_dash()
	var drive_fx := get_node_or_null(^"DriveFX")
	if drive_fx and drive_fx.has_method(&"clear_splat_tracks"):
		drive_fx.clear_splat_tracks()
	if is_in_group(&"player"):
		var audio_s := get_node_or_null(^"/root/AudioDirector")
		if audio_s:
			audio_s.play(&"spawn")  # level start routes through here too — one hook
	global_position = at
	heading = new_heading
	velocity = Vector2.ZERO
	height = 0.0
	vz = 0.0
	_falling = false
	floor_index = -1     # re-adopted from the FloorSensor on first grounded tick
	_takeoff_floor = -1
	if _floor_tween:
		_floor_tween.kill()
	_floor_vis = 1.0
	_floor_lift = 0.0
	_apply_ground_collision()
	_update_draw_order(false)
	if _health:
		_health.hp = _health.max_hp
	if _status:
		_status.clear()  # death doesn't carry its fire into the next life
	set_physics_process(true)
	if _visual:
		_visual.scale = Vector2.ONE * body_scale  # pit falls shrink it
		_visual.modulate = Color.WHITE
	if _shadow:
		_shadow.scale = Vector2.ONE * body_scale
	grant_spawn_shield(shield_seconds)

func take_ram_damage(amount: float, source: Node2D = null) -> void:
	if source:
		last_attacker = source
	if _health:
		_health.take_damage(amount)

## Client-side replay of the host's attacker/victim event. This is presentation
## only: streamed HP remains the sole damage authority on a puppet.
func present_combat_hit(attacker: Node2D) -> void:
	if is_instance_valid(attacker):
		combat_hit.emit(attacker)

## Speed-based collision damage after move_and_slide: other vehicles, plus any
## Health-bearing body (destructible blocks, dummies). The rammer takes nothing
## from static targets; Toe Jam's armed charge is saved for vehicles.
func _update_ram(delta: float, pre_slide_vel: Vector2) -> void:
	var impact_speed := pre_slide_vel.length()
	if _ram_cd > 0.0:
		_ram_cd -= delta
		return
	for i in get_slide_collision_count():
		var other = get_slide_collision(i).get_collider()
		if other == self:
			continue
		if other is Vehicle:
			var rel: float = (velocity - other.velocity).length()
			if rel > ram_min_speed:
				# An armed Toe Jam charge replaces the speed-scaled hit.
				var charged: float = _special.take_armed_hit() if _special else 0.0
				var hit: float = charged if charged > 0.0 else (rel - ram_min_speed) * ram_damage_scale
				if _special:
					hit *= _special.take_dash_ram_multiplier()
				hit = ram_clamp(hit * Combat.scale(self, other), self, other)
				other.take_ram_damage(hit, self)
				_ram_cd = ram_cooldown
				break
		else:
			var health := _find_health_child(other)
			if health and impact_speed > ram_min_speed:
				health.take_damage((impact_speed - ram_min_speed) * ram_damage_scale)
				if health.hp <= 0.0:
					# The prop broke: punch through with most of the entry
					# momentum instead of eating the bounce — trash flies,
					# heavier cover still takes a real bite out of the run.
					velocity = pre_slide_vel * clampf(1.0 - health.max_hp / punch_hp_ref,
						punch_keep_min, punch_keep_max)
				_ram_cd = ram_cooldown
				break

## Deflection: reflect the pre-slide velocity component that went INTO the
## surface, scaled by bounce_factor — angled hits carom, dead-on stays a thud.
## Sub-threshold contact (grinding along a wall) is left smooth. Hitting
## another car shoves it along the same normal at half strength.
func _apply_bounce(pre_vel: Vector2) -> void:
	if get_slide_collision_count() == 0:
		return
	var col := get_slide_collision(0)
	var n := col.get_normal()
	var into := -pre_vel.dot(n)  # positive = moving into the surface
	if into < bounce_min_speed:
		return
	velocity += n * into * bounce_factor
	var other = col.get_collider()
	if other is Vehicle and other != self:
		other.velocity -= n * into * bounce_factor * 0.5
	# Crash audio rides the same impact moments the shake does; player-involved
	# only (either seat). Sub-2x-threshold contact is grinding, not a crash;
	# past CRASH_HARD_SPEED the fender-bender becomes a totaling.
	if into >= bounce_min_speed * 2.0 \
			and (is_in_group(&"player") or (other is Node and other.is_in_group(&"player"))):
		var audio_c := get_node_or_null(^"/root/AudioDirector")
		if audio_c:
			audio_c.play(&"crash_hard" if into >= CRASH_HARD_SPEED else &"crash_soft")

## Rams involving the player are lethal BOTH ways (your bumper finishes NPCs,
## theirs finishes you). AI-on-AI rams never land the killing blow (>=1% HP
## floor) — the mercy governor checks HP before the hit, so rams just above
## its line were still finishing cars. Obstacle crashes damage nobody anyway.
static func ram_clamp(hit: float, attacker: Node, victim: Node) -> float:
	if attacker.is_in_group(&"player") or victim.is_in_group(&"player"):
		return hit
	if victim.has_method(&"get_hp"):
		return minf(hit, maxf(victim.get_hp() - 0.01 * victim.get_max_hp(), 0.0))
	return hit

func _find_health_child(body: Node) -> Health:
	for child in body.get_children():
		if child is Health:
			return child
	return null
