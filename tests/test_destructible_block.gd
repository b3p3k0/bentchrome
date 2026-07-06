extends RefCounted
## Destructible block: block-layer semantics, exported size applied to visuals
## and collision, damage tint, and death -> freed. Driven by tests/run_tests.gd.

const BlockScene := preload("res://environment/destructible_block.tscn")

var t

func _init(runner) -> void:
	t = runner

func test_block_layer_and_size() -> void:
	var block = BlockScene.instantiate()
	block.size = Vector2(192, 64)
	t.root.add_child(block)
	t.check(block.collision_layer == 4, "block sits on obstacle layer")
	t.check(block.collision_mask == 0, "block collides into nothing")
	var shape: RectangleShape2D = block.get_node("Col").shape
	t.check(shape.size == Vector2(192, 64), "exported size reaches collision shape")
	var vis: Polygon2D = block.get_node("Vis")
	t.check(vis.polygon[2] == Vector2(96, 32), "exported size reaches visual polygon")
	t.root.remove_child(block)
	block.free()

func test_block_hp_override_and_tint() -> void:
	var block = BlockScene.instantiate()
	block.max_hp = 40.0
	t.root.add_child(block)
	var health = block.get_node("Health")
	t.check_approx(health.hp, 40.0, "hp follows exported max_hp despite child-first ready")
	var base: Color = block.get_node("Vis").color
	health.take_damage(20.0)
	t.check_approx(health.hp, 20.0, "damage lands")
	t.check(block.get_node("Vis").color != base, "damage tints toward rubble")
	t.root.remove_child(block)
	block.free()

func test_block_dies_and_frees() -> void:
	var block = BlockScene.instantiate()
	t.root.add_child(block)
	block.get_node("Health").take_damage(999.0)
	t.check(block.is_queued_for_deletion(), "lethal damage frees the block")
	t.root.remove_child(block)
	block.free()
