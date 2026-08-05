# Feature: Player Input Movement Behavior

## Summary
Refactor `player.gd` to follow the existing component/behavior-based movement architecture already used by `enemy.gd`. The player's inline `get_input()` logic (reading `Input.get_vector` and scaling by speed) moves into a new `InputMovementBehavior` Resource under `components/movement/`, which implements the `MovementBehavior` interface (`get_velocity(position)`). `player.gd` becomes a thin script that delegates to an `@export var movement_behavior: MovementBehavior`, matching `enemy.gd`.

## User Stories
- As a developer extending HopOnHero, I want player movement to use the same `MovementBehavior` component pattern as enemies, so that movement logic is consistent, swappable, and testable across all entities.
- As a game designer, I want to tune player speed via an exported Resource field in the editor, so that I can adjust movement without touching code.

## Functional Requirements

### FR-01: InputMovementBehavior class
Create `components/movement/input_movement_behavior.gd` with `class_name InputMovementBehavior extends MovementBehavior`. It exposes `@export var speed = 400` and implements `get_velocity(position: Vector2)`, which reads `Input.get_vector("left", "right", "up", "down")` and returns `input_direction * speed`. The `position` parameter is accepted (per the base class signature) but unused.

### FR-02: Refactor player.gd
Update `player.gd` to match the shape of `enemy.gd`:
- Remove `@export var speed` and the `get_input()` method.
- Add `@export var movement_behavior: MovementBehavior`.
- In `_physics_process`, set `velocity = movement_behavior.get_velocity(position)` then call `move_and_slide()`.

### FR-03: Update player.tscn
Attach an `InputMovementBehavior` sub-resource to the `Player` node's `movement_behavior` export slot (as a `SubResource`, mirroring how `enemy.tscn` would attach a `TargetMovementBehavior`), with `speed = 400` to preserve current behavior. Remove the now-unused `speed` property from the `Player` node in the scene file.

## Acceptance Criteria
- [x] AC-01: `components/movement/input_movement_behavior.gd` exists, extends `MovementBehavior`, and returns `input_direction * speed` from `get_velocity`.
- [x] AC-02: `player.gd` no longer contains `get_input()` or its own `speed` export; it holds `@export var movement_behavior: MovementBehavior` and delegates velocity calculation to it in `_physics_process`, identical in structure to `enemy.gd`.
- [x] AC-03: `player.tscn` assigns an `InputMovementBehavior` sub-resource with `speed = 400` to the Player's `movement_behavior` field.
- [x] AC-04: Running the game, the player moves in response to left/right/up/down input at the same speed as before the refactor (400 px/s, normalized diagonal via `Input.get_vector`'s built-in behavior).
- [x] AC-05: No regressions to `enemy.gd` or `TargetMovementBehavior` — both remain unchanged.

## Technical Scope

### Affected Modules
- `player.gd`
- `player.tscn`

### New Components Required
- `components/movement/input_movement_behavior.gd` (`InputMovementBehavior` class)

### Integration Points
- `MovementBehavior` base class (`components/movement/movement_behavior.gd`) — consumed, not modified.
- Pattern parallels `enemy.gd` + `TargetMovementBehavior`, which remain the reference implementation and are not modified.

## Non-Functional Requirements
- Performance: negligible — same per-frame work, just relocated.
- Security: not applicable.
- Scalability: improves consistency for future entities/behaviors (e.g. dash, auto-shoot movement modifiers) by keeping all movement logic behind the same interface.

## Out of Scope
- Changing the `MovementBehavior.get_velocity(position)` interface signature.
- Adding new movement behaviors beyond `InputMovementBehavior` (e.g. no combined input+dodge behavior).
- Any combat, shooting, or tower-defense mechanics.
- Adding automated tests (none configured in this project yet).

## Open Questions
None — naming, interface, and speed placement were confirmed with the user during spec analysis.
