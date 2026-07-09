extends RefCounted
## Hazard curbs: AI-only rails on the hazard_edge layer (64). A vehicle drives
## clean through one; the AI's feeler rays see it; a line-of-sight ray never
## does (a curb must not block shots). Locks the FEELER/LOS mask split.

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const CurbScene := preload("res://environment/hazard_curb.tscn")
const DriverScript := preload("res://vehicles/drivers/enemy_driver.gd")

var t

func _init(runner) -> void:
	t = runner

func test_masks_split_correctly() -> void:
	t.check(DriverScript.LOS_MASK == 6, "curb: LoS mask stays the classic walls+blocks 6")
	t.check(DriverScript.FEELER_MASK == (2 | 4 | 64), "curb: feelers add the hazard bit")

func test_cars_pass_rays_see() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var curb = CurbScene.instantiate()
	curb.size = Vector2(64, 240)
	container.add_child(curb)  # (0,0)
	var car = VehicleScene.instantiate()
	car.position = Vector2(-90, 0)
	container.add_child(car)
	await t.physics_frame
	await t.physics_frame
	t.check(not car.test_move(car.global_transform, Vector2(180, 0)),
		"curb: a vehicle drives clean through")
	var space: PhysicsDirectSpaceState2D = car.get_world_2d().direct_space_state
	var feeler := PhysicsRayQueryParameters2D.create(
		Vector2(-200, 0), Vector2(200, 0), DriverScript.FEELER_MASK)
	feeler.exclude = [car.get_rid()]
	t.check(not space.intersect_ray(feeler).is_empty(), "curb: feeler rays see the rail")
	var los := PhysicsRayQueryParameters2D.create(
		Vector2(-200, 0), Vector2(200, 0), DriverScript.LOS_MASK)
	los.exclude = [car.get_rid()]
	t.check(space.intersect_ray(los).is_empty(), "curb: LoS rays pass through")
	t.root.remove_child(container)
	container.free()
