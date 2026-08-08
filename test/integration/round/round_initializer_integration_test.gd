extends GutTest

func after_each() -> void:
	GameEvents.next_level_seed = 0

func test_world_size_changed_reflects_final_post_fill_size() -> void:
	var game_scene: PackedScene = load("res://scenes/game.tscn")
	var game: Node2D = add_child_autofree(game_scene.instantiate())
	await wait_physics_frames(1)

	var world: World = game.get_node("World")

	assert_eq(GameEvents.world_size_changed.get_value(), world.world_size, "world_size_changed's cached value must reflect the final, post-fill world size")
