extends Area2D
## A dropped mine. Arms after a short delay (dim until live); the dropper gets
## a grace window so laying mines mid-chase doesn't pop your own. Grounded
## vehicles that roll over it trigger it — airborne cars sail over.
##   jump = false: damage + a random course deviation (±5-45°).
##   jump = true:  no damage — pops the car airborne and re-vectors it hard
##                 (±45-80°). Disruption, not a catapult.

const Floors := preload("res://game/floors.gd")  # dependency-free floor gate

const ARM_DELAY := 1.0
const DROPPER_GRACE := 2.0
const LAND_DEV_MIN := 5.0
const LAND_DEV_MAX := 45.0
const JUMP_DEV_MIN := 45.0
const JUMP_DEV_MAX := 80.0
const JUMP_VZ := 450.0

@export var jump := false

var damage := 20.0
var dropper: Node = null
var floor_index := -1  # stamped at drop; the mine only arms for its own terrace

var _age := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 26.0
	col.shape = shape
	add_child(col)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_age += delta
	if _age < ARM_DELAY:
		return
	queue_redraw()
	for body in get_overlapping_bodies():
		if body == dropper and _age < DROPPER_GRACE:
			continue
		if body.get("height") != 0.0:  # airborne cars sail over
			continue
		if not Floors.same_floor(self, body):
			continue  # a dock mine doesn't hear roof wheels
		if not (body is CharacterBody2D):
			continue
		_trigger(body)
		return

func _trigger(body: CharacterBody2D) -> void:
	var Combat := preload("res://game/combat.gd")
	if body.is_in_group(&"player"):
		var audio := get_node_or_null(^"/root/AudioDirector")
		if audio:
			audio.play(&"hit_weapon")
	# Launch-immune rigs (Goliath) just crush the mine: no deviation, no pop —
	# a land mine still bills its damage, a jump mine is consumed for nothing.
	var immune: bool = body.get("launch_immune") == true
	if not immune:
		var dev := deg_to_rad(randf_range(LAND_DEV_MIN, LAND_DEV_MAX))
		if jump:
			dev = deg_to_rad(randf_range(JUMP_DEV_MIN, JUMP_DEV_MAX))
		if randf() < 0.5:
			dev = -dev
		body.velocity = body.velocity.rotated(dev)
		if "heading" in body:
			body.heading += dev
	if jump:
		if not immune and body.has_method(&"pop_airborne"):
			body.pop_airborne(JUMP_VZ)
	elif damage > 0.0:
		# The soft underbelly: some rigs (Goliath) trade everything for top
		# armor and pay for it from below — mine_weakness scales the bill.
		var soft: Variant = body.get("mine_weakness")
		var belly: float = float(soft) if soft is float else 1.0
		for child in body.get_children():
			if child is Health:
				if "last_attacker" in body and is_instance_valid(dropper) and dropper is Node2D:
					body.last_attacker = dropper
				child.take_damage(damage * belly * Combat.scale(dropper, body))
				break
	var scene := get_tree().current_scene
	if scene:
		var boom := preload("res://environment/explosion.tscn").instantiate()
		boom.global_position = global_position
		boom.size_scale = 0.5 if not jump else 0.35
		boom.tint = Color(0.85, 0.4, 0.15) if not jump else Color(0.4, 0.75, 0.95)
		scene.add_child(boom)
	queue_free()

func _draw() -> void:
	var live := _age >= ARM_DELAY
	var base := Color(0.55, 0.2, 0.12) if not jump else Color(0.2, 0.5, 0.65)
	var dot := Color(0.95, 0.3, 0.2) if not jump else Color(0.45, 0.85, 1.0)
	if not live:
		base.a = 0.45
		dot.a = 0.45
	draw_circle(Vector2.ZERO, 14.0, base)
	if jump:
		# chevron: this one sends you flying
		draw_colored_polygon(PackedVector2Array([
			Vector2(-6, 4), Vector2(0, -7), Vector2(6, 4), Vector2(0, 0),
		]), dot)
	else:
		draw_circle(Vector2.ZERO, 5.0, dot)
