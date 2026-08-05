# Implementation Plan: Unit Tests for Existing Pure-Logic Components

## Overview
Add GUT test scripts under `test/unit/<category>/`, mirroring the `components/<category>/` source layout, covering the pure-logic scripts identified in `feature.md`: `TargetMovementBehavior`, `InputMovementBehavior`, `BehaviorSubject`, `StatusEvent`, `HealthComponent`, `ShieldComponent`, and `BossActivity._max_reachable_distance()`. Since no `.gutconfig.json` exists yet, this plan also creates one so the suite can be run headlessly via the addon's existing `gut_cmdln.gd` runner, establishing the convention for all future test work. No production source files are modified — this is test-only, per `feature.md`'s Out of Scope section.

## Architecture Decisions
- **`test/unit/<category>/` mirrors `components/<category>/`**: keeps the existing project convention (`docs/project.md` Conventions section) of category-based folder naming consistent between source and tests, making it obvious where a new component's test belongs.
- **One test script per source script, suffixed `_test.gd`**: GUT's default discovery pattern picks up `test_*.gd` or `*_test.gd` — the project will standardize on the `_test.gd` suffix (matches the snake_case file-naming convention already in place) rather than GUT's `test_*` default prefix.
- **`.gutconfig.json` created at project root**: pins the test directory (`res://test/unit`) and enables headless-friendly defaults (no GUI panel), so `godot --headless -s addons/gut/gut_cmdln.gd` "just works" without CLI flags every time, both for the developer and any future CI setup.
- **`HealthComponent`/`ShieldComponent` tests instantiate the component as a bare orphan `Node` via `add_child_autofree()`**: GUT's `add_child_autofree()` (from its scene-tree test helpers) adds the node to the test's scene tree so `_ready()` actually runs (required, since both components initialize their current value in `_ready()`), and auto-frees it after the test — no full `Status`/`Player` scene needed, matching the "call `handle_event()` directly" approach from `feature.md`.
- **`BossActivity._max_reachable_distance()` is called on a bare `BossActivity.new()` Resource, no scene tree needed**: it's a pure function of its arguments with no `_ready()` dependency, so no autofree/scene-tree machinery is required for that test file.
- **`InputMovementBehavior` tests reset all four actions in an `after_each()`**: guarantees no leaked `Input` action state bleeds into subsequent tests, regardless of test order or early assertion failure.

## Implementation Steps

### Step 1: GUT configuration
- [x] Create `.gutconfig.json` at project root, pointing at `res://test/unit` as the test directory, with reasonable defaults (e.g. `should_exit: true` for headless runs, `log_level: 1`).
- Files: `.gutconfig.json` (created)

### Step 2: Movement behavior tests
- [x] Create `test/unit/movement/target_movement_behavior_test.gd`: within-threshold → `Vector2.ZERO`; outside-threshold → direction-to-target scaled by `speed`.
- [x] Create `test/unit/movement/input_movement_behavior_test.gd`: no input → zero; single direction → scaled vector; opposing directions → cancel out; `after_each()` releases all four actions.
- Files: `test/unit/movement/target_movement_behavior_test.gd`, `test/unit/movement/input_movement_behavior_test.gd` (created)

### Step 3: BehaviorSubject tests
- [x] Create `test/unit/events/behavior_subject_test.gd`: `has_value()` false before emit; `get_value()`/`has_value()` after emit; `subscribe()` with no prior value doesn't fire immediately; `subscribe()` with a prior value replays immediately; `emit()` notifies all existing subscribers.
- Files: `test/unit/events/behavior_subject_test.gd` (created)

