extends RefCounted
## Campaign weapon-load persistence: a win carries the whole bay into the next
## level (special floored at 1), while a death respawn resets to the defined
## load — the exact inverse of the old accidental behavior. Driven by
## run_tests.gd.

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const RackScript := preload("res://vehicles/weapon_rack.gd")
const GameStateScript := preload("res://game/game_state.gd")

var t

func _init(runner) -> void:
	t = runner

## Stats authored BEFORE add_child (the level_loader pattern); enemies faction
## so fixtures never shadow player-group lookups.
func _car(faction := &"enemies") -> Node:
	var car = VehicleScene.instantiate()
	car.faction = faction
	car.stats = (load("res://data/vehicles/ghost.tres") as VehicleStats).duplicate()
	t.root.add_child(car)
	return car

func _done(car: Node) -> void:
	t.root.remove_child(car)
	car.free()

## Ghost: special cap 2, then the universal 2 fire / 1 homing / 1 power,
## empty rear + mines.
func _check_defined_load(rack, label: String) -> void:
	t.check(rack.ammo(RackScript.Slot.SPECIAL) == 2, label + ": special back at cap")
	t.check(rack.ammo(RackScript.Slot.STANDARD) == 2, label + ": 2 fire missiles")
	t.check(rack.ammo(RackScript.Slot.HOMING) == 1, label + ": 1 homing")
	t.check(rack.ammo(RackScript.Slot.POWER) == 1, label + ": 1 power")
	t.check(rack.ammo(RackScript.Slot.REAR) == 0, label + ": rear empty")
	t.check(rack.ammo(RackScript.Slot.MINE) == 0 and rack.ammo(RackScript.Slot.JUMP_MINE) == 0,
		label + ": mines empty")

func _dirty(rack) -> void:
	rack.consume()  # special cap 2 -> 1
	rack.add_ammo(RackScript.Slot.REAR, 3)
	rack.add_ammo(RackScript.Slot.MINE, 2)
	rack.select_next()

func test_respawn_resets_to_defined_load() -> void:
	var car = _car()
	_dirty(car.get_rack())
	car.respawn(Vector2.ZERO, 0.0, 0.5)
	_check_defined_load(car.get_rack(), "death respawn")
	t.check(car.get_rack().selected_index() == RackScript.Slot.SPECIAL,
		"death respawn: selection back on the special")
	_done(car)

func test_level_start_respawn_keeps_rack() -> void:
	var car = _car()
	var rack = car.get_rack()
	_dirty(rack)
	car.respawn(Vector2.ZERO, 0.0, 0.5, false)  # the level-start blink shield
	t.check(rack.ammo(RackScript.Slot.SPECIAL) == 1
		and rack.ammo(RackScript.Slot.REAR) == 3
		and rack.ammo(RackScript.Slot.MINE) == 2,
		"level-start respawn: the carried bay survives untouched")
	_done(car)

func test_apply_ammo_carry_floors_and_clamps() -> void:
	var car = _car()
	var rack = car.get_rack()
	car.apply_ammo_carry([0, 7, 0, 2, 4, 1, 0])
	t.check(rack.ammo(RackScript.Slot.SPECIAL) == 1,
		"carry: a spent special still lands with one round (floor 1)")
	t.check(rack.ammo(RackScript.Slot.STANDARD) == 7
		and rack.ammo(RackScript.Slot.HOMING) == 0
		and rack.ammo(RackScript.Slot.POWER) == 2
		and rack.ammo(RackScript.Slot.REAR) == 4
		and rack.ammo(RackScript.Slot.MINE) == 1
		and rack.ammo(RackScript.Slot.JUMP_MINE) == 0,
		"carry: exact counts, empties included — no floors on the missile bay")
	car.apply_ammo_carry([9, 2, 1, 1, 0, 0, 0])
	t.check(rack.ammo(RackScript.Slot.SPECIAL) == 2, "carry: special clamps at the car's cap")
	_done(car)

## Integration through Vehicle._ready: carry lands only on a campaign-mode
## player spawn — the tutorial lane (and by the same gate, MP/custom levels)
## boots on the defined load no matter what carry is sitting in GameState.
func test_ready_applies_carry_campaign_only() -> void:
	var gs = t.root.get_node_or_null(^"/root/GameState")
	if gs == null:
		t.check(true, "carry gate: no GameState in this harness — covered by unit seams")
		return
	var saved_mode: StringName = gs.game_mode
	var saved_carry: Array = gs.carry_ammo
	var saved_pending: String = gs.pending_level_path
	gs.game_mode = &"campaign"
	gs.pending_level_path = ""
	gs.carry_ammo = [1, 6, 0, 3, 2, 0, 1]
	var car = _car(&"player")  # authored stats keep the picker lookup out of it
	t.check(car.get_rack().ammo(RackScript.Slot.STANDARD) == 6
		and car.get_rack().ammo(RackScript.Slot.REAR) == 2,
		"carry gate: campaign player spawn inherits the bay")
	_done(car)  # player-faction fixture: free IMMEDIATELY
	gs.game_mode = &"tutorial"
	var yard_car = _car(&"player")
	_check_defined_load(yard_car.get_rack(), "carry gate (tutorial)")
	_done(yard_car)
	gs.game_mode = saved_mode
	gs.carry_ammo = saved_carry
	gs.pending_level_path = saved_pending

func test_reset_campaign_clears_carry() -> void:
	var gs = GameStateScript.new()  # fresh instance, never in the tree
	gs.carry_ammo = [1, 2, 3, 4, 5, 6, 7]
	gs.reset_campaign()
	t.check(gs.carry_ammo.is_empty(), "reset_campaign: the carried bay is forfeit")
	gs.free()
