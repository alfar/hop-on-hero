class_name InventoryDropInput
extends Node

@export var inventory: Inventory
@export var spawn_parent: Node
@export var drop_distance: float = 80.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("drop_slot_1"):
		_drop(0)
	elif event.is_action_pressed("drop_slot_2"):
		_drop(1)
	elif event.is_action_pressed("drop_slot_3"):
		_drop(2)

func _drop(slot_index: int) -> void:
	var item := inventory.unequip(slot_index)
	if item == null:
		return

	var instance: ItemPickup = item.pickup_scene.instantiate()
	var direction := Vector2.RIGHT.rotated(randf_range(0, TAU))
	instance.global_position = get_parent().global_position + direction * drop_distance
	instance.item = item

	spawn_parent.add_child.call_deferred(instance)
