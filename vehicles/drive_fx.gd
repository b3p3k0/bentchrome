extends Node2D
## Cosmetic driving feedback for the parent Vehicle: skid marks while the
## handbrake is out, terrain dust while hauling off-road, and a nitro flame
## while boosting. Pure paint — reads the controller's state flags, never
## touches physics. Rides on every vehicle (AI boost flames included).

const SKID_COLOR := Color(0.05, 0.05, 0.06, 0.6)  # rubber on pavement (road/fallback)
# Off-road surfaces gouge a terrain-colored scar instead of black rubber. Any
# terrain named here also lays a mark on a hard slide (no handbrake needed);
# road is absent on purpose, so pavement stays handbrake-only.
const SKID_COLORS := {
	&"grass": Color(0.34, 0.26, 0.16, 0.7),   # torn earth under the sod
	&"dirt":  Color(0.28, 0.2, 0.12, 0.75),   # darker churned dirt
	&"mud":   Color(0.12, 0.075, 0.045, 0.82), # wet ruts stay darker than the pool
	&"snow":  Color(0.62, 0.68, 0.78, 0.85),  # compressed bluish-white
	&"ice":   Color(0.72, 0.8, 0.9, 0.5),     # faint polished streak
}
const SKID_WIDTH := 5.0
const SKID_MIN_SPEED := 200.0
const SKID_SLIP_MIN := 120.0  # sideways px/s that marks an off-road surface
const SKID_FADE := 2.0
const MAX_SKID_NODES := 24  # global cap (12 pairs), via the "skidmarks" group
const BLOOD_COLOR := Color(0.38, 0.015, 0.02, 0.82)
const BLOOD_WIDTH := 4.5
const BLOOD_FADE := 3.0
const BLOOD_MIN_SPEED := 10.0
const DUST_MIN_SPEED := 150.0
const DUST_COLORS := {
	&"dirt":  Color(0.55, 0.42, 0.28, 0.7),
	&"mud":   Color(0.28, 0.19, 0.12, 0.72),
	&"grass": Color(0.35, 0.5, 0.3, 0.6),
	&"snow":  Color(0.9, 0.94, 1.0, 0.85),   # kicked-up powder
	&"water": Color(0.6, 0.78, 0.88, 0.7),   # blue-white spray
}
# Fling amplification: a light kick at a cruise, a fat rooster tail under a
# hard drift. Driven by sideways slip (lat), so it fattens the same on a
# network puppet; handbrake just pins it to full.
const FLING_SLIP_FULL := 260.0  # sideways px/s that maxes the tail
const FLING_VEL_CALM := 55.0    # backward launch speed, gentle
const FLING_VEL_HARD := 190.0   # backward launch speed, full drift
const FLING_SCALE_CALM := 3.0
const FLING_SCALE_HARD := 6.0

const PeaceMarkerScript := preload("res://vehicles/peace_marker.gd")

var _vehicle: CharacterBody2D
var _skids: Array = []  # the active pair of Line2Ds, parented to the level
var _dust: CPUParticles2D
var _flame: Polygon2D
var _burn_fx: CPUParticles2D
var _peace: Node2D
var _blood_tracks: Array = []
var _blood_t := 0.0

func _ready() -> void:
	_vehicle = get_parent() as CharacterBody2D
	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.amount = 24
	_dust.lifetime = 0.5
	_dust.local_coords = false  # debris stays where it was flung, in world space
	_dust.spread = 55.0  # a backward rooster-tail arc, not an omni puff
	_dust.initial_velocity_min = 20.0
	_dust.initial_velocity_max = 60.0
	_dust.scale_amount_min = 2.0
	_dust.scale_amount_max = 4.0
	_dust.gravity = Vector2(0, 90)  # debris arcs and settles back down
	add_child(_dust)
	# Burning: licks of fire riding the hull so a burn is never invisible.
	_burn_fx = CPUParticles2D.new()
	_burn_fx.emitting = false
	_burn_fx.amount = 18
	_burn_fx.lifetime = 0.4
	_burn_fx.spread = 180.0
	_burn_fx.initial_velocity_min = 15.0
	_burn_fx.initial_velocity_max = 45.0
	_burn_fx.scale_amount_min = 2.5
	_burn_fx.scale_amount_max = 5.0
	_burn_fx.gravity = Vector2.ZERO
	_burn_fx.color = Color(1.0, 0.5, 0.1, 0.85)
	add_child(_burn_fx)
	# Disarmed: the peace sign floats over the roof (Chill Out, Man).
	_peace = PeaceMarkerScript.new()
	_peace.visible = false
	_peace.z_index = 3  # over the car, under explosions
	add_child(_peace)
	var visual := _vehicle.get_node_or_null(^"Visual") if _vehicle else null
	if visual:
		_flame = Polygon2D.new()
		_flame.color = Color(0.3, 0.7, 1.0, 0.9)  # nitro blue, matches the HUD bar
		_flame.visible = false
		visual.add_child(_flame)

