# Code Review: Game Modes for ActivityManager

## Summary
This is a well-executed, thoroughly-tested implementation of a genuinely difficult refactor — `ActivityManager`'s core loop moved from a `Timer`/`timeout` mechanism to a `_physics_process` poll loop, two new strategy hierarchies (`GameMode`, `ActivityGate`) were introduced cleanly, and the win/loss simultaneity tie-break (left as an open question in `feature.md`) was resolved correctly with a symmetric mutual-check design that the test suite specifically exercises. All 14 acceptance criteria have direct, passing test coverage (132/132 in the full suite, stable across repeated runs). All four minor findings below have been fixed and re-verified; the two info-level notes are left as-is (no action needed). A fifth, post-review fix was also applied: Godot's own editor linter flagged `GameEvents.round_ended`/`paused`/`resumed` as signals never emitted from within their declaring script — `GameEvents` now exposes `emit_round_ended()`/`emit_paused()`/`emit_resumed()` wrapper methods, and all call sites (`Player`, `ActivityManager`, `Game`, tests) were updated to use them. Ready to merge.

## Findings

### 🔴 Critical

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|

### 🟠 Major

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|

### 🟡 Minor

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [x] | `components/activities/enemies_defeated_activity_gate.gd:4`, `components/activities/timer_activity_gate.gd:9,12` | Style Consistency | `elapsed_time`/`spawn_parent` parameters are intentionally unused in some concrete leaf overrides but weren't underscore-prefixed, unlike this project's own established convention (`World.fill_tiles(_rng: RandomNumberGenerator, ...)`). | Fixed: underscore-prefixed the permanently-unused parameters in `EnemiesDefeatedActivityGate.is_ready`/`TimerActivityGate.start`/`is_ready`; left `GameMode`/`ActivityGate` base virtual methods unprefixed since subclasses genuinely use those parameters (matches `MovementBehavior.get_velocity(position)`'s existing precedent). |
| [x] | `test/unit/activities/activity_manager_test.gd:3-17`, `test/integration/activities/enemies_defeated_gate_deferred_spawn_test.gd:15-19`, `test/integration/activities/round_outcome_test.gd:7-9` | Code Duplication | `SpyActivity` is defined independently in two test files and `AlwaysWonGameMode` in two others — small (3-8 line) but exact copy-paste duplication. | Fixed: extracted `test/unit/activities/activities_test_helpers.gd` (`ActivitiesTestHelpers.SpyActivity`/`.AlwaysWonGameMode`), mirroring the existing `WeaponTestHelpers` pattern; all four call sites updated. |
| [x] | `test/integration/activities/round_outcome_test.gd:24-46` | Test Quality | `test_preset_game_mode_wins_once_count_reached_and_enemies_cleared` reached into a live, fully-loaded `game.tscn` fixture (with its own uncontrolled random startup activity already having run) and force-reset `activity_manager.activities_triggered`/`round_over` to fake a clean scenario — fragile to future `ActivityManager` internal changes. | Fixed: rewritten to use a bare `ActivityManager` + `PresetGameMode` fixture (matching `activity_manager_test.gd`'s own style), fully under the test's control from the start; the AC-08 simultaneity test still uses full `game.tscn` since it genuinely needs the real `Player`/`ActivityManager` sibling wiring. |
| [x] | `test/integration/activities/enemies_defeated_gate_deferred_spawn_test.gd:49` | Test Quality | `activity_manager.get_tree().get_nodes_in_group("enemy")[0]` indexed without asserting the array is non-empty first; if the setup assumption ever broke, this would fail with an opaque "Out of bounds" engine error instead of a clear test assertion message. | Fixed: added `assert_eq(enemies.size(), 1, ...)` before indexing. |

### 🔵 Info / Suggestions

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [ ] | `components/activities/activity_manager.gd:18-19` | Design | `activities_triggered`/`round_over` are public, externally-mutable fields — necessary for `Player`'s cross-check (documented in `plan.md`'s Architecture Decisions), consistent with this codebase's existing convention of exposing similar state directly (e.g. `RoundInitializer.level_seed`), but nothing in the code marks that external *writes* should only ever happen as part of the documented tie-break contract. | Optional: add a one-line comment noting that external mutation should be limited to the `Player`/test tie-break contract, not general-purpose configuration — mainly to help a future reader who finds `round_outcome_test.gd` mutating these fields directly. |
| [ ] | `components/activities/activity_manager.gd:83-84` | Robustness | `_declare_win()` accesses `player.is_dead` via duck-typing on a `Node` fetched from the `"player"` group, with no cast/type check — safe today since only `Player` ever joins that group, but would throw a runtime error (not a graceful fallback) if any other node type ever joined it. | No action needed now; worth a defensive `is_instance_of`/duck-typed `has_method`/`in` check only if the `"player"` group ever becomes shared with other node types. |

## Acceptance Criteria Coverage
| AC | Test | Status |
|----|------|--------|
| AC-01: default EndlessGameMode+TimerActivityGate behaves like today | `activity_manager_test.gd#test_advances_once_the_current_gate_reports_ready`, `#test_does_not_advance_before_the_gate_is_ready` | ✅ Covered |
| AC-02: PresetGameMode schedules exactly N activities | `activity_manager_test.gd#test_stops_scheduling_once_game_mode_says_so` | ✅ Covered |
| AC-03: round_ended fires WON once count reached + enemies cleared | `round_outcome_test.gd#test_preset_game_mode_wins_once_count_reached_and_enemies_cleared` | ✅ Covered |
| AC-04: no premature win while enemies remain | same test, asserting no emission mid-scenario | ✅ Covered |
| AC-05: Player's ordinary death path still emits LOST; existing tests pass | `player_death_test.gd` (updated), `round_end_test.gd` suite | ✅ Covered |
| AC-06: SummaryScreen shows 3 distinct messages | `summary_screen_test.gd#test_shows_distinct_message_for_each_outcome`, `#test_time_label_and_visibility_are_unaffected_by_outcome` | ✅ Covered |
| AC-07: same seed reproduces the same PresetGameMode activity sequence | `activity_manager_test.gd#test_same_seed_produces_the_same_activity_sequence_under_preset_mode` | ✅ Covered |
| AC-08: simultaneous win+loss resolves as PYRRHIC_VICTORY, exactly once | `round_outcome_test.gd#test_simultaneous_win_and_player_death_resolves_as_pyrrhic_victory` | ✅ Covered |
| AC-09: different Activity instances can use different gates in the same pool | `activity_manager_test.gd#test_advances_once_the_current_gate_reports_ready` | ✅ Covered |
| AC-10: EnemiesDefeatedActivityGate doesn't false-positive on a deferred spawn's own frame | `enemies_defeated_gate_deferred_spawn_test.gd` | ✅ Covered |
| AC-11: TimerActivityGate reproduces the old interval range | `timer_activity_gate_test.gd` | ✅ Covered |
| AC-12/13: weighted selection biases toward higher weight; default stays unbiased | `activity_manager_test.gd#test_pick_weighted_activity_favors_higher_weight_with_a_fixed_seed` | ✅ Covered |
| AC-14: non-positive total weight behaves like empty pool | `activity_manager_test.gd#test_pick_weighted_activity_treats_non_positive_total_weight_as_empty` | ✅ Covered |

## Verdict
- [x] ✅ Ready to merge
- [ ] 🟡 Merge after minor fixes (no re-review needed)
- [ ] 🟠 Requires fixes and re-review
- [ ] 🔴 Do not merge — significant issues found
