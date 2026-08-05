# Feature: Unit Tests for Existing Pure-Logic Components

## Summary
Add GUT unit tests covering the deterministic, self-contained logic across the four features implemented so far: movement behaviors, the `BehaviorSubject` event primitive, the status/health/shield pipeline, and `BossActivity`'s reachable-distance math. This pass is scoped to scripts whose behavior does not depend on a running scene tree, autoloads, or the physics engine, establishing the test file layout and conventions (`test/unit/...`, `GutTest` base class) for future feature work to build on.

## User Stories
- As a developer, I want automated regression coverage of the movement/status/activity logic so that future refactors (like the `status_type` refactor done manually last time) can be verified by running a test suite instead of writing and deleting throwaway headless scripts.
- As a developer, I want a consistent test file layout and naming convention established now, so that tests for future features have an obvious place to go.

## Functional Requirements

### FR-01: Movement Behavior Tests
Test `MovementBehavior.get_velocity()` (base class returns `Vector2.ZERO`) and `TargetMovementBehavior.get_velocity()`:
- Returns `Vector2.ZERO` when within 10px of target (the snap-to-stop threshold).
- Returns a velocity vector pointing from position toward target, scaled to `speed`, when outside the threshold.

### FR-02: Input Movement Behavior Tests
Test `InputMovementBehavior.get_velocity()` using Godot's `Input` singleton action simulation (`Input.action_press`/`action_release` on the project's `left`/`right`/`up`/`down` actions):
- No input pressed → `Vector2.ZERO`.
- A single direction pressed → velocity scaled to `speed` in that direction.
- Opposing directions pressed simultaneously → they cancel out per `Input.get_vector` semantics.
- Release all actions after each test to avoid leaking state between tests.

### FR-03: BehaviorSubject Tests
Test `components/events/behavior_subject.gd`:
- `has_value()` is `false` before any `emit()`.
- `get_value()` returns the last emitted value; `has_value()` becomes `true` after `emit()`.
- `subscribe()` on a subject with no prior value does not immediately invoke the callable.
- `subscribe()` on a subject that already has a value immediately replays that value to the new subscriber (the RxJS-style "replay last value" behavior that motivated this class — see Architecture Decisions in `docs/project.md`).
- `emit()` notifies all existing subscribers with the new value.

### FR-04: StatusEvent Tests
Test `components/status/status_event.gd`:
- Constructor sets `type` and `amount` from its arguments.

### FR-05: HealthComponent Tests
Test `components/status/health_component.gd`, instanced as a bare `Node` (no parent `Status` scene needed since `handle_event()` is called directly):
- `_ready()` initializes `current_health` to `max_health`.
- A `"physical_damage"` event reduces `current_health` by `roundi(event.amount)`.
- Damage is clamped at `0` (never negative) — e.g. damage far exceeding current health.
- Fractional damage amounts round rather than truncate (e.g. `30.6` → `31` applied), guarding the precision fix from the original implementation.
- `value_changed` emits `("health", current_health, max_health)` after damage is applied.
- `died` emits exactly once when `current_health` reaches exactly `0`, and does not re-emit on a subsequent event once already at `0` and further damaged (still at `0`).
- An event with `type != "physical_damage"` is ignored (no change to `current_health`, no signal emitted).
- An event whose `roundi(event.amount)` rounds to `0` is a no-op (no change to `current_health`, no `value_changed` emitted) — avoids broadcasting a spurious "changed" update when nothing actually changed.

### FR-06: ShieldComponent Tests
Test `components/status/shield_component.gd`, instanced as a bare `Node`:
- `_ready()` initializes `current_shield` to `max_shield`.
- A `"physical_damage"` event reduces `current_shield` by `roundi(event.amount)`, clamped at `0`.
- When damage exceeds `current_shield`, the shield is depleted to `0` and `event.amount` is mutated to carry only the *remaining* (unabsorbed) damage — this is the mechanism that lets a sibling `HealthComponent` receive the leftover damage in the real pipeline.
- When `current_shield` is already `0`, further `"physical_damage"` events are ignored entirely (event passes through with `amount` unchanged, no signal emitted) — guards the "shield only absorbs while it has capacity" rule.
- `value_changed` emits `("shield", current_shield, max_shield)` after an event it did act on.
- An event with `type != "physical_damage"` is ignored.
- An event whose `roundi(event.amount)` rounds to `0` is a no-op (no change to `current_shield`, `event.amount` left untouched, no `value_changed` emitted) — avoids broadcasting a spurious "changed" update when nothing actually changed.

