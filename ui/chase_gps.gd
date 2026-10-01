extends Control
## The dashboard GPS: a scrolling north-up ribbon of the pre-rolled course
## from just behind the player to a few turns ahead — never the whole map.
## Draws the road strip (widths included, so narrows read before they arrive),
## Buzzard blips near the player, pickup markers, a next-turn arrow, and the
## horde itself: a band filling the ribbon from the dust crest's TRUE course
## position south, pulsing once the pack is on the bumper. Redraws at ~10Hz.

const BACK := 800.0     # course px shown behind the player — room for the pack
const AHEAD := 3500.0   # course px shown ahead — "a few turns"
const SAMPLE := 150.0
const BLIP_RANGE := 1500.0

const ChunkDefs := preload("res://levels/chase/chunk_defs.gd")

const BG := Color(0.05, 0.08, 0.06)
const ROAD := Color(0.22, 0.24, 0.27)
const TRAIL := Color(0.5, 0.36, 0.2)
const RIVER := Color(0.07, 0.16, 0.28)
const SPINE := Color(0.45, 0.75, 0.5, 0.7)
const PLAYER := Color(1.0, 0.85, 0.2)
const ENEMY := Color(0.85, 0.25, 0.2)
const TECH := Color(0.95, 0.65, 0.2)
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
	_draw_back_roads(course, d0, window, player_d, center_x, sy)
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
		var edriver = enemy.get_node_or_null(^"Driver")
		var erole: Variant = edriver.get("role") if edriver != null else null
		if erole == &"technical":
			draw_colored_polygon(PackedVector2Array([  # amber diamond — the truck
				ep + Vector2(0, -5), ep + Vector2(5, 0), ep + Vector2(0, 5), ep + Vector2(-5, 0),
			]), TECH)
		elif erole == &"blocker":
			draw_rect(Rect2(ep - Vector2(6, 2), Vector2(12, 4)), TECH)  # amber bar — a lane, taken
		else:
			draw_rect(Rect2(ep - Vector2(3, 3), Vector2(6, 6)), ENEMY)
	# The player chevron (fixed BACK / (BACK + AHEAD) up from the south edge).
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
	# The horde: everything south of the dust crest, drawn where it really is.
	var crest_y := clampf(size.y - (BACK - host.wall_gap()) * sy, 0.0, size.y)
	if crest_y < size.y:
		var col := WALL
		col.a = 0.7
		if host.in_danger():
			col.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.012))
		draw_rect(Rect2(0, crest_y, size.x, size.y - crest_y), col)
		draw_line(Vector2(0, crest_y), Vector2(size.x, crest_y), WALL.lightened(0.35), 2.0)

## Chunk extras the ribbon can't show on its own: a cutoff's trail (a dirt
## thread beside the road with its mouths) and the finale's river.
func _draw_back_roads(course, d0: float, window: float, player_d: float, center_x: float, sy: float) -> void:
	var first: int = course.chunk_index_at(maxf(d0, 0.0))
	var i := first
	while i < course.plan.size():
		var entry: Dictionary = course.plan[i]
		var start: float = entry["start_d"]
		if start > d0 + window:
			break
		var def: Dictionary = entry["def"]
		if def.has("cutoff"):
			var cf: Dictionary = def["cutoff"]
			var pts: Array = cf["trail"]
			var line := PackedVector2Array()
			var from_d: float = pts[0][0]
			var to_d: float = pts[pts.size() - 1][0]
			var k := int((to_d - from_d) / 120.0)
			for j in k + 1:
				var local := lerpf(from_d, to_d, float(j) / float(k))
				var world := Vector2(float(entry["entry_x"]) + ChunkDefs.cutoff_x(def, local), -(start + local))
				line.append(_panel(world, player_d, center_x, sy))
			# The long-grass shoulders as a faint band, the packed track as a
			# thin thread down its middle: the width you have to hold.
			var shoulder: float = float(cf.get("shoulder", 0.0))
			if shoulder > 0.0:
				draw_polyline(line, Color(TRAIL, 0.3), maxf((float(cf["width"]) + 2.0 * shoulder) * sy * 1.6, 3.0))
			draw_polyline(line, TRAIL, maxf(float(cf["width"]) * sy * 1.6, 1.5))
			var font := ThemeDB.fallback_font
			var mouth := line[0] + Vector2(-14.0 if float(cf["side"]) < 0.0 else 4.0, -4.0)
			draw_string(font, mouth, "TRAIL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, TRAIL.lightened(0.3))
		if def.has("river"):
			var r: Dictionary = def["river"]
			var top := _panel(Vector2(0.0, -(start + float(r["deep_to"]))), player_d, center_x, sy).y
			var bottom := _panel(Vector2(0.0, -(start + float(r["brink"]))), player_d, center_x, sy).y
			draw_rect(Rect2(0.0, top, size.x, bottom - top), RIVER)
		i += 1

func _panel(world: Vector2, player_d: float, center_x: float, sy: float) -> Vector2:
	var d := -world.y
	var y := size.y - (d - (player_d - BACK)) * sy
	var x := size.x * 0.5 + (world.x - center_x) * sy * 1.6
	return Vector2(clampf(x, 2.0, size.x - 2.0), y)
