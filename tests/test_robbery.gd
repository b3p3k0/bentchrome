extends RefCounted
## The robbery leaf (game/robbery.gd): the default wheel's shape, the
## which-parts-can-go rule over the SHIPPED garage catalog, every rigging
## rule, the seeded spin, and what each slice actually takes.
## DISCIPLINE: Economy and Difficulty are process-global statics — every
## test restores tier=HARD, enabled=false, god=false, and reset_run().

const Robbery := preload("res://game/robbery.gd")
const Economy := preload("res://game/economy.gd")
const Difficulty := preload("res://game/difficulty.gd")
const GarageItems := preload("res://ui/garage/garage_catalog.gd")

var t

## GameState's robbery-facing surface, without the autoload.
class FakeState:
	var lives := 3
	var owned_mods: Array = []
	var carry_ammo: Array = []

func _init(runner) -> void:
	t = runner

func _open(funds: int) -> void:
	Difficulty.tier = Difficulty.Tier.HARD
	Economy.god = false
	Economy.enabled = true
	Economy.reset_run()
	Economy.funds = funds

func _close() -> void:
	Difficulty.tier = Difficulty.Tier.HARD
	Economy.god = false
	Economy.enabled = false
	Economy.reset_run()

func _count(wheel: Array, kind: int) -> int:
	var n := 0
	for slice in wheel:
		if int(slice["kind"]) == kind:
			n += 1
	return n

func _rich() -> Dictionary:
	return {"funds": 5000, "parts": ["armor_plating"], "bay": [1, 3, 0, 2, 0, 0, 0], "lives": 3}

func test_default_wheel_shape() -> void:
	var wheel: Array = Robbery.WHEEL
	t.check(wheel.size() == 10, "wheel: ten slices")
	t.check(_count(wheel, Robbery.Kind.BOLTS) == 5, "wheel: five bites of bolts")
	t.check(_count(wheel, Robbery.Kind.PARTS) == 3, "wheel: three slices take a part")
	t.check(_count(wheel, Robbery.Kind.BAY) == 1, "wheel: one slice cleans out the bay")
	t.check(_count(wheel, Robbery.Kind.BLOOD) == 1, "wheel: one slice in ten is blood")
	t.check(_count(wheel, Robbery.Kind.DIGNITY) == 0, "wheel: dignity is only ever a re-deal")
	var bites: Array = []
	for slice in wheel:
		if int(slice["kind"]) == Robbery.Kind.BOLTS:
			bites.append(float(slice["frac"]))
	bites.sort()
	t.check(bites == [0.25, 0.25, 0.5, 0.5, 1.0], "wheel: mixed bites — two quarters, two halves, EVERYTHING")
	for i in wheel.size():
		var here: int = wheel[i]["kind"]
		var next: int = wheel[(i + 1) % wheel.size()]["kind"]
		t.check(here != next or here == Robbery.Kind.BOLTS and float(wheel[i]["frac"]) != float(wheel[(i + 1) % wheel.size()]["frac"]),
			"wheel: no two neighbouring wedges read the same (wedge %d)" % i)
	for slice in wheel:
		var face: Dictionary = Robbery.describe(slice)
		t.check(String(face["label"]) != "" and face["color"] is Color, "wheel: every wedge has a face")
	t.check(String(Robbery.describe({"kind": Robbery.Kind.BOLTS, "frac": 1.0})["label"]) == "EVERYTHING",
		"wheel: the whole wallet has its own name")

## Only a part nothing else depends on can be unbolted — checked against the
## catalog the game actually ships.
func test_removable_parts_respect_the_chains() -> void:
	var items: Array = GarageItems.load_catalog()
	t.check(not items.is_empty(), "parts: the shipped catalog loads")
	t.check(Robbery.removable_parts([], items).is_empty(), "parts: nothing owned, nothing to take")
	var chain: Array = Robbery.removable_parts(["engine_stage1", "engine_stage2"], items)
	t.check(chain == ["engine_stage2"], "parts: stage 1 stays while stage 2 depends on it (%s)" % str(chain))
	var full: Array = Robbery.removable_parts(["engine_stage1", "engine_stage2", "engine_stage3", "armor_plating"], items)
	t.check(full.size() == 2 and "engine_stage3" in full and "armor_plating" in full,
		"parts: only the top of a chain and the loose parts can go (%s)" % str(full))
	t.check(Robbery.removable_parts(["not_a_real_part"], items).is_empty(),
		"parts: ids the catalog doesn't know are left alone")
	# Every chain in the shipped catalog: owning an item and its prerequisite
	# never offers the prerequisite.
	for item in items:
		var req := String(item.get("requires", ""))
		if req == "":
			continue
		var loose: Array = Robbery.removable_parts([req, String(item["id"])], items)
		t.check(req not in loose and String(item["id"]) in loose,
			"parts: %s protects %s" % [item["id"], req])

