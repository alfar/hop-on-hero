extends GutTest

func test_item_holds_assigned_components() -> void:
	var component := FixedDamageWeaponComponent.new()
	var item := Item.new()
	item.display_name = "Test Item"
	item.components = [component]

	assert_eq(item.display_name, "Test Item")
	assert_eq(item.components, [component])
