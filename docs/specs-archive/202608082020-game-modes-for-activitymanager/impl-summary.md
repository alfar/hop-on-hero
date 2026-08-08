## Implementation Complete

### Files Created
- `components/activities/game_mode.gd` — base `GameMode` Resource (default: always schedule, never win)
- `components/activities/endless_game_mode.gd` — `EndlessGameMode`, empty subclass inheriting base defaults
- `components/activities/preset_game_mode.gd` — `PresetGameMode`, fixed `activity_count` + win-on-enemies-cleared
- `components/activities/activity_gate.gd` — base `ActivityGate` Resource (default: always ready)
- `components/activities/timer_activity_gate.gd` — `TimerActivityGate`, extracted current random-interval behavior
- `components/activities/enemies_defeated_activity_gate.gd` — `EnemiesDefeatedActivityGate`, wave-clear gate
- `test/unit/activities/endless_game_mode_test.gd`
- `test/unit/activities/timer_activity_gate_test.gd`
- `test/integration/activities/preset_game_mode_test.gd`
- `test/integration/activities/enemies_defeated_activity_gate_test.gd`
- `test/integration/activities/enemies_defeated_gate_deferred_spawn_test.gd`
- `test/integration/activities/round_outcome_test.gd`
- `test/integration/game/summary_screen_test.gd`

### Files Modified
- `components/events/game_events.gd` — added `RoundOutcome` enum; `round_ended` gains `outcome` parameter
- `components/activities/activity.gd` — removed `next_interval_min/max`/`get_next_interval`; added `gate`, `weight`
- `components/activities/activity_manager.gd` — full rewrite: removed `Timer`; added `game_mode`, `round_over`, `activities_triggered`, weighted selection, `_physics_process`-driven gate/win polling with unified skip-first-frame guard
- `scenes/player/player.gd` — added `is_dead`; `_on_died()` now calls `_resolve_round_outcome()` (mutual win/loss tie-break against `ActivityManager`)
- `scenes/summary_screen/summary_screen.gd` / `.tscn` — added `OutcomeLabel`; `show_summary` takes `outcome`, shows distinct text per outcome
- `scenes/game.gd` — `_on_round_ended` forwards `outcome` to `SummaryScreen`
- `scenes/game.tscn` — migrated `BossActivity`/`ItemDropActivity`'s `next_interval_min/max` (5.0/10.0) into new `TimerActivityGate` sub-resources wired via `gate`
- `test/unit/events/game_events_test.gd`, `test/integration/player/player_death_test.gd` — updated for `round_ended`'s new 2-arg signature
- `test/unit/activities/activity_manager_test.gd` — full rewrite replacing the removed-Timer test with poll-based, weighted-selection, and win-declaration tests

### Acceptance Criteria
- [x] AC-01: Passed — `activity_manager_test.gd#test_advances_once_the_current_gate_reports_ready`, `#test_does_not_advance_before_the_gate_is_ready`
- [x] AC-02: Passed — `activity_manager_test.gd#test_stops_scheduling_once_game_mode_says_so`
- [x] AC-03: Passed — `round_outcome_test.gd#test_preset_game_mode_wins_once_count_reached_and_enemies_cleared`
- [x] AC-04: Passed — same test, asserting no emission while an enemy remains
- [x] AC-05: Passed — `player_death_test.gd` (updated), full `round_end_test.gd` suite
- [x] AC-06: Passed — `summary_screen_test.gd#test_shows_distinct_message_for_each_outcome`, `#test_time_label_and_visibility_are_unaffected_by_outcome`
- [x] AC-07: Passed — `activity_manager_test.gd#test_same_seed_produces_the_same_activity_sequence_under_preset_mode`
- [x] AC-08: Passed — `round_outcome_test.gd#test_simultaneous_win_and_player_death_resolves_as_pyrrhic_victory`
- [x] AC-09: Passed — `activity_manager_test.gd#test_advances_once_the_current_gate_reports_ready` (two differently-gated spies)
- [x] AC-10: Passed — `enemies_defeated_gate_deferred_spawn_test.gd`
- [x] AC-11: Passed — `timer_activity_gate_test.gd`
- [x] AC-12/13: Passed — `activity_manager_test.gd#test_pick_weighted_activity_favors_higher_weight_with_a_fixed_seed`
- [x] AC-14: Passed — `activity_manager_test.gd#test_pick_weighted_activity_treats_non_positive_total_weight_as_empty`

### Notes
- Fixed a GDScript type-inference bug in `ActivityManager._declare_win()` (ternary assigned to `var x :=` needs an explicit `: float` annotation) caught during initial test run.
- Discovered and fixed a real deadlock risk while writing `test_simultaneous_win_and_player_death_resolves_as_pyrrhic_victory`: awaiting `Player`'s death animation after triggering a win is unsafe, since `GameEvents.paused` (emitted by the win declaration) pauses the real `SceneTree`, halting the `AnimationPlayer`'s progress and hanging the `await` forever. The test now asserts via physics-frame waits instead, relying on `is_dead` being set synchronously (documented in code).
- `round_outcome_test.gd`'s `PresetGameMode` win test had to explicitly clear any enemy `game.tscn`'s default `EndlessGameMode` startup may have already spawned (non-deterministic per random seed) before setting up its own controlled scenario — otherwise the test was flaky depending on whether `BossActivity` happened to fire first during `RoundInitializer`'s initial (uncontrolled) activation.
- Added `test/integration/game/summary_screen_test.gd` (not explicitly enumerated in `plan.md`'s test list) to give AC-06 direct automated coverage, since the plan's mapping table had referenced it only informally ("covered inline in round_outcome_test.gd/round_end_test.gd").
- Full GUT suite: 132/132 passing, stable across repeated runs.
