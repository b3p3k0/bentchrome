class_name Vehicle
extends CharacterBody2D
## The one vehicle. A Driver supplies intent; a DrivingController turns it into
## motion. Player and AI both instance this scene — only the Driver, faction, and
## stats differ. If a VehicleStats resource is assigned, StatCurves configures the
## controller + health from its 1-10 design stats, then per-car handling_overrides
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
const HEADING_STEPS := 16  # quantize the visual to N compass steps (retro
							# directional-sprite feel); 0 = smooth rotation
const FLOOR_SCALE_TWEEN := 0.25  # size-cue tween on floor change (visuals only)
const FLOOR_LIFT := 32.0  # px of visual lift per floor above the baseline (2) —
						  # the jump-cue held: body up, shadow grounded, so an
						  # elevated car reads elevated even overlapping a low one
const Combat := preload("res://game/combat.gd")  # AI-vs-AI governor/mercy rules
const Floors := preload("res://game/floors.gd")  # terraced-floor math (dependency-free)
const ExplosionScene := preload("res://environment/explosion.tscn")
const SinkBubbles := preload("res://environment/sink_bubbles.gd")

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

@export_group("Bounce")
@export var bounce_factor := 0.35     # fraction of the into-surface speed reflected
@export var bounce_min_speed := 100.0  # below this, grinding along walls stays smooth

var heading: float = 0.0  # radians; the direction the nose points
var current_terrain: StringName = &"road"
var height: float = 0.0   # fake vertical offset (px); 0 = on the ground
var vz: float = 0.0       # vertical velocity (px/s)
var floor_index := -1     # terrace we drive on; -1 = legacy single-plane level
var _takeoff_floor := -1  # floor at the moment we went airborne (fall bookkeeping)
var _floor_tween: Tween = null
var _floor_lift := 0.0    # visual elevation for upper terraces (see FLOOR_LIFT)
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
var last_attacker: Node2D = null  # whoever hurt us last — AI holds a grudge

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
		# Same loadout as the player, a third of the trigger speed.
		if _mg_mount:
			_mg_mount.cooldown_scale = ai_cooldown_scale
		var secondary := get_node_or_null(^"SecondaryMount") as WeaponMount
		if secondary:
			secondary.cooldown_scale = ai_cooldown_scale
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
	# DEVGOD (settings): player-only — damage-immune, one of everything, firing
	# never depletes. Pits still kill; the level's lives loop comps the life.
	var god_gs := get_node_or_null(^"/root/GameState")
	if faction == &"player" and god_gs and god_gs.devgod:
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

## Hit feedback: brief white pulse (skipped for sub-1 DoT ticks, which would
## strobe), plus camera shake when it's the player taking it.
func _on_damaged(amount: float, _hp: float) -> void:
	if amount < 1.0:
		return
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
		_rack.configure(stats.special, stats.special_ammo_cap, stats.special_recharge_seconds)
	if stats.special and _special:
		_special.set_weapon(_rack.selected_def() if _rack else stats.special)

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

func _physics_process(delta: float) -> void:
	if _terrain_sensor:
		current_terrain = _terrain_sensor.current_terrain
	_update_floor()
	var intent: Dictionary = _driver.get_intent(self, delta) if _driver else {}
	if _controller and not (_special and _special.is_dashing()):
		# Normal driving; skipped mid-Leap so the controller's top-speed clamp
		# doesn't eat the dash velocity.
		_controller.apply(self, intent, delta)
		if _controller.boosting and _status:
			_status.clear_kind(&"burn")  # nitro wind blows the fire out
	# Captured before move_and_slide: a head-on hit on a static body zeroes
	# velocity during the slide, so post-slide speed under-reads the impact.
	var pre_slide_vel := velocity
	move_and_slide()
	_apply_bounce(pre_slide_vel)
	_update_ram(delta, pre_slide_vel.length())
	var visual_heading := heading if HEADING_STEPS <= 0 else snappedf(heading, TAU / HEADING_STEPS)
	_visual.rotation = visual_heading
	if _shadow:
		_shadow.rotation = visual_heading
	_update_depth(delta)
	var aim := Vector2.RIGHT.rotated(heading)
	if _mg_mount and _muzzle and intent.get("fire_mg", false):
		_mg_mount.try_fire(_muzzle.global_position, aim, self)
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
		if _special.activate(wants_fire, _muzzle.global_position, aim, self) and _rack:
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
	var lift := height + _floor_lift  # jump arc + held terrace elevation
	_visual.position.y = -lift
	if _shadow:
		var s := clampf(1.0 - lift * 0.0012, 0.5, 1.0) * body_scale * _floor_vis
		_shadow.scale = Vector2(s, s)
		_shadow.modulate.a = clampf(1.0 - lift * 0.0016, 0.4, 1.0)

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
	if height > 0.0:
		return
	vz = vz_speed
	_set_airborne(true)

