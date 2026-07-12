extends RefCounted
## First-class mud and reusable rain stay data-driven and cosmetic-only.

const RainScript := preload("res://environment/rain_squall.gd")
const DriveFXScript := preload("res://vehicles/drive_fx.gd")
const SpeckleShader := preload("res://shaders/terrain_speckle.gdshader")
const TuningDeckScript := preload("res://game/tuning_deck.gd")
const SchemaScript := preload("res://levels/level_schema.gd")

var t

func _init(runner) -> void:
	t = runner

func test_global_mud_contract() -> void:
	var mud: Dictionary = DrivingController.TERRAIN[&"mud"]
	t.check_approx(mud.accel, 0.55, "mud: global acceleration")
	t.check_approx(mud.top, 0.60, "mud: global top speed")
	t.check_approx(mud.grip, 0.42, "mud: global grip")
	t.check_approx(mud.steer, 0.90, "mud: global steering")
	t.check(&"mud" in TuningDeckScript.TERRAIN_TYPES, "mud: F2 tuning exposes surface")
	t.check("mud" in SchemaScript.TERRAIN_TYPES, "mud: custom schema exposes surface")

func test_mud_drive_fx_has_tracks_and_spray() -> void:
	t.check(DriveFXScript.SKID_COLORS.has(&"mud"), "mud: hard slides leave wet tracks")
	t.check(DriveFXScript.DUST_COLORS.has(&"mud"), "mud: speed throws restrained spray")

func test_rain_component_is_cosmetic_and_bounded() -> void:
	var rain := RainScript.new()
	rain.bounds = Vector2(1024, 768)
	rain.intensity = 0.75
	t.check(rain.bounds == Vector2(1024, 768) and rain.intensity == 0.75,
		"rain: authored extent and intensity round-trip")
	t.check(rain is Node2D and rain.get_child_count() == 0,
		"rain: authoring root is paint-only before rendering setup")

func test_ripple_material_is_local_and_opt_in() -> void:
	var shared := ShaderMaterial.new()
	shared.shader = SpeckleShader
	shared.set_shader_parameter("rain_ripples", false)
	var wet := RainScript.configure_wet_material(shared, 0.14)
	t.check(wet != shared, "rain: wet material duplicates instead of mutating shared terrain")
	t.check(bool(wet.get_shader_parameter("rain_ripples")), "rain: duplicate opts into ripples")
	t.check_approx(float(wet.get_shader_parameter("rain_ripple_strength")), 0.14,
		"rain: authored ripple strength lands")
	t.check(not bool(shared.get_shader_parameter("rain_ripples")),
		"rain: dry material stays on unchanged shader path")
