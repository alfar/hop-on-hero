extends GutTest

func _make_health(max_health: int = 100) -> HealthComponent:
	var health := HealthComponent.new()
	health.max_health = max_health
	add_child_autofree(health)
	return health

func test_ready_initializes_current_health_to_max() -> void:
	var health := _make_health(100)

	assert_eq(health.current_health, 100)

func test_physical_damage_reduces_health_by_rounded_amount() -> void:
	var health := _make_health(100)

	health.handle_event(StatusEvent.new("physical_damage", 30.0))

	assert_eq(health.current_health, 70)

func test_fractional_damage_rounds_instead_of_truncating() -> void:
	var health := _make_health(100)

	health.handle_event(StatusEvent.new("physical_damage", 30.6))

	assert_eq(health.current_health, 69)

func test_damage_clamps_at_zero_not_negative() -> void:
	var health := _make_health(100)

	health.handle_event(StatusEvent.new("physical_damage", 99999.0))

	assert_eq(health.current_health, 0)

func test_value_changed_emits_health_status_type_and_values() -> void:
	var health := _make_health(100)
	watch_signals(health)

	health.handle_event(StatusEvent.new("physical_damage", 30.0))

	assert_signal_emitted_with_parameters(health, "value_changed", ["health", 70, 100])

func test_died_emits_exactly_once_when_health_reaches_zero() -> void:
	var health := _make_health(100)
	watch_signals(health)

	health.handle_event(StatusEvent.new("physical_damage", 100.0))
	health.handle_event(StatusEvent.new("physical_damage", 10.0))

	assert_signal_emit_count(health, "died", 1)

func test_non_physical_damage_event_is_ignored() -> void:
	var health := _make_health(100)
	watch_signals(health)

	health.handle_event(StatusEvent.new("mana_cost", 30.0))

	assert_eq(health.current_health, 100)
	assert_signal_not_emitted(health, "value_changed")

func test_zero_rounded_damage_is_a_no_op() -> void:
	var health := _make_health(100)
	watch_signals(health)

	health.handle_event(StatusEvent.new("physical_damage", 0.4))

	assert_eq(health.current_health, 100)
	assert_signal_not_emitted(health, "value_changed")
