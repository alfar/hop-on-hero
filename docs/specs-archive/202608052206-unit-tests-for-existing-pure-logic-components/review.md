# Code Review: Unit Tests for Existing Pure-Logic Components

## Summary
Solid first pass at GUT coverage: 33 tests across 7 files, all passing, correctly scoped to pure-logic code with no scene-tree/autoload dependencies. Two real pre-existing bugs (`died` re-firing, spurious `value_changed` on zero-rounded damage) were found and fixed along the way, which is exactly what this kind of pass should surface. Findings below are minor — one test is tautological rather than a real check, `MovementBehavior`'s base-class behavior from FR-01 was never actually tested, and a couple of small polish items. Ready to merge after the two Minor items are addressed (or accepted as-is).

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
| [x] | `test/unit/activities/boss_activity_test.gd:30-39` | Test Quality | The diagonal test computes its `expected` value using the exact same formula (`(_world_size.y - _origin.y) / direction.y`) as the line under test (`boss_activity.gd:45`), so a bug in that formula would pass the test too — it only truly verifies that the *y-axis branch* was the one selected as the limiting factor, not that the formula itself is correct. | Assert against an independently-computed literal value (e.g. `500.0 / sin(PI/4)` ≈ `707.107`) instead of re-deriving it from the same expression the source uses. **Fixed**: now asserts against the literal `707.107`; the redundant `test_zero_x_component_direction_does_not_divide_by_zero` was folded into `test_reachable_distance_facing_down`. |
| [x] | `feature.md:12-15` (FR-01), `test/unit/movement/` | Acceptance Criteria | FR-01 explicitly calls for testing `MovementBehavior.get_velocity()` (base class returns `Vector2.ZERO`), but no test in `target_movement_behavior_test.gd` or elsewhere instantiates `MovementBehavior` directly — only the `TargetMovementBehavior` subclass is covered. | Add a one-line test instantiating `MovementBehavior.new()` and asserting `get_velocity(...)` returns `Vector2.ZERO`, or narrow FR-01/AC-01's wording if the base class is considered trivial enough to skip intentionally. **Fixed**: added `test_base_movement_behavior_returns_zero` to `target_movement_behavior_test.gd`. |

### 🔵 Info / Suggestions

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [x] | `test/unit/activities/boss_activity_test.gd:41-45` | Code Duplication | `test_zero_x_component_direction_does_not_divide_by_zero` is an exact duplicate of `test_reachable_distance_facing_down` (same inputs, same assertions, plus one extra `assert_ne`) — it doesn't add coverage beyond what facing-down already proves. | Either fold the `assert_ne(distance, INF)` line into `test_reachable_distance_facing_down` or give this test a distinct direction (e.g. a case where *both* axis components are zero-or-negative) to actually add value. **Fixed**: folded into `test_reachable_distance_facing_down` as part of the Minor #1 fix above; the standalone duplicate test was removed. |
| [ ] | `components/status/health_component.gd:16`, `components/status/shield_component.gd:14` | Code Duplication | Both components now share the identical `roundi(event.amount) == 0` no-op guard clause, duplicated rather than shared — minor since `StatusComponent` subclasses are otherwise independent, but worth noting if a third component repeats the pattern. | If a third `StatusComponent` subclass needs the same zero-amount guard, consider a small protected helper on the base class (e.g. `_is_no_op_amount(event)`) rather than a third copy-paste. |

## Acceptance Criteria Coverage
| AC | Test | Status |
|----|------|--------|
| AC-01 | `test/unit/movement/target_movement_behavior_test.gd` (both cases) | ✅ Covered (TargetMovementBehavior only — base `MovementBehavior` untested, see Minor finding) |
| AC-02 | `test/unit/movement/input_movement_behavior_test.gd` (no-input, single-direction, opposing-direction) | ✅ Covered |
| AC-03 | `test/unit/events/behavior_subject_test.gd` (all 5 cases) | ✅ Covered |
| AC-04 | `test/unit/status/status_event_test.gd` | ✅ Covered |
| AC-05 | `test/unit/status/health_component_test.gd` (8 tests, incl. zero-rounded-damage no-op) | ✅ Covered |
| AC-06 | `test/unit/status/shield_component_test.gd` (8 tests, incl. zero-rounded-damage no-op) | ✅ Covered |
| AC-07 | `test/unit/activities/boss_activity_test.gd` (4 axes + diagonal + zero-x-component) | ✅ Covered (diagonal test is tautological, see Minor finding) |
| AC-08 | Full suite: 7 scripts, 33 tests, 33 passing, headless run via `-s addons/gut/gut_cmdln.gd -gexit` confirmed in this review | ✅ Covered |
| AC-09 | `docs/project.md:35` still says "not yet populated with any tests" | ❌ Not yet done — correctly deferred to `/sdd-archive` per `plan.md`, not a review blocker |

## Verdict
- [ ] ✅ Ready to merge
- [x] 🟡 Merge after minor fixes (no re-review needed)
- [ ] 🟠 Requires fixes and re-review
- [ ] 🔴 Do not merge — significant issues found
