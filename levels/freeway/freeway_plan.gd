extends RefCounted
## Signed-off Freeway Firefight expansion layout. Dependency-free on purpose:
## no class_name, nodes, drawing, or preloads. Consumers preload by path.

const ARENA_RECT := Rect2(-1088, -2688, 4096, 5376)

const FLOOR_ZONES := {
	&"FZPlate": {"floor": 2, "rect": Rect2(-1088, -2688, 2176, 5376)},
	&"FZLowland": {"floor": 1, "rect": Rect2(1088, -2688, 1920, 5376)},
	&"FZDeck": {"floor": 3, "rect": Rect2(-1088, -928, 2176, 320)},
	&"FZLanding": {"floor": 2, "rect": Rect2(1472, -928, 256, 320)},
	&"FZShelfN": {"floor": 2, "rect": Rect2(1088, -2304, 256, 512)},
	&"FZShelfS": {"floor": 2, "rect": Rect2(1088, 256, 256, 512)},
}

const RAMPS := {
	&"RampW": {
		"low": 2, "high": 3, "rect": Rect2(-1088, -608, 256, 384),
		"toward": &"north",
	},
	&"RampA": {
		"low": 2, "high": 3, "rect": Rect2(1088, -928, 384, 320),
		"toward": &"west",
	},
	&"RampB": {
		"low": 1, "high": 2, "rect": Rect2(1728, -928, 384, 320),
		"toward": &"west",
	},
	&"RampN": {
		"low": 1, "high": 2, "rect": Rect2(1088, -1792, 256, 512),
		"toward": &"north",
	},
	&"RampS": {
		"low": 1, "high": 2, "rect": Rect2(1088, -256, 256, 512),
		"toward": &"south",
	},
}

const WALLS := {
	&"RetainE_1": {"layer": 12, "rect": Rect2(1088, -2688, 24, 384)},
	&"RetainE_2": {"layer": 12, "rect": Rect2(1088, -1792, 24, 864)},
	&"RetainE_3": {"layer": 12, "rect": Rect2(1088, -608, 24, 864)},
	&"RetainE_4": {"layer": 12, "rect": Rect2(1088, 768, 24, 1920)},
	&"ShelfN_E": {"layer": 12, "rect": Rect2(1344, -2304, 24, 512)},
	&"ShelfN_N": {"layer": 12, "rect": Rect2(1088, -2328, 280, 24)},
	&"ShelfS_E": {"layer": 12, "rect": Rect2(1344, 256, 24, 512)},
	&"ShelfS_S": {"layer": 12, "rect": Rect2(1088, 768, 280, 24)},
	&"LandingN": {"layer": 12, "rect": Rect2(1472, -952, 256, 24)},
	&"LandingS": {"layer": 12, "rect": Rect2(1472, -608, 256, 24)},
	&"RampAN": {"layer": 12, "rect": Rect2(1088, -952, 384, 24)},
	&"RampAS": {"layer": 12, "rect": Rect2(1088, -608, 384, 24)},
	&"RampBN": {"layer": 12, "rect": Rect2(1728, -952, 384, 24)},
	&"RampBS": {"layer": 12, "rect": Rect2(1728, -608, 384, 24)},
	&"DeckEastStop": {"layer": 20, "rect": Rect2(1064, -928, 24, 320)},
}

const COUNTRY_ROAD := Rect2(2112, -896, 896, 256)

static func rect_of(table: Dictionary, name: StringName) -> Rect2:
	return table[name]["rect"]

static func floor_at(point: Vector2) -> int:
	var best := -1
	for zone: Dictionary in FLOOR_ZONES.values():
		if (zone["rect"] as Rect2).has_point(point):
			best = maxi(best, int(zone["floor"]))
	return best

static func plate_east_edge_covered(y: float) -> bool:
	var plate := rect_of(FLOOR_ZONES, &"FZPlate")
	var point := Vector2(plate.end.x, y)
	for wall: Dictionary in WALLS.values():
		if _has_point_inclusive(wall["rect"], point):
			return true
	for ramp: Dictionary in RAMPS.values():
		if _has_point_inclusive(ramp["rect"], point):
			return true
	for shelf_name: StringName in [&"FZShelfN", &"FZShelfS"]:
		if _has_point_inclusive(rect_of(FLOOR_ZONES, shelf_name), point):
			return true
	return false

static func _has_point_inclusive(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x \
		and point.y >= rect.position.y and point.y <= rect.end.y
