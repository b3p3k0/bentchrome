extends Node2D
## Paint-only Driver's Ed set pieces — non-colliding by design (street_deco
## philosophy: AI feelers and shots never see paint). `kind` picks the piece:
##   tunnel:    the exit maw through the north wall — throat bands darkening
##              as they recede to -y, concrete jambs either side (stadium's
##              locker-room maw, re-cut for the yard).
##   exit_text: EXIT painted on the approach asphalt in road-paint white,
##              chevrons marching north toward the mouth.
##   sign:      the overhead EXIT board. Author the node at z_index 1 (the
##              overhead layer) so cars pass beneath it.
##   gate:      caution-striped planking. Rides the ExitGate body as its Vis
##              so the closed look and the collision can never disagree.
##   helipad:   the yard's centerpiece — a repurposed helicopter pad, worn
##              double ring + blocky H + years of tire scuffs. size.x =
##              outer diameter. Doubles as the spawn marker.

const CONCRETE := Color(0.52, 0.52, 0.55)
const PAINT := Color(0.92, 0.92, 0.88, 0.8)    # road-paint white
const CHEVRON := Color(0.95, 0.75, 0.2, 0.85)  # caution amber
const PANEL_BG := Color(0.07, 0.07, 0.09)
const PANEL_FRAME := Color(0.3, 0.3, 0.34)
const AMBER := Color(1.0, 0.85, 0.2)
const STRIPE_DARK := Color(0.13, 0.12, 0.1)
const STRIPE_AMBER := Color(0.85, 0.68, 0.12)

@export var kind: StringName = &"tunnel"
@export var size := Vector2(384, 256)

func _draw() -> void:
	match kind:
		&"tunnel":
			_draw_tunnel()
		&"exit_text":
			_draw_exit_text()
		&"sign":
			_draw_sign()
		&"gate":
			_draw_gate()
		&"helipad":
			_draw_helipad()

## Five bands, deepest darkest; jambs overhang the mouth by a hair.
func _draw_tunnel() -> void:
	var hw := size.x * 0.5
	var depth := size.y
	var steps := 5
	for i in steps:
		var a := lerpf(1.0, 0.55, float(i) / float(steps - 1))
		draw_rect(Rect2(Vector2(-hw, -depth + depth * float(i) / steps),
			Vector2(size.x, depth / steps + 1.0)), Color(0.04, 0.04, 0.06, a))
	draw_rect(Rect2(Vector2(-hw - 10.0, -depth), Vector2(10.0, depth + 6.0)), CONCRETE)
	draw_rect(Rect2(Vector2(hw, -depth), Vector2(10.0, depth + 6.0)), CONCRETE)

## Ground lettering the size of the approach lane; size.y is letter height.
func _draw_exit_text() -> void:
	var font := ThemeDB.fallback_font
	var fs := int(size.y)
	var x := -_string_width("EXIT", fs, 12.0) * 0.5
	for ch in "EXIT":
		draw_char(font, Vector2(x, fs * 0.35), ch, fs, PAINT)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
	for i in 3:
		var cy := -fs * 0.5 - 70.0 - 84.0 * i
		draw_polyline(PackedVector2Array([
			Vector2(-38.0, cy + 22.0), Vector2(0.0, cy - 22.0), Vector2(38.0, cy + 22.0),
		]), CHEVRON, 10.0)

func _draw_sign() -> void:
	var half := size * 0.5
	draw_rect(Rect2(Vector2(-half.x + 10.0, half.y), Vector2(12.0, 28.0)), PANEL_FRAME)
	draw_rect(Rect2(Vector2(half.x - 22.0, half.y), Vector2(12.0, 28.0)), PANEL_FRAME)
	draw_rect(Rect2(-half, size), PANEL_BG)
	var font := ThemeDB.fallback_font
	var fs := int(size.y * 0.7)
	var w := _string_width("EXIT", fs, 8.0)
	var x := -w * 0.5
	for ch in "EXIT":
		draw_char(font, Vector2(x, fs * 0.35), ch, fs, AMBER)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0
	draw_rect(Rect2(-half, size), PANEL_FRAME, false, 6.0)

## Vertical caution planking — stripes stay inside the rect, no spill onto
## the jambs; rails top and bottom finish the barricade read.
func _draw_gate() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), STRIPE_DARK)
	var sw := 28.0
	var x := -half.x
	var idx := 0
	while x < half.x:
		if idx % 2 == 0:
			draw_rect(Rect2(Vector2(x, -half.y), Vector2(minf(sw, half.x - x), size.y)),
				STRIPE_AMBER)
		x += sw
		idx += 1
	draw_rect(Rect2(Vector2(-half.x, -half.y), Vector2(size.x, 6.0)), PANEL_FRAME)
	draw_rect(Rect2(Vector2(-half.x, half.y - 6.0), Vector2(size.x, 6.0)), PANEL_FRAME)

## Somebody used to land here; now somebody practices donuts here.
func _draw_helipad() -> void:
	var r := size.x * 0.5
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, PAINT, 10.0)
	draw_arc(Vector2.ZERO, r - 22.0, 0.0, TAU, 64,
		Color(PAINT.r, PAINT.g, PAINT.b, 0.35), 4.0)
	var hh := r * 0.52
	var hw := r * 0.38
	var bar := 16.0
	draw_rect(Rect2(Vector2(-hw - bar * 0.5, -hh), Vector2(bar, hh * 2.0)), PAINT)
	draw_rect(Rect2(Vector2(hw - bar * 0.5, -hh), Vector2(bar, hh * 2.0)), PAINT)
	draw_rect(Rect2(Vector2(-hw, -bar * 0.5), Vector2(hw * 2.0, bar)), PAINT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # stable scuffs — deco never flickers between boots
	for i in 5:
		var a0 := rng.randf_range(0.0, TAU)
		var rr := rng.randf_range(r * 0.35, r * 0.95)
		draw_arc(Vector2.ZERO, rr, a0, a0 + rng.randf_range(0.4, 1.4), 24,
			Color(0.05, 0.05, 0.06, 0.35), rng.randf_range(5.0, 9.0))

func _string_width(text: String, fs: int, gap: float) -> float:
	var font := ThemeDB.fallback_font
	var total := 0.0
	for ch in text:
		total += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + gap
	return total - gap
