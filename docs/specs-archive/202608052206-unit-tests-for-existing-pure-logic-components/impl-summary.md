## Implementation Complete

### Files Created
- `.gutconfig.json` — GUT config: `test/unit` dir, `""`/`_test.gd` prefix/suffix, headless-friendly defaults
- `test/unit/movement/target_movement_behavior_test.gd`
- `test/unit/movement/input_movement_behavior_test.gd`
- `test/unit/events/behavior_subject_test.gd`
- `test/unit/status/status_event_test.gd`
- `test/unit/status/health_component_test.gd`
- `test/unit/status/shield_component_test.gd`
- `test/unit/activities/boss_activity_test.gd`

### Files Modified
- `components/status/health_component.gd` — added a guard (`current_health == 0`) so `handle_event()` is a no-op once the character is already dead, fixing a real bug where `died` re-fired on every subsequent damage event; also no-ops when `roundi(event.amount) == 0`
- `components/status/shield_component.gd` — no-ops when `roundi(event.amount) == 0`, same rationale as `HealthComponent`
- `docs/project.md` — added Godot executable path to Tech Stack for future headless test/CLI invocations

### Acceptance Criteria
- [x] AC-01: Passed — `target_movement_behavior_test.gd` (2/2)
- [x] AC-02: Passed — `input_movement_behavior_test.gd` (3/3)
- [x] AC-03: Passed — `behavior_subject_test.gd` (5/5)
- [x] AC-04: Passed — `status_event_test.gd` (1/1)
- [x] AC-05: Passed — `health_component_test.gd` (8/8, includes zero-rounded-damage no-op added post-implementation)
- [x] AC-06: Passed — `shield_component_test.gd` (8/8, includes zero-rounded-damage no-op added post-implementation)
- [x] AC-07: Passed — `boss_activity_test.gd` (6/6)
- [x] AC-08: Passed — full suite run via `godot --headless -s addons/gut/gut_cmdln.gd -gexit`: 7 scripts, 31 tests, 31 passing, 0 failing
- [ ] AC-09: Deferred to `/sdd-archive` per plan.md — docs/project.md testing convention note update happens at archive time, not implementation

### Notes
- Post-implementation refinement: `HealthComponent.handle_event()` and `ShieldComponent.handle_event()` now also no-op when `roundi(event.amount)` is `0`, so no `value_changed` is emitted when nothing actually changed. Added `test_zero_rounded_damage_is_a_no_op` to both `health_component_test.gd` and `shield_component_test.gd`. See `feature.md` Revision History.
- `HealthComponent`'s `died`-re-fire bug was found while writing the AC-05 test (a legitimate pre-existing gap from the earlier Status feature, not introduced by this change). Flagged to the user via AskUserQuestion; user chose to fix it now rather than defer or weaken the test. Fix: `handle_event()` now returns early if `current_health == 0`, in addition to the existing `event.type` check.
- GUT's default test-discovery is by filename *prefix* (`test_` by default), not suffix — `.gutconfig.json` explicitly sets `prefix: ""` and `suffix: "_test.gd"` to match this project's existing snake_case suffix convention instead of adopting GUT's default naming.
- All plan assumptions about GUT's API (`GutTest`, `add_child_autofree`, `watch_signals`/`assert_signal_emitted_with_parameters`/`assert_signal_emit_count`/`assert_signal_not_emitted`) held up as expected; no deviations from the planned test structure.
- `Status`, `HealthBar`, `ActivityManager`, `CameraBounds`, `World`, `Player`, `Enemy` remain untested per `feature.md`'s Out of Scope section (scene-tree/autoload/physics-dependent, deferred to a future pass).
