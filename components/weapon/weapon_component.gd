class_name WeaponComponent
extends Node

## Called by WeaponSystem for each child in scene-tree order, threading the
## running damage total through every component. The base implementation is a
## no-op pass-through.
func modify_damage(current_damage: int) -> int:
	return current_damage
