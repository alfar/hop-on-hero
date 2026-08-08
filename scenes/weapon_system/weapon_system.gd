class_name WeaponSystem
extends Node2D

@export var components: Array[WeaponComponent] = []

func get_total_damage() -> int:
	var current_damage := 0
	for component in components:
		current_damage = component.modify_damage(current_damage)
	return current_damage
