extends Driver
## Route 666 autopilot: a stand-in for a competent-but-unremarkable player,
## seated by tools/probes/chase_run.gd. It holds the road with a look-ahead,
## steers around solid things it can see coming (three fanned rays), stays
## flat out, boosts when the pack is on the bumper, and fires at whatever is
## directly in front of it. It never dodges gunfire, never goes looking for
## pickups, and never uses the rear weapons — a real player does all three,
## so read its results as a FLOOR, not a forecast.

const SpeedBand := preload("res://levels/chase/speed_band.gd")
const Pedal := preload("res://levels/chase/chase_player_driver.gd")
const ChunkDefs := preload("res://levels/chase/chunk_defs.gd")

const LOOK := 520.0        # px of obstacle sight at skill 1.0
const DODGE_HOLD := 0.45   # seconds a dodge is committed to
const DODGE_SIDE := 150.0  # px of sidestep asked for
const TRAIL_LEAD := 700.0  # px before a trail's first station the bot starts lining up

var host: Node = null      # the buzzard_run scene (course + wall_gap)
var skill := 1.0           # scales LOOK: lower = later reactions
var boost_gap := 170.0     # boost when the pack is closer than this
var take_trails := 0.5     # the share of cutoffs it takes (dealt per chunk, deterministic per course)

var _dodge := 0.0
var _dodge_t := 0.0

func get_intent(vehicle, delta: float) -> Dictionary:
	var own: Vector2 = vehicle.global_position
	var s: Dictionary = host.course.sample(-(own.y - 300.0))
	var road_x: float = s["x"]
	var half: float = s["half_w"]
	# A washout has one paved ribbon left, and anyone with eyes drives on it.
	var look_d: float = -own.y + 200.0
	var chunk: Dictionary = host.course.plan[host.course.chunk_index_at(look_d)]
	var cdef: Dictionary = chunk["def"]
	if cdef.has("washout"):
		var local: float = look_d - float(chunk["start_d"])
		if local > float(cdef["washout"]["from"]) - 250.0 and local < float(cdef["washout"]["to"]):
			road_x = float(host.course.sample(look_d)["x"]) + ChunkDefs.washout_lane(cdef, local)
	# A cutoff's trail: taken on the chunks it was dealt (a deterministic
	# coin per chunk, so a course seed always plays the same way). Like a
	# driver reading the GPS, it lines up for the mouth from the chunk
	# before; on the trail the wheel follows the packed TRACK (not the
	# long-grass shoulders — mud, the gamble's price) and the road clamp
	# narrows to the track's width.
	var on_trail := false
	var ray_mask := 2 | 4   # walls + obstacles
	var idx: int = host.course.chunk_index_at(look_d)
	for probe_i in [idx, idx + 1]:
		if probe_i >= host.course.plan.size():
			break
		var pc: Dictionary = host.course.plan[probe_i]
		var pdef: Dictionary = pc["def"]
		if not pdef.has("cutoff") or int(pc["start_d"]) % 100 >= int(take_trails * 100.0):
			continue
		var cf: Dictionary = pdef["cutoff"]
		var local: float = look_d - float(pc["start_d"])
		var pts: Array = cf["trail"]
		if local > float(pts[0][0]) - TRAIL_LEAD and local < float(pts[pts.size() - 1][0]):
			road_x = float(pc["entry_x"]) + ChunkDefs.cutoff_x(pdef, local)
			half = float(cf["width"]) * 0.5
			on_trail = true
			ray_mask = 4   # the treeline is a wall: don't dodge into the ditch over it
			break
	var space: PhysicsDirectSpaceState2D = vehicle.get_world_2d().direct_space_state
	var blocked := {-1: false, 0: false, 1: false}
	for side in [-1, 0, 1]:
		var from := own + Vector2(side * 22.0, -30.0)
		var to := from + Vector2(side * 70.0, -LOOK * skill)
		var query := PhysicsRayQueryParameters2D.create(from, to, ray_mask)
		query.exclude = [vehicle.get_rid()]
		blocked[side] = not space.intersect_ray(query).is_empty()
	_dodge_t -= delta
	if blocked[0] or blocked[-1] or blocked[1]:
		if _dodge_t <= 0.0:
			if blocked[-1] and not blocked[1]:
				_dodge = 1.0
			elif blocked[1] and not blocked[-1]:
				_dodge = -1.0
			else:
				_dodge = signf(road_x - own.x) if absf(road_x - own.x) > 10.0 else 1.0
			_dodge_t = DODGE_HOLD
	elif _dodge_t <= 0.0:
		_dodge = 0.0
	var want_x: float = road_x if _dodge == 0.0 else own.x + _dodge * DODGE_SIDE
	var inset: float = 60.0 if not on_trail else half * 0.6   # on the track: a wheel's width of slack, no more
	want_x = clampf(want_x, road_x - half + inset, road_x + half - inset)
	# The same lane-change wheel the player has: a sidestep is an axis push,
	# and a sweeper has to be driven. Gentle on the wheel: full lock only for
	# a big correction (every degree of yaw is northward speed spent).
	# (Lining up for a trail is the one time it commits the whole cone: the
	# mouth is a hard date.)
	var steer := Pedal.lane_steer(vehicle.heading, clampf((want_x - own.x) / (100.0 if on_trail else 240.0), -1.0, 1.0))
	var ctrl = vehicle.get_controller()
	var boosting: bool = host.wall_gap() < boost_gap and ctrl.boost_fuel > 0.0
	var fwd: float = vehicle.velocity.dot(Vector2.RIGHT.rotated(vehicle.heading))
	var fire := false
	for enemy in vehicle.get_tree().get_nodes_in_group(&"enemies"):
		var d: Vector2 = enemy.global_position - own
		if d.y < -40.0 and d.y > -520.0 and absf(d.x) < 60.0:
			fire = true
	return {
		"throttle": SpeedBand.pedal(1.0, fwd, SpeedBand.road_top(vehicle), boosting),
		"steer": steer, "fire_mg": fire, "fire_selected": fire,
		"weapon_prev": false, "weapon_next": false, "handbrake": false, "boost": boosting,
	}
