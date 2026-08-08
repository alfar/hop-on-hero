class_name ItemDropActivity
extends Activity

@export var items: Array[Item] = []

func execute(rng: RandomNumberGenerator, world_size: Vector2, spawn_parent: Node) -> void:
	if items.is_empty():
		push_error("ItemDropActivity: items is empty, cannot drop an item.")
		return

	var item: Item = items[rng.randi() % items.size()]
	var spawn_position := Vector2(rng.randf_range(0, world_size.x), rng.randf_range(0, world_size.y))

	var instance: ItemPickup = item.pickup_scene.instantiate()
	instance.position = spawn_position
	instance.item = item

	spawn_parent.add_child.call_deferred(instance)
