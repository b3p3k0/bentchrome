class_name RainSquall
extends Node2D
## Reusable visual-only weather. One GPU emitter covers an authored arena;
## wet terrain materials opt into world-space ripple math independently.

@export var bounds := Vector2(4608, 3840)
@export_range(0.0, 2.0, 0.05) var intensity := 1.0
@export_range(32, 1200, 1) var base_amount := 760
@export var wind := Vector2(135.0, 760.0)
@export_range(8.0, 48.0, 1.0) var streak_length := 32.0
@export_range(0.0, 0.25, 0.01) var ripple_strength := 0.12

var particles: GPUParticles2D = null

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or intensity <= 0.0:
		return
	particles = GPUParticles2D.new()
	particles.name = "Rain"
	particles.amount = maxi(1, roundi(float(base_amount) * intensity))
	particles.lifetime = 1.25
	particles.preprocess = particles.lifetime
	particles.visibility_rect = Rect2(-bounds * 0.5 - Vector2(128, 128), bounds + Vector2(256, 256))
	particles.texture = _streak_texture()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(bounds.x * 0.5, bounds.y * 0.5, 0.0)
	var direction := wind.normalized()
	mat.direction = Vector3(direction.x, direction.y, 0.0)
	mat.spread = 4.0
	mat.initial_velocity_min = wind.length() * 0.92
	mat.initial_velocity_max = wind.length() * 1.08
	mat.gravity = Vector3.ZERO
	# Near-white and well over half alpha: a dusk CanvasModulate multiplies
	# every canvas item, so timid bluish streaks vanish into the gloom.
	mat.color = Color(0.86, 0.91, 1.0, 0.62)
	particles.process_material = mat
	particles.z_index = 4
	add_child(particles)
	_add_splashes()

## Ground layer: brief pale flicker dots reading as drop splashes. Same
## cosmetic-only contract as the streaks; built here in _ready, never _init.
func _add_splashes() -> void:
	var splash := CPUParticles2D.new()
	splash.name = "Splashes"
	splash.amount = maxi(1, roundi(float(base_amount) * intensity * 0.22))
	splash.lifetime = 0.35
	splash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	splash.emission_rect_extents = bounds * 0.5
	splash.direction = Vector2.ZERO
	splash.spread = 180.0
	splash.initial_velocity_min = 0.0
	splash.initial_velocity_max = 6.0
	splash.gravity = Vector2.ZERO
	splash.scale_amount_min = 1.5
	splash.scale_amount_max = 3.0
	splash.color = Color(0.88, 0.93, 1.0, 0.30)
	splash.z_index = 3
	add_child(splash)

func _streak_texture() -> Texture2D:
	var height := maxi(8, roundi(streak_length))
	var image := Image.create(3, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in height:
		var alpha := sin(float(y) / float(height - 1) * PI)
		image.set_pixel(1, y, Color(0.86, 0.92, 1.0, alpha))
	return ImageTexture.create_from_image(image)

static func configure_wet_material(source: ShaderMaterial, strength: float) -> ShaderMaterial:
	if source == null:
		return null
	var local := source.duplicate() as ShaderMaterial
	local.set_shader_parameter("rain_ripples", true)
	local.set_shader_parameter("rain_ripple_strength", clampf(strength, 0.0, 0.25))
	return local
