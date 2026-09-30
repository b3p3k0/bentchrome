extends RefCounted
## Keyboard-only PIT STOP state machine, guarded confirmation, purchase rules,
## and the mouse-inert paint tree.

const GarageScene := preload("res://ui/garage/garage.tscn")
const GarageScript := preload("res://ui/garage/garage.gd")
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

func _descendant_controls(node: Node, output: Array) -> void:
	for child in node.get_children(true):
		if child is Control:
			output.append(child)
		_descendant_controls(child, output)

func test_opens_without_buying_and_browses_with_wrap() -> void:
	var saved_funds := Economy.funds
	Economy.funds = 100000
	var owned: Array = []
	var shop := _shop(owned)
	t.check(shop.mode == GarageScript.Mode.MENU and shop.category_index == 0
		and shop.item_index == 0, "garage: setup opens MENU at the first item")
	t.check(owned.is_empty() and Economy.funds == 100000,
		"garage: opening never buys the highlighted card")
	_key(shop, KEY_DOWN)
	t.check(shop.item_index == 1, "garage: DOWN browses forward")
	_key(shop, KEY_UP)
	_key(shop, KEY_UP)
	t.check(shop.item_index == shop.category_items().size() - 1,
		"garage: UP wraps within the category")
	_key(shop, KEY_RIGHT)
	t.check(shop.category_index == 1 and shop.item_index == 0,
		"garage: RIGHT changes category and resets the item")
	_key(shop, KEY_LEFT)
	_key(shop, KEY_LEFT)
	t.check(shop.category_index == shop.categories.size() - 1 and shop.item_index == 0,
		"garage: LEFT wraps categories and resets the item")
	_done(shop)
	Economy.funds = saved_funds

func test_buyable_requires_confirm_cancel_or_purchase() -> void:
	var saved_funds := Economy.funds
	Economy.funds = 100000
	var owned: Array = []
	var shop := _shop(owned)
	var bought_hits: Array = []
	shop.bought.connect(func(id: String) -> void: bought_hits.append(id))
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
	shop._process(0.3)
	_key(shop, KEY_DOWN)
	var before := Economy.funds
	_key(shop, KEY_ENTER)
	t.check(shop.mode == GarageScript.Mode.MENU and Economy.funds == before
		and shop.mo_line.contains("Bolt on"), "garage: locked parts explain the prerequisite")
	Economy.funds = 0
	shop.setup(load("res://data/vehicles/hornet.tres"), owned, "NEXT: TEST")
	shop._process(0.3)
	_key(shop, KEY_ENTER)
	t.check(shop.mode == GarageScript.Mode.MENU and Economy.funds == 0
		and shop.mo_line.contains("short"), "garage: short parts explain the shortfall")
	Economy.funds = 100000
	owned.append("engine_stage1")
	shop.setup(load("res://data/vehicles/hornet.tres"), owned, "NEXT: TEST")
	shop._process(0.3)
	_key(shop, KEY_ENTER)
	t.check(shop.mode == GarageScript.Mode.MENU and Economy.funds == 100000
		and owned == ["engine_stage1"] and shop.mo_line.contains("Already"),
		"garage: owned parts cannot be bought twice")
	_done(shop)
	Economy.funds = saved_funds

func test_guard_blocks_arrival_and_every_mode_change() -> void:
	var saved_funds := Economy.funds
	Economy.funds = 100000
	var owned: Array = []
	var shop := _shop(owned)
	var exits: Array = []
	shop.left.connect(func() -> void: exits.append(true))
	_key(shop, KEY_ENTER)
	_key(shop, KEY_ENTER)
	_key(shop, KEY_ESCAPE)
	t.check(shop.mode == GarageScript.Mode.MENU and owned.is_empty()
		and Economy.funds == 100000 and exits.is_empty(),
		"garage: setup guard ignores double ENTER and ESC")
	shop._process(0.3)
	_key(shop, KEY_ENTER)
	_key(shop, KEY_ENTER)
	_key(shop, KEY_ESCAPE)
	t.check(shop.mode == GarageScript.Mode.CONFIRM and owned.is_empty(),
		"garage: CONFIRM guard freezes immediate ENTER and ESC")
	shop._process(0.3)
	_key(shop, KEY_ESCAPE)
	_key(shop, KEY_ESCAPE)
	t.check(shop.mode == GarageScript.Mode.MENU and exits.is_empty(),
		"garage: returning to MENU rearms its guard")
	shop._process(0.3)
	_key(shop, KEY_ESCAPE)
	t.check(exits.size() == 1, "garage: guarded MENU ESC eventually emits left once")
	_done(shop)
	Economy.funds = saved_funds

func test_menu_escape_emits_left_once() -> void:
	var saved_funds := Economy.funds
	Economy.funds = 100000
	var shop := _shop([])
	var exits: Array = []
	shop.left.connect(func() -> void: exits.append(true))
	shop._process(0.3)
	_key(shop, KEY_ESCAPE)
	t.check(exits.size() == 1, "garage: MENU ESC emits left once")
	_done(shop)
	Economy.funds = saved_funds

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
	t.check(shop.mode == GarageScript.Mode.MENU and shop.category_index == 0
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
