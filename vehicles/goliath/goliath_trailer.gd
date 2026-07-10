extends Node2D
## Goliath's towed fortress: two AnimatableBody2D plates (TrailerMain + the
## weak TrailerNose kingpin quarter) dragged behind the cab by single-link
## follow-the-leader tow math — the kingpin is pinned to the cab's fifth
## wheel, the bogie axle chases it on a rigid bar, and a hard cab yank swings
## the tail wide. The JACKKNIFE is emergent: abs(yaw_rate) is the weapon
## window (consumed by Batch C). Which plate a shot or ram physically hits IS
## the weak-spot quarter — both carry never-dying Health proxies that forward
## quarter-scaled damage into the cab's pool, and both are stamped with the
## part_of meta so the rig's own turret fire sails over them.
## Duck-typed toward the cab (NEVER names Vehicle — this node lives beside
## paint/turret code): heading, body_scale, stats are reached via get().
## Spawned and attached by goliath_boss.gd; freed whole at the phase change.

const CarPaintScript := preload("res://vehicles/car_paint.gd")
const TurretScript := preload("res://weapons/turret.gd")
const TurretDef := preload("res://data/weapons/goliath_turret.tres")
const Floors := preload("res://game/floors.gd")

# Geometry assumes the shipped body_scale 1.6 (paint-local px ×2 world).
static var TRAILER_LEN := 180.0       # kingpin -> bogie axle (the tow bar)
static var TRAILER_BODY_LEN := 210.0  # collision box length (visual 220)
static var TRAILER_WIDTH := 64.0      # collision box width (visual 72)
static var HITCH_OFFSET := 52.0       # cab center -> fifth wheel, behind
static var KINGPIN_AHEAD := 96.0      # kingpin -> trailer body center
static var MAX_ARTIC := deg_to_rad(75.0)  # a real semi folds, it doesn't spin
static var NOSE_FRAC := 0.25          # front quarter = the weak kingpin plate
static var TRAILER_DMG_FRAC := 0.25   # armored: fraction of hits that forward
static var TRAILER_WEAK_MULT := 2.0   # nose quarter forwards this much more
static var SWING_ATTACK_RATE := 2.6   # rad/s: the tail is live past this
static var SWING_HIT_COOLDOWN := 1.2  # seconds between tail bites
static var SWING_BOX_PAD := 36.0      # hitbox reach beyond the paint
static var JACKKNIFE_DMG := 26.0      # getting hit by a semi HURTS
static var JACKKNIFE_KNOCKBACK := 900.0  # fling speed off the tail (px/s)
static var JACKKNIFE_SPIN := deg_to_rad(140.0)  # heading kick on the victim
static var JACKKNIFE_STUN := 0.5      # hands-off-the-wheel window (s)
static var SKID_SWAY_RATE := 1.2      # rad/s: the bogie lays rubber past this
									  # (under the attack rate — marks telegraph
									  # the sway before the tail goes live)

const SKID_COLOR := Color(0.05, 0.05, 0.06, 0.6)  # drive_fx's rubber
const SKID_WIDTH := 6.0
const SKID_FADE := 2.0
const MAX_SKID_NODES := 24            # shared global cap ("skidmarks" group)
const BOGIE_POINTS := [Vector2(-58, -30), Vector2(-58, 30)]  # main-plate local

var yaw := 0.0        # trailer facing (radians, world)
var yaw_rate := 0.0   # rad/s, signed — the jackknife window reads abs()
# Computed plate poses — the tow math's output, the source of truth the node
# transforms follow (and what headless tests assert on).
var main_center := Vector2.ZERO
var nose_center := Vector2.ZERO

var _cab: CharacterBody2D = null
var _rear := Vector2.ZERO  # bogie axle, world
var _main: AnimatableBody2D = null
var _nose: AnimatableBody2D = null
var _swing_box: Area2D = null
var _swing_cd := 0.0
var _skids: Array = []  # active bogie Line2D pair, parented to the level
var _vis_scale := 1.6

## Build plates, pin behind the cab, exempt the cab's own physics, stamp
## part_of. Call AFTER this node is in the tree (turret paths need it).
func attach(cab: CharacterBody2D) -> void:
	_cab = cab
	var bs: Variant = cab.get("body_scale")
	_vis_scale = float(bs) if bs is float else 1.6
	_main = _build_plate("TrailerMain", TRAILER_BODY_LEN * (1.0 - NOSE_FRAC), false)
	_nose = _build_plate("TrailerNose", TRAILER_BODY_LEN * NOSE_FRAC, true)
	_dress_main()
	yaw = _cab_heading()
	var hitch := _hitch(cab.global_position, yaw)
	_rear = hitch - Vector2.RIGHT.rotated(yaw) * TRAILER_LEN
	_place(hitch)
	cab.add_collision_exception_with(_main)
	cab.add_collision_exception_with(_nose)
	_main.set_meta(&"part_of", cab.get_path())
	_nose.set_meta(&"part_of", cab.get_path())

