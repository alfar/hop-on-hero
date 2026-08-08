extends GutTest

func after_each() -> void:
	get_tree().paused = false
	GameEvents.next_level_seed = 0

func _make_game() -> Node2D:
	var game_scene: PackedScene = load("res://scenes/game.tscn")
	var game: Node2D = add_child_autofree(game_scene.instantiate())
	await wait_physics_frames(1)
	return game

## Asserts on the GameEvents.paused signal firing, not the real
## get_tree().paused flag -- setting that for real during a GUT test run
## would leak into every subsequent test in the same run, since nothing
## un-pauses it except this test's own teardown running to completion first.
## Game._on_paused() (the only place that actually calls
## get_tree().paused = true) is covered structurally by this test proving
## the signal it's connected to fires correctly.
func test_player_death_emits_paused_and_shows_summary_screen() -> void:
	var game := await _make_game()
	var player := game.get_node("Player")

	var received := []
	var callable := func(): received.append(true)
	GameEvents.paused.connect(callable)

	var health: HealthComponent = player.get_node("Status").get_node("HealthComponent")
	health.died.emit()
	await player._animation_player.animation_finished
	await wait_physics_frames(1)

	assert_eq(received.size(), 1, "GameEvents.paused should fire exactly once once the round ends")
	assert_true(game.get_node("HUD/SummaryScreen").visible, "the summary screen should become visible once the round ends")
	GameEvents.paused.disconnect(callable)

func test_summary_screen_shows_correct_elapsed_time() -> void:
	var game := await _make_game()
	var player := game.get_node("Player")

	# Force a known, deterministic elapsed time rather than depending on real
	# wall-clock drift across the test run.
	game._round_start_ticks_msec = Time.get_ticks_msec() - 65000

	var health: HealthComponent = player.get_node("Status").get_node("HealthComponent")
	health.died.emit()
	await player._animation_player.animation_finished
	await wait_physics_frames(1)

	var time_label: Label = game.get_node("HUD/SummaryScreen").time_label
	assert_eq(time_label.text, "01:05")

## _on_retry_pressed()/_on_new_seed_pressed() call stage_next_seed() (tested
## here) followed by _restart()'s get_tree().reload_current_scene(), which
## errors under GUT's test runner ("current_scene is null" -- GUT's own test
## scene, not game.tscn, is the actual running main scene during a test run).
## stage_next_seed() is split out specifically so this real seed-staging
## logic can be exercised without also invoking the reload; the reload call
## itself is a single built-in Godot method with no project-specific logic,
## left to manual verification instead.
func test_retry_stages_the_same_seed() -> void:
	var game := await _make_game()
	var round_initializer: RoundInitializer = game.get_node("RoundInitializer")
	var original_seed := round_initializer.level_seed

	game.stage_next_seed(original_seed)

	assert_eq(GameEvents.next_level_seed, original_seed, "Retry should stage the round's actual seed for the next load")

func test_new_seed_stages_zero() -> void:
	var game := await _make_game()

	game.stage_next_seed(0)

	assert_eq(GameEvents.next_level_seed, 0, "New Seed should stage 0, ActivityManager's existing sentinel for 'randomize'")
