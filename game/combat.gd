extends RefCounted
## Combat balance rules, dependency-free ON PURPOSE — no class_name, no
## preloads except difficulty.gd (itself a dependency-free leaf), group checks
## instead of `is Vehicle`. Scripts on the projectile side of the graph load
## this; naming Vehicle there creates a circular resource load (missile.tscn
## -> projectile.gd -> Vehicle -> WeaponRack -> missile .tres -> missile.tscn)
## that kills cold boots. Duck-type only.

const Difficulty := preload("res://game/difficulty.gd")

# static var, not const: the botlab harness (tools/botlab/) overrides both for
# playerless data matches — a pure-AI FFA can never end under the shipping
# governor. Defaults are the shipping values; nothing in the game writes them.
static var AI_VS_AI_DAMAGE := 0.35  # governor: AI brawls are theater, kills are the player's
static var AI_MERCY_HP := 0.10      # below this an AI is immune to OTHER AI (never to the player)

## Damage multiplier for a hit: AI-on-AI runs at reduced power so opponents
## skirmish without wiping each other, and a nearly-dead AI is immune to
## fellow AI entirely — they keep shooting (theater), it keeps not dying,
## and the finishing blow stays the player's. Anything involving the player
## (or non-vehicle scenery) is full strength on the hard baseline; easier
## tiers scale the player-involved branches (difficulty.gd — HARD is 1.0).
static func scale(shooter, victim) -> float:
	if shooter == null or victim == null:
		return 1.0
	if not is_instance_valid(shooter) or not is_instance_valid(victim):
		# Posthumous shot: the shooter died with this round in flight (typed
		# params would hard-error on the freed instance). The round dies with
		# its owner — a car the theater rules protect must never eat a
		# full-strength hit from a ghost.
		return 0.0
	if not (shooter.is_in_group(&"vehicles") and victim.is_in_group(&"vehicles")):
		return 1.0
	var shooter_player: bool = shooter.is_in_group(&"player")
	var victim_player: bool = victim.is_in_group(&"player")
	if victim_player and not shooter_player:
		return Difficulty.knob(&"player_damage_taken")
	if shooter_player and not victim_player:
		return Difficulty.knob(&"player_damage_dealt")
	if shooter_player or victim_player:
		return 1.0
	if victim.has_method(&"get_hp_fraction") and victim.get_hp_fraction() < AI_MERCY_HP:
		return 0.0
	return AI_VS_AI_DAMAGE
