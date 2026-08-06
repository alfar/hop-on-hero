extends GutTest

func test_returns_zero_when_player_is_null() -> void:
	var behavior := ChasePlayerMovementBehavior.new()

	assert_eq(behavior.get_velocity(Vector2(50, 50)), Vector2.ZERO)

func test_returns_velocity_toward_player_at_speed_magnitude() -> void:
	var player := Node2D.new()
	player.global_position = Vector2(100, 0)
	add_child_autofree(player)

	var behavior := ChasePlayerMovementBehavior.new()
	behavior.player = player
	behavior.speed = 400

	var velocity: Vector2 = behavior.get_velocity(Vector2(0, 0))

	assert_eq(velocity, Vector2.RIGHT * 400)

func test_returns_zero_when_player_reference_is_freed() -> void:
	var player := Node2D.new()
	add_child(player)

	var behavior := ChasePlayerMovementBehavior.new()
	behavior.player = player

	player.free()

	assert_eq(behavior.get_velocity(Vector2(50, 50)), Vector2.ZERO)
