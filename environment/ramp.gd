class_name Ramp
extends Node2D
## The DRIVEABLE floor transition — jump pads launch, ramps CLIMB. One node
## builds the whole recipe at ready:
##   - two ramp-flagged FloorZone halves (low half tags low_floor, high half
##     high_floor): crossing the midline grades a car's floor over at ground
##     level, both directions — no hop, no fall damage;
##   - side rails along the FULL slope: thin statics carrying BOTH floors'
##     bits — the ramp is a CHOKEPOINT by design, entered at its low end only
##     (smash-proof; they're the geometry, not set dressing);
##   - slope shading painted over whatever sits under the strip. Surface FEEL
##     is composition: author a TerrainZone over the strip (grass = hill,
##     snow = slippery climb, bare asphalt = parking-garage grade).
## Local convention: the strip runs along local Y with the HIGH end at -y;
## rotate the node to orient. size = (width, length). Duck-typed only —
## never names Vehicle.

const Floors := preload("res://game/floors.gd")
const FloorZoneScene := preload("res://environment/floor_zone.tscn")
const EDGE := Color(0.55, 0.55, 0.62)
const CHEVRON := Color(0.95, 0.9, 0.6, 0.5)
const SHADE_STEPS := 6
const HILITE_A := 0.14  # extra light at the high end
const SHADOW_A := 0.16  # extra dark at the low end
const RAIL_W := 12.0
const ROW_DEPTH := 44.0  # tier cadence for stairs — matches stadium seating rows

static var STAIR_SHAKE := 1.2  # per-tier camera kick for the player

@export var low_floor := 2
@export var high_floor := 3
@export var size := Vector2(192, 448)  # width x length (length along local y)
@export var surface_color := Color(0.16, 0.16, 0.19)  # OPAQUE built surface
	# (asphalt default; author snow/dirt tones to match the hill's terrain —
	# the TerrainZone underneath still owns the grip)
@export var surface_paint := true  # false = zones + rails only; a deco layer
	# owns the slope's look (stadium grandstands ARE the ramp — seat rows
	# paint the grade, the Ramp node stays the physics/floor authority)
@export var rails := true  # false = no built side rails; the level authors its
	# own guards (stadium slope ends wear light DESTRUCTIBLE guardrails so a
	# beached rig can smash out instead of pinning on indestructible geometry)
@export var downhill_pull := 0.0  # px/s² bias along local +y (toward the low
	# end): climbing fights it, descending rides it. Environment-side force —
	# controller gains and the test-locked feel bands stay untouched. 0 = off.
@export var stairs := false  # tiered seating: a light per-tier camera bump for
	# the player while crossing rows — the grade is stairs, not tarmac

var _grade_area: Area2D = null
var _tier_bucket: Dictionary = {}  # body instance id -> last row bucket

func _ready() -> void:
	for cfg in [{"floor": high_floor, "y": -size.y * 0.25}, {"floor": low_floor, "y": size.y * 0.25}]:
		var zone := FloorZoneScene.instantiate()
		zone.floor_index = cfg.floor
		zone.ramp = true
		zone.size = Vector2(size.x, size.y * 0.5)
		zone.position = Vector2(0.0, cfg.y)
		add_child(zone)
	if rails:
		var rail_bits: int = 4 | Floors.floor_bit(low_floor) | Floors.floor_bit(high_floor)
		for s in [-1.0, 1.0]:
			var rail := StaticBody2D.new()
			rail.collision_layer = rail_bits
			rail.collision_mask = 0
			rail.position = Vector2(s * (size.x * 0.5 + RAIL_W * 0.5 + 2.0), 0.0)
			var col := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(RAIL_W, size.y)
			col.shape = shape
			rail.add_child(col)
			add_child(rail)
	if downhill_pull > 0.0 or stairs:
		_grade_area = Area2D.new()
		_grade_area.collision_layer = 0
		_grade_area.collision_mask = 1  # cars always keep the ground bit
		var gcol := CollisionShape2D.new()
		var gshape := RectangleShape2D.new()
		gshape.size = size
		gcol.shape = gshape
		_grade_area.add_child(gcol)
		add_child(_grade_area)
		_grade_area.body_exited.connect(_on_grade_exit)
	set_physics_process(_grade_area != null)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _grade_area == null:
		return
	var downhill := Vector2.DOWN.rotated(global_rotation)  # local +y = low end
	for body in _grade_area.get_overlapping_bodies():
		if not (body is CharacterBody2D):
			continue
		if body.get("height") != 0.0:
			continue  # airborne cars aren't on the grade
		if downhill_pull > 0.0:
			body.velocity += downhill * downhill_pull * delta
		if stairs:
			_tier_tick(body)

## Tier bumps: bucket each body's travel along the slope axis; every row line
## crossed kicks the player's camera a little — you FEEL the seating.
func _tier_tick(body: CharacterBody2D) -> void:
	var bucket := int(floorf(to_local(body.global_position).y / ROW_DEPTH))
	var id := body.get_instance_id()
	if _tier_bucket.has(id) and int(_tier_bucket[id]) != bucket \
			and body.is_in_group(&"player") and body.has_method(&"add_shake"):
		body.add_shake(STAIR_SHAKE)
	_tier_bucket[id] = bucket

func _on_grade_exit(body: Node) -> void:
	_tier_bucket.erase(body.get_instance_id())

func _draw() -> void:
	var half := size * 0.5
	if rails:
		# Rail faces along the full slope (the painted side of the chokepoint) —
		# drawn even when a deco layer owns the surface: the rails are physical.
		var rail_x := half.x + 2.0
		draw_rect(Rect2(Vector2(-rail_x - RAIL_W, -half.y), Vector2(RAIL_W, size.y)), EDGE)
		draw_rect(Rect2(Vector2(rail_x, -half.y), Vector2(RAIL_W, size.y)), EDGE)
	if not surface_paint:
		return
	# The slope is a built structure — fully opaque, never tinted street.
	draw_rect(Rect2(-half, size), surface_color)
	var step_h := size.y / SHADE_STEPS
	for i in SHADE_STEPS:
		var t := float(i) / float(SHADE_STEPS - 1)  # 0 = high end, 1 = low end
		var band := Rect2(Vector2(-half.x, -half.y + i * step_h), Vector2(size.x, step_h + 1.0))
		draw_rect(band, Color(1.0, 1.0, 1.0, HILITE_A * (1.0 - t)))
		draw_rect(band, Color(0.0, 0.0, 0.0, SHADOW_A * t))
	draw_rect(Rect2(-half, size), EDGE, false, 2.0)
	# Up-slope chevrons along the centerline.
	var chevrons := maxi(int(size.y / 112.0), 2)
	for i in chevrons:
		var cy := -half.y + size.y * (float(i) + 0.5) / chevrons
		draw_polyline(PackedVector2Array([
			Vector2(-11.0, cy + 7.0), Vector2(0.0, cy - 7.0), Vector2(11.0, cy + 7.0),
		]), CHEVRON, 3.0)
