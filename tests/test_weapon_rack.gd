extends RefCounted
## WeaponRack tests: slot config, selection cycling, ammo consume/add caps,
## special recharge. The rack is pure bookkeeping — no tree needed; time is
## driven via tick().

const RackScript := preload("res://vehicles/weapon_rack.gd")
const DefScript := preload("res://resources/weapon_def.gd")

var t

func _init(runner) -> void:
	t = runner

func _rack(special_cap := 1, recharge := 12.0):
	var r = RackScript.new()
	var special = DefScript.new()
	special.display_name = "Test Special"
	r.configure(special, special_cap, recharge)
	return r

func test_configure_defaults() -> void:
	var r = _rack()
	t.check(r.selected_index() == RackScript.Slot.SPECIAL, "rack: special selected on configure")
	t.check(r.ammo(RackScript.Slot.SPECIAL) == 1, "rack: special starts at cap")
	t.check(r.ammo(RackScript.Slot.STANDARD) == 2, "rack: 2 standard to start")
	t.check(r.ammo(RackScript.Slot.HOMING) == 1, "rack: 1 homing to start")
	t.check(r.selected_def() != null and r.selected_def().display_name == "Test Special", "rack: selected def is the special")
	r.free()

func test_selection_cycles_and_wraps() -> void:
	var r = _rack()
	r.select_next()
	t.check(r.selected_index() == RackScript.Slot.STANDARD, "cycle: next -> standard")
	r.select_next()
	t.check(r.selected_index() == RackScript.Slot.HOMING, "cycle: next -> homing")
	r.select_next()
	t.check(r.selected_index() == RackScript.Slot.SPECIAL, "cycle: next wraps to special")
	r.select_prev()
	t.check(r.selected_index() == RackScript.Slot.HOMING, "cycle: prev wraps to homing")
	r.free()

func test_consume_and_dry() -> void:
	var r = _rack()
	r.select_next()  # standard, ammo 2
	t.check(r.can_consume(), "consume: standard available")
	r.consume()
	r.consume()  # standard dry -> auto-cycles to homing
	t.check(r.ammo(RackScript.Slot.STANDARD) == 0, "consume: two shots spent")
	r.consume()  # homing dry -> auto-cycles to special
	r.consume()  # special dry -> everything empty, stays put
	t.check(not r.can_consume(), "consume: fully dry rack blocks fire")
	r.consume()  # no-op
	t.check(r.ammo(RackScript.Slot.SPECIAL) == 0, "consume: dry consume is a no-op")
	r.free()

func test_depletion_auto_cycles() -> void:
	var r = _rack()  # special selected, ammo 1
	var selections: Array = []
	r.selection_changed.connect(func(i: int) -> void: selections.append(i))
	r.consume()  # special 1 -> 0
	t.check(r.selected_index() == RackScript.Slot.STANDARD, "auto-cycle: dry special advances to standard")
	t.check(selections == [RackScript.Slot.STANDARD], "auto-cycle: selection_changed emitted")
	r.consume()  # standard 2 -> 1
	t.check(r.selected_index() == RackScript.Slot.STANDARD, "auto-cycle: no advance while ammo remains")
	r.consume()  # standard 1 -> 0
	t.check(r.selected_index() == RackScript.Slot.HOMING, "auto-cycle: skips the dry recharging special")
	r.consume()  # homing 1 -> 0; every slot dry
	t.check(r.selected_index() == RackScript.Slot.HOMING, "auto-cycle: all dry stays put")
	r.free()

func test_refill_does_not_move_selection() -> void:
	var r = _rack()
	r.consume()  # special dry -> standard
	r.add_ammo(RackScript.Slot.HOMING, 1)
	t.check(r.selected_index() == RackScript.Slot.STANDARD, "refill: pickups don't move selection")
	r.free()

func test_add_ammo_respects_cap() -> void:
	var r = _rack()
	var accepted = r.add_ammo(RackScript.Slot.STANDARD, 10)
	t.check(accepted == 4, "add: accepts only up to cap (2 + 4 = 6)")
	t.check(r.ammo(RackScript.Slot.STANDARD) == 6, "add: standard at cap")
	t.check(r.add_ammo(RackScript.Slot.STANDARD, 1) == 0, "add: full slot accepts nothing")
	r.free()

func test_special_recharges_to_cap() -> void:
	var r = _rack(2, 5.0)
	r.consume()
	r.consume()
	t.check(r.ammo(RackScript.Slot.SPECIAL) == 0, "recharge: special spent")
	r.tick(2.5)
	t.check_approx(r.recharge_fraction(), 0.5, "recharge: halfway to next round")
	r.tick(2.5)
	t.check(r.ammo(RackScript.Slot.SPECIAL) == 1, "recharge: one round back after 5s")
	r.tick(5.0)
	t.check(r.ammo(RackScript.Slot.SPECIAL) == 2, "recharge: refilled to cap")
	r.tick(5.0)
	t.check(r.ammo(RackScript.Slot.SPECIAL) == 2, "recharge: never exceeds cap")
	t.check_approx(r.recharge_fraction(), 1.0, "recharge: fraction is 1.0 at cap")
	r.free()

func test_signals_fire() -> void:
	var r = _rack()
	var selections: Array = []
	var ammo_events: Array = []
	r.selection_changed.connect(func(i: int) -> void: selections.append(i))
	r.ammo_changed.connect(func(i: int, a: int) -> void: ammo_events.append([i, a]))
	r.select_next()
	r.consume()
	t.check(selections == [RackScript.Slot.STANDARD], "signals: selection_changed emitted once")
	t.check(ammo_events == [[RackScript.Slot.STANDARD, 1]], "signals: ammo_changed carries slot + new count")
	r.free()
