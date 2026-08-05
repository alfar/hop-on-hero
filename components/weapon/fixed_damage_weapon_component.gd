class_name FixedDamageWeaponComponent
extends WeaponComponent

@export var damage: int = 10

func modify_damage(current_damage: int) -> int:
	return current_damage + damage
