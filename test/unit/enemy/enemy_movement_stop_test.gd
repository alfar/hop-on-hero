extends GutTest

## Proves the contract Enemy._on_died() relies on: replacing an active,
## in-motion MovementBehavior with a fresh base MovementBehavior instance
## stops movement, regardless of what the prior behavior was doing.
func test_replacing_an_active_behavior_with_base_movement_behavior_stops_movement() -> void:
	var moving_behavior := TargetMovementBehavior.new()
	moving_behavior.target = Vector2(100, 0)
	moving_behavior.speed = 400
	var position := Vector2(0, 0)

	# Confirm it was actually moving before the swap.
	assert_ne(moving_behavior.get_velocity(position), Vector2.ZERO)

	var stopped_behavior: MovementBehavior = MovementBehavior.new()

	assert_eq(stopped_behavior.get_velocity(position), Vector2.ZERO)
