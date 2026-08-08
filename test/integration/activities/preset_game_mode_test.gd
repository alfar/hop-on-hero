extends GutTest

## PresetGameMode.is_round_won queries the "enemy" group via
## spawn_parent.get_tree(), so this needs a live scene tree and lives under
## test/integration/ rather than test/unit/.
func _make_spawn_parent() -> Node:
	return add_child_autofree(Node.new())

func test_should_schedule_next_activity_cuts_off_at_activity_count() -> void:
	var game_mode := PresetGameMode.new()
	game_mode.activity_count = 3

	assert_true(game_mode.should_schedule_next_activity(0))
	assert_true(game_mode.should_schedule_next_activity(2))
	assert_false(game_mode.should_schedule_next_activity(3))
	assert_false(game_mode.should_schedule_next_activity(4))

func test_is_round_won_is_false_before_activity_count_is_reached_regardless_of_enemies() -> void:
	var game_mode := PresetGameMode.new()
	game_mode.activity_count = 3
	var spawn_parent := _make_spawn_parent()

	assert_false(game_mode.is_round_won(2, spawn_parent), "count not yet reached, even with zero enemies alive")

func test_is_round_won_is_false_while_an_enemy_remains_after_count_is_reached() -> void:
	var game_mode := PresetGameMode.new()
	game_mode.activity_count = 1
	var spawn_parent := _make_spawn_parent()

	var enemy := Node2D.new()
	enemy.add_to_group("enemy")
	add_child_autofree(enemy)

	assert_false(game_mode.is_round_won(1, spawn_parent))

func test_is_round_won_is_true_once_count_is_reached_and_enemies_are_cleared() -> void:
	var game_mode := PresetGameMode.new()
	game_mode.activity_count = 1
	var spawn_parent := _make_spawn_parent()

	assert_true(game_mode.is_round_won(1, spawn_parent), "count reached and no enemies alive should win")
