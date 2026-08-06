# Feature: Enemy Death Sequence (Stop, Disable, Fade, Free)

## Summary
When an `Enemy`'s `HealthComponent` emits `died` (health reaches `0`), the enemy should stop behaving like a living combatant and play a short death sequence before removing itself from the scene: movement stops, further contact interactions are disabled, its visual fades out over about a second, and then the node frees itself. This closes the loop the Weapon System feature opened — damage can now actually kill something, and a dead enemy visibly and permanently leaves the game rather than lingering as an inert, still-collidable corpse.

## User Stories
- As a player, I want an enemy I've killed to visibly die (stop moving, fade away) rather than freeze in place indefinitely, so that combat feels like it has a real conclusion.
- As a player, I want a dying enemy to stop being able to hurt me during its death animation, so that "finishing it off" doesn't come with an unfair parting hit.

## Functional Requirements

### FR-01: React to HealthComponent.died
`scenes/enemy/enemy.gd`:
- In `_ready()`, connect to `$Status/HealthComponent.died`.
- On `died`, run the death sequence described in FR-02 through FR-05, in order.
- `died` is only ever emitted once per `HealthComponent` (existing guard: `handle_event()` no-ops once `current_health == 0`), so no additional re-entrancy guard is needed in `Enemy` itself.

### FR-02: Stop Movement
- On death, `Enemy.movement_behavior` is replaced with a fresh base `MovementBehavior.new()` instance (whose `get_velocity()` always returns `Vector2.ZERO`), immediately halting movement on the next `_physics_process()` tick.
- `Enemy._physics_process()` is otherwise unchanged — it keeps calling `move_and_slide()` every frame (now with zero velocity), consistent with not adding a death-state branch into the per-frame movement logic.

### FR-03: Disable Further Interaction
- On death, set `HitArea.monitoring = false` on the enemy's own `HitArea` (the `Area2D` used by `MeleeContactWeaponTrigger` to detect contact with the player). This stops the dying enemy from dealing any further contact damage during its fade-out, and stops it from registering new contact-start events.
- No change to `MeleeContactWeaponTrigger`, `WeaponSystem`, or `HitArea`'s collision layer/mask — `monitoring = false` is sufficient and requires no new wiring.

### FR-04: Fade Out
- On death, tween the enemy's visual from fully opaque to fully transparent over `@export var death_fade_duration: float = 1.0` seconds, using `Enemy.modulate.a` (the root `CharacterBody2D` node's own `modulate`), which affects all of its visual children (`Sprite2D`, `HealthBar`) uniformly — no need to fade each child separately.
- Implemented via `create_tween()` (Godot's standard tweening API), consistent with this being the project's first use of a fade/tween effect — no existing precedent to follow, this establishes one.

### FR-05: Free the Node
- After the fade-out tween completes, call `queue_free()` on the `Enemy` node, removing it from the scene tree entirely.

## Acceptance Criteria
- [x] AC-01: When `HealthComponent.died` fires, `Enemy.movement_behavior` is replaced with a `MovementBehavior` instance (not a subclass), and the enemy's `velocity` becomes `Vector2.ZERO` on the next physics frame, regardless of what behavior was active before.
- [x] AC-02: When `HealthComponent.died` fires, `Enemy`'s `HitArea.monitoring` becomes `false`, and no further `MeleeContactWeaponTrigger` contact damage is dealt by that enemy afterward (verified by having a live player overlap the dead enemy's `HitArea` after death and confirming no additional damage occurs).
- [x] AC-03: When `HealthComponent.died` fires, the `Enemy` node's `modulate.a` decreases from `1.0` to `0.0` over `death_fade_duration` seconds (default `1.0`).
- [x] AC-04: After the fade-out completes, the `Enemy` node is freed (`queue_free()`'d) and no longer present in the scene tree.
- [x] AC-05: The death sequence (stop movement, disable `HitArea`, start fade) all begins within the same frame `died` fires — there is no delay before the enemy starts reacting.
- [x] AC-06: A `HealthComponent.died` signal on a `Player`'s `Status` (if it were ever to fire, e.g. via manual testing) does not trigger any part of this sequence — this feature only wires the reaction into `Enemy`, not `Player` or `Status`/`HealthComponent` themselves.
- [x] AC-07: Unit/integration tests (GUT, per this project's established conventions) cover: `movement_behavior` replacement and zero velocity after death (unit-testable in isolation), and an integration test instancing the real `Enemy` scene that fires `died` and verifies `HitArea.monitoring` becomes `false`, `modulate.a` reaches `0.0` after waiting out the fade duration, and the node is freed afterward.

## Technical Scope

### Affected Modules
- `scenes/enemy/enemy.gd` (modified: add death-sequence reaction)

### New Components Required
- None — no new classes or scenes. This is entity-script logic in `enemy.gd`, consistent with the "Enemy-only for now" scope decision (not extracted into a reusable component/behavior, since `Player` death is a distinct, much larger concern — game over screen, respawn, etc. — not addressed here).

### Integration Points
- `components/status/health_component.gd`'s existing `died` signal (no changes needed there).
- `components/movement/movement_behavior.gd` (the base class, instantiated directly as the "stopped" behavior — no new subclass).
- `Enemy`'s existing `HitArea` (from the Weapon System feature) — reused via `monitoring = false`, no structural changes.
- Godot's built-in `Tween`/`create_tween()` API (new usage for this project, first fade/tween effect).

## Non-Functional Requirements
- Performance: N/A at this scale — one `Tween` per dying enemy, freed automatically when it finishes or the node is freed.
- Security: N/A — client-side single-player game.
- Scalability: N/A — no batching/pooling concerns at current enemy counts.

## Out of Scope
- Player death/game-over handling — explicitly deferred; this feature only wires the reaction into `Enemy`.
- Death animations beyond a simple opacity fade (no scale/rotation effects, no particle effects, no death sound).
- A reusable/shared "death behavior" component or resource — this is implemented directly in `enemy.gd` for now; revisit extraction if/when Player (or other entity types) need equivalent death handling.
- Rewarding the player on enemy death (score, loot, currency) — not addressed by this feature.
- Removing/hiding the enemy's `HealthBar` independently during the fade (it fades along with everything else via the root's `modulate`, no special-casing).
- Any change to `HealthComponent`, `Status`, or the `died` signal itself — this feature is purely a new listener in `Enemy`.

## Open Questions
- None remaining — post-death interaction scope (also disable `HitArea`), fade visual (simple opacity over ~1s), and Enemy-only scope were all confirmed via clarifying questions before finalizing this spec.
