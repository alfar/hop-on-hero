extends GutTest

## show_summary() relies on @onready node lookups within its own scene, so
## this needs the real summary_screen.tscn instanced into a live tree, hence
## test/integration/ rather than test/unit/.
func _make_summary_screen() -> SummaryScreen:
	var scene: PackedScene = load("res://scenes/summary_screen/summary_screen.tscn")
	return add_child_autofree(scene.instantiate())

func test_shows_distinct_message_for_each_outcome() -> void:
	var summary_screen := _make_summary_screen()

	summary_screen.show_summary(0.0, GameEvents.RoundOutcome.LOST)
	var lost_text := summary_screen.outcome_label.text

	summary_screen.show_summary(0.0, GameEvents.RoundOutcome.WON)
	var won_text := summary_screen.outcome_label.text

	summary_screen.show_summary(0.0, GameEvents.RoundOutcome.PYRRHIC_VICTORY)
	var pyrrhic_text := summary_screen.outcome_label.text

	assert_ne(lost_text, won_text)
	assert_ne(won_text, pyrrhic_text)
	assert_ne(lost_text, pyrrhic_text)

func test_time_label_and_visibility_are_unaffected_by_outcome() -> void:
	var summary_screen := _make_summary_screen()

	for outcome in [GameEvents.RoundOutcome.LOST, GameEvents.RoundOutcome.WON, GameEvents.RoundOutcome.PYRRHIC_VICTORY]:
		summary_screen.show_summary(65.0, outcome)
		assert_eq(summary_screen.time_label.text, "01:05")
		assert_true(summary_screen.visible)
