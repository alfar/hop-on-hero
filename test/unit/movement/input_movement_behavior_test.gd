extends GutTest

func after_each() -> void:
	Input.action_release("left")
	Input.action_release("right")
	Input.action_release("up")
	Input.action_release("down")

func test_returns_zero_when_no_input_pressed() -> void:
	var behavior := InputMovementBehavior.new()
	behavior.speed = 400

	var velocity: Vector2 = behavior.get_velocity(Vector2.ZERO)

	assert_eq(velocity, Vector2.ZERO)

func test_returns_scaled_velocity_for_single_direction() -> void:
	var behavior := InputMovementBehavior.new()
	behavior.speed = 400
	Input.action_press("right")

	var velocity: Vector2 = behavior.get_velocity(Vector2.ZERO)

	assert_eq(velocity, Vector2.RIGHT * 400)

func test_opposing_directions_cancel_out() -> void:
	var behavior := InputMovementBehavior.new()
	behavior.speed = 400
	Input.action_press("left")
	Input.action_press("right")

	var velocity: Vector2 = behavior.get_velocity(Vector2.ZERO)

	assert_eq(velocity, Vector2.ZERO)
