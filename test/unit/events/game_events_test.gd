extends GutTest

## Smoke test guarding against GameEvents.round_ended ever being changed
## back into a BehaviorSubject: a BehaviorSubject replays its last cached
## value to every new subscriber immediately on subscribe(), which would
## incorrectly re-fire "round ended" the moment the next round's fresh
## Game._ready() connects to it.
func test_round_ended_does_not_replay_to_a_late_subscriber() -> void:
	GameEvents.emit_round_ended(42.0, GameEvents.RoundOutcome.LOST)

	var received := []
	var callable := func(time, outcome): received.append([time, outcome])
	GameEvents.round_ended.connect(callable)

	assert_eq(received.size(), 0, "a plain signal must not replay its last emitted value to a subscriber that connects afterward")
	GameEvents.round_ended.disconnect(callable)

func test_round_ended_delivers_exactly_once_to_a_connected_subscriber() -> void:
	var received := []
	var callable := func(time, outcome): received.append([time, outcome])
	GameEvents.round_ended.connect(callable)

	GameEvents.emit_round_ended(10.0, GameEvents.RoundOutcome.WON)

	assert_eq(received, [[10.0, GameEvents.RoundOutcome.WON]])
	GameEvents.round_ended.disconnect(callable)
