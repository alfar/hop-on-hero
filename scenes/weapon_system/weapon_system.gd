class_name WeaponSystem
extends Node2D

func get_total_damage() -> int:
	var current_damage := 0
	for child in get_children():
		if child is WeaponComponent:
			current_damage = child.modify_damage(current_damage)
	return current_damage
