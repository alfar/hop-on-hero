# Implementation Plan: Movement Behavior Stack with Chase-Player Fallback

## Overview
Replace `Enemy`'s single `@export var movement_behavior: MovementBehavior` with a `MovementStack` (a `Resource` holding an ordered `Array[MovementBehavior]`) that polls each behavior's new `is_finished(position)` and permanently pops finished ones off the top. Add `ChasePlayerMovementBehavior` as a new leaf behavior. Wire `BossActivity` to push `ChasePlayerMovementBehavior` (bottom) then `TargetMovementBehavior` (top) onto a fresh stack per spawn, and update `Enemy`/`Player` and all affected tests accordingly. This is a pure GDScript change — no scenes, autoloads, or new dependencies — following the existing `components/<category>/` Resource-based behavior convention.

## Architecture Decisions
- `MovementStack` is `extends Resource` (not `Node`), matching `MovementBehavior`/`Activity` and keeping it `@export`-assignable on `Enemy`, consistent with `docs/project.md`'s existing convention for swappable behavior.
- Finished-behavior detection is polled (`is_finished(position: Vector2) -> bool`, called from `MovementStack.get_velocity` every physics frame), not signal-based — decided in the refinement pass in `feature.md` (Revision History) to avoid an arrival-race where a behavior already past threshold at push time would never fire a signal.
- Popping is permanent and one-directional (top → bottom) within a `MovementStack`'s lifetime; nothing in this feature re-pushes a popped behavior. This keeps `MovementStack` itself dead simple (no requeueing logic) and matches the "chase-player is a permanent bottom layer" decision in `feature.md`.
- `ChasePlayerMovementBehavior` receives its player reference via an injected `@export var player: Node2D` rather than resolving it itself. `MovementBehavior` subclasses are `Resource`s with no `get_tree()`, so a self-resolving group lookup would need an untested `Engine.get_main_loop()` cast; injection keeps all tree/group access in `BossActivity`, which already does this kind of scene-level wiring (it receives `spawn_parent`, a `Node`, as a parameter).

## Implementation Steps

### Step 1: `MovementBehavior` base — add `is_finished`
- [x] Add `func is_finished(position: Vector2) -> bool: return false` to `components/movement/movement_behavior.gd`.
- Files: `components/movement/movement_behavior.gd`

### Step 2: `TargetMovementBehavior` — override `is_finished`
- [x] Add `func is_finished(position: Vector2) -> bool: return position.distance_to(target) < 10`, reusing the same threshold `get_velocity` already checks.
- Files: `components/movement/target_movement_behavior.gd`

### Step 3: New `MovementStack` component
- [x] Create `components/movement/movement_stack.gd`:
  - `class_name MovementStack`, `extends Resource`
  - `var behaviors: Array[MovementBehavior] = []` (internal; top of stack = last element)
  - `func push_behavior(behavior: MovementBehavior) -> void` — `behaviors.append(behavior)`
  - `func pop_behavior() -> MovementBehavior` — `return behaviors.pop_back()`
  - `func get_velocity(position: Vector2) -> Vector2`:
    - `while behaviors.size() > 0 and behaviors[-1].is_finished(position): behaviors.pop_back()`
    - `if behaviors.is_empty(): return Vector2.ZERO`
    - `return behaviors[-1].get_velocity(position)`
- Files: `components/movement/movement_stack.gd`

### Step 4: New `ChasePlayerMovementBehavior`
- [x] Create `components/movement/chase_player_movement_behavior.gd`:
  - `class_name ChasePlayerMovementBehavior`, `extends MovementBehavior`
  - `@export var player: Node2D`
  - `@export var speed = 400`
  - `func get_velocity(position: Vector2) -> Vector2`:
    - `if not is_instance_valid(player): return Vector2.ZERO`
    - `return position.direction_to(player.global_position) * speed`
- Files: `components/movement/chase_player_movement_behavior.gd`

### Step 5: `Player` joins `"player"` group
- [x] Add `func _ready() -> void:` (or extend the existing one if `player.gd` gains one) with `add_to_group("player")`, mirroring `enemy.gd`'s `_ready()`.
- Note: `scenes/player/player.gd` currently has no `_ready()` — check current file state before editing in case that's changed; add one if still absent.
- Files: `scenes/player/player.gd`

