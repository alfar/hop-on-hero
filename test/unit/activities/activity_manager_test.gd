extends GutTest

class ManualGate extends ActivityGate:
	var ready: bool = false

	func is_ready(_elapsed_time: float, _spawn_parent: Node) -> bool:
		return ready

## Appends its label to a shared log array on execute(), so a test can
## assert not just how many times each activity ran but the exact order.
class LabeledSpyActivity extends Activity:
	var label: String
	var log_entries: Array

	func execute(_rng: RandomNumberGenerator, _world_size: Vector2, _spawn_parent: Node) -> void:
		log_entries.append(label)

func _make_manager() -> ActivityManager:
	var activity_manager := ActivityManager.new()
	add_child_autofree(activity_manager)
	activity_manager.spawn_parent = activity_manager
	activity_manager.rng = RandomNumberGenerator.new()
	activity_manager.rng.seed = 42

	var world := World.new()
	var tile_map_layer := TileMapLayer.new()
	tile_map_layer.name = "TileMapLayer"
	world.add_child(tile_map_layer)
	activity_manager.world = add_child_autofree(world)
	activity_manager.world.world_size = Vector2(640, 640)

	return activity_manager

func test_start_executes_the_first_activity_and_starts_its_gate() -> void:
	var activity_manager := _make_manager()
	var activity := ActivitiesTestHelpers.SpyActivity.new()
	activity_manager.activities = [activity]

	activity_manager.start()

	assert_eq(activity.execute_count, 1, "start() should execute the first activity exactly once")
	assert_eq(activity_manager.activities_triggered, 1)

func test_advances_once_the_current_gate_reports_ready() -> void:
	var activity_manager := _make_manager()
	var first_activity := ActivitiesTestHelpers.SpyActivity.new()
	first_activity.gate = ManualGate.new()
	var second_activity := ActivitiesTestHelpers.SpyActivity.new()
	second_activity.gate = ManualGate.new()
	activity_manager.activities = [first_activity]

	activity_manager.start()
	await wait_physics_frames(2)
	assert_eq(second_activity.execute_count, 0, "the second activity should not exist yet since activities is a single-element pool")

	activity_manager.activities = [second_activity]
	first_activity.gate.ready = true
	await wait_physics_frames(1)

	assert_eq(second_activity.execute_count, 1, "the next activity should trigger once the current gate reports ready")

func test_does_not_advance_before_the_gate_is_ready() -> void:
	var activity_manager := _make_manager()
	var activity := ActivitiesTestHelpers.SpyActivity.new()
	activity.gate = ManualGate.new()
	activity_manager.activities = [activity]

	activity_manager.start()
	await wait_physics_frames(5)

	assert_eq(activity.execute_count, 1, "no second trigger should happen while the gate is not ready")

func test_stops_scheduling_once_game_mode_says_so() -> void:
	var activity_manager := _make_manager()
	var activity := ActivitiesTestHelpers.SpyActivity.new()
	activity.gate = ManualGate.new()
	activity_manager.activities = [activity]
	var game_mode := PresetGameMode.new()
	game_mode.activity_count = 1
	activity_manager.game_mode = game_mode

	activity_manager.start()
	activity.gate.ready = true
	await wait_physics_frames(5)

	assert_eq(activity.execute_count, 1, "PresetGameMode with activity_count = 1 should never trigger a second activity")

func test_declares_win_and_emits_round_ended_once_game_mode_reports_won() -> void:
	var activity_manager := _make_manager()
	var activity := ActivitiesTestHelpers.SpyActivity.new()
	activity_manager.activities = [activity]
	activity_manager.game_mode = ActivitiesTestHelpers.AlwaysWonGameMode.new()

	var received := []
	var callable := func(time, outcome): received.append([time, outcome])
	GameEvents.round_ended.connect(callable)

	activity_manager.start()
	await wait_physics_frames(2)

	assert_eq(received, [[0.0, GameEvents.RoundOutcome.WON]], "with no player/game node present, the win should fall back to WON with 0.0 elapsed time")
	assert_true(activity_manager.round_over)
	GameEvents.round_ended.disconnect(callable)

func test_pick_weighted_activity_favors_higher_weight_with_a_fixed_seed() -> void:
	var activity_manager := _make_manager()
	var low := Activity.new()
	low.weight = 1.0
	var high := Activity.new()
	high.weight = 9.0
	activity_manager.activities = [low, high]

	var picks := []
	for i in 10:
		picks.append(activity_manager._pick_weighted_activity())

	var high_count := picks.count(high)
	assert_gt(high_count, picks.count(low), "the activity with 9x the weight should be picked far more often across a fixed-seed sample")

func test_pick_weighted_activity_treats_non_positive_total_weight_as_empty() -> void:
	var activity_manager := _make_manager()
	var a := Activity.new()
	a.weight = 0.0
	var b := Activity.new()
	b.weight = -5.0
	activity_manager.activities = [a, b]

	assert_null(activity_manager._pick_weighted_activity())

## AC-07: the same seed must reproduce the identical sequence of activity
## picks under PresetGameMode -- the activity_count is a fixed export, not
## randomized, but which activities run and in what order is still fully
## seed-determined.
func test_same_seed_produces_the_same_activity_sequence_under_preset_mode() -> void:
	var first_sequence := await _run_preset_mode_and_collect_labels(123, 5)
	var second_sequence := await _run_preset_mode_and_collect_labels(123, 5)

	assert_eq(first_sequence, second_sequence, "the same seed should reproduce the identical sequence of activity picks")
	assert_eq(first_sequence.size(), 5)

func _run_preset_mode_and_collect_labels(seed_value: int, count: int) -> Array:
	var activity_manager := _make_manager()
	activity_manager.rng.seed = seed_value

	var log_entries := []
	var a := LabeledSpyActivity.new()
	a.label = "a"
	a.log_entries = log_entries
	a.gate = ActivityGate.new()
	a.weight = 2.0
	var b := LabeledSpyActivity.new()
	b.label = "b"
	b.log_entries = log_entries
	b.gate = ActivityGate.new()
	b.weight = 1.0
	activity_manager.activities = [a, b]

	var game_mode := PresetGameMode.new()
	game_mode.activity_count = count
	activity_manager.game_mode = game_mode

	activity_manager.start()
	await wait_physics_frames(count * 2 + 2)

	return log_entries
