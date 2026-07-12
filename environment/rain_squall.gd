class_name RainSquall
extends Node2D
## Reusable visual-only weather. One GPU emitter covers an authored arena;
## wet terrain materials opt into world-space ripple math independently.

@export var bounds := Vector2(4608, 3840)
@export_range(0.0, 2.0, 0.05) var intensity := 1.0
@export_range(32, 1200, 1) var base_amount := 520
@export var wind := Vector2(135.0, 760.0)
@export_range(8.0, 48.0, 1.0) var streak_length := 24.0
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
	mat.color = Color(0.72, 0.82, 0.94, 0.42)
	particles.process_material = mat
	particles.z_index = 4
	add_child(particles)

func _streak_texture() -> Texture2D:
	var height := maxi(8, roundi(streak_length))
	var image := Image.create(3, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in height:
		var alpha := sin(float(y) / float(height - 1) * PI) * 0.8
		image.set_pixel(1, y, Color(0.86, 0.92, 1.0, alpha))
	return ImageTexture.create_from_image(image)

static func configure_wet_material(source: ShaderMaterial, strength: float) -> ShaderMaterial:
	if source == null:
		return null
	var local := source.duplicate() as ShaderMaterial
	local.set_shader_parameter("rain_ripples", true)
	local.set_shader_parameter("rain_ripple_strength", clampf(strength, 0.0, 0.25))
	return local