## Per-car body metrics, read lazily: the vehicle applies its paint style in
## its own _ready (after this child's), and re-rolls can swap it live.
func _skid_offsets() -> Array:
	if _vehicle and _vehicle.has_method("body_metrics"):
		var m: Dictionary = _vehicle.body_metrics()
		if m.has("skid_points"):
			return m.skid_points
	return [Vector2(-20, -14), Vector2(-20, 14)]

## Average of the rear tire contacts — where the fling debris streams from.
func _rear_midpoint() -> Vector2:
	var offs: Array = _skid_offsets()
	if offs.is_empty():
		return Vector2(-20, 0)
	var sum: Vector2 = Vector2.ZERO
	for p in offs:
		sum += p as Vector2
	return sum / offs.size()

## Longest body reach — how far up-screen the disarm marker floats.
func _marker_lift() -> float:
	if _vehicle and _vehicle.has_method("body_metrics"):
		var m: Dictionary = _vehicle.body_metrics()
		return maxf(float(m.get("half_len", 26.0)), float(m.get("half_wid", 13.0)))
	return 26.0

func _flame_poly() -> PackedVector2Array:
	var tail := 26.0
	if _vehicle and _vehicle.has_method("body_metrics"):
		var m: Dictionary = _vehicle.body_metrics()
		tail = float(m.get("half_len", tail))
	return PackedVector2Array([
		Vector2(-tail, -6), Vector2(-tail - 18, 0), Vector2(-tail, 6),
	])

