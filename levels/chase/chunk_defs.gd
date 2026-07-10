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
			{"kind": &"standard", "at": [640.0, 130.0]},
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
}

## No two of these back to back — breathers between technical sections.
const NO_REPEAT := [&"narrow", &"chicane", &"slalom"]
