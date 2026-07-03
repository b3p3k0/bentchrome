extends Control
## North-up radar: world axes are fixed (up = north = world -y); the player is
## a center wedge rotated to show heading, enemy blips plot at their true
## relative bearing. Scaled to fit the whole arena (RANGE px of world per radius).

const RANGE := 1500.0
const RADIUS := 110.0
const BG := Color(0.03, 0.08, 0.05)
const RIM := Color(0.25, 0.5, 0.3)
const RING := Color(0.15, 0.3, 0.2)
const PLAYER_COLOR := Color(1.0, 0.85, 0.2)
const ENEMY_COLOR := Color(0.95, 0.25, 0.2)
const DUMMY_COLOR := Color(0.5, 0.5, 0.5, 0.6)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, RADIUS + 3.0, RIM)
	draw_circle(center, RADIUS, BG)
	draw_arc(center, RADIUS * 0.5, 0.0, TAU, 48, RING, 1.0)
	draw_line(center - Vector2(RADIUS, 0), center + Vector2(RADIUS, 0), RING, 1.0)
	draw_line(center - Vector2(0, RADIUS), center + Vector2(0, RADIUS), RING, 1.0)

	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null or not is_instance_valid(player):
		return

	for e in get_tree().get_nodes_in_group(&"enemies"):
		_blip(center, e.global_position - player.global_position, 4.0, ENEMY_COLOR)
	for d in get_tree().get_nodes_in_group(&"dummies"):
		_blip(center, d.global_position - player.global_position, 3.0, DUMMY_COLOR)

	# The player: a center wedge rotated to the car's heading (heading 0 = east).
	var spin: float = player.heading + PI / 2
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -9).rotated(spin),
		center + Vector2(6, 7).rotated(spin),
		center + Vector2(-6, 7).rotated(spin),
	]), PLAYER_COLOR)

func _blip(center: Vector2, rel: Vector2, r: float, color: Color) -> void:
	var pos := rel * (RADIUS / RANGE)
	if pos.length() > RADIUS - 6.0:  # off-scale contacts pin to the rim
		pos = pos.normalized() * (RADIUS - 6.0)
	draw_circle(center + pos, r, color)
