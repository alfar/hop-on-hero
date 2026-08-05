# Unit Tests for Existing Pure-Logic Components

Implemented on: 2026-08-05

Added GUT unit test coverage for the deterministic, scene-tree-independent logic across four already-shipped features: movement behaviors (`MovementBehavior`, `TargetMovementBehavior`, `InputMovementBehavior`), the `BehaviorSubject` event primitive, the status/health/shield pipeline (`StatusEvent`, `HealthComponent`, `ShieldComponent`), and `BossActivity`'s reachable-distance math. Scope was deliberately limited to pure logic — `Status`, `HealthBar`, `ActivityManager`, `CameraBounds`, `World`, `Player`, and `Enemy` remain untested since they depend on a live scene tree, the `GameEvents` autoload, or physics, and were left for a future pass. This established the project's first real test suite and its conventions.

Key files:
- `.gutconfig.json` — GUT config: `test/unit` as the test directory, `_test.gd` suffix (not GUT's default `test_` prefix), headless-friendly defaults
- `test/unit/movement/target_movement_behavior_test.gd`, `input_movement_behavior_test.gd`
- `test/unit/events/behavior_subject_test.gd`
- `test/unit/status/status_event_test.gd`, `health_component_test.gd`, `shield_component_test.gd`
- `test/unit/activities/boss_activity_test.gd`

Notable decisions:
- Test files live under `test/unit/<category>/`, mirroring `components/<category>/`, using a `*_test.gd` filename suffix rather than GUT's default `test_*` prefix — matches the project's existing snake_case suffix convention.
- `HealthComponent`/`ShieldComponent` are tested as bare orphan `Node`s via `add_child_autofree()` (no full `Status`/`Player` scene needed) since `handle_event()` can be called directly.
- Two real pre-existing bugs were found and fixed while writing tests, both flagged to the user before fixing:
  - `HealthComponent.died` was re-emitting on every damage event received after death (no guard against re-triggering). Fixed by returning early once `current_health == 0`.
  - Both `HealthComponent` and `ShieldComponent` emitted a spurious `value_changed` signal even when `roundi(event.amount)` rounded to `0` (i.e. no actual change). Fixed by adding a no-op guard for zero-rounded damage in both components.
- No production code was otherwise changed; this was scoped as test-only per `feature.md`'s Out of Scope section.
