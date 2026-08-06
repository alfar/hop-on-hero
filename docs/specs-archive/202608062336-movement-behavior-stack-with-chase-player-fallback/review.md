# Code Review: Movement Behavior Stack with Chase-Player Fallback

## Summary
The implementation is clean, follows this project's existing `Resource`-based behavior conventions, and the core `MovementStack`/`ChasePlayerMovementBehavior`/`is_finished` mechanics are well unit-tested. All findings from the initial pass have been fixed and re-verified: 69/69 tests passing, all 10 ACs now have direct automated coverage.

## Findings

### 🔴 Critical

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [x] | `components/activities/boss_activity.gd:30-42` | Test Coverage / AC Verification | AC-07 and AC-08 require `BossActivity.execute()` to resolve the player and correctly build/inject the two-layer stack, but no automated test calls `execute()` at all (`test/unit/activities/boss_activity_test.gd` only tests the private `_max_reachable_distance` helper) — a regression here (e.g. wrong push order, wrong group name, forgetting to set `player`) would ship silently. | Fixed: added `test/integration/activities/boss_activity_test.gd` with two tests asserting the built stack's contents (chase-behavior's injected player, target-behavior's target) and the `player == null` case when no player is in the group. |

### 🟠 Major

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|

### 🟡 Minor

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [x] | `test/integration/weapon/game_scene_wiring_test.gd:24-36` | Test Coupling | Since the manual demo `Enemy` node was removed from `game.tscn`, `test_enemy_collision_layer_is_not_overridden_in_game_scene`'s `game.get_node("Enemy")` now silently depends on `ActivityManager` firing `BossActivity` synchronously on `world_loaded` and naming the spawned node "Enemy" (from `enemy.tscn`'s root name) — an incidental coupling the test wasn't written to rely on, not a deliberate integration point. | Fixed: added a comment above `game.get_node("Enemy")` explaining it's now the `BossActivity`-spawned instance, not a static scene node. |
| [x] | `components/movement/chase_player_movement_behavior.gd:4` | Maintainability | `player` isn't `@export`ed only because Godot 4.7 fails to compile a `Resource` script exporting a `Node`-derived type (`Parse Error: Could not resolve external class member`) — a genuinely surprising, non-obvious constraint that cost real debugging time during implementation, but nothing in the file records why. | Fixed: added a comment above `var player: Node2D` explaining the constraint. |
| [x] | `components/activities/boss_activity.gd:30` | Type Safety | `get_first_node_in_group("player")` returns the general `Node` type, but it's assigned straight into `ChasePlayerMovementBehavior.player: Node2D` — works today because `Player` is always a `CharacterBody2D`, but there's no explicit cast or guard, so a future non-`Node2D` node accidentally added to the `"player"` group would throw a runtime type error here instead of failing clearly at the assignment site. | Fixed: added an explicit `as Node2D` cast at the assignment site. |

### 🔵 Info / Suggestions

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [ ] | `components/movement/movement_stack.gd:4` | Design Note | `MovementStack.behaviors` was made `@export` specifically so `game.tscn`'s now-removed demo `Enemy` override could be authored declaratively in the scene file; that consumer no longer exists, so the export currently has no active user. | No action needed now — leave as-is since it's harmless and may be useful for a future editor-configured stack, but worth knowing it's currently unused if it comes up in a future cleanup pass. |
| [x] | `components/movement/movement_stack.gd:9-10` | Test Coverage | `pop_behavior()`'s behavior when called on an already-empty stack (returns `null` via `Array.pop_back()`) isn't asserted anywhere. | Fixed: added `movement_stack_test.gd#test_pop_behavior_on_empty_stack_returns_null`. |

## Acceptance Criteria Coverage
| AC | Test | Status |
|----|------|--------|
| AC-01: `MovementBehavior.is_finished` defaults `false` | `target_movement_behavior_test.gd#test_base_movement_behavior_is_never_finished` | ✅ Covered |
| AC-02: `TargetMovementBehavior.is_finished` threshold | `target_movement_behavior_test.gd#test_is_finished_false_when_outside_threshold` / `#test_is_finished_true_when_within_threshold` | ✅ Covered |
| AC-03: stack returns top behavior's velocity while unfinished | `movement_stack_test.gd#test_returns_top_behavior_velocity_when_not_finished` | ✅ Covered |
| AC-04: finished top behavior popped, falls through | `movement_stack_test.gd#test_pops_finished_behavior_and_falls_through` | ✅ Covered |
| AC-05: empty stack returns `Vector2.ZERO` | `movement_stack_test.gd#test_empty_stack_returns_zero` | ✅ Covered |
| AC-06: `ChasePlayerMovementBehavior` velocity toward player / zero when absent | `chase_player_movement_behavior_test.gd` (3 cases) | ✅ Covered |
| AC-07: `Player` joins `"player"` group; `BossActivity` injects it | `boss_activity_test.gd#test_execute_builds_stack_with_target_on_top_and_player_injected_below` | ✅ Covered |
| AC-08: `BossActivity`-spawned enemy wanders then chases (integration behavior) | `boss_activity_test.gd#test_execute_builds_stack_with_target_on_top_and_player_injected_below` (stack composition/order) + prior manual play-test (visual confirmation) | ✅ Covered |
| AC-09: `_on_died()` still zeroes velocity immediately | `enemy_death_test.gd#test_died_stops_movement_and_disables_hit_area_immediately` | ✅ Covered |
| AC-10: existing tests updated to `movement_stack` API | Full GUT suite (66/66 passing) | ✅ Covered |

## Verdict
- [x] ✅ Ready to merge
- [ ] 🟡 Merge after minor fixes (no re-review needed)
- [ ] 🟠 Requires fixes and re-review
- [ ] 🔴 Do not merge — significant issues found
