extends GutTest

## Smoke test guarding against GameEvents.round_ended ever being changed
## back into a BehaviorSubject: a BehaviorSubject replays its last cached
## value to every new subscriber immediately on subscribe(), which would
## incorrectly re-fire "round ended" the moment the next round's fresh
## Game._ready() connects to it.
func test_round_ended_does_not_replay_to_a_late_subscriber() -> void:
	GameEvents.round_ended.emit(42.0)

	var received := []
	var callable := func(value): received.append(value)
	GameEvents.round_ended.connect(callable)

	assert_eq(received.size(), 0, "a plain signal must not replay its last emitted value to a subscriber that connects afterward")
	GameEvents.round_ended.disconnect(callable)

func test_round_ended_delivers_exactly_once_to_a_connected_subscriber() -> void:
	var received := []
	var callable := func(value): received.append(value)
	GameEvents.round_ended.connect(callable)

	GameEvents.round_ended.emit(10.0)

	assert_eq(received, [10.0])
	GameEvents.round_ended.disconnect(callable)
