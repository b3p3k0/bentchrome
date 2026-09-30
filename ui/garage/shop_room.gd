extends Control
## Paint-only first-person view of Slo Mo's shop, after hours: a dim room,
## warm pools under the overhead fixtures, and the player's phone flashlight
## on the selected station (shaders/shop_spotlight.gdshader). The garage shell
## owns all selection and Economy state; this view presents what it receives.

const UiStyle := preload("res://ui/ui_style.gd")
const SpotlightShader := preload("res://shaders/shop_spotlight.gdshader")

const CANVAS_SIZE := Vector2(1280.0, 720.0)
const ART_PATH := "res://assets/img/garage/bg.png"
const SPOT_MOVE_SEC := 0.15

## Light knobs. The menu dims the room further and half-drops the beam.
static var ROOM_AMBIENT := 0.25
static var MENU_AMBIENT := 0.14
static var ROOM_BEAM := 1.0
static var MENU_BEAM := 0.55
static var BEAM_PAD := 1.15      # beam radii = hotspot half-size × this
static var BEAM_MIN_RADIUS := 90.0
static var SWAY_PX := 3.0        # handheld wobble of the beam, in px

static var HOTSPOTS: Array = [
	{"category": "ENGINE", "label": "ENGINE HOIST",
		"rect": Rect2(15, 205, 215, 210),
		"quip": "More go. Same no-stop. Your problem."},
	{"category": "SUSPENSION", "label": "TIRE RACK",
		"rect": Rect2(175, 80, 225, 370),
		"quip": "Springs, frames, rubber. Keeps your teeth in."},
	{"category": "WEAPONS", "label": "GUN BENCH",
		"rect": Rect2(695, 205, 285, 125),
		"quip": "Everything on that bench has been fired at least once."},
	{"category": "CPU", "label": "ELECTRONICS",
		"rect": Rect2(960, 40, 185, 440),
		"quip": "Blips and bleeps. I don't touch 'em, I just sell 'em."},
	{"category": "ARMOR", "label": "ARMOR WALL",
		"rect": Rect2(1085, 110, 195, 480),
		"quip": "Plate's plate. Bolt it on and drive it into things."},
]

## Overhead fixtures measured on bg.png: Vector4(x, y, pool radius x, pool
## radius y). Re-measure with HOTSPOTS whenever the painting changes.
static var LAMPS: Array = [
	Vector4(297, 40, 200, 170),   # left fluorescent tube
	Vector4(567, 55, 170, 160),   # the bulb over Mo's counter
	Vector4(942, 42, 200, 170),   # right fluorescent tube
]

var hotspot_index := 0

var _art: TextureRect
var _material: ShaderMaterial
var _station: Label
var _quip: Label
var _next_level: Label
var _wallet: Label
var _spot_rect := Rect2()
var _spot_tween: Tween
var _sway := 0.0
var _in_menu := false
var _chrome: Array = []   # room-only plates; the menu panel owns the screen
var _source_texture: Texture2D
var _source_supplied := false

## Injects a texture (including null) before the node enters the tree. Tests
## use this seam to exercise the missing-art fallback without touching files.
func use_texture(texture: Texture2D) -> void:
	_source_texture = texture
	_source_supplied = true

func _ready() -> void:
	name = "ShopRoom"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_background()
	_build_chrome()
	_ignore_controls(self)
	focus(0, true)

func _process(delta: float) -> void:
	_sway = fposmod(_sway + delta, TAU * 10.0)
	_push_beam()

func refresh(shell) -> void:
	focus(shell.category_index)
	var data: Dictionary = HOTSPOTS[hotspot_index]
	var category := String(data["category"])
	var total := 0
	var owned_count := 0
	for item in shell.items:
		if String(item.category) != category:
			continue
		total += 1
		if String(item.id) in shell.owned:
			owned_count += 1
	_station.text = "%s — %s %d/%d" % [data["label"], category, owned_count, total]
	_quip.text = "SLO MO: " + String(data["quip"])
	_next_level.text = shell.next_level_name
	_wallet.text = "⚙ %s" % shell.fmt(shell.wallet())
	_set_menu_light(not shell.is_room())

## Moves the shader rectangle and brackets to a station. Tests can request an
## instant move; live navigation uses the short pause-safe ease-out tween.
func focus(index: int, instant := false) -> void:
	if HOTSPOTS.is_empty():
		return
	hotspot_index = wrapi(index, 0, HOTSPOTS.size())
	var data: Dictionary = HOTSPOTS[hotspot_index]
	var target: Rect2 = data["rect"]
	if _spot_tween != null and _spot_tween.is_valid():
		_spot_tween.kill()
	if instant or not is_inside_tree() or _spot_rect == target:
		_set_spot_rect(target)
		return
	_spot_tween = create_tween()
	_spot_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_spot_tween.tween_method(_set_spot_rect, _spot_rect, target, SPOT_MOVE_SEC) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func has_room_texture() -> bool:
	return _art != null and _art.texture != null

