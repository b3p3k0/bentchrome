class_name ArenaContract
extends RefCounted
## Dependency-light machine half of docs/arena_field_manual.md. Runtime flow
## ignores profile metadata; tests make omissions and silent exceptions red.

const MIN_CARS := 4
const MIN_AREA_PER_CAR := 1_600_000.0
const MIN_SHORT_SIDE := 2048.0
const MODES := [&"arena", &"specialty", &"placeholder"]
const SIZE_CLASSES := [&"small", &"medium", &"large"]
const ENCOUNTERS := [&"melee", &"miniboss", &"boss", &"chase"]
const SIZE_CAR_BANDS := {
	&"small": Vector2i(4, 4),
	&"medium": Vector2i(5, 7),
	&"large": Vector2i(7, 8),
}
const STATION_BANDS := {
	&"small": Vector2i(1, 1),
	&"medium": Vector2i(1, 2),
	&"large": Vector2i(2, 3),
}
const LEGACY_MP_EXCEPTIONS := {
	"res://levels/depot/depot.tscn": "boss scene currently bakes only player + Lackey",
	"res://levels/stadium/stadium.tscn": "boss scene currently bakes only player + Goliath",
}
const NAMED_COLLISION_MASK := (1 << 10) - 1

static func is_regular(profile: Dictionary) -> bool:
	return StringName(profile.get("mode", &"")) == &"arena"

static func area_per_car(profile: Dictionary) -> float:
	var size: Vector2 = profile.get("arena_size", Vector2.ZERO)
	var cars := int(profile.get("target_cars", 0))
	return size.x * size.y / float(cars) if cars > 0 else 0.0

static func validate(profile: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var label := String(profile.get("name", "<unnamed>"))
	var mode := StringName(profile.get("mode", &""))
	if mode not in MODES:
		errors.append("%s: mode must be arena, specialty, or placeholder" % label)
		return errors
	if mode == &"specialty":
		if StringName(profile.get("encounter", &"")) != &"chase":
			errors.append("%s: specialty profile must declare chase encounter" % label)
		return errors
	if mode == &"placeholder":
		# An unbuilt slot: pinned in the order, no scene to validate. The
		# interstitial's under-construction card rolls players past it.
		if String(profile.get("scene", "?")) != "":
			errors.append("%s: placeholder slots carry no scene" % label)
		if profile.get("mp_ready", false) == true:
			errors.append("%s: placeholder slots cannot be MP-ready" % label)
		return errors
	var size_class := StringName(profile.get("size_class", &""))
	var encounter := StringName(profile.get("encounter", &""))
	var cars := int(profile.get("target_cars", 0))
	var stations := int(profile.get("stations", 0))
	var arena_size: Vector2 = profile.get("arena_size", Vector2.ZERO)
	if size_class not in SIZE_CLASSES:
		errors.append("%s: invalid size_class" % label)
	if encounter not in ENCOUNTERS or encounter == &"chase":
		errors.append("%s: regular arena needs melee/miniboss/boss encounter" % label)
	if cars < MIN_CARS:
		errors.append("%s: target_cars must be at least %d" % [label, MIN_CARS])
	if minf(arena_size.x, arena_size.y) < MIN_SHORT_SIDE:
		errors.append("%s: short side must be at least %d" % [label, int(MIN_SHORT_SIDE)])
	if area_per_car(profile) < MIN_AREA_PER_CAR:
		errors.append("%s: needs at least %d px^2 per target car" %
			[label, int(MIN_AREA_PER_CAR)])
	var boss_overlay := encounter in [&"miniboss", &"boss"]
	if SIZE_CAR_BANDS.has(size_class) and not boss_overlay:
		var band: Vector2i = SIZE_CAR_BANDS[size_class]
		if cars < band.x or cars > band.y:
			errors.append("%s: target cars outside %s band %d-%d" %
				[label, size_class, band.x, band.y])
	if STATION_BANDS.has(size_class) and not boss_overlay:
		var station_band: Vector2i = STATION_BANDS[size_class]
		if stations < station_band.x or stations > station_band.y:
			errors.append("%s: stations outside %s band %d-%d" %
				[label, size_class, station_band.x, station_band.y])
	elif boss_overlay and stations != 1:
		errors.append("%s: current boss overlay contract expects one station" % label)
	var path := String(profile.get("scene", ""))
	var mp_ready: bool = profile.get("mp_ready", false) == true
	if not mp_ready:
		if not LEGACY_MP_EXCEPTIONS.has(path):
			errors.append("%s: new regular arenas may not add an MP exception" % label)
		elif String(profile.get("mp_exception", "")) != String(LEGACY_MP_EXCEPTIONS[path]):
			errors.append("%s: MP exception must match the named legacy debt" % label)
	return errors

static func script_inherits(script: Script, base_path: String) -> bool:
	var cursor := script
	while cursor:
		if cursor.resource_path == base_path:
			return true
		cursor = cursor.get_base_script()
	return false