## AI stuck-escape: a jump-mine-style hop — re-aim, launch, sail over whatever
## we're wedged against (airborne already drops car+obstacle collision bits).
## Reads as the established jump mechanic, not noclip. Driver-called, AI only.
const ESCAPE_HOP_SPEED := 420.0
const ESCAPE_HOP_VZ := 430.0

func escape_hop(direction: Vector2) -> void:
	if height > 0.0 or direction == Vector2.ZERO:
		return
	heading = direction.angle()
	velocity = direction * ESCAPE_HOP_SPEED
	pop_airborne(ESCAPE_HOP_VZ)

## Jump pads call this; needs speed and ground. (Driveable RAMPS never launch —
## they grade the floor over via ramp-flagged FloorZones.)
func launch_from_jump() -> void:
	if height > 0.0 or velocity.length() < min_launch_speed:
		return
	vz = jump_launch
	_set_airborne(true)

## Over the edge: kill physics and collisions, shrink into the void, then die
## for real. The fall suppresses the explosion — you fell, you didn't pop.
func fall_into_pit() -> void:
	if _falling or height > 0.0 or (_health and _health.hp <= 0.0):
		return
	_falling = true
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
	if not _falling:
		_spawn_explosion()
	var audio_d := get_node_or_null(^"/root/AudioDirector")
	if is_in_group(&"player"):
		if audio_d:
			audio_d.play(&"player_death")
		set_physics_process(false)
		print("[player] destroyed")
	else:
		if audio_d:
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

func apply_effect(spec: StatusEffectSpec) -> void:
	if _status:
		_status.apply(spec)

func is_burning() -> bool:
	return _status != null and _status.has_effect(&"burn")

## Campaign respawn: back to a spawn point, full tank, physics on, and a brief
## invuln blink-shield so spawn-camping hunters can't chain-kill.
func respawn(at: Vector2, new_heading: float, shield_seconds := 2.0) -> void:
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
	if shield_seconds > 0.0 and _status:
		var shield := StatusEffectSpec.new()
		shield.kind = &"invuln"
		shield.duration = shield_seconds
		apply_effect(shield)
		if _visual:
			var tween := create_tween()
			tween.set_loops(int(shield_seconds / 0.2))
			tween.tween_property(_visual, "modulate:a", 0.35, 0.1)
			tween.tween_property(_visual, "modulate:a", 1.0, 0.1)

func take_ram_damage(amount: float, source: Node2D = null) -> void:
	if source:
		last_attacker = source
	if _health:
		_health.take_damage(amount)

## Speed-based collision damage after move_and_slide: other vehicles, plus any
## Health-bearing body (destructible blocks, dummies). The rammer takes nothing
## from static targets; Toe Jam's armed charge is saved for vehicles.
func _update_ram(delta: float, impact_speed: float) -> void:
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
				hit = ram_clamp(hit * Combat.scale(self, other), self, other)
				other.take_ram_damage(hit, self)
				_ram_cd = ram_cooldown
				break
		else:
			var health := _find_health_child(other)
			if health and impact_speed > ram_min_speed:
				health.take_damage((impact_speed - ram_min_speed) * ram_damage_scale)
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
	# only (either seat). Sub-2x-threshold contact is grinding, not a crash.
	if into >= bounce_min_speed * 2.0 \
			and (is_in_group(&"player") or (other is Node and other.is_in_group(&"player"))):
		var audio_c := get_node_or_null(^"/root/AudioDirector")
		if audio_c:
			audio_c.play(&"crash")

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
