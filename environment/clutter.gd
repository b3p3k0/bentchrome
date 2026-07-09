extends StaticBody2D
## Roadside clutter — trash piles, dry scrub, suburb bushes, snow drifts.
## Block semantics (layer 4) so shots connect, but 1 HP: any hit or ram pops
## it with a quiet scatter puff (no ring, no shake — this is set dressing,
## not an explosion). Too small for the radar (ui/radar.gd size-gates it).
## Paint is a seeded lumpy blob cluster; kind picks the palette.

const KINDS := {
	&"trash": {"base": Color(0.34, 0.32, 0.28), "dark": Color(0.22, 0.2, 0.18), "fleck": Color(0.5, 0.46, 0.38)},
	&"brush": {"base": Color(0.45, 0.42, 0.22), "dark": Color(0.3, 0.28, 0.14), "fleck": Color(0.6, 0.54, 0.3)},
	&"bush": {"base": Color(0.22, 0.38, 0.18), "dark": Color(0.13, 0.24, 0.1), "fleck": Color(0.34, 0.52, 0.26)},
	&"drift": {"base": Color(0.82, 0.85, 0.92), "dark": Color(0.62, 0.68, 0.8), "fleck": Color(0.95, 0.97, 1.0)},
	# Street furniture (bespoke draw funcs; palette base tints the pop puff):
	&"mailbox": {"base": Color(0.25, 0.3, 0.4), "dark": Color(0.16, 0.19, 0.26), "fleck": Color(0.8, 0.2, 0.15)},
	&"sign": {"base": Color(0.55, 0.56, 0.6), "dark": Color(0.35, 0.36, 0.4), "fleck": Color(0.8, 0.15, 0.1)},
	&"cone": {"base": Color(0.95, 0.5, 0.1), "dark": Color(0.7, 0.35, 0.06), "fleck": Color(0.95, 0.93, 0.88)},
	&"bike": {"base": Color(0.2, 0.45, 0.7), "dark": Color(0.12, 0.12, 0.14), "fleck": Color(0.7, 0.72, 0.76)},
	&"hydrant": {"base": Color(0.8, 0.18, 0.14), "dark": Color(0.5, 0.1, 0.08), "fleck": Color(0.85, 0.87, 0.9)},
	# Dockyard furniture:
	&"bollard": {"base": Color(0.16, 0.17, 0.2), "dark": Color(0.09, 0.1, 0.12), "fleck": Color(0.85, 0.7, 0.2)},
	&"pallet": {"base": Color(0.52, 0.42, 0.27), "dark": Color(0.34, 0.27, 0.17), "fleck": Color(0.65, 0.55, 0.38)},
}

const Floors := preload("res://game/floors.gd")  # terraced-floor layer bit

@export var kind: StringName = &"trash"
@export var footprint := 40.0  # collision square; paint spills a little past it
@export var floor_index := -1  # ≥1 joins that terrace's collision world

@onready var _health: Health = $Health

func _ready() -> void:
	if floor_index >= 1:
		collision_layer |= Floors.floor_bit(floor_index)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(footprint, footprint)
	($Col as CollisionShape2D).shape = shape
	# Health (child) readies before this node — set hp along with max_hp.
	_health.max_hp = 1.0
	_health.hp = 1.0
	_health.died.connect(_pop)
	queue_redraw()

func _pop() -> void:
	var scene := get_tree().current_scene
	if scene:  # headless fixtures may not set one
		var palette: Dictionary = KINDS.get(kind, KINDS[&"trash"])
		var puff := CPUParticles2D.new()
		puff.one_shot = true
		puff.emitting = true
		puff.amount = 12
		puff.lifetime = 0.5
		puff.explosiveness = 1.0
		puff.spread = 180.0
		puff.initial_velocity_min = 120.0
		puff.initial_velocity_max = 260.0
		puff.damping_min = 150.0
		puff.damping_max = 300.0
		puff.scale_amount_min = 2.0
		puff.scale_amount_max = 4.0
		puff.gravity = Vector2.ZERO
		puff.color = palette.base
		puff.finished.connect(puff.queue_free)
		puff.global_position = global_position
		scene.add_child(puff)
		if kind == &"hydrant":
			_spout(scene)
	queue_free()

## Hydrant beat: a lingering water fountain where the hydrant stood.
const SPOUT_SECONDS := 8.0

func _spout(scene: Node) -> void:
	var water := CPUParticles2D.new()
	water.amount = 26
	water.lifetime = 0.7
	water.local_coords = false
	water.direction = Vector2(0, -1)
	water.spread = 20.0
	water.initial_velocity_min = 160.0
	water.initial_velocity_max = 260.0
	water.gravity = Vector2(0, 420)  # arcs up, rains down
	water.scale_amount_min = 1.5
	water.scale_amount_max = 3.0
	water.color = Color(0.55, 0.75, 0.95, 0.85)
	water.global_position = global_position
	scene.add_child(water)
	scene.get_tree().create_timer(SPOUT_SECONDS).timeout.connect(water.queue_free, CONNECT_ONE_SHOT)

func _draw() -> void:
	match kind:
		&"mailbox":
			_draw_mailbox()
		&"sign":
			_draw_sign()
		&"cone":
			_draw_cone()
		&"bike":
			_draw_bike()
		&"hydrant":
			_draw_hydrant()
		&"bollard":
			_draw_bollard()
		&"pallet":
			_draw_pallet()
		_:
			_draw_blob()

