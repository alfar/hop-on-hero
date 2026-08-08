extends GutTest

func _make_item() -> Item:
	var item := Item.new()
	item.display_name = "Test Item"
	item.pickup_scene = load("res://scenes/item_pickup/item_pickup.tscn")
	return item

func test_execute_spawns_chosen_items_pickup_within_world_bounds() -> void:
	var spawn_parent := Node.new()
	add_child_autofree(spawn_parent)

	var item := _make_item()
	var activity := ItemDropActivity.new()
	activity.items = [item]

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var world_size := Vector2(1000, 800)

	activity.execute(rng, world_size, spawn_parent)
	await wait_physics_frames(1)

	var pickup: ItemPickup = spawn_parent.get_node("ItemPickup")
	assert_eq(pickup.item, item, "the spawned pickup should carry the chosen item")
	assert_true(Rect2(Vector2.ZERO, world_size).has_point(pickup.position), "the pickup should spawn within world bounds")
