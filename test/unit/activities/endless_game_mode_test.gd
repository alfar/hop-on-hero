extends GutTest

func test_should_schedule_next_activity_is_always_true() -> void:
	var game_mode := EndlessGameMode.new()

	assert_true(game_mode.should_schedule_next_activity(0))
	assert_true(game_mode.should_schedule_next_activity(500))

func test_is_round_won_is_always_false() -> void:
	var game_mode := EndlessGameMode.new()
	var spawn_parent: Node = add_child_autofree(Node.new())

	assert_false(game_mode.is_round_won(0, spawn_parent))
	assert_false(game_mode.is_round_won(9999, spawn_parent))
