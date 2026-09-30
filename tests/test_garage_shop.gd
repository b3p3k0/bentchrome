extends RefCounted
## Keyboard-only PIT STOP room/menu state machine, guarded confirmation,
## purchase rules, hotspot contract, and mouse-inert paint tree.

const GarageScene := preload("res://ui/garage/garage.tscn")
const GarageScript := preload("res://ui/garage/garage.gd")
const ShopRoom := preload("res://ui/garage/shop_room.gd")
const Catalog := preload("res://ui/garage/garage_catalog.gd")
const Economy := preload("res://game/economy.gd")

var t

func _init(runner) -> void:
	t = runner

func _shop(owned: Array) -> Control:
	var shop := GarageScene.instantiate()
	t.root.add_child(shop)
	shop.setup(load("res://data/vehicles/hornet.tres"), owned, "NEXT: TEST")
	return shop

func _done(shop: Control) -> void:
	t.root.remove_child(shop)
	shop.free()

func _key(shop: Control, code: Key, pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	shop._unhandled_input(event)

func _open_menu(shop: Control) -> void:
	shop._process(0.3)
	_key(shop, KEY_ENTER)

func _room(shop: Control):
	return shop.find_child("ShopRoom", true, false)

func _menu(shop: Control) -> Control:
	return shop.find_child("ShopMenu", true, false) as Control

func _descendant_controls(node: Node, output: Array) -> void:
	for child in node.get_children(true):
		if child is Control:
			output.append(child)
		_descendant_controls(child, output)

func test_setup_opens_room_without_buying() -> void:
	var saved_funds := Economy.funds
	Economy.funds = 100000
	var owned: Array = []
	var shop := _shop(owned)
	var room = _room(shop)
	var menu := _menu(shop)
	t.check(shop.mode == GarageScript.Mode.ROOM and shop.category_index == 0
		and shop.item_index == 0 and room.hotspot_index == 0,
		"garage: setup opens ROOM on hotspot zero")
	t.check(not menu.visible and owned.is_empty() and Economy.funds == 100000,
		"garage: setup hides the menu and buys nothing")
	_done(shop)
	Economy.funds = saved_funds

func test_room_walks_hotspots_in_order_and_wraps() -> void:
	var shop := _shop([])
	var room = _room(shop)
	for index in range(1, ShopRoom.HOTSPOTS.size()):
		_key(shop, KEY_RIGHT)
		t.check(shop.category_index == index and room.hotspot_index == index,
			"garage: ROOM RIGHT reaches hotspot %d" % index)
	_key(shop, KEY_RIGHT)
	t.check(shop.category_index == 0 and room.hotspot_index == 0,
		"garage: ROOM RIGHT wraps to the first hotspot")
	_key(shop, KEY_LEFT)
	t.check(shop.category_index == ShopRoom.HOTSPOTS.size() - 1
		and room.hotspot_index == ShopRoom.HOTSPOTS.size() - 1,
		"garage: ROOM LEFT wraps to the last hotspot")
	_done(shop)

func test_room_enter_opens_each_matching_category() -> void:
	var shop := _shop([])
	var menu := _menu(shop)
	for index in ShopRoom.HOTSPOTS.size():
		shop.setup(load("res://data/vehicles/hornet.tres"), [], "NEXT: TEST")
		for step in index:
			_key(shop, KEY_RIGHT)
		_open_menu(shop)
		var hotspot: Dictionary = ShopRoom.HOTSPOTS[index]
		t.check(shop.mode == GarageScript.Mode.MENU and menu.visible
			and shop.category_index == index and shop.item_index == 0
			and shop.categories[index] == hotspot["category"],
			"garage: hotspot %d opens its matching category" % index)
	_done(shop)

func test_menu_browses_with_wrap_and_keeps_room_in_sync() -> void:
	var shop := _shop([])
	_open_menu(shop)
	var room = _room(shop)
	_key(shop, KEY_DOWN)
	t.check(shop.item_index == 1, "garage: MENU DOWN browses forward")
	_key(shop, KEY_UP)
	_key(shop, KEY_UP)
	t.check(shop.item_index == shop.category_items().size() - 1,
		"garage: MENU UP wraps within the category")
	_key(shop, KEY_RIGHT)
	t.check(shop.category_index == 1 and shop.item_index == 0
		and room.hotspot_index == 1,
		"garage: MENU RIGHT changes category and syncs the room")
	_key(shop, KEY_LEFT)
	_key(shop, KEY_LEFT)
	t.check(shop.category_index == shop.categories.size() - 1 and shop.item_index == 0
		and room.hotspot_index == shop.categories.size() - 1,
		"garage: MENU LEFT wraps category and room hotspot")
	_done(shop)

func test_menu_escape_returns_to_guarded_room_then_leaves() -> void:
	var shop := _shop([])
	var exits: Array = []
	shop.left.connect(func() -> void: exits.append(true))
	_open_menu(shop)
	shop._process(0.3)
	_key(shop, KEY_ESCAPE)
	t.check(shop.mode == GarageScript.Mode.ROOM and not _menu(shop).visible,
		"garage: MENU ESC returns to ROOM and hides the menu")
	_key(shop, KEY_ESCAPE)
	t.check(exits.is_empty(), "garage: immediate second ESC is stopped by the ROOM guard")
	shop._process(0.3)
	_key(shop, KEY_ESCAPE)
	t.check(exits.size() == 1, "garage: guarded ROOM ESC eventually emits left once")
	_done(shop)

func test_arrival_guard_blocks_enter_spam_and_spending() -> void:
	var saved_funds := Economy.funds
	Economy.funds = 100000
	var owned: Array = []
	var shop := _shop(owned)
	_key(shop, KEY_ENTER)
	_key(shop, KEY_ENTER)
	_key(shop, KEY_ENTER)
	t.check(shop.mode == GarageScript.Mode.ROOM and not _menu(shop).visible,
		"garage: ENTER spam straight after setup never reaches CONFIRM")
	t.check(owned.is_empty() and Economy.funds == 100000,
		"garage: guarded ENTER spam spends and installs nothing")
	_done(shop)
	Economy.funds = saved_funds

func test_buyable_requires_confirm_cancel_or_purchase() -> void:
	var saved_funds := Economy.funds
	Economy.funds = 100000
	var owned: Array = []
	var shop := _shop(owned)
	var bought_hits: Array = []
	shop.bought.connect(func(id: String) -> void: bought_hits.append(id))
	_open_menu(shop)
	var price: int = Economy.price(int(shop.selected_item().price))
	shop._process(0.3)
	_key(shop, KEY_ENTER)
	t.check(shop.mode == GarageScript.Mode.CONFIRM,
		"garage: ENTER on buyable opens CONFIRM")
	t.check(Economy.funds == 100000 and owned.is_empty(),
		"garage: opening CONFIRM spends and installs nothing")
	var mo := shop.find_child("MoLine", true, false) as Label
	t.check(mo != null and mo.text.begins_with("SLO MO: ") and mo.text.contains("Deal?"),
		"garage: the confirmation is Slo Mo's Deal line")
	_key(shop, KEY_ENTER)
	_key(shop, KEY_ESCAPE)
	t.check(shop.mode == GarageScript.Mode.CONFIRM and Economy.funds == 100000,
		"garage: CONFIRM guard freezes immediate ENTER and ESC")
	shop._process(0.3)
	_key(shop, KEY_ESCAPE)
	t.check(shop.mode == GarageScript.Mode.MENU and Economy.funds == 100000
		and owned.is_empty(), "garage: ESC cancels without spending")
	shop._process(0.3)
	_key(shop, KEY_ENTER)
	shop._process(0.3)
	_key(shop, KEY_ENTER)
	t.check(shop.mode == GarageScript.Mode.MENU and Economy.funds == 100000 - price,
		"garage: confirmed purchase spends exactly the scaled price")
	t.check(owned == ["engine_stage1"] and bought_hits == ["engine_stage1"],
		"garage: confirmed purchase appends the id and emits bought once")
	_done(shop)
	Economy.funds = saved_funds

func test_exclusive_slot_replaces_the_owned_part() -> void:
	var saved_funds := Economy.funds
	Economy.funds = 100000
	var owned: Array = ["tires_offroad"]
	var shop := _shop(owned)
	_key(shop, KEY_RIGHT)
	_open_menu(shop)
	for index in 3:
		_key(shop, KEY_DOWN)
	t.check(String(shop.selected_item().id) == "tires_lowering",
		"garage: test reaches the other tire in SUSPENSION")
	shop._process(0.3)
	_key(shop, KEY_ENTER)
	shop._process(0.3)
	_key(shop, KEY_KP_ENTER)
	t.check("tires_lowering" in owned and "tires_offroad" not in owned,
		"garage: an exclusive-slot purchase removes the old tire")
	_done(shop)
	Economy.funds = saved_funds

func test_locked_short_and_owned_are_rejected() -> void:
	var saved_funds := Economy.funds
	Economy.funds = 100000
	var owned: Array = []
	var shop := _shop(owned)
	_open_menu(shop)
	_key(shop, KEY_DOWN)
	shop._process(0.3)
	var before := Economy.funds
	_key(shop, KEY_ENTER)
	t.check(shop.mode == GarageScript.Mode.MENU and Economy.funds == before
		and shop.mo_line.contains("Bolt on"), "garage: locked parts explain the prerequisite")
	Economy.funds = 0
	shop.setup(load("res://data/vehicles/hornet.tres"), owned, "NEXT: TEST")
	_open_menu(shop)
	shop._process(0.3)
	_key(shop, KEY_ENTER)
	t.check(shop.mode == GarageScript.Mode.MENU and Economy.funds == 0
		and shop.mo_line.contains("short"), "garage: short parts explain the shortfall")
	Economy.funds = 100000
	owned.append("engine_stage1")
	shop.setup(load("res://data/vehicles/hornet.tres"), owned, "NEXT: TEST")
	_open_menu(shop)
	shop._process(0.3)
	_key(shop, KEY_ENTER)
	t.check(shop.mode == GarageScript.Mode.MENU and Economy.funds == 100000
		and owned == ["engine_stage1"] and shop.mo_line.contains("Already"),
		"garage: owned parts cannot be bought twice")
	_done(shop)
	Economy.funds = saved_funds

func test_hotspots_match_catalog_and_room_bounds() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var catalog: Array = Catalog.categories()
	var seen: Dictionary = {}
	var previous_center_x := -INF
	var geometry_valid := true
	var copy_valid := true
	for index in ShopRoom.HOTSPOTS.size():
		var hotspot: Dictionary = ShopRoom.HOTSPOTS[index]
		var category := String(hotspot.get("category", ""))
		var rect: Rect2 = hotspot.get("rect", Rect2())
		var center := rect.get_center()
		seen[category] = int(seen.get(category, 0)) + 1
		geometry_valid = geometry_valid and rect.size.x > 0.0 and rect.size.y > 0.0 \
			and bounds.encloses(rect) and center.x > previous_center_x
		previous_center_x = center.x
		copy_valid = copy_valid and not String(hotspot.get("label", "")).strip_edges().is_empty() \
			and not String(hotspot.get("quip", "")).strip_edges().is_empty()
		for other_index in ShopRoom.HOTSPOTS.size():
			if other_index == index:
				continue
			var other: Dictionary = ShopRoom.HOTSPOTS[other_index]
			var other_rect: Rect2 = other.get("rect", Rect2())
			geometry_valid = geometry_valid and not other_rect.has_point(center)
	var categories_valid := seen.size() == catalog.size()
	for category in catalog:
		categories_valid = categories_valid and int(seen.get(category, 0)) == 1
	t.check(categories_valid,
		"garage room: every catalog category appears in HOTSPOTS exactly once")
	t.check(geometry_valid,
		"garage room: hotspot rects are positive, bounded, ordered, and center-disjoint")
	t.check(copy_valid, "garage room: every hotspot has a label and Slo Mo quip")

func test_room_null_texture_fallback_is_mouse_inert() -> void:
	var room := ShopRoom.new()
	room.use_texture(null)
	room.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.root.add_child(room)
	var controls: Array = [room]
	_descendant_controls(room, controls)
	var has_button := false
	var all_ignore := true
	for control in controls:
		has_button = has_button or control is BaseButton
		all_ignore = all_ignore and control.mouse_filter == Control.MOUSE_FILTER_IGNORE
	t.check(not room.has_room_texture(),
		"garage room: injected null texture selects the fallback path")
	t.check(not has_button and all_ignore,
		"garage room: fallback has no Buttons and every Control ignores the mouse")
	t.root.remove_child(room)
	room.free()

func test_only_raw_navigation_keys_can_change_state() -> void:
	var saved_funds := Economy.funds
	Economy.funds = 100000
	var owned: Array = []
	var shop := _shop(owned)
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE]:
		_key(shop, code)
	_key(shop, KEY_DOWN, false)
	_key(shop, KEY_DOWN, true, true)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	shop._gui_input(mouse)
	shop._unhandled_input(mouse)
	t.check(shop.mode == GarageScript.Mode.ROOM and shop.category_index == 0
		and shop.item_index == 0 and Economy.funds == 100000 and owned.is_empty(),
		"garage: WASD, Space, releases, echoes, and mouse presses do nothing")
	_done(shop)
	Economy.funds = saved_funds

func test_control_tree_has_no_buttons_or_mouse_targets() -> void:
	var saved_funds := Economy.funds
	Economy.funds = 100000
	var shop := _shop([])
	var controls: Array = []
	_descendant_controls(shop, controls)
	var has_button := false
	for control in controls:
		if control is BaseButton:
			has_button = true
	t.check(not has_button, "garage: no BaseButton exists anywhere in the shop")
	t.check(shop.mouse_filter == Control.MOUSE_FILTER_STOP,
		"garage: the root stops mouse input")
	var all_ignore := true
	for control in controls:
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			all_ignore = false
	t.check(all_ignore, "garage: every descendant Control ignores mouse input")
	_done(shop)
	Economy.funds = saved_funds
