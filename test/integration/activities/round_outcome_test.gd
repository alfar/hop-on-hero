extends GutTest

func after_each() -> void:
	get_tree().paused = false
	GameEvents.next_level_seed = 0

## AC-03/AC-04: PresetGameMode must not win while an enemy remains, even
## after its activity_count is reached, and must win the moment the last one
## is gone. Uses a bare ActivityManager (not a full game.tscn load) so the
## "enemy" group and activities_triggered count are fully under this test's
## control from the start, rather than depending on -- and having to undo --
## whatever game.tscn's default EndlessGameMode happened to trigger first.
func test_preset_game_mode_wins_once_count_reached_and_enemies_cleared() -> void:
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

	var game_mode := PresetGameMode.new()
	game_mode.activity_count = 1
	activity_manager.game_mode = game_mode
	activity_manager.activities = [ActivitiesTestHelpers.SpyActivity.new()]

	var enemy := Node2D.new()
	enemy.add_to_group("enemy")
	add_child_autofree(enemy)

	var received := []
	var callable := func(time, outcome): received.append([time, outcome])
	GameEvents.round_ended.connect(callable)

	activity_manager.start()
	await wait_physics_frames(2)
	assert_eq(received.size(), 0, "round_ended should not fire while an enemy remains")

	enemy.queue_free()
	await wait_physics_frames(2)

	assert_eq(received.size(), 1, "round_ended should fire exactly once the last enemy is gone")
	assert_eq(received[0][1], GameEvents.RoundOutcome.WON)
	GameEvents.round_ended.disconnect(callable)

## AC-08: if the player's death and the active GameMode's win condition
## become true within the same resolution window, the round must resolve as
## PYRRHIC_VICTORY exactly once -- not a plain LOST, and not a double
## WON+LOST emission. is_dead is forced true (via health.died.emit()) before
## any physics frame elapses, so this holds regardless of which side
## (ActivityManager's poll or Player's own animation-gated resolution)
## actually gets to declare the outcome first. This scenario needs the real
## Player/ActivityManager sibling wiring from game.tscn, so it uses a full
## scene load rather than the lighter fixture above.
func test_simultaneous_win_and_player_death_resolves_as_pyrrhic_victory() -> void:
	var game_scene: PackedScene = load("res://scenes/game.tscn")
	var game: Node2D = add_child_autofree(game_scene.instantiate())
	await wait_physics_frames(1)

	var activity_manager: ActivityManager = game.get_node("ActivityManager")
	var player := game.get_node("Player")

	activity_manager.game_mode = ActivitiesTestHelpers.AlwaysWonGameMode.new()

	var received := []
	var callable := func(time, outcome): received.append([time, outcome])
	GameEvents.round_ended.connect(callable)

	var health: HealthComponent = player.get_node("Status").get_node("HealthComponent")
	health.died.emit()

	# Deliberately do NOT await the player's death animation here: is_dead is
	# set synchronously the instant died fires (before the animation even
	# starts), so ActivityManager's per-physics-frame win-check reliably
	# resolves the outcome first, well before the (slow, under headless)
	# animation would ever complete. Awaiting animation_finished here would
	# risk a deadlock -- ActivityManager's win declaration emits round_ended,
	# which triggers GameEvents.paused, which pauses the real SceneTree and
	# halts the AnimationPlayer's own progress before it can finish.
	await wait_physics_frames(3)

	assert_eq(received.size(), 1, "round_ended should fire exactly once, not double-emitted by both ActivityManager and Player")
	assert_eq(received[0][1], GameEvents.RoundOutcome.PYRRHIC_VICTORY, "a simultaneous win and death should resolve as a Pyrrhic Victory")
	GameEvents.round_ended.disconnect(callable)
