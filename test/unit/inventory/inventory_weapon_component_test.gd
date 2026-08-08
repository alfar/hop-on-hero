extends GutTest

## Test-only component that doubles the running damage total, used to prove
## InventoryWeaponComponent folds in slot order then per-item component
## order, rather than summing independently.
class DoubleDamageWeaponComponent:
	extends WeaponComponent

	func modify_damage(current_damage: int) -> int:
		return current_damage * 2

func _make_inventory(slot_count: int = 3) -> Inventory:
	var inventory := Inventory.new()
	inventory.slot_count = slot_count
	add_child_autofree(inventory)
	return inventory

func test_returns_input_unchanged_when_inventory_is_null() -> void:
	var component := InventoryWeaponComponent.new()

	assert_eq(component.modify_damage(42), 42)

func test_folds_over_single_equipped_item() -> void:
	var inventory := _make_inventory()
	var weapon_component := FixedDamageWeaponComponent.new()
	weapon_component.damage = 10
	var item := Item.new()
	item.components = [weapon_component]
	inventory.equip(item)

	var component := InventoryWeaponComponent.new()
	component.inventory = inventory

	assert_eq(component.modify_damage(0), 10)

func test_skips_null_slots() -> void:
	var inventory := _make_inventory(3)
	var weapon_component := FixedDamageWeaponComponent.new()
	weapon_component.damage = 10
	var item := Item.new()
	item.components = [weapon_component]
	inventory.equip(item)
	# Slots 1 and 2 remain null/empty.

	var component := InventoryWeaponComponent.new()
	component.inventory = inventory

	assert_eq(component.modify_damage(0), 10)

func test_folds_in_slot_order_then_per_item_component_order() -> void:
	var fixed_component := FixedDamageWeaponComponent.new()
	fixed_component.damage = 10

	var item_with_fixed := Item.new()
	item_with_fixed.components = [fixed_component]

	var item_with_double := Item.new()
	item_with_double.components = [DoubleDamageWeaponComponent.new()]

	var fixed_then_double := _make_inventory()
	fixed_then_double.equip(item_with_fixed)
	fixed_then_double.equip(item_with_double)

	var double_then_fixed := _make_inventory()
	double_then_fixed.equip(item_with_double)
	double_then_fixed.equip(item_with_fixed)

	var component_a := InventoryWeaponComponent.new()
	component_a.inventory = fixed_then_double
	var component_b := InventoryWeaponComponent.new()
	component_b.inventory = double_then_fixed

	assert_eq(component_a.modify_damage(0), 20)
	assert_eq(component_b.modify_damage(0), 10)
