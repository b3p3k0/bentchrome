extends RefCounted
## Combat balance rules, dependency-free ON PURPOSE — no class_name, no
## preloads, group checks instead of `is Vehicle`. Scripts on the projectile
## side of the graph load this; naming Vehicle there creates a circular
## resource load (missile.tscn -> projectile.gd -> Vehicle -> WeaponRack ->
## missile .tres -> missile.tscn) that kills cold boots. Duck-type only.

const AI_VS_AI_DAMAGE := 0.35  # governor: AI brawls are theater, kills are the player's
const AI_MERCY_HP := 0.10      # below this an AI is immune to OTHER AI (never to the player)

## Damage multiplier for a hit: AI-on-AI runs at reduced power so opponents
## skirmish without wiping each other, and a nearly-dead AI is immune to
## fellow AI entirely — they keep shooting (theater), it keeps not dying,
## and the finishing blow stays the player's. Anything involving the player
## (or non-vehicle scenery) is full strength.
static func scale(shooter: Node, victim: Node) -> float:
	if shooter == null or victim == null:
		return 1.0
	if not (shooter.is_in_group(&"vehicles") and victim.is_in_group(&"vehicles")):
		return 1.0
	if shooter.is_in_group(&"player") or victim.is_in_group(&"player"):
		return 1.0
	if victim.has_method(&"get_hp_fraction") and victim.get_hp_fraction() < AI_MERCY_HP:
		return 0.0
	return AI_VS_AI_DAMAGE
