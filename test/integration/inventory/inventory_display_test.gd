extends GutTest

func _make_display(slot_count: int = 3) -> InventoryDisplay:
	var inventory := Inventory.new()
	inventory.slot_count = slot_count
	add_child_autofree(inventory)

	var display_scene: PackedScene = load("res://scenes/inventory_display/inventory_display.tscn")
	var display: InventoryDisplay = display_scene.instantiate()
	display.inventory = inventory
	return add_child_autofree(display)

func test_builds_one_slot_visual_per_slot_count() -> void:
	var display := _make_display(3)

	assert_eq(display._slot_icons.size(), 3)

func test_empty_slot_shows_no_texture() -> void:
	var display := _make_display(3)

	for slot_icon in display._slot_icons:
		assert_null(slot_icon.texture)

func test_equip_updates_the_corresponding_slot_visual() -> void:
	var display := _make_display(3)
	var item := Item.new()
	item.icon = PlaceholderTexture2D.new()

	display.inventory.equip(item)

	assert_eq(display._slot_icons[0].texture, item.icon)

func test_unequip_reverts_the_slot_visual_to_no_texture() -> void:
	var display := _make_display(3)
	var item := Item.new()
	item.icon = PlaceholderTexture2D.new()
	display.inventory.equip(item)

	display.inventory.unequip(0)

	assert_null(display._slot_icons[0].texture)
