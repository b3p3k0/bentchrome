extends RefCounted
## The tournament economy (BOLTS), dependency-free ON PURPOSE — the
## difficulty.gd/combat.gd leaf pattern (no class_name, preloads only other
## leaves) so zones, stations, levels, and shop UI can all bill and award
## without dependency cycles. Design truth: docs/garage/economy.md.
##
## BOLTS are run state: start at 0, reset with the campaign, never persisted.
## Rewards are flat, size-proportionate for salvage, and difficulty-scaled;
## penalties are a PERCENTAGE of current funds — always hurts the same, rich
## or poor, and can never drive the wallet below zero.
##
## feature/garage phase 1: NOT WIRED into live gameplay — the sim harness and
## the shop are the only consumers. The plug-in phase connects kills, smashes,
## pits/deep water, and health stations to these entry points.

const Difficulty := preload("res://game/difficulty.gd")

# --- earn (HARD baseline; reward_scale multiplies) ----------------------------
static var KILL_REWARDS := {&"mook": 100, &"mini_boss": 250, &"boss": 500, &"chase": 25}
static var SALVAGE_FACTOR := 0.2   # per smash: clamp(round(max_hp * factor), 1, MAX_EACH)
static var SALVAGE_MAX_EACH := 30
static var SALVAGE_CAP := 300      # per-level ceiling on destructible/soft income

# --- lose (fractions of CURRENT funds; penalty_scale multiplies) ---------------
static var PENALTY_DESTROYED := 0.20
static var PENALTY_FALL := 0.30    # pits and deep water tax clumsiness harder
static var PENALTY_STATION := 0.10

static var funds: int = 0
static var salvage_earned: int = 0  # this level's progress toward SALVAGE_CAP
static var god := false             # DEVGOD courtesy: penalties inert, rewards stay fun

static func reset_run() -> void:
	funds = 0
	salvage_earned = 0

static func reset_level() -> void:
	salvage_earned = 0

## rank ∈ KILL_REWARDS keys; unknown ranks pay the mook rate. Returns bolts paid.
static func award_kill(rank: StringName) -> int:
	var base: int = KILL_REWARDS.get(rank, KILL_REWARDS[&"mook"])
	var paid := int(round(base * Difficulty.knob(&"reward_scale")))
	funds += paid
	return paid

## Size-proportionate smash money (max_hp is the size proxy), capped per level.
## Returns what was actually paid — 0 once the level's salvage is tapped.
static func award_salvage(max_hp: float) -> int:
	var base := clampi(int(round(max_hp * SALVAGE_FACTOR)), 1, SALVAGE_MAX_EACH)
	var scaled := int(round(base * Difficulty.knob(&"reward_scale")))
	var paid := clampi(SALVAGE_CAP - salvage_earned, 0, scaled)
	salvage_earned += paid
	funds += paid
	return paid

## kind ∈ {&"destroyed", &"fall", &"station"}. Returns the bolts taken.
## floori + maxi keep the wallet an int and never below zero.
static func apply_penalty(kind: StringName) -> int:
	if god:
		return 0
	var frac := PENALTY_DESTROYED
	match kind:
		&"fall":
			frac = PENALTY_FALL
		&"station":
			frac = PENALTY_STATION
	frac *= Difficulty.knob(&"penalty_scale")
	var taken := floori(funds * frac)
	funds = maxi(funds - taken, 0)
	return taken

## Shop-side: what an authored price costs on the current tier.
static func price(base: int) -> int:
	return int(round(base * Difficulty.knob(&"price_scale")))

## Everything a knobs panel may touch — export/reset round-trips.
static func snapshot() -> Dictionary:
	return {
		"kill_rewards": {"mook": KILL_REWARDS[&"mook"], "mini_boss": KILL_REWARDS[&"mini_boss"],
			"boss": KILL_REWARDS[&"boss"], "chase": KILL_REWARDS[&"chase"]},
		"salvage_factor": SALVAGE_FACTOR,
		"salvage_max_each": SALVAGE_MAX_EACH,
		"salvage_cap": SALVAGE_CAP,
		"penalty_destroyed": PENALTY_DESTROYED,
		"penalty_fall": PENALTY_FALL,
		"penalty_station": PENALTY_STATION,
	}
