class_name InventoryDisplay
extends Node2D

const SLOT_SIZE := Vector2(32, 32)
const SLOT_SPACING := 32.0
const MARGIN := Vector2(24, 32)

var _inventory : Inventory

func _ready() -> void:
	var viewport_size := get_viewport_rect().size
	position = Vector2(MARGIN.x, viewport_size.y - SLOT_SIZE.y - MARGIN.y)

@export var inventory: Inventory:
	get:
		return _inventory
	set(value):
		if _inventory != null:
			_inventory.slots_changed.disconnect(_on_slots_changed)
		for rect in _slot_icons:
			rect.queue_free()
		_slot_icons.clear()

		_inventory = value
		if _inventory == null:
			return

		for i in range(inventory.slot_count):
			var rect := TextureRect.new()
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.custom_minimum_size = SLOT_SIZE
			rect.size = SLOT_SIZE
			rect.position = Vector2(i * (SLOT_SIZE.x + SLOT_SPACING), 0)
			add_child(rect)
			_slot_icons.append(rect)

		inventory.slots_changed.connect(_on_slots_changed)
		_on_slots_changed()

var _slot_icons: Array[TextureRect] = []

func _on_slots_changed() -> void:
	for i in range(_slot_icons.size()):
		var slot_item: Item = inventory.slots[i] if i < inventory.slots.size() else null
		_slot_icons[i].texture = slot_item.icon if slot_item != null else null
