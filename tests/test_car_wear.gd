extends RefCounted
## Progressive visual damage (FRESH / BANGED / BUSTED): deterministic seeded
## wear marks derived from STYLE footprint metrics alone, bounds-checked for
## EVERY registered style (the structural future-car guard), plus the
## turntable-safety contract — a paint node with no HP source stays pristine.
## Driven by run_tests.gd.

const WearScript := preload("res://vehicles/paint/wear.gd")
const PaintScript := preload("res://vehicles/car_paint.gd")

var t

func _init(runner) -> void:
	t = runner

func _marks(style: StringName, tier: int, seed_value := 1234) -> Array:
	return WearScript.wear_marks(PaintScript.STYLES[style], tier, seed_value)

func test_marks_deterministic_and_progressive() -> void:
	var a := _marks(&"ghost", WearScript.BUSTED)
	var b := _marks(&"ghost", WearScript.BUSTED)
	t.check(a.size() > 0 and a.size() == b.size(), "wear: same inputs, same mark count")
	var identical := true
	for i in a.size():
		if a[i] != b[i]:
			identical = false
	t.check(identical, "wear: same inputs regenerate element-identical marks")
	var other := _marks(&"ghost", WearScript.BUSTED, 9876)
	var differs := other.size() != a.size()
	for i in mini(other.size(), a.size()):
		if other[i] != a[i]:
			differs = true
	t.check(differs, "wear: a different seed rolls different damage")
	# Progressive superset: BUSTED = the exact BANGED layer + extras.
	var banged := _marks(&"ghost", WearScript.BANGED)
	t.check(banged.size() < a.size(), "wear: BUSTED carries more marks than BANGED")
	var prefix := true
	for i in banged.size():
		if banged[i] != a[i]:
			prefix = false
	t.check(prefix, "wear: going BUSTED accumulates onto the same dents, never reshuffles")
	t.check(_marks(&"ghost", WearScript.FRESH).is_empty(), "wear: FRESH draws nothing")
	var seed_a := WearScript.wear_seed(&"ghost", Color.RED, Color.WHITE)
	t.check(seed_a == WearScript.wear_seed(&"ghost", Color.RED, Color.WHITE),
		"wear: seed is stable for the same model + palette")
	t.check(seed_a != WearScript.wear_seed(&"ghost", Color.BLUE, Color.WHITE),
		"wear: a different palette rolls a different seed")

## The structural guard: every registered style (box fallback included) keeps
## every mark inside its own footprint at both tiers — a future car added to
## the registry is bounds-checked automatically.
func test_marks_inside_every_styles_footprint() -> void:
	for style_v in PaintScript.STYLES:
		var style := StringName(style_v)
		var m: Dictionary = PaintScript.STYLES[style]
		var half_len := float(m.get("half_len", 16.0))
		var l := minf(half_len, float(m.get("tail_len", half_len)))
		var w := float(m.get("half_wid", 10.0))
		for tier in [WearScript.BANGED, WearScript.BUSTED]:
			for seed_value in [42, 31337]:
				var marks := WearScript.wear_marks(m, tier, seed_value)
				t.check(not marks.is_empty(), "wear bounds: %s tier %d has marks" % [style, tier])
				var inside := true
				var visible := true
				for mark in marks:
					if mark.color.a <= 0.0:
						visible = false
					if mark.kind == &"blob":
						if absf(mark.pos.x) + mark.radius > l or absf(mark.pos.y) + mark.radius > w:
							inside = false
					else:
						for p in mark.points:
							if absf(p.x) > l or absf(p.y) > w:
								inside = false
				t.check(inside, "wear bounds: %s tier %d seed %d stays on the body"
					% [style, tier, seed_value])
				t.check(visible, "wear bounds: %s marks all carry visible alpha" % style)

func test_counts_scale_with_footprint() -> void:
	t.check(_marks(&"mrghastly", WearScript.BUSTED).size()
		< _marks(&"hammertoe", WearScript.BUSTED).size(),
		"wear: the bike carries fewer marks than the APC")
	t.check(_marks(&"mrghastly", WearScript.BANGED).size() >= 2,
		"wear: even the bike shows at least a scratch and a dent")

func test_turntable_safety() -> void:
	var paint = PaintScript.new()
	t.check(paint.wear == 0, "wear: a fresh paint node defaults FRESH")
	paint.apply(&"ghost", Color.RED, Color.WHITE)
	t.check(paint.wear == 0, "wear: apply() never dirties a turntable")
	paint.set_wear(5)
	t.check(paint.wear == WearScript.BUSTED, "wear: set_wear clamps high")
	paint.set_wear(-3)
	t.check(paint.wear == WearScript.FRESH, "wear: set_wear clamps low")
	paint.set_wear(1)
	t.check(paint.wear == WearScript.BANGED, "wear: no Vehicle needed anywhere")
	paint.free()
