extends RefCounted
## Radial glow-disc PointLight2D builder shared by the Coliseum's night game
## and any other dusk arena. A PointLight2D only READS as light because the
## level's CanvasModulate (group night_arena) darkens the world around it.

static func make_light(radius: float, energy: float, color: Color) -> PointLight2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	var light := PointLight2D.new()
	light.texture = tex
	light.texture_scale = radius / 128.0
	light.energy = energy
	light.color = color
	return light
