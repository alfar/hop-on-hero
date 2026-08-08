extends GutTest

## _drop(slot_index) is called directly rather than simulating the actual
## drop_slot_1/2/3 keypress -- GUT's own input simulation is documented as
## unreliable under --headless, which this project's test suite always runs
## under. This still proves the drop logic; only the thin key-to-action
## binding in project.godot's InputMap goes unexercised.

## Uses a separate spawn_parent (mirroring game.tscn's real topology, where
## weapon_spawn_parent is the origin-positioned Game root, not Player itself)
## rather than WeaponTestHelpers.make_player()'s self-referencing spawn_parent
## -- InventoryDropInput._drop() sets global_position before the deferred
## add_child reparents the pickup, so a non-origin, moving spawn_parent like
## Player would shift the pickup's final position once reparented.
func _make_player() -> Node2D:
	var spawn_parent := Node.new()
	add_child_autofree(spawn_parent)

	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var player: Node2D = player_scene.instantiate()
	player.weapon_spawn_parent = spawn_parent
	return add_child_autofree(player)

func test_dropping_a_filled_slot_spawns_pickup_and_clears_slot() -> void:
	var player := _make_player()
	player.global_position = Vector2(2000, 2000)
	var inventory: Inventory = player.get_node("Inventory")
	var drop_input: InventoryDropInput = player.get_node("InventoryDropInput")
	var item := Item.new()
	item.pickup_scene = load("res://scenes/item_pickup/item_pickup.tscn")
	inventory.equip(item)

	drop_input._drop(0)

	# unequip() happens synchronously inside _drop(), so check it immediately;
	# only the deferred add_child for the pickup needs a physics frame.
	assert_eq(inventory.slots[0], null, "the slot should be cleared after dropping")

	await wait_physics_frames(1)

	var pickup: ItemPickup = player.weapon_spawn_parent.get_node("ItemPickup")
	assert_eq(pickup.item, item, "the dropped item's pickup should carry the dropped item")
	assert_almost_eq(pickup.global_position.distance_to(player.global_position), drop_input.drop_distance, 0.01, "the pickup should be thrown drop_distance away from the player, not placed on top of them")

func test_dropped_pickup_does_not_immediately_re_equip_the_player() -> void:
	var player := _make_player()
	player.global_position = Vector2(2200, 2000)
	var inventory: Inventory = player.get_node("Inventory")
	var drop_input: InventoryDropInput = player.get_node("InventoryDropInput")
	var item := Item.new()
	item.pickup_scene = load("res://scenes/item_pickup/item_pickup.tscn")
	inventory.equip(item)

	drop_input._drop(0)
	await wait_physics_frames(3)

	assert_eq(inventory.slots[0], null, "the player should not immediately walk back into and re-collect the item they just dropped")

func test_dropping_an_empty_slot_is_a_no_op() -> void:
	var player := _make_player()
	player.global_position = Vector2(2500, 2000)
	var inventory: Inventory = player.get_node("Inventory")
	var drop_input: InventoryDropInput = player.get_node("InventoryDropInput")

	drop_input._drop(0)
	await wait_physics_frames(1)

	assert_eq(inventory.slots, [null, null, null])
	assert_null(player.weapon_spawn_parent.get_node_or_null("ItemPickup"), "no pickup should be spawned for an empty slot")