func test_rigged_to_what_you_own() -> void:
	# Own everything: the wheel is dealt straight.
	var straight: Array = Robbery.build_wheel(_rich())
	t.check(straight.size() == Robbery.WHEEL.size(), "rig: the wheel keeps its ten wedges")
	for i in straight.size():
		t.check(int(straight[i]["kind"]) == int(Robbery.WHEEL[i]["kind"]), "rig: nothing re-dealt when you can pay (wedge %d)" % i)
	# Last life: BLOOD is gone, the rest stands.
	var last := _rich()
	last["lives"] = 1
	var no_blood: Array = Robbery.build_wheel(last)
	t.check(_count(no_blood, Robbery.Kind.BLOOD) == 0, "rig: never blood on the last life")
	t.check(_count(no_blood, Robbery.Kind.BOLTS) == 6, "rig: the blood wedge re-deals into bolts")
	# No parts on the car: PARTS re-deal into bolts.
	var bare := _rich()
	bare["parts"] = []
	var no_parts: Array = Robbery.build_wheel(bare)
	t.check(_count(no_parts, Robbery.Kind.PARTS) == 0 and _count(no_parts, Robbery.Kind.BOLTS) == 8,
		"rig: no parts to take = three more bites of bolts")
	# Dry wallet: BOLTS re-deal into parts.
	var broke := _rich()
	broke["funds"] = 0
	var no_bolts: Array = Robbery.build_wheel(broke)
	t.check(_count(no_bolts, Robbery.Kind.BOLTS) == 0 and _count(no_bolts, Robbery.Kind.PARTS) == 8,
		"rig: a dry wallet = they come for the parts")
	# Empty bay: BAY re-deals.
	var unarmed := _rich()
	unarmed["bay"] = [1, 0, 0, 0, 0, 0, 0]
	t.check(_count(Robbery.build_wheel(unarmed), Robbery.Kind.BAY) == 0,
		"rig: an empty bay isn't worth a wedge (the special's first round always comes back)")
	unarmed["bay"] = []
	t.check(_count(Robbery.build_wheel(unarmed), Robbery.Kind.BAY) == 0, "rig: no carry at all, no bay wedge")
	# Only the bay left: everything unpayable lands on it.
	var bay_only := {"funds": 0, "parts": [], "bay": [1, 4, 0, 0, 0, 0, 0], "lives": 1}
	var all_bay: Array = Robbery.build_wheel(bay_only)
	t.check(_count(all_bay, Robbery.Kind.BAY) == 10, "rig: with only a bay to your name, the bay it is")
	# Nothing at all: ten wedges of dignity.
	var nothing := {"funds": 0, "parts": [], "bay": [], "lives": 1}
	var hollow: Array = Robbery.build_wheel(nothing)
	t.check(_count(hollow, Robbery.Kind.DIGNITY) == 10, "rig: nothing to take = dignity, ten times over")
	# Nothing but spare lives: blood keeps its ONE wedge, never more.
	var blood_only := {"funds": 0, "parts": [], "bay": [], "lives": 3}
	var thin: Array = Robbery.build_wheel(blood_only)
	t.check(_count(thin, Robbery.Kind.BLOOD) == 1 and _count(thin, Robbery.Kind.DIGNITY) == 9,
		"rig: blood is never a re-deal — one wedge in ten, at most")
	# The rigging never mutates the default wheel.
	t.check(_count(Robbery.WHEEL, Robbery.Kind.BLOOD) == 1 and Robbery.WHEEL.size() == 10,
		"rig: the default wheel is untouched")

func test_spin_is_seeded_and_covers_the_wheel() -> void:
	var wheel: Array = Robbery.build_wheel(_rich())
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 666
	b.seed = 666
	var same := true
	var seen := {}
	for i in 400:
		var landed: int = Robbery.spin(wheel, a)
		if landed != Robbery.spin(wheel, b):
			same = false
		t.check(landed >= 0 and landed < wheel.size(), "spin: lands on a real wedge") if i < 3 else null
		seen[landed] = true
	t.check(same, "spin: the same seed is the same night")
	t.check(seen.size() == wheel.size(), "spin: every wedge can come up (%d of %d)" % [seen.size(), wheel.size()])
	t.check(Robbery.spin([], a) == -1, "spin: no wheel, no landing")

