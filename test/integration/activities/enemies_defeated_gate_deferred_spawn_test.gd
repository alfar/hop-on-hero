extends GutTest

## Regression test for the deferred-add_child race: activities like
## BossActivity spawn their enemy via spawn_parent.add_child.call_deferred(...),
## so the enemy isn't actually in the "enemy" group until later in the same
## frame (or the next one). ActivityManager must not poll a gate on the same
## physics frame it started waiting, or EnemiesDefeatedActivityGate would
## falsely report "ready" before the enemy it's meant to wait for exists.
class DeferredSpawnActivity extends Activity:
	func execute(_rng: RandomNumberGenerator, _world_size: Vector2, spawn_parent: Node) -> void:
		var dummy := Node2D.new()
		dummy.add_to_group("enemy")
		spawn_parent.add_child.call_deferred(dummy)

func test_activity_manager_does_not_advance_on_the_same_frame_a_deferred_enemy_is_spawned() -> void:
	var activity_manager := ActivityManager.new()
	add_child_autofree(activity_manager)
	activity_manager.spawn_parent = activity_manager
	activity_manager.rng = RandomNumberGenerator.new()

	var world := World.new()
	var tile_map_layer := TileMapLayer.new()
	tile_map_layer.name = "TileMapLayer"
	world.add_child(tile_map_layer)
	activity_manager.world = add_child_autofree(world)
	activity_manager.world.world_size = Vector2(640, 640)

	var activity := DeferredSpawnActivity.new()
	activity.gate = EnemiesDefeatedActivityGate.new()
	var second_activity := ActivitiesTestHelpers.SpyActivity.new()
	activity_manager.activities = [activity]

	activity_manager.start()
	# ActivityManager skips polling on the very frame the activity was
	# triggered; the deferred add_child also resolves during this window.
	await wait_physics_frames(1)

	activity_manager.activities = [second_activity]
	await wait_physics_frames(1)

	assert_eq(second_activity.execute_count, 0, "the gate must not report ready before the deferred enemy actually exists in the group")

	var enemies := activity_manager.get_tree().get_nodes_in_group("enemy")
	assert_eq(enemies.size(), 1, "the deferred add_child should have resolved the dummy enemy into the group by now")
	var enemy: Node2D = enemies[0]
	enemy.queue_free()
	await wait_physics_frames(2)

	assert_eq(second_activity.execute_count, 1, "once the deferred-spawned enemy is gone, the gate should report ready and advance")