### Step 6: `Enemy` — switch to `MovementStack`
- [x] Replace `@export var movement_behavior: MovementBehavior` with `@export var movement_stack: MovementStack` in `scenes/enemy/enemy.gd`.
- [x] `_physics_process`: `velocity = movement_stack.get_velocity(position)`.
- [x] `_on_died()`: replace `movement_behavior = MovementBehavior.new()` with `movement_stack = MovementStack.new()`.
- [x] Check `scenes/enemy/enemy.tscn` for any exported `movement_behavior` value set directly on the node in the scene file — none found in the current scene (BossActivity assigns it at spawn time), so no `.tscn` edit expected, but re-verify before finishing this step.
- Files: `scenes/enemy/enemy.gd`

### Step 7: `BossActivity` — build the stack
- [x] In `boss_activity.gd`'s `execute()`, replace the single `TargetMovementBehavior` construction/assignment with:
  ```gdscript
  var player := spawn_parent.get_tree().get_first_node_in_group("player")

  var stack := MovementStack.new()

  var chase_behavior := ChasePlayerMovementBehavior.new()
  chase_behavior.player = player
  stack.push_behavior(chase_behavior)

  var behavior := TargetMovementBehavior.new()
  behavior.target = target
  stack.push_behavior(behavior)

  instance.movement_stack = stack
  ```
  `player` may be `null` in contexts with no `Player` in the tree (e.g. a test); `ChasePlayerMovementBehavior` already handles that by returning `Vector2.ZERO` (Step 4).
- Files: `components/activities/boss_activity.gd`

### Step 8: Update existing tests for the new API
- [x] `test/unit/movement/target_movement_behavior_test.gd`: add `is_finished` coverage (see Step 9) — no existing test needs to change since `get_velocity` behavior is untouched.
- [x] `test/unit/enemy/enemy_movement_stop_test.gd`: currently proves "replacing `movement_behavior` with `MovementBehavior.new()` stops movement" directly on bare `MovementBehavior`/`TargetMovementBehavior` instances (no `Enemy` involved) — rewrite to prove the equivalent `MovementStack` contract instead: a stack containing a moving `TargetMovementBehavior`, when replaced by a fresh empty `MovementStack`, returns `Vector2.ZERO`. Rename test method accordingly.
- [x] `test/integration/weapon/weapon_test_helpers.gd`: `make_enemy` currently does `enemy.movement_behavior = MovementBehavior.new()` — change to `enemy.movement_stack = MovementStack.new()` (an empty stack already returns `Vector2.ZERO`, so no behavior needs pushing) and update the doc comment above it.
- [x] `test/integration/enemy/enemy_death_test.gd`: `test_died_stops_movement_and_disables_hit_area_immediately` sets `enemy.movement_behavior = moving_behavior` and asserts `enemy.movement_behavior.get_velocity(...)`  — change to construct a `MovementStack`, `push_behavior(moving_behavior)`, assign to `enemy.movement_stack`, and assert against `enemy.movement_stack.get_velocity(enemy.position)` post-death.
- Files: `test/unit/enemy/enemy_movement_stop_test.gd`, `test/integration/weapon/weapon_test_helpers.gd`, `test/integration/enemy/enemy_death_test.gd`

