extends GutTest

func test_empty_stack_returns_zero() -> void:
	var stack := MovementStack.new()

	assert_eq(stack.get_velocity(Vector2(50, 50)), Vector2.ZERO)

func test_returns_top_behavior_velocity_when_not_finished() -> void:
	var behavior := TargetMovementBehavior.new()
	behavior.target = Vector2(100, 0)
	behavior.speed = 400

	var stack := MovementStack.new()
	stack.push_behavior(behavior)

	assert_eq(stack.get_velocity(Vector2(0, 0)), Vector2.RIGHT * 400)

func test_pops_finished_behavior_and_falls_through() -> void:
	var chase_behavior := ChasePlayerMovementBehavior.new()
	chase_behavior.player = Node2D.new()
	chase_behavior.player.global_position = Vector2(0, 100)
	chase_behavior.speed = 400

	var target_behavior := TargetMovementBehavior.new()
	target_behavior.target = Vector2(0, 0)

	var stack := MovementStack.new()
	stack.push_behavior(chase_behavior)
	stack.push_behavior(target_behavior)

	var position := Vector2(0, 0)

	# The target is already reached, so the top behavior is finished and
	# should be popped, falling through to the chase-player behavior below.
	var velocity := stack.get_velocity(position)

	assert_eq(velocity, position.direction_to(chase_behavior.player.global_position) * chase_behavior.speed)
	assert_eq(stack.behaviors.size(), 1, "the finished TargetMovementBehavior should have been popped")

	chase_behavior.player.free()

func test_push_and_pop_behavior_round_trip() -> void:
	var behavior := MovementBehavior.new()
	var stack := MovementStack.new()

	stack.push_behavior(behavior)

	assert_eq(stack.pop_behavior(), behavior)
	assert_true(stack.behaviors.is_empty())

func test_pop_behavior_on_empty_stack_returns_null() -> void:
	var stack := MovementStack.new()

	assert_eq(stack.pop_behavior(), null)
