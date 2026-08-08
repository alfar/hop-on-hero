extends GutTest

func _make_player() -> Node2D:
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var player: Node2D = player_scene.instantiate()
	player.weapon_spawn_parent = player
	return add_child_autofree(player)

func _make_pickup(item: Item) -> ItemPickup:
	var pickup_scene: PackedScene = load("res://scenes/item_pickup/item_pickup.tscn")
	var pickup: ItemPickup = pickup_scene.instantiate()
	pickup.item = item
	return add_child_autofree(pickup)

func test_walking_into_pickup_with_empty_slot_equips_and_frees_it() -> void:
	var player := _make_player()
	player.global_position = Vector2(3000, 2000)
	var item := Item.new()
	var pickup := _make_pickup(item)
	pickup.global_position = player.global_position

	await wait_physics_frames(2)

	var inventory: Inventory = player.get_node("Inventory")
	assert_eq(inventory.slots[0], item, "the item should have been equipped into the first slot")
	assert_true(not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "the pickup should be freed after being collected")

func test_walking_into_pickup_with_full_inventory_is_a_no_op() -> void:
	var player := _make_player()
	player.global_position = Vector2(3500, 2000)
	var inventory: Inventory = player.get_node("Inventory")
	for i in range(inventory.slot_count):
		inventory.equip(Item.new())
	var previous_slots := inventory.slots.duplicate()

	var item := Item.new()
	var pickup := _make_pickup(item)
	pickup.global_position = player.global_position

	await wait_physics_frames(2)

	assert_eq(inventory.slots, previous_slots, "inventory should be unchanged when already full")
	assert_true(is_instance_valid(pickup) and not pickup.is_queued_for_deletion(), "the pickup should remain in the world when the inventory is full")
