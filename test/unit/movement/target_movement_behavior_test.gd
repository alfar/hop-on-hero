extends GutTest

func test_base_movement_behavior_returns_zero() -> void:
	var behavior := MovementBehavior.new()

	var velocity: Vector2 = behavior.get_velocity(Vector2(50, 50))

	assert_eq(velocity, Vector2.ZERO)

func test_returns_zero_when_within_threshold_of_target() -> void:
	var behavior := TargetMovementBehavior.new()
	behavior.target = Vector2(100, 100)
	behavior.speed = 400

	var velocity: Vector2 = behavior.get_velocity(Vector2(105, 100))

	assert_eq(velocity, Vector2.ZERO)

func test_returns_scaled_direction_when_outside_threshold() -> void:
	var behavior := TargetMovementBehavior.new()
	behavior.target = Vector2(100, 0)
	behavior.speed = 400

	var velocity: Vector2 = behavior.get_velocity(Vector2(0, 0))

	assert_eq(velocity, Vector2.RIGHT * 400)
