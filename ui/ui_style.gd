extends RefCounted
## Shared menu chrome: the amber-on-dark tokens and widget builders every screen
## was copy-pasting. One source of truth so the SP front-door look (open amber
## bracket-lists) and the widget screens (MP, pause, end) read as one game.
##
## No class_name on purpose — consumers preload BY PATH
## (const UiStyle := preload("res://ui/ui_style.gd")) so the headless -s test
## chain never trips on an unregistered global (the net-stack convention).

const AMBER := Color(1.0, 0.85, 0.2)
const DIM_TEXT := Color(0.55, 0.58, 0.62)
const PANEL_BG := Color(0.07, 0.07, 0.09)
const BORDER_WIDTH := 6

## The bordered dark panel every dialog frames itself with.
static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.border_color = AMBER
	for side in ["left", "right", "top", "bottom"]:
		s.set("border_width_" + side, BORDER_WIDTH)
	return s

static func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	for side in ["left", "right", "top", "bottom"]:
		s.set("border_width_" + side, 2)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

## Retheme a default (grey) Godot Button into the amber-on-dark look: dim at
## rest, amber text + amber ring when focused/hovered — the keyboard focus IS
## the selection cue, mirroring the SP bracket-list highlight.
static func theme_button(btn: Button) -> void:
	btn.add_theme_color_override("font_color", DIM_TEXT)
	btn.add_theme_color_override("font_hover_color", AMBER)
	btn.add_theme_color_override("font_focus_color", AMBER)
	btn.add_theme_color_override("font_hover_pressed_color", AMBER)
	btn.add_theme_color_override("font_pressed_color", AMBER)
	btn.add_theme_color_override("font_disabled_color", Color(0.34, 0.35, 0.39))
	btn.add_theme_stylebox_override("normal", _button_box(Color(0.10, 0.10, 0.13), Color(0.24, 0.24, 0.28)))
	btn.add_theme_stylebox_override("hover", _button_box(Color(0.14, 0.13, 0.10), AMBER))
	btn.add_theme_stylebox_override("pressed", _button_box(Color(0.18, 0.16, 0.08), AMBER))
	btn.add_theme_stylebox_override("disabled", _button_box(Color(0.09, 0.09, 0.11), Color(0.20, 0.20, 0.22)))
	# Focus is drawn OVER the base box — a transparent amber ring, not a fill.
	btn.add_theme_stylebox_override("focus", _button_box(Color(0, 0, 0, 0), AMBER))