func test_bolts_bites() -> void:
	_open(4000)
	var gs := FakeState.new()
	var quarter: Dictionary = Robbery.apply({"kind": Robbery.Kind.BOLTS, "frac": 0.25}, gs)
	t.check(quarter["kind"] == Robbery.Kind.BOLTS and quarter["bolts"] == 1000 and Economy.funds == 3000,
		"bolts: a quarter bite")
	t.check(String(quarter["detail"]).contains("1000") and String(quarter["detail"]).contains("4000"),
		"bolts: the verdict names the bite and the wallet")
	var all: Dictionary = Robbery.apply({"kind": Robbery.Kind.BOLTS, "frac": 1.0}, gs)
	t.check(all["bolts"] == 3000 and Economy.funds == 0, "bolts: EVERYTHING is everything")
	t.check(String(all["headline"]).contains("EVERYTHING"), "bolts: and says so")
	var lint: Dictionary = Robbery.apply({"kind": Robbery.Kind.BOLTS, "frac": 0.5}, gs)
	t.check(lint["kind"] == Robbery.Kind.DIGNITY and lint["bolts"] == 0, "bolts: a dry wallet is only lint")
	# Easier tiers soften the bite (the economy's own penalty scale).
	Difficulty.tier = Difficulty.Tier.EASY
	Economy.funds = 4000
	var soft: Dictionary = Robbery.apply({"kind": Robbery.Kind.BOLTS, "frac": 0.5}, gs)
	t.check(soft["bolts"] == 1000 and Economy.funds == 3000, "bolts: the easy tier halves the bite")
	t.check(gs.lives == 3 and gs.owned_mods.is_empty(), "bolts: nothing else is touched")
	_close()

func test_parts_bay_and_blood() -> void:
	_open(4000)
	var items: Array = GarageItems.load_catalog()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var gs := FakeState.new()
	gs.owned_mods = ["engine_stage1", "engine_stage2"]
	gs.carry_ammo = [2, 5, 1, 0, 3, 0, 1]
	var part: Dictionary = Robbery.apply({"kind": Robbery.Kind.PARTS}, gs, items, rng)
	t.check(part["kind"] == Robbery.Kind.PARTS and part["part"] == "engine_stage2",
		"parts: the top of the chain goes (%s)" % str(part["part"]))
	t.check(gs.owned_mods == ["engine_stage1"], "parts: the rest of the build stays bolted on")
	t.check(String(part["detail"]).contains("Stage 2"), "parts: the verdict names the part")
	t.check(Economy.funds == 4000 and gs.lives == 3, "parts: the wallet and the lives are untouched")
	var bay: Dictionary = Robbery.apply({"kind": Robbery.Kind.BAY}, gs, items, rng)
	t.check(bay["kind"] == Robbery.Kind.BAY, "bay: cleaned out")
	t.check(gs.carry_ammo.size() == 7 and gs.carry_ammo == [0, 0, 0, 0, 0, 0, 0],
		"bay: seven zeros — an empty array would mean 'no carry' and hand the default load back")
	var again: Dictionary = Robbery.apply({"kind": Robbery.Kind.BAY}, gs, items, rng)
	t.check(again["kind"] == Robbery.Kind.DIGNITY, "bay: an empty bay can't be robbed twice")
	var blood: Dictionary = Robbery.apply({"kind": Robbery.Kind.BLOOD}, gs, items, rng)
	t.check(blood["kind"] == Robbery.Kind.BLOOD and gs.lives == 2, "blood: one life")
	t.check(String(blood["detail"]).contains("2"), "blood: the verdict counts what's left")
	gs.lives = 1
	var spared: Dictionary = Robbery.apply({"kind": Robbery.Kind.BLOOD}, gs, items, rng)
	t.check(spared["kind"] == Robbery.Kind.DIGNITY and gs.lives == 1,
		"blood: never the last life, even if a blood slice is forced")
	gs.owned_mods = []
	var none: Dictionary = Robbery.apply({"kind": Robbery.Kind.PARTS}, gs, items, rng)
	t.check(none["kind"] == Robbery.Kind.DIGNITY, "parts: no parts, no theft")
	_close()

func test_devgod_and_state() -> void:
	_open(4000)
	var items: Array = GarageItems.load_catalog()
	var gs := FakeState.new()
	gs.owned_mods = ["armor_plating"]
	gs.carry_ammo = [1, 5, 0, 0, 0, 0, 0]
	var state: Dictionary = Robbery.state_of(gs, items)
	t.check(state["funds"] == 4000 and state["parts"] == ["armor_plating"] and state["lives"] == 3
		and state["bay"] == gs.carry_ammo, "state: the snapshot reads the run")
	state["bay"][1] = 0
	t.check(gs.carry_ammo[1] == 5, "state: the snapshot is a copy")
	Economy.god = true
	for kind in [Robbery.Kind.BOLTS, Robbery.Kind.PARTS, Robbery.Kind.BAY, Robbery.Kind.BLOOD]:
		var out: Dictionary = Robbery.apply({"kind": kind, "frac": 1.0}, gs, items)
		t.check(out["kind"] == Robbery.Kind.DIGNITY, "devgod: slice %d is inert" % kind)
	t.check(Economy.funds == 4000 and gs.owned_mods == ["armor_plating"] and gs.lives == 3
		and gs.carry_ammo[1] == 5, "devgod: nothing was taken")
	Economy.god = false
	Economy.enabled = false
	t.check(Robbery.state_of(gs, items)["funds"] == 0, "state: a closed wallet reads as empty")
	_close()
