extends Control
## The dashboard GPS: a scrolling north-up ribbon of the pre-rolled course
## from just behind the player to a few turns ahead — never the whole map.
## Draws the road strip (widths included, so narrows read before they arrive),
## Buzzard blips near the player, pickup markers, a next-turn arrow, and a
## wall-proximity band rising from the south edge. Redraws at ~10Hz.

const BACK := 500.0     # course px shown behind the player
const AHEAD := 3500.0   # course px shown ahead — "a few turns"
const SAMPLE := 150.0
const BLIP_RANGE := 1500.0

const BG := Color(0.05, 0.08, 0.06)
const ROAD := Color(0.22, 0.24, 0.27)
const SPINE := Color(0.45, 0.75, 0.5, 0.7)
const PLAYER := Color(1.0, 0.85, 0.2)
const ENEMY := Color(0.85, 0.25, 0.2)
const PICKUP := Color(0.3, 0.85, 0.4)
const WALL := Color(0.8, 0.3, 0.15)

var _redraw_t := 0.0

func _process(delta: float) -> void:
	_redraw_t += delta
	if _redraw_t >= 0.1:
		_redraw_t = 0.0
		queue_redraw()

func _host() -> Node:
	return get_tree().get_first_node_in_group(&"chase_host")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var host := _host()
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if host == null or host.course == null or player == null:
		return
	var course = host.course
	var player_d: float = -player.global_position.y
	var d0 := player_d - BACK
	var window := BACK + AHEAD
	var sy := size.y / window                      # course px -> panel px
	var center_x: float = course.sample(player_d)["x"]
	# Road ribbon: left edge north, right edge back south, one filled strip.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var spine := PackedVector2Array()
	var steps := int(window / SAMPLE)
	for i in steps + 1:
		var d := d0 + window * float(i) / float(steps)
		var s: Dictionary = course.sample(d)
		var px := _panel(Vector2(s["x"], -d), player_d, center_x, sy)
		var half: float = s["half_w"] * sy * 1.6   # widen the read a touch
		left.append(px + Vector2(-half, 0))
		right.append(px + Vector2(half, 0))
		spine.append(px)
	var strip := PackedVector2Array()
	strip.append_array(left)
	for i in range(right.size() - 1, -1, -1):
		strip.append(right[i])
	draw_colored_polygon(strip, ROAD)
	draw_polyline(spine, SPINE, 1.5)
	# Pickup markers in the window.
	for pickup in get_tree().get_nodes_in_group(&"pickups"):
		if not (pickup is Node2D) or not pickup.visible:
			continue
		var pd: float = -pickup.global_position.y
		if pd < d0 or pd > d0 + window:
			continue
		var pp := _panel(pickup.global_position, player_d, center_x, sy)
		draw_rect(Rect2(pp - Vector2(2.5, 2.5), Vector2(5, 5)), PICKUP)
	# Buzzard blips near the player.
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if not (enemy is Node2D):
			continue
		if enemy.global_position.distance_to(player.global_position) > BLIP_RANGE:
			continue
		var ep := _panel(enemy.global_position, player_d, center_x, sy)
		draw_rect(Rect2(ep - Vector2(3, 3), Vector2(6, 6)), ENEMY)
	# The player chevron (fixed 87.5% down by construction).
	var me := _panel(player.global_position, player_d, center_x, sy)
	draw_colored_polygon(PackedVector2Array([
		me + Vector2(0, -7), me + Vector2(5, 5), me + Vector2(-5, 5),
	]), PLAYER)
	# Next-turn arrow across the top.
	var turn: Dictionary = course.next_turn_after(player_d + 100.0)
	if turn["dist"] < AHEAD:
		var dir: float = turn["dir"]
		var cx := size.x * 0.5
		draw_line(Vector2(cx - dir * 14.0, 18.0), Vector2(cx + dir * 10.0, 18.0), PLAYER, 4.0)
		var tip := Vector2(cx + dir * 20.0, 18.0)
		draw_colored_polygon(PackedVector2Array([
			tip, tip - Vector2(dir * 10.0, 7.0), tip - Vector2(dir * 10.0, -7.0),
		]), PLAYER)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(cx - 32.0, 42.0),
			"TURN %dm" % int(turn["dist"] * 0.1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PLAYER)
	# Wall pressure band rising from the south edge.
	var gap: float = host.wall_gap()
	var max_gap: float = 2400.0
	var press := clampf(1.0 - gap / max_gap, 0.0, 1.0)
	if press > 0.02:
		var h := 8.0 + press * 52.0
		var col := WALL
		if gap < 600.0:
			col.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.012))
		draw_rect(Rect2(0, size.y - h, size.x, h), col)

func _panel(world: Vector2, player_d: float, center_x: float, sy: float) -> Vector2:
	var d := -world.y
	var y := size.y - (d - (player_d - BACK)) * sy
	var x := size.x * 0.5 + (world.x - center_x) * sy * 1.6
	return Vector2(clampf(x, 2.0, size.x - 2.0), y)
