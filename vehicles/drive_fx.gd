extends Node2D
## Cosmetic driving feedback for the parent Vehicle: skid marks while the
## handbrake is out, terrain dust while hauling off-road, and a nitro flame
## while boosting. Pure paint — reads the controller's state flags, never
## touches physics. Rides on every vehicle (AI boost flames included).

const SKID_COLOR := Color(0.05, 0.05, 0.06, 0.6)
const SKID_WIDTH := 5.0
const SKID_MIN_SPEED := 200.0
const SKID_FADE := 2.0
const MAX_SKID_NODES := 24  # global cap (12 pairs), via the "skidmarks" group
const DUST_MIN_SPEED := 150.0
const DUST_COLORS := {
	&"dirt": Color(0.55, 0.42, 0.28, 0.7),
	&"grass": Color(0.35, 0.5, 0.3, 0.6),
}

var _vehicle: CharacterBody2D
var _skids: Array = []  # the active pair of Line2Ds, parented to the level
var _dust: CPUParticles2D
var _flame: Polygon2D
var _burn_fx: CPUParticles2D

func _ready() -> void:
	_vehicle = get_parent() as CharacterBody2D
	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.amount = 24
	_dust.lifetime = 0.5
	_dust.local_coords = false  # puffs stay where they were kicked up
	_dust.spread = 180.0
	_dust.initial_velocity_min = 20.0
	_dust.initial_velocity_max = 60.0
	_dust.scale_amount_min = 2.0
	_dust.scale_amount_max = 4.0
	_dust.gravity = Vector2.ZERO
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

	var terrain: StringName = _vehicle.current_terrain
	var dusty: bool = grounded and speed > DUST_MIN_SPEED and DUST_COLORS.has(terrain)
	_dust.emitting = dusty
	if dusty:
		_dust.color = DUST_COLORS[terrain]

	var skidding: bool = grounded and ctrl.handbraking and speed > SKID_MIN_SPEED
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

func _start_skid() -> void:
	var host := get_tree().current_scene
	if host == null or get_tree().get_nodes_in_group(&"skidmarks").size() >= MAX_SKID_NODES:
		return
	for i in _skid_offsets().size():
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
