extends GutTest

## Proves the contract Enemy._on_died() relies on: replacing an active,
## in-motion MovementStack with a fresh empty MovementStack instance
## stops movement, regardless of what the prior stack was doing.
func test_replacing_an_active_stack_with_empty_movement_stack_stops_movement() -> void:
	var moving_behavior := TargetMovementBehavior.new()
	moving_behavior.target = Vector2(100, 0)
	moving_behavior.speed = 400
	var moving_stack := MovementStack.new()
	moving_stack.push_behavior(moving_behavior)
	var position := Vector2(0, 0)

	# Confirm it was actually moving before the swap.
	assert_ne(moving_stack.get_velocity(position), Vector2.ZERO)

	var stopped_stack := MovementStack.new()

	assert_eq(stopped_stack.get_velocity(position), Vector2.ZERO)
