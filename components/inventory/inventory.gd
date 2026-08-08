class_name Inventory
extends Node

signal slots_changed

@export var slot_count: int = 3

var slots: Array[Item] = []

func _ready() -> void:
	slots.resize(slot_count)

func equip(item: Item) -> bool:
	var empty_index := slots.find(null)
	if empty_index == -1:
		return false

	slots[empty_index] = item
	slots_changed.emit()
	return true

func unequip(slot_index: int) -> Item:
	if slot_index < 0 or slot_index >= slots.size():
		return null

	var item := slots[slot_index]
	if item == null:
		return null

	slots[slot_index] = null
	slots_changed.emit()
	return item

func has_empty_slot() -> bool:
	return slots.has(null)
