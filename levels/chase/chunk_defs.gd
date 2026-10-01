extends RefCounted
## The Buzzard Run chunk library: authored highway segments the course
## pre-rolls into a 180-second run. Chunk-local convention: d runs 0..len
## NORTH into the chunk (world y = -(start_d + d)); the centerline starts at
## x-offset 0 and ends at exit_dx, bending through optional `path` stations
## [d, x_off]. Props and pickups sit at [d, side] RELATIVE to the centerline —
## they follow the road through curves by construction. half_w is the asphalt
## half-width; the drivable grass/dirt verge and the embankment wall hang off
## it in the builder.

const DEFS := {
	&"straight": {
		"len": 1200.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"straight", "shoulder": &"grass",
	},
	&"straight_junk": {
		"len": 1200.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"straight", "shoulder": &"grass",
		"props": [
			{"kind": &"derelict", "at": [420.0, -250.0]},
			{"kind": &"pothole", "at": [640.0, 90.0]},
			{"kind": &"cone", "at": [800.0, 300.0]},
			{"kind": &"cone", "at": [860.0, 266.0]},
			{"kind": &"barrel", "at": [950.0, -330.0]},
		],
	},
	&"curve_l": {
		"len": 1400.0, "exit_dx": -460.0, "half_w": 360.0,
		"kind": &"curve", "shoulder": &"grass",
		"path": [[380.0, -70.0], [1020.0, -390.0]],
	},
	&"curve_r": {
		"len": 1400.0, "exit_dx": 460.0, "half_w": 360.0,
		"kind": &"curve", "shoulder": &"grass",
		"path": [[380.0, 70.0], [1020.0, 390.0]],
	},
	&"chicane": {
		"len": 1500.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"chicane", "shoulder": &"dirt",
		"path": [[400.0, -190.0], [750.0, 0.0], [1100.0, 190.0]],
		"props": [
			{"kind": &"barrel", "at": [750.0, -300.0]},
			{"kind": &"barrel", "at": [790.0, -336.0]},
		],
		# Crumple rails down the weave: take the S for real, or pay hull.
		"median": [
			{"kind": &"rail", "from": 300.0, "to": 1200.0, "half_w": 10.0},
		],
	},
	&"divided": {
		"len": 1400.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"divided", "shoulder": &"grass",
		"median": [
			{"kind": &"rail", "from": 150.0, "to": 280.0, "half_w": 10.0},
			{"kind": &"grass", "from": 280.0, "to": 1120.0, "half_w": 70.0},
			{"kind": &"rail", "from": 1120.0, "to": 1250.0, "half_w": 10.0},
		],
	},
	&"narrow": {
		"len": 1000.0, "exit_dx": 0.0, "half_w": 260.0,
		"kind": &"narrow", "shoulder": &"dirt",
		"props": [
			{"kind": &"barrier", "at": [360.0, -308.0]},
			{"kind": &"barrier", "at": [360.0, 308.0]},
		],
	},
	&"slalom": {
		"len": 1500.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"slalom", "shoulder": &"grass",
		"props": [
			{"kind": &"derelict", "at": [300.0, -170.0]},
			{"kind": &"derelict", "at": [650.0, 170.0]},
			{"kind": &"derelict", "at": [1000.0, -170.0]},
			{"kind": &"log", "at": [1180.0, -60.0]},
			{"kind": &"cone", "at": [1300.0, 170.0]},
			{"kind": &"cone", "at": [1340.0, 140.0]},
		],
	},
	&"pickup": {
		"len": 1000.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"pickup", "shoulder": &"grass",
		"props": [
			{"kind": &"cone", "at": [380.0, -190.0]},
			{"kind": &"cone", "at": [660.0, 190.0]},
		],
		"pickups": [
			{"kind": &"heal", "at": [400.0, -130.0]},
			{"kind": &"rear", "at": [640.0, 130.0]},
			{"kind": &"boost", "at": [860.0, -100.0]},
		],
	},
	# Bad road: a stretch the county gave up on — jagged POTHOLES (dirt: a
	# bump that bleeds speed) between OIL SLICKS (ice: the car keeps going
	# where it was going). Two reads, two feels, one dodge.
	&"bad_road": {
		"len": 1200.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"bad_road", "shoulder": &"dirt",
		"props": [
			{"kind": &"cone", "at": [130.0, -220.0]},
			{"kind": &"pothole", "at": [220.0, -140.0]},
			{"kind": &"slick", "at": [430.0, 120.0]},
			{"kind": &"pothole", "at": [640.0, -50.0]},
			{"kind": &"slick", "at": [850.0, 200.0]},
			{"kind": &"pothole", "at": [1050.0, -180.0]},
		],
	},
	# Washout: the county gave up on this mile. The asphalt has crumbled to
	# DIRT edge to edge — except for one surviving paved ribbon that wanders
	# from one side of the road to the other. Hold the ribbon and you keep
	# your pace; miss it and you are on dirt while the pack is not (the one
	# place on Route 666 where off-road tires earn their bolts). `washout`:
	# from/to = the broken stretch, lane_w = the ribbon's width, lane = its
	# centre as [d, x_off] stations. The pair mirror each other, and each
	# ends on the side the other begins.
	&"washout_l": {
		"len": 1400.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"washout", "shoulder": &"dirt",
		"washout": {
			"from": 160.0, "to": 1240.0, "lane_w": 190.0,
			"lane": [[160.0, -130.0], [420.0, -130.0], [960.0, 130.0], [1240.0, 130.0]],
		},
		"props": [
			{"kind": &"cone", "at": [120.0, -250.0]},
			{"kind": &"cone", "at": [120.0, -10.0]},
		],
	},
	&"washout_r": {
		"len": 1400.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"washout", "shoulder": &"dirt",
		"washout": {
			"from": 160.0, "to": 1240.0, "lane_w": 190.0,
			"lane": [[160.0, 130.0], [420.0, 130.0], [960.0, -130.0], [1240.0, -130.0]],
		},
		"props": [
			{"kind": &"cone", "at": [120.0, 250.0]},
			{"kind": &"cone", "at": [120.0, 10.0]},
		],
	},
	&"log_run": {
		"len": 1300.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"log_run", "shoulder": &"grass",
		"props": [
			{"kind": &"log", "at": [300.0, -180.0]},
			{"kind": &"log", "at": [620.0, 140.0]},
			{"kind": &"junk", "at": [880.0, -240.0]},
			{"kind": &"log", "at": [1050.0, -40.0]},
		],
	},
	&"launch": {
		"len": 1100.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"launch", "shoulder": &"grass",
		"props": [
			{"kind": &"cone", "at": [280.0, -160.0]},
			{"kind": &"cone", "at": [280.0, 160.0]},
			{"kind": &"jump", "at": [430.0, 0.0]},
		],
		"pickups": [
			{"kind": &"heal", "at": [720.0, 0.0]},
		],
	},
	# Toll plaza: three booths across the road with a striped arm dropped in
	# every lane — pick a gate and smash the arm (25 HP, a nick), or hit a
	# booth (60 HP, a real bite). CASH ONLY; nobody's home.
	&"tollbooth": {
		"len": 1300.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"tollbooth", "shoulder": &"dirt",
		"set_piece": &"tollbooth",
		"props": [
			{"kind": &"cone", "at": [380.0, -330.0]},
			{"kind": &"cone", "at": [380.0, 330.0]},
			{"kind": &"barrel", "at": [900.0, 300.0]},
		],
	},
	# Jackknife: a rig lost it here — the trailer lies across two lanes with
	# its load spilled around it. Slalom the open lane, or pay hull to the
	# trailer (90 HP: the heaviest thing on the road after the pillars).
	&"jackknife": {
		"len": 1400.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"jackknife", "shoulder": &"grass",
		"set_piece": &"jackknife",
		"props": [
			{"kind": &"junk", "at": [520.0, 250.0]},
			{"kind": &"barrel", "at": [480.0, -80.0]},
			{"kind": &"barrel", "at": [530.0, -120.0]},
			{"kind": &"derelict", "at": [720.0, -150.0]},
			{"kind": &"junk", "at": [880.0, 60.0]},
		],
		"pickups": [
			{"kind": &"boost", "at": [1100.0, 200.0]},
		],
	},
	# --- traps (the Buzzardz got here first) ----------------------------
	# Tire wall: stacked tires across the road, every stack burning, one
	# lane-wide gap that moves with the chunk seed. A stack is 22 HP (a nick,
	# most of the momentum kept) — but touching one sets the car on fire
	# (a few seconds of light DoT; nitro blows it out). Cones well ahead.
	&"tire_wall": {
		"len": 1200.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"tire_wall", "shoulder": &"dirt",
		"set_piece": &"tire_wall",
		"props": [
			{"kind": &"cone", "at": [380.0, -240.0]},
			{"kind": &"cone", "at": [380.0, 240.0]},
			{"kind": &"cone", "at": [450.0, 0.0]},
		],
	},
	# Spike strip: a Buzzard parked on the right verge, its rider standing by
	# with a coil of spikes — come within reach and it goes skidding across
	# the near lane. Cross it grounded and you're on a flat tire for a beat
	# (a slow, a wobble, sparks); the other lanes are open, the tell is the
	# bike and the throw. Airborne clears it. The pack's birds pay the same.
	&"spike_strip": {
		"len": 1300.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"spike_strip", "shoulder": &"grass",
		"set_piece": &"spike_strip",
		"props": [
			{"kind": &"cone", "at": [300.0, 300.0]},
			{"kind": &"junk", "at": [1080.0, -260.0]},
		],
	},
	# Tanker: a rig jackknifed into the verge and burning, its load spilled in
	# a sheet of oil across two lanes (slicks: ice — the car keeps going where
	# it was going). The dry lane is the line. Vultures already overhead.
	&"tanker": {
		"len": 1400.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"tanker", "shoulder": &"dirt",
		"set_piece": &"tanker",
		"props": [
			{"kind": &"cone", "at": [400.0, -330.0]},
			{"kind": &"cone", "at": [400.0, 330.0]},
			{"kind": &"barrel", "at": [1150.0, 320.0]},
		],
	},
	# --- the back roads --------------------------------------------------
	# Cutoff: the highway swings wide in an S while a dirt-bike trail runs
	# straight along the inside — through a GAP in the shoulder and the
	# embankment, fenced by a treeline, and back through a second gap. The
	# `cutoff` block: `side` (-1 = the trail is on the left), `trail`
	# stations [d, x_off] from the chunk ENTRY x (not the bent centreline),
	# `width` of the packed track, `shoulder` the long-grass band EACH side
	# of it (mud underneath — the gamble: the track is the fast line, blow
	# it and the shoulder bogs you), the embankment `gaps` [from, to] on
	# that side, `trees_x` the treeline's offset. Honest dirt (slower) — the
	# pay-off is the pack losing sight of you (horde_wall.lost_sight) and
	# the S-bend's curve tax you skip. The pair mirror each other.
	&"cutoff_l": {
		"len": 2000.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"cutoff", "shoulder": &"grass",
		"path": [[300.0, 0.0], [760.0, 200.0], [1240.0, 200.0], [1700.0, 0.0]],
		"cutoff": {
			"side": -1.0, "width": 70.0, "shoulder": 150.0, "trees_x": -790.0,
			"trail": [[100.0, -230.0], [860.0, -565.0], [1180.0, -565.0], [1760.0, -330.0]],
			"gaps": [[300.0, 780.0], [1280.0, 1700.0]],
		},
		"props": [
			{"kind": &"cone", "at": [240.0, -300.0]},
			{"kind": &"cone", "at": [1760.0, -300.0]},
		],
	},
	&"cutoff_r": {
		"len": 2000.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"cutoff", "shoulder": &"grass",
		"path": [[300.0, 0.0], [760.0, -200.0], [1240.0, -200.0], [1700.0, 0.0]],
		"cutoff": {
			"side": 1.0, "width": 70.0, "shoulder": 150.0, "trees_x": 790.0,
			"trail": [[100.0, 230.0], [860.0, 565.0], [1180.0, 565.0], [1760.0, 330.0]],
			"gaps": [[300.0, 780.0], [1280.0, 1700.0]],
		},
		"props": [
			{"kind": &"cone", "at": [240.0, 300.0]},
			{"kind": &"cone", "at": [1760.0, 300.0]},
		],
	},
	# --- the finale (never rolled: buzzard_run splices it in at 0:00) -------
	# The bridge is out. A straight mile with a river across it: the deck runs
	# from the near `bank` to the `brink` where it breaks off, the DEEP channel
	# (a deep_water_zone — grounded cars sink) runs brink..deep_to, far
	# shallows to shallow_to, then the road resumes. `pad_d` is the launch lip
	# on the deck's last stretch (bikes launch off it; the player pops at the
	# brink under the finale driver). World y of any key: river_y(entry, key).
	&"bridge_out": {
		"len": 2400.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"bridge_out", "shoulder": &"dirt",
		"set_piece": &"bridge_out",
		"river": {"bank": 600.0, "brink": 1000.0, "deep_to": 1650.0, "shallow_to": 1750.0, "pad_d": 878.0},
		"props": [
			{"kind": &"barrier", "at": [420.0, -300.0]},
			{"kind": &"barrier", "at": [420.0, 300.0]},
			{"kind": &"cone", "at": [480.0, -200.0]},
			{"kind": &"cone", "at": [480.0, 200.0]},
		],
	},
	# --- set pieces (RARE: the picker spaces them ≥15k apart) ---------------
	&"overpass": {
		"len": 1100.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"overpass", "shoulder": &"dirt",
		"set_piece": &"overpass",
		"props": [
			{"kind": &"barrel", "at": [830.0, 300.0]},
		],
	},
	&"truckstop": {
		"len": 1400.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"truckstop", "shoulder": &"dirt",
		"set_piece": &"truckstop",
		"props": [
			{"kind": &"cone", "at": [420.0, 240.0]},
			{"kind": &"pump", "at": [560.0, 330.0]},
			{"kind": &"pump", "at": [660.0, 330.0]},
			{"kind": &"barrel", "at": [610.0, 390.0]},
			{"kind": &"barrel", "at": [702.0, 368.0]},
			{"kind": &"derelict", "at": [860.0, 300.0]},
		],
		"pickups": [
			{"kind": &"standard", "at": [780.0, 260.0]},
		],
	},
	&"convoy": {
		"len": 1400.0, "exit_dx": 0.0, "half_w": 360.0,
		"kind": &"convoy", "shoulder": &"grass",
		"props": [
			{"kind": &"derelict", "at": [350.0, -120.0]},
			{"kind": &"derelict", "at": [470.0, -30.0]},
			{"kind": &"derelict", "at": [560.0, 130.0]},
			{"kind": &"junk", "at": [700.0, -180.0]},
			{"kind": &"derelict", "at": [820.0, 40.0]},
			{"kind": &"log", "at": [950.0, -140.0]},
		],
		"pickups": [
			{"kind": &"heal", "at": [1080.0, 100.0]},
			{"kind": &"power", "at": [1120.0, -100.0]},
		],
	},
}