func _physics_process(delta: float) -> void:
	if _cab == null or not is_instance_valid(_cab):
		return
	tow_tick(_cab.global_position, _cab_heading(), delta)
	_swing_cd = maxf(_swing_cd - delta, 0.0)
	_update_skids()
	if absf(yaw_rate) > SWING_ATTACK_RATE:
		_swing_strike()

## The stegosaurus tail: while the trailer whips (hard cab yank OR a violent
## corner — don't hug the tail), any grounded car caught in the box takes the
## full jackknife treatment. Purely physical: no AI state needed to arm it.
func _swing_strike() -> void:
	if _swing_box == null or _swing_cd > 0.0:
		return
	for body in _swing_box.get_overlapping_bodies():
		if body == _cab or not (body is CharacterBody2D):
			continue
		if not body.has_method(&"apply_impact"):
			continue
		if body.get("height") != 0.0:
			continue  # airborne cars sail over the tail
		body.apply_impact(_main.global_position, JACKKNIFE_DMG,
			JACKKNIFE_KNOCKBACK, JACKKNIFE_SPIN, JACKKNIFE_STUN)
		if "last_attacker" in body:
			body.last_attacker = _cab  # the grudge lands on the boss
		_swing_cd = SWING_HIT_COOLDOWN
		return  # one bite per swing

## The whole tow model, separated for headless tests: pin the hitch, let the
## axle chase it, clamp the articulation, measure the swing.
func tow_tick(cab_pos: Vector2, cab_heading: float, delta: float) -> void:
	var hitch := _hitch(cab_pos, cab_heading)
	var new_yaw := (hitch - _rear).angle()
	var artic := angle_difference(cab_heading, new_yaw)
	if absf(artic) > MAX_ARTIC:
		new_yaw = cab_heading + clampf(artic, -MAX_ARTIC, MAX_ARTIC)
	_rear = hitch - Vector2.RIGHT.rotated(new_yaw) * TRAILER_LEN
	yaw_rate = angle_difference(yaw, new_yaw) / maxf(delta, 0.0001)
	yaw = new_yaw
	_place(hitch)

## Current articulation angle (trailer vs cab), for tests and the AI.
func articulation() -> float:
	return angle_difference(_cab_heading(), yaw) if _cab else 0.0

func _cab_heading() -> float:
	var h: Variant = _cab.get("heading")
	return float(h) if h is float else _cab.rotation

func _hitch(cab_pos: Vector2, cab_heading: float) -> Vector2:
	return cab_pos - Vector2.RIGHT.rotated(cab_heading) * HITCH_OFFSET

func _place(hitch: Vector2) -> void:
	var fwd := Vector2.RIGHT.rotated(yaw)
	var center := hitch - fwd * KINGPIN_AHEAD
	nose_center = center + fwd * (TRAILER_BODY_LEN * (0.5 - NOSE_FRAC * 0.5))
	main_center = center - fwd * (TRAILER_BODY_LEN * NOSE_FRAC * 0.5)
	_nose.global_position = nose_center
	_nose.global_rotation = yaw
	_main.global_position = main_center
	_main.global_rotation = yaw

## One collision plate: floor-1 bit only (players and straight shots collide;
## the radar's layer-4 static snapshot never sees it), never-dying Health.
func _build_plate(plate_name: String, length: float, weak: bool) -> AnimatableBody2D:
	var plate := AnimatableBody2D.new()
	plate.name = plate_name
	# NOT sync_to_physics: Godot discards direct transform sets on synced
	# bodies wholesale (even physics-tick ones) — the rig was born parked at
	# the world origin until this flag died. Plates teleport per tick like
	# every body in this game; the swing hitbox is the authoritative weapon.
	plate.sync_to_physics = false
	plate.collision_layer = Floors.floor_bit(1)
	plate.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, TRAILER_WIDTH)
	col.shape = shape
	plate.add_child(col)
	var proxy := Health.new()
	proxy.name = "Health"
	proxy.max_hp = 100000.0
	plate.add_child(proxy)
	proxy.damaged.connect(_on_plate_damaged.bind(proxy, weak))
	add_child(plate)
	return plate

