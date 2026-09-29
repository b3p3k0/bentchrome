extends RefCounted
## What the Buzzardz take when they catch you on Route 666: BOLTS, PARTS, OR
## BLOOD. Dependency-free leaf (the economy.gd / difficulty.gd pattern: no
## class_name, preloads only other leaves) so the chase host, the robbery
## screen, and the tests can all reach it without cycles. The garage catalog
## is PASSED IN (items array) — this leaf never reaches into ui/.
##
## Nobody loses a life for getting caught by default — they get ROBBED. A
## ten-slice roulette wheel decides what goes: a bite of the wallet, a garage
## part off the car, the whole weapon bay, or (one slice in ten) a campaign
## life. The wheel is RIGGED TO WHAT YOU OWN: a slice you couldn't pay is
## re-dealt into one you can, the BLOOD slice vanishes on your last life, and
## a driver with nothing at all keeps everything but their dignity.
##
## Flow: state_of() -> build_wheel() -> spin() -> apply(). Everything takes
## its randomness from a passed-in RandomNumberGenerator, so tests (and the
## wheel's pre-rolled landing) are deterministic.

const Economy := preload("res://game/economy.gd")

enum Kind { BOLTS, PARTS, BAY, BLOOD, DIGNITY }

## The default wheel, in wedge order (kinds interleaved so no two neighbours
## match): five BOLTS bites, three PARTS, one BAY, one BLOOD.
static var WHEEL := [
	{"kind": Kind.BOLTS, "frac": 0.25},
	{"kind": Kind.PARTS},
	{"kind": Kind.BOLTS, "frac": 0.50},
	{"kind": Kind.BAY},
	{"kind": Kind.BOLTS, "frac": 0.25},
	{"kind": Kind.PARTS},
	{"kind": Kind.BOLTS, "frac": 1.00},
	{"kind": Kind.BLOOD},
	{"kind": Kind.BOLTS, "frac": 0.50},
	{"kind": Kind.PARTS},
]
## What an unpayable slice is re-dealt into, first payable wins. BLOOD is
## never a substitute: the wheel holds at most the one it was dealt.
static var REDEAL_ORDER := [Kind.BOLTS, Kind.PARTS, Kind.BAY]
static var REDEAL_BITE := 0.25   # the BOLTS bite a re-dealt slice takes
const BAY_SLOTS := 7             # WeaponRack.Slot.size(): special + four missiles + two mines

## Owned parts the pack can unbolt: nothing else you own depends on them
## (own engine stages 1 and 2 and only stage 2 can go). items = the garage
## catalog's item dicts; ids missing from the catalog are left alone.
static func removable_parts(owned: Array, items: Array) -> Array:
	var needed := {}
	var known := {}
	for item in items:
		var id := String(item.get("id", ""))
		known[id] = true
		if id in owned:
			var req := String(item.get("requires", ""))
			if req != "":
				needed[req] = true
	var out: Array = []
	for id_v in owned:
		var id := String(id_v)
		if known.has(id) and not needed.has(id):
			out.append(id)
	return out

## Snapshot of what there is to take. gs = the GameState node (duck-typed:
## lives, owned_mods, carry_ammo); items = the garage catalog.
static func state_of(gs, items: Array) -> Dictionary:
	var owned: Array = gs.owned_mods if gs != null else []
	var bay: Array = gs.carry_ammo if gs != null else []
	return {
		"funds": Economy.funds if Economy.enabled else 0,
		"parts": removable_parts(owned, items),
		"bay": bay.duplicate(),
		"lives": int(gs.lives) if gs != null else 1,
	}

## Anything in the bay worth taking? The special's first round doesn't count:
## a level never starts with a dead special (Vehicle.apply_ammo_carry floors
## it at 1), so that one always comes back.
static func bay_has_loot(bay: Array) -> bool:
	for i in bay.size():
		if int(bay[i]) > (1 if i == 0 else 0):
			return true
	return false

static func can_pay(kind: int, state: Dictionary) -> bool:
	match kind:
		Kind.BOLTS:
			return int(state.get("funds", 0)) > 0
		Kind.PARTS:
			return not (state.get("parts", []) as Array).is_empty()
		Kind.BAY:
			return bay_has_loot(state.get("bay", []))
		Kind.BLOOD:
			return int(state.get("lives", 1)) > 1
	return true  # DIGNITY: always affordable

