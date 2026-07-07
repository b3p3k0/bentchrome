extends StaticBody2D
## Paint-only decoration for rectangular building bodies: drop shadow (fake
## height, same trick as the vehicle shadows), flat fill, a deterministic
## window grid (a few windows glow), and a parapet outline. Size comes from
## the Col shape; the plain Vis polygon is hidden at runtime and kept only as
## the editor preview. No collision or gameplay here — pure paint.

const SHADOW := Color(0.0, 0.0, 0.0, 0.32)
const SHADOW_OFFSET := Vector2(10, 14)
const BODY_COLOR := Color(0.3, 0.3, 0.36)
const WINDOW := Color(0.18, 0.2, 0.26)
const WINDOW_LIT := Color(0.75, 0.65, 0.35, 0.9)
const PARAPET := Color(0.42, 0.42, 0.5)
const CELL := 64.0                 # window grid pitch
const WIN_SIZE := Vector2(20, 20)
const MIN_WINDOW_DIM := 192.0      # smaller slabs (statue, court walls) skip windows

var _size := Vector2.ZERO
var _rng_seed := 0

func _ready() -> void:
	var col := get_node_or_null(^"Col") as CollisionShape2D
	if col == null or not (col.shape is RectangleShape2D):
		return
	_size = col.shape.size
	_rng_seed = int(absf(position.x * 7.0 + position.y * 13.0))
	var vis := get_node_or_null(^"Vis") as CanvasItem
	if vis:
		vis.visible = false
	queue_redraw()

func _draw() -> void:
	if _size == Vector2.ZERO:
		return
	var half := _size * 0.5
	draw_rect(Rect2(-half + SHADOW_OFFSET, _size), SHADOW)
	draw_rect(Rect2(-half, _size), BODY_COLOR)
	if _size.x >= MIN_WINDOW_DIM and _size.y >= MIN_WINDOW_DIM:
		var cols := maxi(int((_size.x - 48.0) / CELL), 1)
		var rows := maxi(int((_size.y - 48.0) / CELL), 1)
		var start := Vector2(-(cols - 1), -(rows - 1)) * CELL * 0.5
		for i in cols:
			for j in rows:
				var lit := (_rng_seed + i * 31 + j * 17) % 7 == 0
				var p := start + Vector2(i, j) * CELL
				draw_rect(Rect2(p - WIN_SIZE * 0.5, WIN_SIZE), WINDOW_LIT if lit else WINDOW)
	draw_rect(Rect2(-half, _size), PARAPET, false, 3.0)
