## Implementation Complete

### Files Created
- `scenes/summary_screen/summary_screen.gd` + `.tscn` — `SummaryScreen` (this project's first `Control`-based UI: time-played label, Retry/New Seed buttons, `PROCESS_MODE_ALWAYS`)
- `test/integration/player/player_death_test.gd` — `Player` death sequence tests
- `test/integration/game/round_end_test.gd` — round-end flow tests (pause signal, summary display, seed staging)
- `test/unit/events/game_events_test.gd` — `GameEvents.round_ended` signal-semantics smoke test
- `test/unit/activities/activity_manager_test.gd` — `ActivityManager`'s `next_level_seed` consumption

### Files Modified
- `scenes/player/player.gd` — `_on_died()` handler (stop movement, stop weapon, play death animation, emit `round_ended`); new `_animation_player` ref
- `scenes/player/player.tscn` — new `AnimationPlayer` child + `"death"` animation clip (fades `modulate:a` 1→0 over 0.2s)
- `components/weapon/timer_weapon_trigger.gd` — new `stop()` method (halts the underlying `Timer`)
- `components/events/game_events.gd` — new `round_ended`, `paused`, `resumed` signals (all plain signals, not `BehaviorSubject`s — see Notes); new `next_level_seed` field
- `scenes/game.gd` — round timer (`get_time_played_seconds()`), `round_ended`/`paused`/`resumed` subscriptions, `SummaryScreen` wiring, `stage_next_seed()`, `_restart()`
- `scenes/game.tscn` — new `SummaryScreen` child under `HUD`
- `components/activities/activity_manager.gd` — `_ready()` now checks `GameEvents.next_level_seed` before its existing randomize-on-zero fallback
- `test/integration/weapon/projectile_test.gd` — fixed a pre-existing failure unrelated to this feature (see Notes)

### Acceptance Criteria
- [x] AC-01: Passed — `player_death_test.gd#test_died_stops_movement_immediately`
- [x] AC-02: Passed — `player_death_test.gd#test_died_stops_weapon_firing`
- [x] AC-03: Passed — `player_death_test.gd#test_died_fades_out_but_does_not_free_the_player`
- [x] AC-04: Passed — `player_death_test.gd` (all 4 cases) + `game_events_test.gd` (signal semantics)
- [x] AC-05: Passed (structurally) — `round_end_test.gd#test_player_death_emits_paused_and_shows_summary_screen` asserts `GameEvents.paused` fires; `Game._on_paused()` is the sole place performing the real `get_tree().paused = true`
- [x] AC-06: Passed — same test, `SummaryScreen.visible`
- [x] AC-07: Passed — `round_end_test.gd#test_summary_screen_shows_correct_elapsed_time`
- [x] AC-08: Structural only (`process_mode = PROCESS_MODE_ALWAYS`) + deferred to manual verification — GUT can't exercise real click-while-paused behavior
- [x] AC-09: Passed — `activity_manager_test.gd#test_uses_next_level_seed_when_set` + `round_end_test.gd#test_retry_stages_the_same_seed`
- [x] AC-10: Passed — `activity_manager_test.gd#test_falls_back_to_randomize_when_next_level_seed_is_unset` + `round_end_test.gd#test_new_seed_stages_zero`
- [ ] AC-11/AC-12: Deferred to manual verification — `get_tree().reload_current_scene()` isn't exercisable under GUT (errors: "current_scene is null" in a test context)

### Notes
- Mid-implementation design change (user-directed): originally `Game._on_round_ended()` called `get_tree().paused = true` directly. Discovered during the full regression pass that setting the real `SceneTree.paused` flag during a GUT test leaks into every later test in the same run (nothing un-pauses it until that test's own teardown completes). Fixed by adding `GameEvents.paused`/`resumed` as plain signals — `Game` is now the sole subscriber that translates pause *intent* into the real toggle, so tests assert the signal fired without ever setting the real flag.
- `Game._on_retry_pressed()`/`_on_new_seed_pressed()` were split into `stage_next_seed(seed_value)` (the real, testable seed-staging logic) + `_restart()` (`get_tree().reload_current_scene()`, untestable under GUT) — same rationale, avoids exercising the untestable half.
- Confirmed a real headless-specific quirk: `AnimationPlayer`'s idle-process-driven playback runs far slower than wall-clock time under `--headless` (a 0.2s animation observed taking multiple real seconds to complete), unlike `Tween`-based animation (`Enemy`'s existing fade), which completes promptly. All death-animation-completion tests await the `animation_finished` signal directly rather than a fixed `wait_seconds` duration, which is correct regardless of headless playback speed.
- Fixed a real, unrelated pre-existing test failure discovered during the initial regression pass: `projectile_test.gd#test_projectile_self_destructs_when_hitting_a_status_less_body` placed its `StaticBody2D` at the projectile's origin, but the projectile's `CollisionShape2D` is offset (`position = Vector2(17, 0)` in `projectile.tscn`, matching its arrow sprite) — the test's body no longer overlapped that shape after a hitbox change made earlier in this session. Fixed by offsetting the test body to match.
- **Known, documented, deliberately-unfixed gap** (per user decision): in a full headless suite run, `test/integration/inventory/item_pickup_test.gd#test_walking_into_pickup_with_empty_slot_equips_and_frees_it` intermittently fails — passes standalone and in the Godot editor's own GUT panel. Root cause: this feature's `round_end_test.gd` is the first test under `test/integration/game/` (sorts before `test/integration/inventory/`) to instance the real `game.tscn`, whose `World` emits `GameEvents.world_size_changed` — a `BehaviorSubject` that replays its cached value to every later subscriber, including any `Player` a later test constructs. `item_pickup_test.gd`'s hardcoded coordinates fall outside `World`'s default bounds, so `Player`'s position-clamp yanks it away from its pickup once that cached value is set. This is a pre-existing test-isolation fragility that this feature's test newly exposes rather than causes; the user has an upcoming "initialize the world for a new round" feature that will ensure `world_size_changed` is (re-)emitted deterministically per round, which is the right place to fix this — not by patching unrelated inventory test coordinates here.
- Manual verification (Step 11) deferred to the user, per this project's established preference.
