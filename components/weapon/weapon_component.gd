class_name WeaponComponent
extends Resource

## Called by WeaponSystem for each entry in WeaponSystem.components, in array
## order, threading the running damage total through every component. The
## base implementation is a no-op pass-through.
func modify_damage(current_damage: int) -> int:
	return current_damage