func _set_spot_rect(rect: Rect2) -> void:
	_spot_rect = rect
	_push_beam()
	queue_redraw()

## The beam is an ellipse over the hotspot, drifting a few px like a hand.
func _push_beam() -> void:
	if _material == null:
		return
	var radii := (_spot_rect.size * 0.5 * BEAM_PAD).max(Vector2.ONE * BEAM_MIN_RADIUS)
	var sway := Vector2(sin(_sway * 0.9), sin(_sway * 1.3 + 1.0)) * SWAY_PX
	var center := _spot_rect.get_center() + sway
	_material.set_shader_parameter("beam", Vector4(center.x, center.y, radii.x, radii.y))

func _set_menu_light(in_menu: bool) -> void:
	_in_menu = in_menu
	if _material != null:
		_material.set_shader_parameter("ambient", MENU_AMBIENT if in_menu else ROOM_AMBIENT)
		_material.set_shader_parameter("beam_strength", MENU_BEAM if in_menu else ROOM_BEAM)
	for plate in _chrome:
		plate.visible = not in_menu
	queue_redraw()

func _build_background() -> void:
	_art = TextureRect.new()
	_art.name = "RoomArt"
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.show_behind_parent = true
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture = _source_texture if _source_supplied else TextureLoader.load_texture(ART_PATH)
	_material = ShaderMaterial.new()
	_material.shader = SpotlightShader
	_material.set_shader_parameter("canvas_size", CANVAS_SIZE)
	_material.set_shader_parameter("lamps", LAMPS)
	_material.set_shader_parameter("lamp_count", LAMPS.size())
	_set_menu_light(false)
	_art.material = _material
	add_child(_art)

func _build_chrome() -> void:
	var next_panel := _panel(Rect2(18, 16, 400, 48), 0.80)
	_next_level = _label(17, UiStyle.AMBER)
	_next_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_panel.add_child(_next_level)

	var wallet_panel := _panel(Rect2(1070, 16, 192, 48), 0.86)
	_wallet = _label(22, UiStyle.AMBER)
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wallet_panel.add_child(_wallet)

	var caption := _panel(Rect2(140, 604, 1000, 80), 0.86)
	var margin := MarginContainer.new()
	_set_margin(margin, 8)
	caption.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	_station = _label(24, UiStyle.AMBER)
	_station.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_station)
	_quip = _label(15, UiStyle.DIM_TEXT)
	_quip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_quip)

	var hint_panel := _panel(Rect2(238, 690, 804, 26), 0.82)
	var hint := _label(14, UiStyle.DIM_TEXT)
	hint.text = "←/→ look around    [ENTER] browse    [ESC] keep rollin'"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_panel.add_child(hint)

func _panel(rect: Rect2, alpha: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.025, 0.035, alpha)
	style.border_color = Color(UiStyle.AMBER, 0.38)
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 1)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_chrome.append(panel)
	return panel

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _set_margin(container: MarginContainer, amount: int) -> void:
	for side in ["left", "right", "top", "bottom"]:
		container.add_theme_constant_override("margin_" + side, amount)

func _ignore_controls(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(true):
		_ignore_controls(child)

func _draw() -> void:
	if not has_room_texture():
		_draw_fallback()

func _draw_fallback() -> void:
	var depth := 0.62 if _in_menu else 1.0
	var background := Color(0.035, 0.035, 0.05) * depth
	background.a = 1.0
	draw_rect(Rect2(Vector2.ZERO, CANVAS_SIZE), background)
	var font: Font = ThemeDB.fallback_font
	for index in HOTSPOTS.size():
		var data: Dictionary = HOTSPOTS[index]
		var rect: Rect2 = data["rect"]
		var selected := index == hotspot_index
		var fill := Color(0.30, 0.31, 0.34, 0.92 if selected else 0.55) * depth
		fill.a = 0.92 if selected else 0.55
		draw_rect(rect, fill)
		draw_rect(rect, Color(0.48, 0.49, 0.53, depth), false, 2.0)
		var baseline := rect.get_center().y + font.get_ascent(16) * 0.5
		draw_string(font, Vector2(rect.position.x, baseline), String(data["label"]),
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, Color(0.82, 0.83, 0.86, depth))
