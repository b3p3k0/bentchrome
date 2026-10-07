extends Node2D
## Paint-only shooting-gallery set pieces — non-colliding by design
## (tutorial_deco idiom: AI feelers and shots never see paint). `kind` picks
## the piece:
##   range_tick: a thin pale bar across size.x with `text` (the distance from
##               the firing line) at the left margin — the yard's yardage
##               markers.

const BAR := Color(0.85, 0.85, 0.8, 0.5)       # weathered road-paint
const TEXT := Color(0.92, 0.92, 0.88, 0.85)
const TEXT_SIZE := 28
const TEXT_MARGIN := 24.0

@export var kind: StringName = &"range_tick"
@export var size := Vector2(896, 8)
@export var text := ""

var _warned := false  # an unknown kind complains once, not once per redraw

func _draw() -> void:
	match kind:
		&"range_tick":
			_draw_range_tick()
		_:
			if not _warned:
				_warned = true
				push_error("gallery_deco: unknown kind '%s'" % kind)

## Bar centered on the origin; the number sits just above its left end.
func _draw_range_tick() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), BAR)
	if text == "":
		return
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-half.x + TEXT_MARGIN, -half.y - 8.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, TEXT)
