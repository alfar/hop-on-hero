## Implementation Complete

### Files Created
- `components/movement/input_movement_behavior.gd` — `InputMovementBehavior` class, reads `Input.get_vector` and scales by its own `speed` export.

### Files Modified
- `player.gd` — removed `get_input()` and its own `speed` export; now delegates to `@export var movement_behavior: MovementBehavior` in `_physics_process`, matching `enemy.gd`.
- `player.tscn` — added `ext_resource` for the new script, a `SubResource` (`InputMovementBehavior_ihqmb`) with `speed = 400`, and wired it to `Player.movement_behavior`.

### Acceptance Criteria
- [x] AC-01: Passed — code inspection of `input_movement_behavior.gd`.
- [x] AC-02: Passed — code inspection of `player.gd`.
- [x] AC-03: Passed — code inspection of `player.tscn`.
- [x] AC-04: Passed (headless) — `godot --headless --check-only` and a 60-frame headless run of `player.tscn` both completed with no errors (no null `movement_behavior` crash); full interactive WASD playtest not run in this environment.
- [x] AC-05: Passed — `enemy.gd` and `target_movement_behavior.gd` untouched.

### Notes
- Verification used Godot's headless mode instead of the editor (no interactive display in this environment); recommend a quick manual playtest to visually confirm movement feel before archiving.
- No deviations from `plan.md`.
