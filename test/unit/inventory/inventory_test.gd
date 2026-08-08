extends GutTest

func _make_inventory(slot_count: int = 3) -> Inventory:
	var inventory := Inventory.new()
	inventory.slot_count = slot_count
	add_child_autofree(inventory)
	return inventory

func test_new_inventory_has_empty_slots() -> void:
	var inventory := _make_inventory(3)

	assert_eq(inventory.slots.size(), 3)
	assert_eq(inventory.slots, [null, null, null])
	assert_true(inventory.has_empty_slot())

func test_equip_into_empty_slot_returns_true() -> void:
	var inventory := _make_inventory(3)
	var item := Item.new()
	watch_signals(inventory)

	var result := inventory.equip(item)

	assert_true(result)
	assert_eq(inventory.slots[0], item)
	assert_signal_emitted(inventory, "slots_changed")

func test_equip_when_full_returns_false_and_does_not_modify_slots() -> void:
	var inventory := _make_inventory(1)
	var first_item := Item.new()
	var second_item := Item.new()
	inventory.equip(first_item)
	watch_signals(inventory)

	var result := inventory.equip(second_item)

	assert_false(result)
	assert_eq(inventory.slots, [first_item])
	assert_signal_not_emitted(inventory, "slots_changed")

func test_unequip_filled_slot_clears_it_and_returns_item() -> void:
	var inventory := _make_inventory(3)
	var item := Item.new()
	inventory.equip(item)
	watch_signals(inventory)

	var result := inventory.unequip(0)

	assert_eq(result, item)
	assert_eq(inventory.slots[0], null)
	assert_signal_emitted(inventory, "slots_changed")

func test_unequip_empty_slot_returns_null_and_does_not_modify_other_slots() -> void:
	var inventory := _make_inventory(3)
	var item := Item.new()
	inventory.equip(item)
	inventory.equip(Item.new())
	watch_signals(inventory)

	var result := inventory.unequip(2)

	assert_eq(result, null)
	assert_eq(inventory.slots[0], item)
	assert_ne(inventory.slots[1], null)
	assert_signal_not_emitted(inventory, "slots_changed")
