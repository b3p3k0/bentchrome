extends Area2D
## Route 666's oil slick, the part you FEEL. The paint (chunk_builder._slick:
## true black pool, curvy edge, one glint, a drip) is untouched; this is the
## sensor under it. A grounded car that rolls onto the spill gets its NOSE
## kicked ±KICK off the line of travel and a spin that keeps coming
## (`Vehicle.yaw_kick`: YAW_DEG_S fading to nothing over the spell) — the
## velocity is never touched, so the car keeps sliding exactly where it was
## going while the hull comes round — and for OIL_SECONDS its tires are on
## ice whatever the road says (`Vehicle.force_terrain`), so every correction
## rotates the hull without moving the car much. The lane wheel's fight to
## get the nose back north IS the moment: without the lingering spin it won
## in 8 frames (measured — a blink, not a slide); against it the nose hangs
## a step or two off for most of a second and the car crabs a lane's worth
## toward where it points, then settles. A straight entry is north again
## inside a second, a mid-lane-change entry carries across the lanes it was
## crossing. Never HP, never a spin-out (the nose never crosses 45°). Black
## rear-tire tracks and a short screech sell it against the pothole (dirt
## zone, a bump — no kick, no tracks). Airtime clears it. Birds slide too —
## same code, and it's funny.
##
## Duck-typed: anything with `velocity`, `heading` and `height` slides;
## network puppets are skipped (the host simulates, the stream carries it).

static var OIL_SECONDS := 1.0      # how long the tires stay on "ice" after entry
static var KICK_MIN_DEG := 12.0    # nose deflection off the line of travel
static var KICK_MAX_DEG := 28.0
static var YAW_DEG_S := 300.0      # the lingering spin at entry, same sign as the kick,
								   # gone by OIL_SECONDS (the lane wheel's ice-rate is ~228°/s)
static var TRACK_SECONDS := 1.5    # black rear-tire tracks laid after entry
static var SCREECH_SECONDS := 0.5  # the player's skid loop held on entry

const TRACK_COLOR := Color(0.03, 0.03, 0.035, 0.85)  # oil on the tread — blacker than rubber

var _rng := RandomNumberGenerator.new()

## Builder entry: the sensor node under a painted spill. Layer 0 / mask 1
## (ground bit) like a jump pad — the TerrainSensor never sees it, the ice
## comes through the vehicle's override instead.
static func make(pos: Vector2, r: float) -> Area2D:
	var slick := Area2D.new()
	slick.set_script(load("res://levels/chase/oil_slick.gd"))
	slick.name = "Slick"
	slick.collision_layer = 0
	slick.collision_mask = 1
	slick.position = pos
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := CircleShape2D.new()
	shape.radius = r
	col.shape = shape
	slick.add_child(col)
	return slick

func _ready() -> void:
	# Seeded off the spill's place in the world (TerrainZone._soften's idiom):
	# the same slick throws the same car the same way every run of the seed.
	_rng.seed = int(absf(global_position.x * 7.0 + global_position.y * 13.0)) + 29
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not ("velocity" in body and "heading" in body and "height" in body):
		return
	if float(body.get("height")) > 0.0:
		return  # airborne clears the spill
	if body.get("net_puppet") == true:
		return
	slide(body)

## The kick, the ice spell, the tracks and the screech — in that order. Pure
## on the vehicle side: no HP, no velocity change.
func slide(body: Node) -> void:
	var kick := deg_to_rad(_rng.randf_range(KICK_MIN_DEG, KICK_MAX_DEG))
	if _rng.randf() < 0.5:
		kick = -kick
	body.heading += kick
	if body.has_method(&"yaw_kick"):
		body.yaw_kick(signf(kick) * deg_to_rad(YAW_DEG_S), OIL_SECONDS)
	if body.has_method(&"force_terrain"):
		body.force_terrain(&"ice", OIL_SECONDS)
	var fx: Node = body.get_node_or_null(^"DriveFX")
	if fx:
		if fx.has_method(&"carry_tracks"):
			fx.carry_tracks(TRACK_SECONDS, TRACK_COLOR)
		if fx.has_method(&"screech"):
			fx.screech(SCREECH_SECONDS)
	# The player's screech rides DriveFX's skid loop (held by screech());
	# everyone else's is a positional one-shot of the same squeal.
	if not body.is_in_group(&"player"):
		var audio := get_node_or_null(^"/root/AudioDirector")
		if audio and body is Node2D:
			audio.play_at(&"skid", (body as Node2D).global_position)