### FR-07: BossActivity Reachable-Distance Math Tests
Test `BossActivity._max_reachable_distance()` (called directly; it's a private-by-convention but accessible method, pure math with no randomness or node dependency):
- Given an origin, direction, and world bounds, returns the correct maximum travel distance before leaving the world rectangle, for each of the four axis-aligned directions and at least one diagonal direction.
- Handles a direction component of exactly `0` on one axis without dividing by zero (the existing `elif`/`if` branching already guards this — confirm it holds).

## Acceptance Criteria
- [x] AC-01: `MovementBehavior`/`TargetMovementBehavior` tests cover both the "within threshold" and "outside threshold" cases and pass.
- [x] AC-02: `InputMovementBehavior` tests cover no-input, single-direction, and opposing-direction cases and pass.
- [x] AC-03: `BehaviorSubject` tests cover no-value/has-value state, replay-on-subscribe, and multi-subscriber notification, and pass.
- [x] AC-04: `StatusEvent` constructor test passes.
- [x] AC-05: `HealthComponent` tests cover initialization, damage application with rounding, zero-clamping, `died` emitted exactly once, non-`physical_damage` events ignored, zero-rounded-damage no-op, and pass.
- [x] AC-06: `ShieldComponent` tests cover initialization, absorption with rounding, zero-clamping, event `amount` mutation for overflow damage, depleted-shield no-op, non-`physical_damage` events ignored, and zero-rounded-damage no-op, and pass.
- [x] AC-07: `BossActivity._max_reachable_distance()` tests cover all four axis directions plus a diagonal, and pass.
- [x] AC-08: All new test files live under `test/unit/` mirroring the source tree's category folders (e.g. `test/unit/status/health_component_test.gd`), extend `GutTest`, and the full suite runs green via GUT's headless CLI runner.
- [x] AC-09: `docs/project.md`'s testing convention note is updated (at archive time) to reflect the now-populated `test/unit/` directory and any naming pattern actually used.

## Technical Scope

### Affected Modules
- `components/movement/` (test only, no source changes expected)
- `components/events/` (test only)
- `components/status/` (test only)
- `components/activities/` (test only, `BossActivity` only)

### New Components Required
- `test/unit/movement/target_movement_behavior_test.gd`
- `test/unit/movement/input_movement_behavior_test.gd`
- `test/unit/events/behavior_subject_test.gd`
- `test/unit/status/status_event_test.gd`
- `test/unit/status/health_component_test.gd`
- `test/unit/status/shield_component_test.gd`
- `test/unit/activities/boss_activity_test.gd`
- (Exact filenames/grouping may be adjusted during planning to match whatever GUT test-discovery convention is confirmed at plan time.)

### Integration Points
- GUT addon (`addons/gut/`), already vendored, not yet configured with a `.gutconfig.json` or run profile — this feature will establish that if not already present.
- `Input` singleton's `left`/`right`/`up`/`down` actions (already defined in `project.godot` for `InputMovementBehavior` to work at all).

## Non-Functional Requirements
- Performance: N/A — unit tests, no perf targets.
- Security: N/A.
- Scalability: N/A. Test file layout should scale to future components without restructuring (mirrors `components/<category>/` under `test/unit/<category>/`).

## Out of Scope
- `Status` and `HealthBar` (require a live scene tree / node parenting to test meaningfully — deferred to a future pass per user's scope decision).
- `ActivityManager`, `CameraBounds`, `World` (depend on the scene tree, `GameEvents` autoload, or `Timer` — deferred).
- `Player`, `Enemy` (`CharacterBody2D` physics via `move_and_slide()` — deferred, lowest ROI since `move_and_slide` itself is an engine black box).
- `GameEvents` autoload itself (thin wrapper exposing two `BehaviorSubject` instances — covered indirectly by testing `BehaviorSubject` directly).
- CI wiring (e.g. running GUT headless in a pipeline) — not requested, no CI currently exists for this project.
- Any source-code changes to make existing scripts more testable (e.g. extracting `_max_reachable_distance` to a standalone utility) — tests will work with the current code as-is.

## Open Questions
- None remaining — scope and Input-simulation approach confirmed via clarifying questions before writing this spec.

---

## Revision History

| Date | Change Summary |
|------|----------------|
| 2026-08-05 | Initial spec |
| 2026-08-05 | FR-05/AC-05: `HealthComponent.handle_event()` now also no-ops when `roundi(event.amount)` rounds to `0`, avoiding a spurious `value_changed` emit when nothing actually changed; added corresponding test case |
| 2026-08-05 | FR-06/AC-06: Same fix applied to `ShieldComponent.handle_event()` — no-ops when `roundi(event.amount)` rounds to `0`; added corresponding test case |
