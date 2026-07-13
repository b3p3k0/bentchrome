extends RefCounted
## Radial glow-disc PointLight2D builder shared by the Coliseum's night game
## and any other dusk arena. A PointLight2D only READS as light because the
## level's CanvasModulate (group night_arena) darkens the world around it.

## A HEADLIGHT texture: a truncated cone — flat cut at the lamp line (no
## light ever radiates behind the nose), spreading along +x into a rounded
## far base (the distance cap draws the arc). Baked per-pixel once at load
## into an ImageTexture; the meta "center_ahead" tells the caller how far
## the texture center sits past the lamp line so the apex can be pinned to
## the car's nose.
static func make_beam(length: float, spread_deg: float, energy: float, color: Color) -> PointLight2D:
	var w := 256
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var apex := Vector2(-36.0, float(h) * 0.5)  # virtual apex behind the cut
	var cut_x := 14.0                            # the truncation (lamp) line
	var reach := float(w) - 22.0 - apex.x        # apex -> rounded far rim
	var half_angle := deg_to_rad(spread_deg * 0.5)
	for y in h:
		for x in w:
			if float(x) < cut_x:
				continue
			var v := Vector2(float(x), float(y)) - apex
			var d := v.length()
			if d > reach:
				continue
			var ang := absf(atan2(v.y, v.x))
			if ang > half_angle:
				continue
			var a := (1.0 - d / reach) * (1.0 - pow(ang / half_angle, 2.0))
			img.set_pixel(x, y, Color(1, 1, 1, pow(clampf(a, 0.0, 1.0), 0.8)))
	var light := PointLight2D.new()
	light.texture = ImageTexture.create_from_image(img)
	light.texture_scale = length / (reach + apex.x - cut_x)  # usable beam px
	light.energy = energy
	light.color = color
	light.set_meta(&"center_ahead", (float(w) * 0.5 - cut_x) * light.texture_scale)
	return light

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