### Step 4: Status pipeline tests
- [x] Create `test/unit/status/status_event_test.gd`: constructor sets `type`/`amount`.
- [x] Create `test/unit/status/health_component_test.gd`: `_ready()` sets `current_health = max_health`; damage reduces health with `roundi()` rounding; clamps at 0; `died` emitted exactly once at 0 (and does not re-emit on further damage while already at 0); non-`physical_damage` events ignored; `value_changed` payload correctness.
- [x] Create `test/unit/status/shield_component_test.gd`: `_ready()` sets `current_shield = max_shield`; absorption with rounding; clamps at 0; overflow damage mutates `event.amount` to the unabsorbed remainder; depleted shield (`current_shield == 0`) is a full no-op (event passes through unchanged, no signal); non-`physical_damage` events ignored; `value_changed` payload correctness.
- Files: `test/unit/status/status_event_test.gd`, `test/unit/status/health_component_test.gd`, `test/unit/status/shield_component_test.gd` (created)

### Step 5: BossActivity math tests
- [x] Create `test/unit/activities/boss_activity_test.gd`: `_max_reachable_distance()` for each of the four axis-aligned directions (`RIGHT`, `LEFT`, `UP`, `DOWN`) plus one diagonal, against known world bounds and origin, asserting the exact expected distance; confirm a zero-component direction doesn't divide by zero (already guarded by the existing `if`/`elif`, so this test documents/locks in that guarantee).
- Files: `test/unit/activities/boss_activity_test.gd` (created)

### Step 6: Full suite verification
- [x] Run the full suite headlessly: `Godot_v4.7.1-stable_win64.exe --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json` (or equivalent flags per GUT's actual CLI interface — confirm exact invocation against `addons/gut/gut_cmdln.gd` at implementation time) and confirm all tests pass with zero failures/errors.
- [x] Fix any failures found (test bugs or, if truly necessary, flag any source-code surprises to the user rather than silently patching production code, since `feature.md` scopes this as test-only).
- Files: none (verification step)

## Acceptance Criteria Mapping
| AC | Verified By |
|----|-------------|
| AC-01 | `test/unit/movement/target_movement_behavior_test.gd` |
| AC-02 | `test/unit/movement/input_movement_behavior_test.gd` |
| AC-03 | `test/unit/events/behavior_subject_test.gd` |
| AC-04 | `test/unit/status/status_event_test.gd` |
| AC-05 | `test/unit/status/health_component_test.gd` |
| AC-06 | `test/unit/status/shield_component_test.gd` |
| AC-07 | `test/unit/activities/boss_activity_test.gd` |
| AC-08 | Step 6 — full headless suite run, zero failures |
| AC-09 | Handled at `/sdd-archive` time, not during implementation (per `feature.md`, this is a docs update deferred to archive) |

## Risks & Mitigations
- **Risk**: GUT's exact CLI invocation/flags for `.gutconfig.json` may differ slightly from what's assumed here (first time this project has configured GUT for a real run). → **Mitigation**: Step 6 explicitly says to confirm the exact invocation against `addons/gut/gut_cmdln.gd`'s own argument parsing at implementation time rather than assuming the flag names are correct up front.
- **Risk**: `add_child_autofree()` (or whichever GUT scene-tree helper is used) might not trigger `_ready()` synchronously depending on Godot's node-ready timing, which `HealthComponent`/`ShieldComponent` tests depend on for initialization. → **Mitigation**: verify in the first test written (e.g. an initialization-only assertion) before building out the rest of that file's damage-scenario tests, so a timing issue surfaces early and cheaply.
- **Risk**: `Input.action_press`/`action_release` requires the `left`/`right`/`up`/`down` actions to already exist in `project.godot`'s input map. → **Mitigation**: `feature.md` already confirms these actions exist (since `InputMovementBehavior` depends on them in production); no new action definitions needed.
- **Risk**: Test order independence — if GUT runs test methods in a non-deterministic order, leaked `Input` action state from a failed/aborted `InputMovementBehavior` test could affect other tests. → **Mitigation**: `after_each()` unconditionally releases all four actions regardless of test outcome, per the Architecture Decisions above.

## Estimated Complexity
**Low** — seven small, focused test files against already-simple, already-reviewed pure-logic code, plus one new config file. No production code changes, no scene/autoload complexity (deferred per `feature.md`'s Out of Scope). The only real unknown is confirming GUT's exact headless CLI invocation, which is a one-time discovery cost.
