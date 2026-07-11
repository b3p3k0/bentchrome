extends RefCounted
## Difficulty tiers. Dependency-free ON PURPOSE — combat.gd preloads this from
## the projectile side of the graph, so this file must never preload or name
## anything (no class_name, no scene scripts, no autoloads). Leaf only.
##
## tier is run state: picked on the difficulty screen, fixed for the whole
## campaign (script statics survive scene swaps, and the end screen's Restart
## bypasses selection). It resets to HARD on app boot — HARD is today's
## gameplay byte-for-byte, and the headless gates rely on that identity.

enum Tier { EASY, MEDIUM, HARD }

static var tier: int = Tier.HARD

static var NAMES := {
	Tier.EASY: "LEARNER'S PERMIT",
	Tier.MEDIUM: "ROAD RAGING COMMUTER",
	Tier.HARD: "REVOKED LICENSE",
}

## THE knob table. Every value is a MULTIPLIER on the hard-tier baseline, so
## the HARD row is all 1.0 by definition and no consumer's const ever moves.
## Deliberately unscaled: enemy counts, lives, the mook RELENT valve, the
## AI-theater governors (AI_VS_AI_DAMAGE / AI_MERCY_HP), and environmental
## flat damage (barrels, falls, pits, deep water, horde wall) — none of it
## routes through Combat.scale.
static var TIERS := {
	Tier.EASY: {
		&"player_damage_taken": 0.55,   # all AI->player damage, every path
		&"player_damage_dealt": 1.0,    # dormant knob: player->AI damage
		&"ai_fire_cooldown": 1.75,      # >1 = AI (and boss turrets) fire less often
		&"boss_hit_budget": 0.6,        # Lackey breaks off after less damage dealt
		&"boss_engage_limit": 0.7,      # ...and can't press as long even whiffing
		&"boss_break_time": 1.6,        # longer breathers, dominance shape intact
		&"goliath_hp": 0.7,             # trims BOTH phase pools
		&"goliath_ram_cooldown": 1.5,   # rarer phase-2 charges
	},
	Tier.MEDIUM: {
		&"player_damage_taken": 0.75,
		&"player_damage_dealt": 1.0,
		&"ai_fire_cooldown": 1.35,
		&"boss_hit_budget": 0.8,
		&"boss_engage_limit": 0.85,
		&"boss_break_time": 1.25,
		&"goliath_hp": 0.85,
		&"goliath_ram_cooldown": 1.2,
	},
	Tier.HARD: {
		&"player_damage_taken": 1.0,
		&"player_damage_dealt": 1.0,
		&"ai_fire_cooldown": 1.0,
		&"boss_hit_budget": 1.0,
		&"boss_engage_limit": 1.0,
		&"boss_break_time": 1.0,
		&"goliath_hp": 1.0,
		&"goliath_ram_cooldown": 1.0,
	},
}

static func knob(name: StringName) -> float:
	return TIERS[tier].get(name, 1.0)  # missing knob fails soft to hard-identity
