extends GutTest

func test_start_picks_a_duration_within_wait_min_and_wait_max() -> void:
	var gate := TimerActivityGate.new()
	gate.wait_min = 5.0
	gate.wait_max = 10.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	gate.start(rng, null)

	assert_false(gate.is_ready(4.99, null), "should not be ready before the picked duration")
	assert_true(gate.is_ready(10.0, null), "should always be ready by wait_max")

func test_is_ready_becomes_true_once_elapsed_time_reaches_the_target() -> void:
	var gate := TimerActivityGate.new()
	gate.wait_min = 20.0
	gate.wait_max = 20.0
	var rng := RandomNumberGenerator.new()

	gate.start(rng, null)

	assert_false(gate.is_ready(19.9, null))
	assert_true(gate.is_ready(20.0, null))
	assert_true(gate.is_ready(20.1, null))