## The proxies never die — they launder every hit (weapons AND rams) into the
## cab's single pool, quarter-scaled. Batch C's phase gate lives cab-side.
func _on_plate_damaged(amount: float, _hp: float, proxy: Health, weak: bool) -> void:
	proxy.hp = proxy.max_hp
	if _cab == null or not is_instance_valid(_cab):
		return
	var cab_health := _cab.get_node_or_null(^"Health") as Health
	if cab_health:
		cab_health.take_damage(amount * TRAILER_DMG_FRAC
			* (TRAILER_WEAK_MULT if weak else 1.0))

## Bogie rubber while the tail sways hard — drive_fx's skid recipe (Line2D
## pair in the shared "skidmarks" group, points at the wheel contacts, fade
## on settle). The marks telegraph the whip before the strike window opens.
func _update_skids() -> void:
	var swaying := absf(yaw_rate) > SKID_SWAY_RATE
	if swaying and _skids.is_empty():
		_start_skid()
	elif not swaying and not _skids.is_empty():
		_end_skid()
	for i in mini(_skids.size(), BOGIE_POINTS.size()):
		_skids[i].add_point(main_center + (BOGIE_POINTS[i] as Vector2).rotated(yaw))

func _start_skid() -> void:
	var host := get_tree().current_scene
	if host == null or get_tree().get_nodes_in_group(&"skidmarks").size() >= MAX_SKID_NODES:
		return
	for i in BOGIE_POINTS.size():
		var line := Line2D.new()
		line.width = SKID_WIDTH
		line.default_color = SKID_COLOR
		line.add_to_group(&"skidmarks")
		host.add_child(line)
		# Early in the draw order: under buildings and cars, over the floor.
		host.move_child(line, mini(2, host.get_child_count() - 1))
		_skids.append(line)

func _end_skid() -> void:
	for line in _skids:
		if is_instance_valid(line):
			var tween: Tween = line.create_tween()
			tween.tween_property(line, "modulate:a", 0.0, SKID_FADE)
			tween.tween_callback(line.queue_free)
	_skids.clear()

func _exit_tree() -> void:
	_end_skid()

## Shadow, box paint, and the two battery turrets — all on the MAIN plate,
## offset so the paint centers on the whole trailer, not the plate.
func _dress_main() -> void:
	# The jackknife hitbox rides the main plate, centered on the whole box
	# with a little reach — the tail bites slightly wider than the paint.
	_swing_box = Area2D.new()
	_swing_box.name = "SwingHitbox"
	_swing_box.collision_layer = 0
	_swing_box.collision_mask = 1  # cars always keep the ground bit
	var swing_col := CollisionShape2D.new()
	var swing_shape := RectangleShape2D.new()
	swing_shape.size = Vector2(TRAILER_BODY_LEN + SWING_BOX_PAD, TRAILER_WIDTH + SWING_BOX_PAD)
	swing_col.shape = swing_shape
	_swing_box.add_child(swing_col)
	_swing_box.position = Vector2(TRAILER_BODY_LEN * NOSE_FRAC * 0.5, 0.0)
	_main.add_child(_swing_box)
	var visual := Node2D.new()
	visual.name = "Visual"
	visual.scale = Vector2.ONE * _vis_scale
	visual.position = Vector2(TRAILER_BODY_LEN * NOSE_FRAC * 0.5, 0.0)
	_main.add_child(visual)
	var paint := CarPaintScript.new()
	var primary := Color(0.22, 0.23, 0.27)
	var accent := Color(0.85, 0.45, 0.12)
	var stats: Variant = _cab.get("stats")
	if stats != null:
		primary = stats.primary_color
		accent = stats.accent_color
	var shadow := Polygon2D.new()
	shadow.color = Color(0.0, 0.0, 0.0, 0.35)
	shadow.position = Vector2(3.0, 7.0)
	visual.add_child(shadow)
	visual.add_child(paint)
	paint.apply(&"goliath_trailer", primary, accent)
	shadow.polygon = paint.shadow_polygon()
	for cfg in [{"name": "TurretA", "at": Vector2(12.5, 0)},
			{"name": "TurretB", "at": Vector2(-32.5, 0)}]:
		var tur := TurretScript.new()
		tur.name = cfg.name
		tur.position = cfg.at
		visual.add_child(tur)
		tur.set_weapon(TurretDef)
		tur.shooter_path = tur.get_path_to(_cab)
		var excludes: Array[NodePath] = [tur.get_path_to(_main), tur.get_path_to(_nose)]
		tur.los_exclude_paths = excludes
