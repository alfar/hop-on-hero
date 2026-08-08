# Code Review: Player Death Ends the Round with a Summary Screen

## Summary
The implementation is solid: the death sequence correctly mirrors `Enemy`'s established pattern while introducing `AnimationPlayer` for redesignable death animations, and the mid-implementation pivot to `GameEvents.paused`/`resumed` signals (replacing a direct `get_tree().paused` toggle) is a genuinely good design call that eliminates a real test-isolation hazard rather than papering over it. 9 of 12 acceptance criteria have real, passing automated coverage; the remaining 3 are honestly and explicitly documented as untestable under GUT rather than silently skipped. The only real gaps are `feature.md` documentation drift (still describes `round_ended` as a `BehaviorSubject`, and never mentions the new `paused`/`resumed` signals) and one leaking signal connection in a new test file. Ready to merge after the two Minor items are addressed.

## Findings

### 🔴 Critical

*(none)*

### 🟠 Major

*(none)*

### 🟡 Minor

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [x] | `test/unit/events/game_events_test.gd:12` | Test Quality | `GameEvents.round_ended.connect(func(value): received.append(value))` is never disconnected — since `GameEvents` is an autoload, this connection outlives the test and stays attached to `round_ended` for the rest of the entire suite run, silently appending to a dead local array on every later `round_ended.emit()` elsewhere in the run. | Capture the lambda in a variable and call `GameEvents.round_ended.disconnect(...)` at the end of the test, matching the pattern already used in the very next test in this same file. |
| [x] | `feature.md:21,41,66,74,80` | Documentation Drift | FR-02/FR-05/Technical Scope still describe `GameEvents.round_ended` as a `BehaviorSubject`, but the shipped implementation (correctly, per the sound rationale in `plan.md`'s Architecture Decisions) uses a plain `signal` instead; the spec also never mentions the new `GameEvents.paused`/`resumed` signals added mid-implementation to fix a test-isolation hazard. | Update `feature.md` to describe `round_ended` as a plain signal (with the replay-hazard rationale) and add the `paused`/`resumed` signals to FR-02/Technical Scope so the spec matches what shipped. |

### 🔵 Info / Suggestions

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [x] | `components/weapon/timer_weapon_trigger.gd:19` | Dead Code | `set_process(false)` in `stop()` is a no-op today since this script has no `_process()` override — harmless but adds a line with zero current effect. | Fixed: removed by the user post-review. |
| [x] | `feature.md` AC-08/AC-11/AC-12 | Test Coverage | These three ACs have no automated test — `process_mode = PROCESS_MODE_ALWAYS`-based click-responsiveness and a literal `get_tree().reload_current_scene()` are both genuinely unexercisable under GUT's headless test runner (confirmed via a real "current_scene is null" engine error when attempted). | Acknowledged, no code action needed: already transparently documented in `plan.md`'s Risks and `impl-summary.md`'s AC table rather than silently glossed over. |

## Acceptance Criteria Coverage
| AC | Test | Status |
|----|------|--------|
| AC-01: movement stops immediately on death | `player_death_test.gd#test_died_stops_movement_immediately` | ✅ Covered |
| AC-02: `TimerWeaponTrigger` stops firing on death | `player_death_test.gd#test_died_stops_weapon_firing` | ✅ Covered |
| AC-03: death animation plays, fades to 0 | `player_death_test.gd#test_died_fades_out_but_does_not_free_the_player` | ✅ Covered |
| AC-04: `round_ended` fires exactly once | `player_death_test.gd` (4 cases) + `game_events_test.gd` (signal semantics) | ✅ Covered |
| AC-05: tree pauses on round end | `round_end_test.gd#test_player_death_emits_paused_and_shows_summary_screen` (asserts `GameEvents.paused` intent; `Game._on_paused()` is the sole place performing the real toggle, by design not asserted directly to avoid cross-test pause leakage) | ✅ Covered |
| AC-06: summary screen becomes visible | same test, `SummaryScreen.visible` | ✅ Covered |
| AC-07: correct `mm:ss` elapsed time | `round_end_test.gd#test_summary_screen_shows_correct_elapsed_time` | ✅ Covered |
| AC-08: buttons clickable while paused | — | ❌ No automated test (documented, GUT limitation) |
| AC-09: Retry stages/uses the same seed | `activity_manager_test.gd#test_uses_next_level_seed_when_set` + `round_end_test.gd#test_retry_stages_the_same_seed` | ✅ Covered |
| AC-10: New Seed randomizes | `activity_manager_test.gd#test_falls_back_to_randomize_when_next_level_seed_is_unset` + `round_end_test.gd#test_new_seed_stages_zero` | ✅ Covered |
| AC-11: pause/movement restored after restart | — | ❌ No automated test (documented, GUT limitation — `reload_current_scene()` errors under the test runner) |
| AC-12: summary hidden, timer reset after restart | — | ❌ No automated test (same reason) |

Full suite: **102/103 passing** at time of review. The 1 failure is a known, documented, pre-existing test-isolation gap (`item_pickup_test.gd`, unrelated `GameEvents.world_size_changed` `BehaviorSubject` replay hazard newly exposed by this feature's `round_end_test.gd`, explicitly deferred per user decision to an upcoming round-initialization feature) — not a regression introduced by this feature's own logic.

## Verdict
- [x] ✅ Ready to merge
- [ ] 🟡 Merge after minor fixes (no re-review needed)
- [ ] 🟠 Requires fixes and re-review
- [ ] 🔴 Do not merge — significant issues found
