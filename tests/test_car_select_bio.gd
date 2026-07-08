extends RefCounted
## Driver bio on car select: hidden by default, toggle shows the selected
## car's roster flavor, browsing with it open follows along, confirm is
## swallowed while reading. The scene is load()ed at test time, NOT const-
## preloaded: car_select.gd names the GameState autoload, which only compiles
## once autoloads are registered — suite preloads happen before that.

var t

func _init(runner) -> void:
	t = runner

func test_bio_toggle_and_content() -> void:
	t.check(InputMap.has_action(&"select_more_info"), "bio: select_more_info action registered")
	var select: Control = (load("res://ui/car_select.tscn") as PackedScene).instantiate()
	t.root.add_child(select)
	t.check(not select._cars.is_empty(), "bio: roster loaded")
	t.check(select._bio != null and not select._bio.visible, "bio: hidden by default")

	select._toggle_bio()
	t.check(select._bio.visible, "bio: toggle opens")
	var car: Variant = select._cars[select._index]
	t.check(select._bio_flavor.text == car.flavor and car.flavor != "",
		"bio: shows the selected car's flavor prose")
	t.check(select._bio_title.text.contains(car.driver_name), "bio: title names the driver")

	var before: String = select._bio_flavor.text
	select._index = (select._index + 1) % select._cars.size()
	select._show()
	t.check(select._bio_flavor.text != before, "bio: browsing with it open follows along")

	select._toggle_bio()
	t.check(not select._bio.visible, "bio: toggle closes")

	t.root.remove_child(select)
	select.free()
