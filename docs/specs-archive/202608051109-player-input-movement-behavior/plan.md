# Implementation Plan: Player Input Movement Behavior

## Overview
Extract the player's inline input-reading movement logic out of `player.gd` into a new `InputMovementBehavior` Resource under `components/movement/`, following the same `MovementBehavior` strategy pattern already used by `enemy.gd` / `TargetMovementBehavior`. `player.gd` is reduced to a thin script that delegates to an exported `movement_behavior`, and `player.tscn` is updated to wire in the new behavior sub-resource with `speed = 400`.

This is a pure refactor (no new gameplay behavior) confined to three files: one new script, one modified script, one modified scene.

## Architecture Decisions
- **Follow the existing strategy pattern exactly** — mirror `enemy.gd`'s shape (`@export var movement_behavior: MovementBehavior`, single line in `_physics_process`) rather than inventing a new integration style. This keeps `player.gd` and `enemy.gd` structurally identical, per `docs/project.md`'s architecture conventions.
- **Speed lives on the behavior resource, not the node**, consistent with `TargetMovementBehavior` owning its own `@export var speed`. `player.gd` will not retain a `speed` field.
- **`get_velocity(position)` signature stays unchanged.** `InputMovementBehavior.get_velocity` accepts `position` for interface compatibility but ignores it, since input-driven movement has no positional dependency. `MovementBehavior` and `TargetMovementBehavior` are not touched.
- **No test layer** — `docs/project.md` confirms no testing framework is configured; verification is manual (run the game in the editor and confirm movement).

## Implementation Steps

### Step 1: Create InputMovementBehavior ✅
- [x] Create `components/movement/input_movement_behavior.gd`:
  ```gdscript
  class_name InputMovementBehavior
  extends MovementBehavior

  @export var speed = 400

  func get_velocity(position: Vector2):
      var input_direction = Input.get_vector("left", "right", "up", "down")
      return input_direction * speed
  ```
- Files to create: `components/movement/input_movement_behavior.gd`

### Step 2: Refactor player.gd ✅
- [x] Remove `@export var speed = 400`.
- [x] Remove the `get_input()` function entirely.
- [x] Add `@export var movement_behavior: MovementBehavior`.
- [x] Update `_physics_process` to:
  ```gdscript
  extends CharacterBody2D

  @export var movement_behavior: MovementBehavior

  func _physics_process(delta: float) -> void:
      velocity = movement_behavior.get_velocity(position)
      move_and_slide()
  ```
- Files to modify: `player.gd`

### Step 3: Wire up player.tscn ✅
- [x] Add a `SubResource` of type `InputMovementBehavior` with `speed = 400`, following the same `[sub_resource]` block convention already present in `player.tscn` (e.g. `RectangleShape2D_fsqmc`).
- [x] Add `movement_behavior = SubResource("InputMovementBehavior_<id>")` to the `Player` node block.
- [x] Confirm the `Player` node has no leftover `speed` property (it currently has none set explicitly, so no removal needed — verify after edit).
- Files to modify: `player.tscn`

### Step 4: Manual verification ✅ (partial — headless checks passed; interactive input playtest still recommended)
- [x] Ran project headless (`--check-only`) — no compile/parse errors across scripts.
- [x] Ran `player.tscn` headless for 60 frames — no runtime errors, no null `movement_behavior` crash, confirming the sub-resource wiring in Step 3 is correct.
- [ ] Open the project in the Godot editor and confirm the player visibly moves via WASD/arrow keys in all 8 directions at the same speed as before (400 px/s, diagonal normalized by `Input.get_vector`) — requires interactive input, not exercised headlessly.
- [x] Confirm `enemy.tscn` / `enemy.gd` behavior is unaffected (enemy scene untouched — no diffs made).

## Acceptance Criteria Mapping
| AC | Verified By |
|----|-------------|
| AC-01: `InputMovementBehavior` exists, extends `MovementBehavior`, returns `input_direction * speed` | Step 1 — code inspection of `components/movement/input_movement_behavior.gd` |
| AC-02: `player.gd` delegates to `movement_behavior`, no `get_input()`/own `speed` | Step 2 — code inspection of `player.gd` |
| AC-03: `player.tscn` assigns `InputMovementBehavior` sub-resource with `speed = 400` | Step 3 — code inspection of `player.tscn` |
| AC-04: Player moves correctly in-game at same speed | Step 4 — manual playtest in Godot editor |
| AC-05: No regressions to `enemy.gd` / `TargetMovementBehavior` | Step 4 — manual playtest confirms enemy unaffected; no diffs made to those files |

## Risks & Mitigations
- Risk: Forgetting to wire the `movement_behavior` export in `player.tscn` leaves it `null`, causing a runtime error on the first `_physics_process` call. → Mitigation: Step 4 explicitly checks for this; Step 3 is ordered before verification.
- Risk: `unique_id` or node structure in `player.tscn` gets accidentally altered while hand-editing the `.tscn` text. → Mitigation: only add the new `sub_resource` block and one property line; leave all existing node blocks untouched.

## Estimated Complexity
Low — one new ~8-line script, a small edit to an existing ~10-line script, and a small addition to a scene file. No new architectural concepts; directly mirrors the existing `enemy.gd`/`TargetMovementBehavior` pattern.
