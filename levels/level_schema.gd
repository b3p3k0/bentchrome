class_name LevelSchema
extends RefCounted
## Single source of truth for the custom-level JSON format (v1): keys, defaults,
## limits, parse/serialize, and validation. The editor and LevelLoader go through
## this class — nothing else touches raw level JSON keys. Creator-facing spec:
## docs/level_format.md. Unknown top-level keys are ignored with a warning
## (forward-compat); unknown entity kinds/types are hard validation errors.

const FORMAT := "bentchrome-level"
const VERSION := 1
const GRID := 128

const MIN_SIDE := 1280  # roughly one screen at gameplay zoom
const MAX_SIDE := 4864  # keeps radar rim-pinning no worse than the shipped arena
const WALL_THICKNESS := 40.0  # loader synthesizes walls this thick just inside bounds
const ENTITY_MARGIN := 64.0  # point entities keep this far from the wall's inner face
const SPAWN_MARGIN := 128.0  # vehicles need extra clearance
const SPAWN_SEPARATION := 192.0

const TERRAIN_TYPES := ["dirt", "grass", "ice", "snow", "water"]  # road is the unpainted floor
const PICKUP_KINDS := ["standard", "homing", "power", "mine", "jump"]

const BLOCK_SIDE_MIN := 64.0
const BLOCK_SIDE_MAX := 1024.0
const AMOUNT_MIN := 1
const AMOUNT_MAX := 9
const RESPAWN_MIN := 1.0
const RESPAWN_MAX := 120.0
const HP_MIN := 1.0
const HP_MAX := 999.0

# Optional per-entry fields filled in by parse() when a file omits them.
const _ENTRY_DEFAULTS := {
	"enemy_spawns": {},
	"blocks": {},
	"pickups": {"kind": "standard", "amount": 2.0, "respawn_seconds": 20.0},
	"dummies": {"max_hp": 60.0},
	"terrain": {},
}


static func make_empty(width: int = 2944, height: int = 2816) -> Dictionary:
	# Key order here is the canonical serialization order.
	return {
		"format": FORMAT,
		"version": VERSION,
		"name": "Untitled",
		"author": "",
		"description": "",
		"grid": GRID,
		"bounds": {"width": float(width), "height": float(height)},
		"player_spawn": {"pos": [0.0, 0.0], "heading_deg": 0.0},
		"enemy_spawns": [],
		"blocks": [],
		"pickups": [],
		"dummies": [],
		"terrain": [],
	}


