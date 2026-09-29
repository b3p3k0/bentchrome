extends RefCounted
## What the Buzzardz take when they catch you on Route 666. Dependency-free
## leaf (the economy.gd / difficulty.gd pattern: no class_name, preloads only
## other leaves) so the chase host, the robbery screen, and the tests can all
## reach it without cycles.
##
## Nobody loses a LIFE for getting caught — they get ROBBED. A slice names
## what is taken; apply() takes it from the run state and returns an outcome
## the screen can read aloud. Batch A ships the one slice the core loop needs
## (a bite of BOLTS); the full "bolts, parts, or blood" wheel lands on top of
## this same apply() seam.

const Economy := preload("res://game/economy.gd")

enum Kind { BOLTS, PARTS, BAY, BLOOD, DIGNITY }

## The stand-in shakedown until the wheel lands: a quarter of the wallet.
static var PLACEHOLDER_BITE := 0.25

static func placeholder_slice() -> Dictionary:
	return {"kind": Kind.BOLTS, "frac": PLACEHOLDER_BITE}

## Takes what the slice names from the run state. gs = the GameState node
## (duck-typed; BOLTS live on the Economy leaf and never touch it). Returns
## {kind, bolts, headline, detail} — what happened, in the pack's own words.
static func apply(slice: Dictionary, _gs) -> Dictionary:
	var kind: int = slice.get("kind", Kind.DIGNITY)
	match kind:
		Kind.BOLTS:
			var before: int = Economy.funds
			var taken: int = Economy.take_fraction(float(slice.get("frac", 0.0)))
			if taken <= 0:
				return _outcome(Kind.DIGNITY, 0, "THEY FOUND LINT",
					"Pockets turned out. Nothing worth the trouble.")
			return _outcome(Kind.BOLTS, taken, "THEY TOOK YOUR BOLTS",
				"-%d of %d bolts" % [taken, before])
	return _outcome(Kind.DIGNITY, 0, "THEY TOOK YOUR DIGNITY",
		"Laughed at the car. Left you the keys.")

static func _outcome(kind: int, bolts: int, headline: String, detail: String) -> Dictionary:
	return {"kind": kind, "bolts": bolts, "headline": headline, "detail": detail}
