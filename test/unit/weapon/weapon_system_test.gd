extends GutTest

## Test-only component that doubles the running damage total, used to prove
## WeaponSystem folds over its components in array order rather than summing
## them independently.
class DoubleDamageWeaponComponent:
	extends WeaponComponent

	func modify_damage(current_damage: int) -> int:
		return current_damage * 2

func _make_weapon_system() -> WeaponSystem:
	return autofree(WeaponSystem.new())

func test_returns_zero_with_no_components() -> void:
	var weapon_system := _make_weapon_system()

	assert_eq(weapon_system.get_total_damage(), 0)

func test_returns_configured_damage_with_one_fixed_damage_component() -> void:
	var weapon_system := _make_weapon_system()
	var component := FixedDamageWeaponComponent.new()
	component.damage = 10
	weapon_system.components.append(component)

	assert_eq(weapon_system.get_total_damage(), 10)

func test_component_order_affects_the_result() -> void:
	var fixed_then_double := _make_weapon_system()
	var fixed_component_a := FixedDamageWeaponComponent.new()
	fixed_component_a.damage = 10
	fixed_then_double.components.append(fixed_component_a)
	fixed_then_double.components.append(DoubleDamageWeaponComponent.new())

	var double_then_fixed := _make_weapon_system()
	double_then_fixed.components.append(DoubleDamageWeaponComponent.new())
	var fixed_component_b := FixedDamageWeaponComponent.new()
	fixed_component_b.damage = 10
	double_then_fixed.components.append(fixed_component_b)

	assert_eq(fixed_then_double.get_total_damage(), 20)
	assert_eq(double_then_fixed.get_total_damage(), 10)
