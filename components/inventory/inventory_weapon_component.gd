class_name InventoryWeaponComponent
extends WeaponComponent

## Not @export: Inventory is a Node, and per this project's established
## constraint a Resource script cannot @export a Node-derived type in Godot
## 4.7. Set by Player._ready() once both Inventory and WeaponSystem exist.
var inventory: Inventory

func modify_damage(current_damage: int) -> int:
	if inventory == null:
		return current_damage

	for item in inventory.slots:
		if item == null:
			continue
		for component in item.components:
			current_damage = component.modify_damage(current_damage)

	return current_damage
