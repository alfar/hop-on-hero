extends GutTest

func test_modify_damage_adds_configured_damage_to_current_total() -> void:
	var component: FixedDamageWeaponComponent = autofree(FixedDamageWeaponComponent.new())
	component.damage = 10

	var result: int = component.modify_damage(0)

	assert_eq(result, 10)

func test_modify_damage_adds_to_a_nonzero_running_total() -> void:
	var component: FixedDamageWeaponComponent = autofree(FixedDamageWeaponComponent.new())
	component.damage = 15

	var result: int = component.modify_damage(5)

	assert_eq(result, 20)
