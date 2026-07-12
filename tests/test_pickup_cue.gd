extends RefCounted
## Pickup forgiveness and its shared visual language: all collectible families
## expose the same 36px surface and a cosmetic-only pink breathing ring.

const AmmoScene := preload("res://environment/ammo_pickup.tscn")
const HealScene := preload("res://environment/heal_pickup.tscn")
const BoostScene := preload("res://environment/boost_pickup.tscn")
const VehicleScene := preload("res://vehicles/vehicle.tscn")

var t

class PickupCar extends CharacterBody2D:
	var rack: WeaponRack
	func get_rack() -> WeaponRack:
		return rack

func _init(runner) -> void:
	t = runner

func test_all_pickup_families_share_surface_and_cue() -> void:
	for scene in [AmmoScene, HealScene, BoostScene]:
		var pickup = scene.instantiate()
		t.root.add_child(pickup)
		var col := pickup.get_node(^"Col") as CollisionShape2D
		var cue := pickup.get_node(^"PickupCue") as PickupCue
		t.check_approx((col.shape as CircleShape2D).radius, 36.0,
			"pickup cue: collection surface is 36px")
		t.check(cue != null and is_equal_approx(cue.radius, 36.0),
			"pickup cue: ring follows the shared collection surface")
		t.check(cue.get_child_count() == 0,
			"pickup cue: procedural ring carries no collision children")
		t.root.remove_child(pickup)
		pickup.free()

func test_pink_ring_pulses_inside_small_bounds() -> void:
	var cue := PickupCue.new()
	t.check(cue.color == PickupCue.DEFAULT_COLOR and cue.color.r > cue.color.b,
		"pickup cue: shared ink is translucent hot pink")
	var radii: Array[float] = []
	var alphas: Array[float] = []
	for i in 8:
		cue._process(TAU / PickupCue.PULSE_SPEED / 8.0)
		radii.append(cue.current_radius())
		alphas.append(cue.current_alpha())
	t.check(radii.min() >= 34.5 and radii.max() <= 37.5,
		"pickup cue: breathing radius stays subtle around the surface")
	t.check(alphas.min() >= 0.35 and alphas.max() <= 0.5,
		"pickup cue: breathing alpha remains soft and translucent")
	cue.free()

func test_near_pass_collects_and_respawn_restores_whole_cue() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var pickup = AmmoScene.instantiate()
	pickup.respawn_seconds = 0.2
	container.add_child(pickup)
	var car := PickupCar.new()
	car.collision_layer = 1
	car.position = Vector2(30, 0)  # 1px body: beyond old 26px, inside new 36px
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 1.0
	col.shape = shape
	car.add_child(col)
	car.rack = WeaponRack.new()
	car.add_child(car.rack)
	car.rack.configure(WeaponDef.new(), 1, 10.0)
	container.add_child(car)
	for i in 4:
		await t.physics_frame
	t.check(not pickup.visible and not pickup.monitoring,
		"pickup cue: forgiving near pass collects beyond the old surface")
	t.check(not pickup.get_node(^"PickupCue").is_visible_in_tree(),
		"pickup cue: ring hides with a collected respawning crate")
	car.position = Vector2(100, 0)  # clear the respawn surface; don't auto-collect again
	await t.create_timer(0.25).timeout
	t.check(pickup.visible and pickup.monitoring
		and pickup.get_node(^"PickupCue").is_visible_in_tree(),
		"pickup cue: respawn restores identifier and ring together")
	t.root.remove_child(container)
	container.free()

func test_full_ammo_still_banks_the_larger_pickup() -> void:
	var pickup = AmmoScene.instantiate()
	t.root.add_child(pickup)
	var car = VehicleScene.instantiate()
	t.root.add_child(car)
	var rack: WeaponRack = car.get_rack()
	rack.add_ammo(WeaponRack.Slot.STANDARD, 99)
	pickup._on_body_entered(car)
	t.check(pickup.visible and pickup.monitoring,
		"pickup cue: larger surface does not consume a crate when its slot is full")
	t.root.remove_child(car)
	car.free()
	t.root.remove_child(pickup)
	pickup.free()
