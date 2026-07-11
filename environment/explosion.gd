extends Node2D
## One-shot explosion: white-hot flash, expanding ring, debris chunks in the
## victim's colors, then frees itself. Dependency-free paint — spawn it, set
## global_position (and optionally tint/size_scale), done. Nudges the player's
## camera if the blast is close.

const LIFETIME := 0.7
const RING_COLOR := Color(1.0, 0.7, 0.25)
const FLASH_COLOR := Color(1.0, 0.9, 0.6)
const SHAKE_RANGE := 500.0

var tint := Color(0.8, 0.3, 0.2)   # debris color — set to the car's paint job
var size_scale := 1.0              # 0.6 for crates, 1.0 for cars

const NIGHT_LIGHT_ENERGY := 1.6    # bloom strength in a darkened arena

var _t := 0.0
var _light: PointLight2D = null

func _ready() -> void:
	var debris := CPUParticles2D.new()
	debris.one_shot = true
	debris.emitting = true
	debris.amount = 26
	debris.lifetime = 0.6
	debris.explosiveness = 1.0
	debris.spread = 180.0
	debris.initial_velocity_min = 180.0 * size_scale
	debris.initial_velocity_max = 420.0 * size_scale
	debris.damping_min = 200.0
	debris.damping_max = 400.0
	debris.scale_amount_min = 2.0
	debris.scale_amount_max = 5.0
	debris.gravity = Vector2.ZERO
	debris.color = tint
	add_child(debris)
	var player := get_tree().get_first_node_in_group(&"player")
	if player is Node2D and player.has_method(&"add_shake"):
		var d: float = global_position.distance_to(player.global_position)
		if d < SHAKE_RANGE:
			player.add_shake(7.0 * size_scale * (1.0 - d / SHAKE_RANGE))
	# In a night arena (group marker, duck-typed) the blast BLOOMS: a light
	# whose energy dies with the flash. Absent the marker this costs nothing —
	# and this file stays dependency-free, so the texture is built inline.
	if get_tree().get_first_node_in_group(&"night_arena") != null:
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
		_light = PointLight2D.new()
		_light.texture = tex
		_light.texture_scale = 2.4 * size_scale
		_light.energy = NIGHT_LIGHT_ENERGY * size_scale
		_light.color = Color(1.0, 0.8, 0.5)
		add_child(_light)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _light:
		_light.energy = NIGHT_LIGHT_ENERGY * size_scale \
			* maxf(1.0 - _t / LIFETIME, 0.0)
	if _t >= LIFETIME:
		queue_free()

func _draw() -> void:
	var f := clampf(_t / LIFETIME, 0.0, 1.0)
	var eased := 1.0 - (1.0 - f) * (1.0 - f)
	var radius := lerpf(8.0, 90.0, eased) * size_scale
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(RING_COLOR, 1.0 - f), 2.0 + 6.0 * (1.0 - f))
	if f < 0.25:
		draw_circle(Vector2.ZERO, lerpf(26.0, 4.0, f / 0.25) * size_scale, Color(FLASH_COLOR, 1.0 - f / 0.25))