## Picker weights (the pickup chunk is cadence-forced, never rolled).
const WEIGHTS := {
	&"straight": 3.0,
	&"straight_junk": 2.0,
	&"divided": 2.0,
	&"curve_l": 2.0,
	&"curve_r": 2.0,
	&"chicane": 1.0,
	&"narrow": 1.0,
	&"slalom": 1.0,
	&"bad_road": 1.5,
	&"log_run": 1.5,
	&"washout_l": 0.7,
	&"washout_r": 0.7,
	&"cutoff_l": 0.6,
	&"cutoff_r": 0.6,
	&"tollbooth": 0.7,
	&"jackknife": 0.7,
	&"tire_wall": 0.6,
	&"spike_strip": 0.6,
	&"tanker": 0.6,
	&"launch": 1.0,
	&"overpass": 0.8,
	&"truckstop": 0.6,
	&"convoy": 0.6,
}

## No two of these back to back — breathers between technical sections.
const NO_REPEAT := [&"narrow", &"chicane", &"slalom", &"bad_road", &"log_run", &"launch",
	&"washout_l", &"washout_r", &"cutoff_l", &"cutoff_r", &"tollbooth", &"jackknife",
	&"tire_wall", &"spike_strip", &"tanker"]

## A cutoff's trail: its centre at chunk-local d as an offset from the chunk
## ENTRY x (the trail runs straight while the road bends away from it).
## Shared by the builder, the host's on-trail check, the GPS and the bot.
static func cutoff_x(def: Dictionary, d: float) -> float:
	var pts: Array = def["cutoff"]["trail"]
	if d <= float(pts[0][0]):
		return float(pts[0][1])
	for i in pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		if d <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (d - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(pts[pts.size() - 1][1])

## World y of a river landmark (`bank`, `brink`, `deep_to`, `shallow_to`,
## `pad_d`) of a bridge_out plan entry — north is -y, so deeper into the
## chunk is more negative.
static func river_y(entry: Dictionary, key: String) -> float:
	return -(float(entry["start_d"]) + float(entry["def"]["river"][key]))

## A washout's surviving paved ribbon: its centre at chunk-local d, as an
## offset from the road centreline. Shared by the builder and by anything
## that has to find the line (the balance probe's autopilot).
static func washout_lane(def: Dictionary, d: float) -> float:
	var pts: Array = def["washout"]["lane"]
	if d <= float(pts[0][0]):
		return float(pts[0][1])
	for i in pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		if d <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (d - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(pts[pts.size() - 1][1])

## Landmark chunks: at most one per RARE_SPACING of course (chase_course).
const RARE := [&"overpass", &"truckstop", &"convoy"]
