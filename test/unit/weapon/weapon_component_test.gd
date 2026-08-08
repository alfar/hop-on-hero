extends GutTest

func test_base_modify_damage_returns_input_unchanged() -> void:
	var component := WeaponComponent.new()

	var result: int = component.modify_damage(42)

	assert_eq(result, 42)
