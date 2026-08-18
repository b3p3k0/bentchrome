extends RefCounted
## Lethal-hazard awareness: the geometry service (game/hazards.gd) that turns
## the &"lethal_hazards" group into queryable world rects, and the EnemyDriver
## behaviors built on it. The zones themselves are unraycastable (layer 0) —
## these tests lock the substitute senses that keep AI out of the Potomac.

const Hazards := preload("res://game/hazards.gd")
const WaterScene := preload("res://environment/deep_water_zone.tscn")
const PitScene := preload("res://environment/pit_zone.tscn")

var t

func _init(runner) -> void:
	t = runner

func _water(container: Node2D, pos: Vector2, size: Vector2) -> Node:
	var zone = WaterScene.instantiate()
	zone.size = size
	zone.position = pos
	container.add_child(zone)
	return zone

## Capital-shaped river: three tall rects, gapped where the bridges live.
## Gap bands: y -160..160 (Memorial) and y 960..1280 (14th St).
func _river(container: Node2D) -> void:
	_water(container, Vector2(0, -1040), Vector2(384, 1760))
	_water(container, Vector2(0, 560), Vector2(384, 800))
	_water(container, Vector2(0, 1600), Vector2(384, 640))

func test_registry_rects_and_cache() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_water(container, Vector2(100, 200), Vector2(300, 400))
	var pit = PitScene.instantiate()
	pit.size = Vector2(256, 128)
	pit.position = Vector2(-500, 0)
	container.add_child(pit)
	var rects := Hazards.rects(t)
	t.check(rects.size() == 2, "hazards: both zone flavors join the registry")
	var found_water := false
	for r in rects:
		if r.is_equal_approx(Rect2(-50, 0, 300, 400)):
			found_water = true
	t.check(found_water, "hazards: rect matches painted center+size extents")
	# Membership change invalidates the cache without waiting for a new frame.
	_water(container, Vector2(900, 900), Vector2(64, 64))
	t.check(Hazards.rects(t).size() == 3, "hazards: cache rebuilds on group count change")
	t.root.remove_child(container)
	container.free()
	t.check(Hazards.rects(t).is_empty(), "hazards: empty tree yields empty registry")

func test_segment_geometry() -> void:
	var rect := Rect2(-100, -100, 200, 200)
	t.check(Hazards.segment_entry_t(rect, Vector2(-300, 0), Vector2(300, 0)) < 1.0,
		"hazards: crossing segment reports an entry")
	var entry_t := Hazards.segment_entry_t(rect, Vector2(-300, 0), Vector2(300, 0))
	t.check(absf(entry_t - 0.3333) < 0.01, "hazards: entry fraction lands on the near face")
	t.check(Hazards.segment_entry_t(rect, Vector2(-300, 200), Vector2(300, 200)) > 1.0,
		"hazards: parallel segment outside the slab is clear")
	t.check(Hazards.segment_entry_t(rect, Vector2(0, 0), Vector2(300, 0)) == 0.0,
		"hazards: starting inside reports entry 0")
	t.check(Hazards.segment_entry_t(rect, Vector2(-300, 130), Vector2(300, 130), 50.0) < 1.0,
		"hazards: margin grows the blocking slab")
	t.check(Hazards.segment_entry_t(rect, Vector2(-300, 0), Vector2(-150, 0)) > 1.0,
		"hazards: segment ending short of the rect is clear")

func test_segment_hit_first_blocker() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_water(container, Vector2(400, 0), Vector2(200, 200))   # far
	_water(container, Vector2(-400, 0), Vector2(200, 200))  # near for a west start
	var rects := Hazards.rects(t)
	var idx := Hazards.segment_hit(t, Vector2(-900, 0), Vector2(900, 0))
	t.check(idx >= 0 and rects[idx].get_center().x < 0.0,
		"hazards: segment_hit returns the FIRST rect along the travel")
	t.check(Hazards.segment_blocked(t, Vector2(-900, 0), Vector2(900, 0)),
		"hazards: blocked convenience agrees")
	t.check(not Hazards.segment_blocked(t, Vector2(-900, 300), Vector2(900, 300)),
		"hazards: clear lane between rects stays clear")
	t.check(Hazards.point_inside(t, Vector2(-400, 90)),
		"hazards: point_inside sees the interior")
	t.check(not Hazards.point_inside(t, Vector2(-400, 110)),
		"hazards: point just past the rim is outside unmargined")
	t.check(Hazards.point_inside(t, Vector2(-400, 110), 20.0),
		"hazards: margin extends point_inside")
	t.root.remove_child(container)
	container.free()

func test_detour_candidates_find_bridge_gaps() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_river(container)
	# East-bank car hunting a west-bank target straight through the middle rect.
	var from := Vector2(600, 560)
	var to := Vector2(-600, 560)
	var cands := Hazards.detour_candidates(t, from, to)
	t.check(cands.size() == 2, "detour: middle river rect offers both ends")
	for c in cands:
		var p: Vector2 = c["point"]
		var in_memorial: bool = p.y > -160.0 and p.y < 160.0
		var in_14th: bool = p.y > 960.0 and p.y < 1280.0
		t.check(in_memorial or in_14th,
			"detour: candidate lands inside a bridge gap band (y=%.0f)" % p.y)
		t.check((c["normal"] as Vector2).is_equal_approx(Vector2(1, 0)),
			"detour: normal points back to the approach side")
	t.check(Hazards.detour_candidates(t, Vector2(600, 0), Vector2(-600, 0)).is_empty(),
		"detour: the bridge lane itself is clear — no candidates offered")
	t.root.remove_child(container)
	container.free()

func test_detour_orders_clear_approach_first() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_water(container, Vector2(0, -600), Vector2(300, 800))  # y -1000..-200
	# Near the rect's north end: rounding north is clear, rounding south drags
	# the whole flank. Ordering must put the clear approach first.
	var cands := Hazards.detour_candidates(t, Vector2(600, -980), Vector2(-600, -980))
	t.check(cands.size() == 2, "detour: lone rect offers both ends")
	t.check(bool(cands[0]["clear_from"]) and not bool(cands[1]["clear_from"]),
		"detour: clear-approach candidate sorts first")
	t.check((cands[0]["point"] as Vector2).y < -1000.0,
		"detour: the clear candidate rounds the near end")
	t.root.remove_child(container)
	container.free()

func test_detour_filters_chained_neighbor_end() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	# Two rects nearly abutting: the shared end is NOT a gap and must drop.
	_water(container, Vector2(0, -600), Vector2(300, 800))  # y -1000..-200
	_water(container, Vector2(0, 300), Vector2(300, 800))   # y -100..700
	var cands := Hazards.detour_candidates(t, Vector2(600, -600), Vector2(-600, -600))
	t.check(cands.size() == 1, "detour: the end poking into the neighbor is filtered")
	t.check((cands[0]["point"] as Vector2).y < -1000.0,
		"detour: the surviving candidate rounds the open end")
	t.root.remove_child(container)
	container.free()
