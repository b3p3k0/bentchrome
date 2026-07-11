extends RefCounted
## Vehicles.local(): presentation's "whose screen is this?" — prefers the
## marked local_player, falls back to the "player" faction group so unmarked
## scenes (dev boots, chase mode) keep working. Plain Node2D fixtures; no
## Vehicle scenes needed to test group plumbing.

const VehiclesHelper := preload("res://vehicles/vehicles.gd")

var t

func _init(runner) -> void:
	t = runner

func test_local_resolution() -> void:
	var faction_car := Node2D.new()
	faction_car.add_to_group(&"player")
	t.root.add_child(faction_car)

	t.check(VehiclesHelper.local(t.root.get_tree()) == faction_car,
		"local: unmarked scene falls back to the player faction")

	var my_car := Node2D.new()
	t.root.add_child(my_car)
	VehiclesHelper.mark_local(my_car)
	t.check(my_car.is_in_group(&"local_player"), "local: mark adds the group")
	t.check(VehiclesHelper.local(t.root.get_tree()) == my_car,
		"local: the marked car beats the faction fallback")

	VehiclesHelper.mark_local(my_car)  # idempotent
	t.check(VehiclesHelper.local(t.root.get_tree()) == my_car,
		"local: double-mark changes nothing")

	VehiclesHelper.unmark_local(my_car)
	t.check(VehiclesHelper.local(t.root.get_tree()) == faction_car,
		"local: unmark restores the fallback")

	t.root.remove_child(faction_car)
	faction_car.free()
	t.root.remove_child(my_car)
	my_car.free()
	t.check(VehiclesHelper.local(t.root.get_tree()) == null,
		"local: empty tree resolves to null")