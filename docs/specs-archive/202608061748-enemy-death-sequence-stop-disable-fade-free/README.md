# Enemy Death Sequence (Stop, Disable, Fade, Free)

Implemented on: 2026-08-06

When an `Enemy`'s `HealthComponent` emits `died`, the enemy now reacts with a short death sequence: movement stops (swapped to a base `MovementBehavior`, whose `get_velocity()` always returns zero), its `HitArea` is disabled (`monitoring = false`) so it can no longer deal further contact damage via `MeleeContactWeaponTrigger`, its visual fades out over a tunable `death_fade_duration` (default 1s) using Godot's `create_tween()`, and finally the node frees itself. This closes the loop opened by the Weapon System feature — damage dealt via melee or projectiles can now actually and visibly kill an enemy, rather than leaving a dead-but-still-present, still-collidable corpse in the scene.

Key files:
- `scenes/enemy/enemy.gd` — the only file modified; a new `@export var death_fade_duration`, a `died` signal connection in `_ready()`, and the new `_on_died()` handler
- `test/unit/enemy/enemy_movement_stop_test.gd` — proves the "swap to a fresh `MovementBehavior` stops movement" contract in isolation
- `test/integration/enemy/enemy_death_test.gd` — instances the real `Enemy` scene and verifies the full sequence: movement/`HitArea` disabled same-frame, fade completes and frees the node, and no further contact damage occurs post-death

Notable decisions:
- No new class, component, or reusable "death behavior" was introduced — implemented directly in `enemy.gd`, since Player death (game over, respawn, etc.) is a distinct, much larger concern deferred to a future feature. Revisit extraction if/when another entity type needs equivalent handling.
- `HitArea.monitoring = false` was used to stop further contact damage, rather than touching `MeleeContactWeaponTrigger` or the `HitArea`'s collision layer/mask — simplest option, no risk of dangling references before `queue_free()`.
- `create_tween()` is this project's first use of Godot's tweening API, establishing the pattern for future visual-effect work.
- No changes were needed to `HealthComponent`, `Status`, or the Weapon System feature's existing wiring — this is purely a new listener.
