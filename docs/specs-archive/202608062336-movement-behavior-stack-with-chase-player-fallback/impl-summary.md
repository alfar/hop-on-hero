## Implementation Complete

### Files Created
- `components/movement/movement_stack.gd` — `MovementStack` (push/pop stack of `MovementBehavior`, pops finished behaviors, falls through to next)
- `components/movement/chase_player_movement_behavior.gd` — `ChasePlayerMovementBehavior` (moves toward an injected `player` reference)
- `test/unit/movement/movement_stack_test.gd`
- `test/unit/movement/chase_player_movement_behavior_test.gd`

### Files Modified
- `components/movement/movement_behavior.gd` — added `is_finished(_position) -> bool`, default `false`
- `components/movement/target_movement_behavior.gd` — added `is_finished(position)` override (arrival threshold)
- `scenes/enemy/enemy.gd` — `movement_behavior` → `movement_stack: MovementStack`; `_on_died()` resets to a fresh empty `MovementStack`
- `scenes/player/player.gd` — `_ready()` calls `add_to_group("player")`
- `components/activities/boss_activity.gd` — resolves player via `spawn_parent.get_tree().get_first_node_in_group("player")`, builds a `MovementStack` (`ChasePlayerMovementBehavior` bottom, `TargetMovementBehavior` top)
- `scenes/game.tscn` — the demo `Enemy`'s scene-level movement override was changed from a bare `movement_behavior` resource to a `movement_stack` wrapping the same `TargetMovementBehavior`; the user later removed that manually-added demo `Enemy` node entirely after confirming the feature worked, so `game.tscn` no longer has any static enemy or movement override — only `BossActivity`-spawned enemies remain
- `test/unit/movement/target_movement_behavior_test.gd` — added `is_finished` coverage + base-behavior `is_finished` case
- `test/unit/enemy/enemy_movement_stop_test.gd` — rewritten around `MovementStack` instead of a bare `MovementBehavior` sentinel
- `test/integration/enemy/enemy_death_test.gd` — updated to build/assert against `movement_stack`
- `test/integration/weapon/weapon_test_helpers.gd` — `make_enemy` now assigns an empty `MovementStack`
- `test/integration/weapon/game_scene_wiring_test.gd` — doc comment updated (`Enemy.movement_behavior` → `Enemy.movement_stack`)

### Acceptance Criteria
- [x] AC-01: Passed — `target_movement_behavior_test.gd#test_base_movement_behavior_is_never_finished`
- [x] AC-02: Passed — `target_movement_behavior_test.gd#test_is_finished_false_when_outside_threshold` / `#test_is_finished_true_when_within_threshold`
- [x] AC-03: Passed — `movement_stack_test.gd#test_returns_top_behavior_velocity_when_not_finished`
- [x] AC-04: Passed — `movement_stack_test.gd#test_pops_finished_behavior_and_falls_through`
- [x] AC-05: Passed — `movement_stack_test.gd#test_empty_stack_returns_zero`
- [x] AC-06: Passed — `chase_player_movement_behavior_test.gd` (all 3 cases)
- [~] AC-07: Implemented (`Player._ready()` group join, `BossActivity` injection) but no dedicated automated test — verified by code inspection only
- [ ] AC-08: Not automated (accepted gap, per plan.md); manual in-game verification not completed this session — game window was closed by the user before it could be observed
- [x] AC-09: Passed — `enemy_death_test.gd#test_died_stops_movement_and_disables_hit_area_immediately`
- [x] AC-10: Passed — full GUT suite (66/66) including all updated test files
- [x] AC-08: Confirmed manually by the user in a running game — a spawned enemy walks to its destination, then chases the player.

### Notes
- Deviation from plan: `ChasePlayerMovementBehavior.player` was planned as `@export var player: Node2D`, but exporting a `Node`-derived type from a `Resource` script breaks GDScript property registration in Godot 4.7 (`Parse Error: Could not resolve external class member "player"`). Fixed by making it a plain (non-exported) `var player: Node2D` — it's only ever set via code injection (by `BossActivity`), never needed in the inspector, so this has no functional impact.
- `MovementStack.behaviors` was made `@export` (not planned) so `scenes/game.tscn`'s then-existing static demo `Enemy` movement override could be expressed declaratively in the scene file; that demo `Enemy` node has since been removed by the user (see Files Modified), so this only matters if a future scene needs a similarly static, editor-configured stack.
- `game.tscn` required a manual scene-file update not explicitly called out as its own plan step (it fell under Step 6's "check `enemy.tscn`" note, but the override actually lived in `game.tscn`) — found via test failures, fixed, and confirmed by the full suite passing.
