class_name ItemPickup
extends Area2D

@export var item: Item

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if item != null:
		sprite.texture = item.icon

func _on_body_entered(body: Node2D) -> void:
	var inventory: Inventory = body.get_node_or_null("Inventory")
	if inventory == null:
		return

	if not inventory.has_empty_slot():
		return

	inventory.equip(item)
	queue_free()
