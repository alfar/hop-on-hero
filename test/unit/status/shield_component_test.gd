extends GutTest

func _make_shield(max_shield: int = 50) -> ShieldComponent:
	var shield := ShieldComponent.new()
	shield.max_shield = max_shield
	add_child_autofree(shield)
	return shield

func test_ready_initializes_current_shield_to_max() -> void:
	var shield := _make_shield(50)

	assert_eq(shield.current_shield, 50)

func test_physical_damage_reduces_shield_by_rounded_amount() -> void:
	var shield := _make_shield(50)

	shield.handle_event(StatusEvent.new("physical_damage", 20.0))

	assert_eq(shield.current_shield, 30)

func test_fractional_damage_rounds_instead_of_truncating() -> void:
	var shield := _make_shield(50)

	shield.handle_event(StatusEvent.new("physical_damage", 20.6))

	assert_eq(shield.current_shield, 29)

func test_overflow_damage_depletes_shield_and_leaves_remainder_on_event() -> void:
	var shield := _make_shield(50)
	var event := StatusEvent.new("physical_damage", 70.0)

	shield.handle_event(event)

	assert_eq(shield.current_shield, 0)
	assert_eq(event.amount, 20.0)

func test_depleted_shield_ignores_further_damage() -> void:
	var shield := _make_shield(50)
	shield.handle_event(StatusEvent.new("physical_damage", 50.0))
	watch_signals(shield)
	var event := StatusEvent.new("physical_damage", 10.0)

	shield.handle_event(event)

	assert_eq(shield.current_shield, 0)
	assert_eq(event.amount, 10.0)
	assert_signal_not_emitted(shield, "value_changed")

func test_value_changed_emits_shield_status_type_and_values() -> void:
	var shield := _make_shield(50)
	watch_signals(shield)

	shield.handle_event(StatusEvent.new("physical_damage", 20.0))

	assert_signal_emitted_with_parameters(shield, "value_changed", ["shield", 30, 50])

func test_non_physical_damage_event_is_ignored() -> void:
	var shield := _make_shield(50)
	watch_signals(shield)

	shield.handle_event(StatusEvent.new("mana_cost", 20.0))

	assert_eq(shield.current_shield, 50)
	assert_signal_not_emitted(shield, "value_changed")

func test_zero_rounded_damage_is_a_no_op() -> void:
	var shield := _make_shield(50)
	watch_signals(shield)
	var event := StatusEvent.new("physical_damage", 0.4)

	shield.handle_event(event)

	assert_eq(shield.current_shield, 50)
	assert_eq(event.amount, 0.4)
	assert_signal_not_emitted(shield, "value_changed")