## Parses level JSON text. Returns {} for malformed JSON / non-object roots.
## Missing optional fields get defaults; present values pass through untouched
## (even wrong-typed ones) so validate() can report them to the creator.
static func parse(json_text: String) -> Dictionary:
	# Instance parse() reports failures via return code instead of printing an
	# engine ERROR — malformed fan files are expected input, not engine faults.
	var json := JSON.new()
	if json.parse(json_text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = json.data
	var level := make_empty()
	for key in data.keys():
		if not level.has(key):
			push_warning("LevelSchema: ignoring unknown key '%s'" % key)
	# Identity fields never default — an omission must fail validation.
	level.format = str(data.get("format", ""))
	level.version = int(data.version) if _is_num(data.get("version")) else 0
	if not data.has("bounds"):
		level.bounds = {}
	elif typeof(data.bounds) == TYPE_DICTIONARY \
			and _is_num(data.bounds.get("width")) and _is_num(data.bounds.get("height")):
		level.bounds = {"width": float(data.bounds.width), "height": float(data.bounds.height)}
	else:
		level.bounds = data.bounds
	if data.has("grid"):
		level.grid = int(data.grid) if _is_num(data.grid) else data.grid
	for key in ["name", "author", "description"]:
		if data.has(key):
			level[key] = str(data[key])
	if data.has("player_spawn"):
		level.player_spawn = data.player_spawn
		if typeof(level.player_spawn) == TYPE_DICTIONARY and not level.player_spawn.has("heading_deg"):
			level.player_spawn.heading_deg = 0.0
	for key in _ENTRY_DEFAULTS:
		if not data.has(key):
			continue
		level[key] = data[key]
		if typeof(level[key]) != TYPE_ARRAY:
			continue
		for entry in level[key]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			for dk in _ENTRY_DEFAULTS[key]:
				if not entry.has(dk):
					entry[dk] = _ENTRY_DEFAULTS[key][dk]
	return level


static func serialize(level: Dictionary) -> String:
	var ordered := {}
	for key in make_empty():
		if level.has(key):
			ordered[key] = level[key]
	return JSON.stringify(ordered, "\t") + "\n"


## Returns human-readable errors, empty when the level is playable.
## Only a level that validates clean may reach the loader or the editor canvas.
static func validate(level: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(level.get("format", "")) != FORMAT:
		errors.append('format: must be "%s"' % FORMAT)
	if not _is_num(level.get("version")) or int(level.get("version")) != VERSION:
		errors.append("version: must be %d" % VERSION)
	if not _is_num(level.get("grid")) or int(level.get("grid")) != GRID:
		errors.append("grid: must be %d" % GRID)

	var half := Vector2.ZERO
	var bounds_ok := false
	var b: Variant = level.get("bounds")
	if typeof(b) != TYPE_DICTIONARY or not _is_num(b.get("width")) or not _is_num(b.get("height")):
		errors.append("bounds: need numeric width and height")
	else:
		bounds_ok = true
		for side in ["width", "height"]:
			var v := float(b[side])
			if v != floorf(v) or int(v) % GRID != 0:
				errors.append("bounds: %s must be a multiple of %d" % [side, GRID])
			if v < MIN_SIDE or v > MAX_SIDE:
				errors.append("bounds: %s must be between %d and %d" % [side, MIN_SIDE, MAX_SIDE])
		half = Vector2(float(b.width), float(b.height)) * 0.5

	var spawn_points := []  # [{label, pos}] for separation + block-overlap checks
	var ps: Variant = level.get("player_spawn")
	var ps_pos: Variant = _pos_of(ps)
	if ps_pos == null:
		errors.append("player_spawn: need pos [x, y]")
	else:
		if not _is_num(ps.get("heading_deg", 0.0)):
			errors.append("player_spawn: heading_deg must be a number")
		if bounds_ok and not _inside(ps_pos, half, WALL_THICKNESS + SPAWN_MARGIN):
			errors.append("player_spawn: outside the playable area")
		spawn_points.append({"label": "player_spawn", "pos": ps_pos})

	var enemies: Variant = level.get("enemy_spawns")
	if typeof(enemies) != TYPE_ARRAY:
		errors.append("enemy_spawns: must be a list")
	else:
		if enemies.size() < 1 or enemies.size() > 4:
			errors.append("enemy_spawns: need 1-4 spawn points (got %d)" % enemies.size())
		for i in enemies.size():
			var pos: Variant = _pos_of(enemies[i])
			if pos == null:
				errors.append("enemy_spawns[%d]: need pos [x, y]" % i)
				continue
			if bounds_ok and not _inside(pos, half, WALL_THICKNESS + SPAWN_MARGIN):
				errors.append("enemy_spawns[%d]: outside the playable area" % i)
			spawn_points.append({"label": "enemy_spawns[%d]" % i, "pos": pos})

	var block_rects: Array[Rect2] = []
	var blocks: Variant = level.get("blocks")
	if typeof(blocks) != TYPE_ARRAY:
		errors.append("blocks: must be a list")
	else:
		for i in blocks.size():
			var pos: Variant = _pos_of(blocks[i])
			var size: Variant = _pair_of(blocks[i], "size")
			if pos == null or size == null:
				errors.append("blocks[%d]: need pos [x, y] and size [w, h]" % i)
				continue
			if size.x < BLOCK_SIDE_MIN or size.x > BLOCK_SIDE_MAX \
					or size.y < BLOCK_SIDE_MIN or size.y > BLOCK_SIDE_MAX:
				errors.append("blocks[%d]: size must be %d-%d per side" % [i, int(BLOCK_SIDE_MIN), int(BLOCK_SIDE_MAX)])
			var rect := Rect2(pos - size * 0.5, size)
			if bounds_ok and not _rect_inside(rect, half, WALL_THICKNESS):
				errors.append("blocks[%d]: must fit inside the walls" % i)
			block_rects.append(rect)

	var pickups: Variant = level.get("pickups")
	if typeof(pickups) != TYPE_ARRAY:
		errors.append("pickups: must be a list")
	else:
		for i in pickups.size():
			var where := "pickups[%d]" % i
			var pos: Variant = _pos_of(pickups[i])
			if pos == null:
				errors.append(where + ": need pos [x, y]")
				continue
			if bounds_ok and not _inside(pos, half, WALL_THICKNESS + ENTITY_MARGIN):
				errors.append(where + ": outside the playable area")
			var e: Dictionary = pickups[i]
			if str(e.get("kind", "")) not in PICKUP_KINDS:
				errors.append(where + ": kind must be one of %s" % [PICKUP_KINDS])
			if not _is_whole_in(e.get("amount"), AMOUNT_MIN, AMOUNT_MAX):
				errors.append(where + ": amount must be a whole number %d-%d" % [AMOUNT_MIN, AMOUNT_MAX])
			if not _is_num_in(e.get("respawn_seconds"), RESPAWN_MIN, RESPAWN_MAX):
				errors.append(where + ": respawn_seconds must be %d-%d" % [int(RESPAWN_MIN), int(RESPAWN_MAX)])

	var dummies: Variant = level.get("dummies")
	if typeof(dummies) != TYPE_ARRAY:
		errors.append("dummies: must be a list")
	else:
		for i in dummies.size():
			var where := "dummies[%d]" % i
			var pos: Variant = _pos_of(dummies[i])
			if pos == null:
				errors.append(where + ": need pos [x, y]")
				continue
			if bounds_ok and not _inside(pos, half, WALL_THICKNESS + ENTITY_MARGIN):
				errors.append(where + ": outside the playable area")
			if not _is_num_in(dummies[i].get("max_hp"), HP_MIN, HP_MAX):
				errors.append(where + ": max_hp must be %d-%d" % [int(HP_MIN), int(HP_MAX)])

	var terrain: Variant = level.get("terrain")
	if typeof(terrain) != TYPE_ARRAY:
		errors.append("terrain: must be a list")
	else:
		for i in terrain.size():
			var where := "terrain[%d]" % i
			if typeof(terrain[i]) != TYPE_DICTIONARY:
				errors.append(where + ": must be an object")
				continue
			var e: Dictionary = terrain[i]
			if str(e.get("type", "")) not in TERRAIN_TYPES:
				errors.append(where + ": type must be one of %s" % [TERRAIN_TYPES])
			var rect: Variant = _rect4_of(e)
			if rect == null:
				errors.append(where + ": need rect [x, y, w, h] with positive size")
				continue
			var snapped := true
			for v in e.rect:
				if float(v) != floorf(float(v)) or int(v) % GRID != 0:
					snapped = false
			if not snapped:
				errors.append(where + ": rect values must be multiples of %d" % GRID)
			if bounds_ok and not _rect_inside(rect, half, WALL_THICKNESS):
				errors.append(where + ": must fit inside the walls")

	for i in spawn_points.size():
		for j in range(i + 1, spawn_points.size()):
			if spawn_points[i].pos.distance_to(spawn_points[j].pos) < SPAWN_SEPARATION:
				errors.append("%s and %s: closer than %d px" %
						[spawn_points[i].label, spawn_points[j].label, int(SPAWN_SEPARATION)])
		for rect in block_rects:
			if rect.grow(ENTITY_MARGIN).has_point(spawn_points[i].pos):
				errors.append("%s: on top of a block" % spawn_points[i].label)
				break
	return errors


static func _is_num(v: Variant) -> bool:
	return (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v))


static func _is_num_in(v: Variant, lo: float, hi: float) -> bool:
	return _is_num(v) and float(v) >= lo and float(v) <= hi


static func _is_whole_in(v: Variant, lo: int, hi: int) -> bool:
	return _is_num(v) and float(v) == floorf(float(v)) and int(v) >= lo and int(v) <= hi


static func _pos_of(entry: Variant) -> Variant:
	return _pair_of(entry, "pos")


## [a, b] numeric pair -> Vector2, else null.
static func _pair_of(entry: Variant, key: String) -> Variant:
	if typeof(entry) != TYPE_DICTIONARY:
		return null
	var p: Variant = entry.get(key)
	if typeof(p) != TYPE_ARRAY or p.size() != 2 or not _is_num(p[0]) or not _is_num(p[1]):
		return null
	return Vector2(float(p[0]), float(p[1]))


## rect [x, y, w, h] (top-left anchored) -> Rect2, else null.
static func _rect4_of(entry: Dictionary) -> Variant:
	var r: Variant = entry.get("rect")
	if typeof(r) != TYPE_ARRAY or r.size() != 4:
		return null
	for v in r:
		if not _is_num(v):
			return null
	if float(r[2]) <= 0.0 or float(r[3]) <= 0.0:
		return null
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


static func _inside(pos: Vector2, half: Vector2, margin: float) -> bool:
	return absf(pos.x) <= half.x - margin and absf(pos.y) <= half.y - margin


static func _rect_inside(rect: Rect2, half: Vector2, margin: float) -> bool:
	return (rect.position.x >= -half.x + margin and rect.position.y >= -half.y + margin
			and rect.end.x <= half.x - margin and rect.end.y <= half.y - margin)