## The wheel as this driver will spin it: every slice of WHEEL, re-dealt
## where they couldn't pay. Same length, same order — the rigging is
## invisible unless you know what you're looking at.
static func build_wheel(state: Dictionary) -> Array:
	var sub := _substitute(state)
	var out: Array = []
	for slice_v in WHEEL:
		var slice: Dictionary = slice_v
		out.append(slice.duplicate() if can_pay(int(slice["kind"]), state) else sub.duplicate())
	return out

static func _substitute(state: Dictionary) -> Dictionary:
	for kind in REDEAL_ORDER:
		if can_pay(kind, state):
			return {"kind": kind, "frac": REDEAL_BITE} if kind == Kind.BOLTS else {"kind": kind}
	return {"kind": Kind.DIGNITY}

## Where the wheel lands: a uniform wedge index.
static func spin(wheel: Array, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, wheel.size() - 1) if not wheel.is_empty() else -1

## The wedge's face: what the wheel paints on it.
static func describe(slice: Dictionary) -> Dictionary:
	match int(slice.get("kind", Kind.DIGNITY)):
		Kind.BOLTS:
			var frac := float(slice.get("frac", 0.0))
			if frac >= 0.999:
				return {"label": "EVERYTHING", "color": Color(1.0, 0.72, 0.1)}
			return {"label": "BOLTS %d%%" % int(round(frac * 100.0)), "color": Color(0.86, 0.66, 0.16)}
		Kind.PARTS:
			return {"label": "PARTS", "color": Color(0.36, 0.5, 0.62)}
		Kind.BAY:
			return {"label": "THE BAY", "color": Color(0.42, 0.56, 0.3)}
		Kind.BLOOD:
			return {"label": "BLOOD", "color": Color(0.72, 0.14, 0.14)}
	return {"label": "DIGNITY", "color": Color(0.4, 0.38, 0.42)}

## Takes what the slice names from the run state and says so. Returns
## {kind, bolts, part, headline, detail}. DEVGOD (Economy.god) makes every
## kind inert — the wheel still spins so the flow stays testable.
static func apply(slice: Dictionary, gs, items: Array = [], rng: RandomNumberGenerator = null) -> Dictionary:
	var kind: int = slice.get("kind", Kind.DIGNITY)
	if Economy.god:
		return _outcome(Kind.DIGNITY, "THEY KNOW BETTER", "Nobody robs a god. They tip their hats.")
	match kind:
		Kind.BOLTS:
			var before: int = Economy.funds
			var taken: int = Economy.take_fraction(float(slice.get("frac", 0.0)))
			if taken <= 0:
				return _outcome(Kind.DIGNITY, "THEY FOUND LINT",
					"Pockets turned out. Nothing worth the trouble.")
			var all_of_it: bool = taken >= before
			return _outcome(Kind.BOLTS, "THEY TOOK EVERYTHING" if all_of_it else "THEY TOOK YOUR BOLTS",
				"-%d of %d bolts" % [taken, before], taken)
		Kind.PARTS:
			var loose := removable_parts(gs.owned_mods if gs != null else [], items)
			if loose.is_empty():
				return _dignity()
			var pick := 0
			if rng != null:
				pick = rng.randi_range(0, loose.size() - 1)
			var id := String(loose[pick])
			gs.owned_mods.erase(id)
			return _outcome(Kind.PARTS, "THEY TOOK YOUR PARTS",
				"%s. Unbolted and gone." % _part_name(id, items), 0, id)
		Kind.BAY:
			if gs == null or not bay_has_loot(gs.carry_ammo):
				return _dignity()
			var empty: Array = []
			empty.resize(BAY_SLOTS)
			empty.fill(0)
			gs.carry_ammo = empty  # seven zeros — an EMPTY array would mean "no carry"
			return _outcome(Kind.BAY, "THEY CLEANED OUT THE BAY", "Every rack, every round.")
		Kind.BLOOD:
			if gs == null or int(gs.lives) <= 1:
				return _dignity()  # never the last life: the rigging's promise, kept twice
			gs.lives = int(gs.lives) - 1
			return _outcome(Kind.BLOOD, "THEY TOOK IT IN BLOOD",
				"One life. %d left." % int(gs.lives))
	return _dignity()

static func _dignity() -> Dictionary:
	return _outcome(Kind.DIGNITY, "THEY TOOK YOUR DIGNITY", "Laughed at the car. Left you the keys.")

static func _part_name(id: String, items: Array) -> String:
	for item in items:
		if String(item.get("id", "")) == id:
			return String(item.get("display_name", id))
	return id

static func _outcome(kind: int, headline: String, detail: String, bolts := 0, part := "") -> Dictionary:
	return {"kind": kind, "bolts": bolts, "part": part, "headline": headline, "detail": detail}