## The organic pile (trash/brush/bush/drift): seeded lump cluster.
func _draw_blob() -> void:
	var palette: Dictionary = KINDS.get(kind, KINDS[&"trash"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x * 7.0 + position.y * 13.0))
	var reach := footprint * 0.55
	for i in 5 + rng.randi() % 3:
		var at := Vector2(rng.randf_range(-reach, reach), rng.randf_range(-reach, reach)) * 0.8
		var r := rng.randf_range(footprint * 0.2, footprint * 0.38)
		draw_circle(at, r, palette.dark if rng.randf() < 0.4 else palette.base)
	for i in 4 + rng.randi() % 4:
		var p := Vector2(rng.randf_range(-reach, reach), rng.randf_range(-reach, reach))
		draw_rect(Rect2(p, Vector2(3, 3)), palette.fleck)

func _draw_mailbox() -> void:
	var p: Dictionary = KINDS[&"mailbox"]
	draw_rect(Rect2(-2, -2, 4, 12), Color(0.4, 0.3, 0.2))      # wooden post (shadow-down)
	draw_rect(Rect2(-8, -12, 16, 11), p.base)                  # box
	draw_rect(Rect2(-8, -12, 16, 3), p.dark)                   # rounded lid hint
	draw_rect(Rect2(6, -14, 2, 6), p.fleck)                    # red flag up
	draw_rect(Rect2(-8, -12, 16, 11), p.dark, false, 1.5)

func _draw_sign() -> void:
	var p: Dictionary = KINDS[&"sign"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x * 7.0 + position.y * 13.0))
	draw_rect(Rect2(-1.5, -4, 3, 16), p.base)                  # pole
	if rng.randf() < 0.5:
		# STOP octagon
		var pts := PackedVector2Array()
		for i in 8:
			pts.append(Vector2(0, -12) + Vector2(9, 0).rotated(TAU * i / 8.0 + TAU / 16.0))
		draw_colored_polygon(pts, p.fleck)
		draw_rect(Rect2(-5, -13.5, 10, 3), Color(0.95, 0.93, 0.9))  # "STOP" band
	else:
		# yellow warning diamond
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -21), Vector2(9, -12), Vector2(0, -3), Vector2(-9, -12),
		]), Color(0.9, 0.75, 0.2))
		draw_rect(Rect2(-1.5, -14.5, 3, 5), p.dark)                 # glyph hint

func _draw_cone() -> void:
	var p: Dictionary = KINDS[&"cone"]
	draw_rect(Rect2(-8, 2, 16, 4), p.dark)                     # base plate
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, 4), Vector2(0, -14), Vector2(6, 4),
	]), p.base)
	draw_rect(Rect2(-4, -6, 8, 3), p.fleck)                    # reflective band

func _draw_bike() -> void:
	var p: Dictionary = KINDS[&"bike"]
	# Fallen on its side: two wheels + frame lines + a spun-out handlebar.
	draw_arc(Vector2(-11, 2), 8.0, 0.0, TAU, 16, p.dark, 2.0)
	draw_arc(Vector2(11, -1), 8.0, 0.0, TAU, 16, p.dark, 2.0)
	draw_line(Vector2(-11, 2), Vector2(0, -4), p.base, 2.5)    # frame
	draw_line(Vector2(0, -4), Vector2(11, -1), p.base, 2.5)
	draw_line(Vector2(-11, 2), Vector2(-2, 4), p.base, 2.5)
	draw_line(Vector2(10, -8), Vector2(14, -4), p.fleck, 2.0)  # handlebar
	draw_rect(Rect2(-4, -7, 5, 3), p.dark)                     # seat

func _draw_hydrant() -> void:
	var p: Dictionary = KINDS[&"hydrant"]
	draw_circle(Vector2(0, 4), 8.0, p.dark)                    # ground flange
	draw_circle(Vector2.ZERO, 6.5, p.base)                     # barrel (top-down)
	draw_rect(Rect2(-9, -2, 4, 4), p.base)                     # side caps
	draw_rect(Rect2(5, -2, 4, 4), p.base)
	draw_circle(Vector2(0, -1), 3.0, p.fleck)                  # bonnet nut

func _draw_bollard() -> void:
	var p: Dictionary = KINDS[&"bollard"]
	draw_circle(Vector2(1, 3), 9.0, Color(0, 0, 0, 0.3))       # squat shadow
	draw_circle(Vector2.ZERO, 8.0, p.dark)                     # base flange
	draw_circle(Vector2.ZERO, 6.0, p.base)                     # iron post (top-down)
	draw_arc(Vector2.ZERO, 6.0, -2.4, 0.4, 10, p.fleck, 1.5)   # worn brass rim
	draw_line(Vector2(6, 2), Vector2(15, 6), p.dark, 2.0)      # mooring chain slinks off
	draw_line(Vector2(15, 6), Vector2(21, 5), p.dark, 1.5)

func _draw_pallet() -> void:
	var p: Dictionary = KINDS[&"pallet"]
	var h := footprint * 0.5
	draw_rect(Rect2(-h + 2, -h + 3, footprint, footprint), Color(0, 0, 0, 0.25))
	var slats := 5
	for i in slats:  # deck boards with daylight between
		var y := -h + footprint * (0.08 + 0.84 * i / (slats - 1)) - 2.0
		draw_rect(Rect2(-h, y, footprint, 4.5), p.base)
		draw_rect(Rect2(-h, y + 3.0, footprint, 1.2), p.dark)
	draw_rect(Rect2(-h, -h, 4, footprint), p.dark)             # stringers
	draw_rect(Rect2(h - 4, -h, 4, footprint), p.dark)
	draw_rect(Rect2(-2, -h, 4, footprint), p.dark)
