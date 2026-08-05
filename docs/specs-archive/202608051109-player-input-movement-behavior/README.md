# Player Input Movement Behavior

Implemented on: 2026-08-05

Refactored `player.gd` to use the same component/behavior-based movement pattern already established by `enemy.gd`/`TargetMovementBehavior`. Added `components/movement/input_movement_behavior.gd` (`InputMovementBehavior`), which reads `Input.get_vector("left", "right", "up", "down")` and scales by its own `@export var speed`. `player.gd` was reduced to delegate to `movement_behavior.get_velocity(position)`, and `player.tscn` was updated with a wired-up `InputMovementBehavior` sub-resource (`speed = 400`).

Pure refactor — no behavior change from the player's perspective, no new gameplay mechanics. All 5 acceptance criteria passed; code review found no critical or major issues (one pre-existing, unrelated gap noted: `enemy.tscn` has no `movement_behavior` assigned when instanced standalone, though `world.tscn` overrides it correctly).
