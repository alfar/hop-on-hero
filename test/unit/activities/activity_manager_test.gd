extends GutTest

func test_start_triggers_first_activity_using_injected_rng() -> void:
	var activity_manager := ActivityManager.new()
	add_child_autofree(activity_manager)
	activity_manager.spawn_parent = activity_manager
	activity_manager.activities = [Activity.new()]

	var world := World.new()
	var tile_map_layer := TileMapLayer.new()
	tile_map_layer.name = "TileMapLayer"
	world.add_child(tile_map_layer)
	activity_manager.world = add_child_autofree(world)
	activity_manager.world.world_size = Vector2(640, 640)

	activity_manager.rng = RandomNumberGenerator.new()
	activity_manager.rng.seed = 42

	activity_manager.start()

	assert_between(activity_manager._timer.wait_time, 20.0, 40.0, "start() should schedule the next activity's timer using the injected rng")