### Step 9: New unit tests for the new components
- [x] `test/unit/movement/movement_behavior_test.gd` (extend existing base-behavior test file if present, else confirm base coverage already exists in `target_movement_behavior_test.gd`'s `test_base_movement_behavior_returns_zero`): add a case asserting `MovementBehavior.new().is_finished(Vector2.ZERO) == false`.
- [x] `test/unit/movement/target_movement_behavior_test.gd`: add cases for `is_finished` — `false` when outside the 10-unit threshold, `true` when inside it (mirroring the existing `get_velocity` threshold tests).
- [x] `test/unit/movement/movement_stack_test.gd` (new file):
  - Empty stack → `get_velocity` returns `Vector2.ZERO`.
  - Stack with one non-finished behavior → returns that behavior's velocity.
  - Stack with `[ChasePlayerMovementBehavior-like stub or MovementBehavior stub, TargetMovementBehavior]` where the top `is_finished` → asserts it's popped (`get_velocity` now reflects the layer below) and that a subsequent call reflects the popped state persisting.
  - `push_behavior`/`pop_behavior` round-trip.
- [x] `test/unit/movement/chase_player_movement_behavior_test.gd` (new file) — since `player` is now an injected `@export` reference rather than a group lookup, this is pure logic with no scene-tree dependency, so it belongs under `test/unit/movement/` (not `test/integration/`), consistent with `docs/project.md`'s unit-vs-integration split:
  - `player` left `null` → `get_velocity` returns `Vector2.ZERO`.
  - `player` set to a `Node2D` (a plain instance with a known `global_position`, no scene tree needed) → velocity points toward it at `speed` magnitude.
  - `player` set but freed (`queue_free()`'d and no longer a valid instance) → returns `Vector2.ZERO`, proving the `is_instance_valid` guard.
- Files: `test/unit/movement/target_movement_behavior_test.gd`, `test/unit/movement/movement_stack_test.gd`, `test/unit/movement/chase_player_movement_behavior_test.gd`

### Step 10: Manual verification
- [x] Run the GUT suite headlessly (per `docs/project.md`'s `.gutconfig.json` setup) and confirm all unit + integration tests pass. (66/66 passing.)
- [x] Launch the game via the Godot editor/executable, trigger a `BossActivity` spawn, and visually confirm an enemy walks to its random destination and then turns to chase the player. (Confirmed by the user — works as intended. The manually-added demo `Enemy` node in `game.tscn` was subsequently removed by the user, so `game.tscn` no longer has a static scene-level movement override; only `BossActivity`-spawned enemies remain.)

## Acceptance Criteria Mapping
| AC | Verified By |
|----|-------------|
| AC-01: `MovementBehavior.is_finished` defaults `false` | `test/unit/movement/target_movement_behavior_test.gd` (new base-behavior case, Step 9) |
| AC-02: `TargetMovementBehavior.is_finished` threshold | `test/unit/movement/target_movement_behavior_test.gd` (new `is_finished` cases, Step 9) |
| AC-03: stack returns top behavior's velocity while unfinished | `test/unit/movement/movement_stack_test.gd#test_returns_top_behavior_velocity_when_not_finished` |
| AC-04: finished top behavior popped, falls through to next | `test/unit/movement/movement_stack_test.gd#test_pops_finished_behavior_and_falls_through` |
| AC-05: empty stack returns `Vector2.ZERO` | `test/unit/movement/movement_stack_test.gd#test_empty_stack_returns_zero` |
| AC-06: `ChasePlayerMovementBehavior` velocity toward player / zero when absent | `test/unit/movement/chase_player_movement_behavior_test.gd` |
| AC-07: `Player._ready()` joins `"player"` group; `BossActivity` injects it | Manual verification (Step 10) plus, if a `BossActivity` test context exists, asserting `spawn_parent.get_tree().get_first_node_in_group("player")` resolves correctly — otherwise covered end-to-end by Step 10 |
| AC-08: `BossActivity`-spawned enemy wanders then chases | Step 10 manual verification (no existing automated coverage of `BossActivity` spawn behavior beyond its reachable-distance math; adding full spawn-to-chase integration coverage is not in the existing test suite's scope and is called out as a residual risk below) |
| AC-09: `_on_died()` still zeroes velocity immediately | `test/integration/enemy/enemy_death_test.gd#test_died_stops_movement_and_disables_hit_area_immediately` (updated, Step 8) |
| AC-10: existing tests updated to `movement_stack` API | Step 8 (all three files) |

## Risks & Mitigations
- Risk: `BossActivity.execute()`'s `spawn_parent.get_tree().get_first_node_in_group("player")` returns `null` if `Player` hasn't called `add_to_group("player")` yet by the time an activity fires (ordering/timing between `Player._ready()` and the activity scheduler). Mitigation: `ChasePlayerMovementBehavior` already tolerates `player == null` by returning `Vector2.ZERO` (no crash), so worst case is a spawned enemy that doesn't chase until a future spawn re-resolves the reference; confirm via Step 10 manual verification that `Player` is in the tree and grouped before the first activity can fire in practice.
- Risk: AC-08 (full spawn → wander → chase behavior) has no direct automated test in this plan — `BossActivity` integration tests don't currently exist, and building one would need a running `SceneTree` with both `World`/`GameEvents` wiring and a real `Player`, which is a bigger lift than this feature's scope. Mitigation: cover it via manual verification (Step 10) and rely on the component-level unit tests (`MovementStack`, `ChasePlayerMovementBehavior`) to give confidence in the pieces; flag to the user as an accepted gap rather than silently skipping it.
- Risk: Updating `enemy_movement_stop_test.gd` changes its assertion target from bare behaviors to a `MovementStack`, which slightly changes what the test is proving. Mitigation: keep the spirit of the original test (that swapping in a fresh, "stopped" default state kills movement) while updating the mechanism, and keep the test name/doc comment honest about what's being asserted now.

## Estimated Complexity
Low — four new/changed small GDScript files (`movement_behavior.gd`, `target_movement_behavior.gd`, two new components), two call-site updates (`enemy.gd`, `boss_activity.gd`), one small addition (`player.gd`), and mechanical updates to three existing test files plus two new test files. No scene, autoload, or dependency changes. Injecting the player reference (rather than a `Resource`-side tree/group lookup) keeps every new component pure logic, so all new tests are unit-level with no scene-tree setup required.
