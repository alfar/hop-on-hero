extends GutTest

func after_each() -> void:
	get_tree().paused = false

func test_died_stops_movement_immediately() -> void:
	var player: Node2D = WeaponTestHelpers.make_player(self)
	var moving_behavior := TargetMovementBehavior.new()
	moving_behavior.target = Vector2(500, 0)
	moving_behavior.speed = 400
	player.movement_behavior = moving_behavior

	var health: HealthComponent = player.get_node("Status").get_node("HealthComponent")
	health.died.emit()

	# Must be visible immediately (same frame died fires), before any await --
	# only the death animation's completion is asynchronous.
	assert_eq(player.movement_behavior.get_velocity(player.position), Vector2.ZERO, "movement should stop as soon as died fires")

func test_died_stops_weapon_firing() -> void:
	var player: Node2D = WeaponTestHelpers.make_player(self)

	var health: HealthComponent = player.get_node("Status").get_node("HealthComponent")
	health.died.emit()

	# stop() halts the underlying Timer node itself (so it can never elapse
	# and call _on_timeout() again) -- calling _on_timeout() directly would
	# always fire regardless of stop(), since that bypasses the Timer, so
	# the Timer's own stopped state is what actually proves this AC.
	var trigger: TimerWeaponTrigger = player.get_node("TimerWeaponTrigger")
	assert_true(trigger._timer.is_stopped(), "the TimerWeaponTrigger's Timer should be stopped as soon as died fires, so it can never elapse and fire again")

func test_died_fades_out_but_does_not_free_the_player() -> void:
	var player: Node2D = WeaponTestHelpers.make_player(self)
	assert_eq(player.modulate.a, 1.0)

	var health: HealthComponent = player.get_node("Status").get_node("HealthComponent")
	health.died.emit()
	# AnimationPlayer's idle-process-driven playback runs far slower than
	# wall-clock time under --headless (confirmed: a 0.2s animation can take
	# several real seconds to complete), unlike Tween-based animation
	# (Enemy's death fade), which completes promptly. Awaiting the signal
	# directly is correct regardless of headless playback speed.
	await player._animation_player.animation_finished
	# Player._on_died() resumes from the same signal and continues running
	# (reading get_tree(), emitting round_ended) after this await returns --
	# give it a frame to finish before the test ends and GUT autofrees the
	# player, or freeing can race its still-suspended continuation.
	await wait_physics_frames(1)

	assert_eq(player.modulate.a, 0.0, "the death animation should fade the player out")
	assert_true(is_instance_valid(player) and not player.is_queued_for_deletion(), "unlike Enemy, the player must not be freed after its death animation completes")

func test_died_emits_round_ended_with_zero_time_when_no_game_node_exists() -> void:
	var player: Node2D = WeaponTestHelpers.make_player(self)

	var received := []
	var callable := func(time, outcome): received.append([time, outcome])
	GameEvents.round_ended.connect(callable)

	var health: HealthComponent = player.get_node("Status").get_node("HealthComponent")
	health.died.emit()
	await player._animation_player.animation_finished
	await wait_physics_frames(1)

	assert_eq(received, [[0.0, GameEvents.RoundOutcome.LOST]], "with no Game ancestor in the scene tree, round_ended should fire with 0.0/LOST rather than erroring")
	GameEvents.round_ended.disconnect(callable)
