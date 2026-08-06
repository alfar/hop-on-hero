# Movement Behavior Stack with Chase-Player Fallback

Implemented on: 2026-08-06

Replaced `Enemy`'s single `@export var movement_behavior: MovementBehavior` slot with a `MovementStack` — an ordered push/pop stack of `MovementBehavior`s (`components/movement/movement_stack.gd`) that polls each behavior's new `is_finished(position)` and permanently pops finished ones off the top, falling through to the one below. Added `ChasePlayerMovementBehavior` (`components/movement/chase_player_movement_behavior.gd`), which moves toward an injected `player: Node2D` reference. `BossActivity` now resolves the `"player"`-group member and builds each spawn's stack with `ChasePlayerMovementBehavior` at the bottom and `TargetMovementBehavior` on top, so an enemy walks to its randomly-assigned destination first, then permanently falls through to chasing the player once it arrives.

Key files:
- `components/movement/movement_behavior.gd`, `target_movement_behavior.gd` — added `is_finished(position)`
- `components/movement/movement_stack.gd` (new)
- `components/movement/chase_player_movement_behavior.gd` (new)
- `scenes/enemy/enemy.gd` — `movement_behavior` → `movement_stack`
- `scenes/player/player.gd` — joins the `"player"` group
- `components/activities/boss_activity.gd` — builds the stack, injects the resolved player

Notable decisions:
- Completion is polled (`is_finished`), not signaled — avoids an arrival-race where a behavior already past threshold at push time would never fire a signal.
- The player reference is injected (`ChasePlayerMovementBehavior.player`, a plain non-exported `var`), not resolved via a group lookup inside the behavior itself — `Resource` scripts can't `@export` a `Node`-derived type in Godot 4.7 (compile error), so `BossActivity` resolves it once via `get_tree().get_first_node_in_group("player")` and injects it.
- `MovementStack` is the general mechanism for future temporary movement overrides (knockback, stun, charm); this feature only builds its two permanent base-layer consumers, nothing pushes a truly temporary, later-restored behavior yet.