func _physics_process(_delta: float) -> void:
	if _vehicle == null or not _vehicle.has_method(&"get_controller"):
		return
	var ctrl = _vehicle.get_controller()
	if ctrl == null:
		return
	var speed: float = _vehicle.velocity.length()
	var grounded: bool = _vehicle.height == 0.0

	if _flame:
		if ctrl.boosting and not _flame.visible:
			_flame.polygon = _flame_poly()  # anchor to the current body's tail
		_flame.visible = ctrl.boosting
		if ctrl.boosting:
			_flame.scale = Vector2(randf_range(0.7, 1.4), randf_range(0.8, 1.1))

	if _burn_fx:
		_burn_fx.emitting = _vehicle.has_method(&"is_burning") and _vehicle.is_burning()

	if _peace:
		var disarmed: bool = _vehicle.has_method(&"is_disarmed") and _vehicle.is_disarmed()
		if disarmed and not _peace.visible:
			_peace.position = Vector2(0, -(_marker_lift() + 12.0))
		_peace.visible = disarmed

	var terrain: StringName = _vehicle.current_terrain
	# Sideways slip = how hard the car is sliding, derived from kinematics alone
	# (velocity + heading) so it reads true on a network puppet with no live
	# controller. Shared by the off-road skid trigger and the fling amplifier.
	var forward: Vector2 = Vector2.RIGHT.rotated(_vehicle.heading)
	var lat: float = absf(_vehicle.velocity.dot(forward.orthogonal()))

	var dusty: bool = grounded and speed > DUST_MIN_SPEED and DUST_COLORS.has(terrain)
	_dust.emitting = dusty
	if dusty:
		_dust.color = DUST_COLORS[terrain]
		# Fling backward off the rear tires, in world space.
		var rear_mid: Vector2 = _rear_midpoint()
		_dust.global_position = _vehicle.global_position + rear_mid.rotated(_vehicle.heading)
		_dust.direction = -_vehicle.velocity / speed  # already > DUST_MIN_SPEED
		# Fatter tail the harder the slide; handbrake pins it to full.
		var f: float = 1.0 if ctrl.handbraking else clampf(lat / FLING_SLIP_FULL, 0.0, 1.0)
		_dust.initial_velocity_max = lerpf(FLING_VEL_CALM, FLING_VEL_HARD, f)
		_dust.scale_amount_max = lerpf(FLING_SCALE_CALM, FLING_SCALE_HARD, f)

	# Handbrake skids anywhere; off-road surfaces also scar on a hard slide.
	var off_road_slide: bool = SKID_COLORS.has(terrain) and lat > SKID_SLIP_MIN
	var skidding: bool = grounded and speed > SKID_MIN_SPEED and (ctrl.handbraking or off_road_slide)
	if skidding and _skids.is_empty():
		_start_skid()
	elif not skidding and not _skids.is_empty():
		_end_skid()
	# Skid audio tracks the MARKS, not the input — if rubber is going down,
	# sound comes out (player only). loop_set is idempotent per frame.
	if _vehicle.is_in_group(&"player"):
		var audio := get_node_or_null(^"/root/AudioDirector")
		if audio:
			audio.loop_set(&"skid", not _skids.is_empty())
	if not _skids.is_empty():
		var offs: Array = _skid_offsets()  # rear tire contacts (bike lays one line)
		for i in mini(_skids.size(), offs.size()):
			_skids[i].add_point(_vehicle.global_position + offs[i].rotated(_vehicle.heading))

	if _blood_t > 0.0:
		_blood_t = maxf(_blood_t - _delta, 0.0)
		if grounded and speed >= BLOOD_MIN_SPEED:
			_append_blood_points()
		if _blood_t <= 0.0:
			_end_blood_tracks()

func _start_skid() -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var available := MAX_SKID_NODES - get_tree().get_nodes_in_group(&"skidmarks").size()
	# One color for the whole mark, picked from the surface it started on.
	var terrain: StringName = _vehicle.current_terrain
	var color: Color = SKID_COLORS.get(terrain, SKID_COLOR)
	for i in mini(_skid_offsets().size(), maxi(available, 0)):
		var line := Line2D.new()
		line.width = SKID_WIDTH
		line.default_color = color
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

## Called by a live AmbientSplat. Pure presentation: it never reaches the
## controller or changes traction, and repeated stains only refresh the clock.
func carry_splat(seconds := 1.25) -> void:
	_blood_t = maxf(_blood_t, seconds)
	if _blood_tracks.is_empty():
		_start_blood_tracks()

func _start_blood_tracks() -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var available := MAX_SKID_NODES - get_tree().get_nodes_in_group(&"skidmarks").size()
	for i in mini(_skid_offsets().size(), maxi(available, 0)):
		var line := Line2D.new()
		line.width = BLOOD_WIDTH
		line.default_color = BLOOD_COLOR
		line.add_to_group(&"skidmarks")
		host.add_child(line)
		host.move_child(line, mini(2, host.get_child_count() - 1))
		_blood_tracks.append(line)

func _append_blood_points() -> void:
	var offs: Array = _skid_offsets()
	for i in mini(_blood_tracks.size(), offs.size()):
		var line: Line2D = _blood_tracks[i]
		var point: Vector2 = _vehicle.global_position + offs[i].rotated(_vehicle.heading)
		if line.get_point_count() == 0 or line.get_point_position(line.get_point_count() - 1).distance_to(point) >= 2.0:
			line.add_point(point)

func _end_blood_tracks() -> void:
	for line in _blood_tracks:
		if is_instance_valid(line):
			var tween: Tween = line.create_tween()
			tween.tween_property(line, "modulate:a", 0.0, BLOOD_FADE)
			tween.tween_callback(line.queue_free)
	_blood_tracks.clear()

func clear_splat_tracks() -> void:
	_blood_t = 0.0
	_end_blood_tracks()

func _exit_tree() -> void:
	_end_skid()
	clear_splat_tracks()
