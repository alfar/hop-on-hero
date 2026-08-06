# Feature: Movement Behavior Stack with Chase-Player Fallback

## Summary
`MovementBehavior` is currently a single `Resource` assigned directly to an entity's `@export var movement_behavior`. This feature replaces that single-slot model with a `MovementStack` — an ordered, push/pop stack of `MovementBehavior`s — so temporary overrides (e.g. future knockback/stun effects) can be pushed on top of an entity's normal movement and later popped to restore it. It also introduces a new `ChasePlayerMovementBehavior` and wires `Enemy` so its stack has `ChasePlayerMovementBehavior` at the bottom and `TargetMovementBehavior` on top: an enemy first wanders to its randomly-assigned destination (driven by `TargetMovementBehavior`, as `BossActivity` already sets up), and once it arrives, that behavior reports itself finished, is popped off, and the enemy permanently falls through to chasing the player.

## User Stories
- As a player, I want spawned enemies to path to their assigned destination first and then start chasing me, so encounters feel like the enemy is actively hunting me rather than standing still or blindly following a fixed path forever.
- As a developer, I want a generic movement override stack (not a one-off "chase then wander" special case), so future gameplay effects (knockback, stun, charm) can temporarily override an entity's movement and cleanly restore the previous behavior afterward.

## Functional Requirements

### FR-01: `MovementBehavior` gains a finished/exhausted signal
Add a virtual method `is_finished(position: Vector2) -> bool` to the `MovementBehavior` base class (`components/movement/movement_behavior.gd`), defaulting to `false` (a behavior that never reports itself finished, matching current always-active behaviors like `InputMovementBehavior`/`ChasePlayerMovementBehavior`).

`TargetMovementBehavior` overrides `is_finished` to return `true` once `position.distance_to(target) < 10` — the same threshold it already uses in `get_velocity` to stop returning a velocity.

### FR-02: `MovementStack` component
Add a new `MovementStack` class (`components/movement/movement_stack.gd`, `class_name MovementStack`, `extends Resource` — a `Resource`, matching `MovementBehavior`, so it stays consistent with this project's existing `@export`-driven behavior-swapping convention) with:
- `push_behavior(behavior: MovementBehavior) -> void` — appends a behavior to the top of the stack.
- `pop_behavior() -> MovementBehavior` — removes and returns the top behavior.
- `get_velocity(position: Vector2) -> Vector2` — starting from the top of the stack, permanently pops off (discards) any behavior whose `is_finished(position)` is `true`, then returns `get_velocity(position)` of the first (topmost) remaining behavior. If the stack becomes empty, returns `Vector2.ZERO`.

Popping a finished behavior is permanent within a `MovementStack`'s lifetime — there is no mechanism in this feature to push a behavior back once it has been popped for being finished (see Out of Scope).

### FR-03: `ChasePlayerMovementBehavior`
Add a new `ChasePlayerMovementBehavior` class (`components/movement/chase_player_movement_behavior.gd`, `class_name ChasePlayerMovementBehavior`, `extends MovementBehavior`) with:
- `@export var player: Node2D` — an injected reference to the player, set by whoever constructs the behavior (see FR-06). This keeps `ChasePlayerMovementBehavior` a pure data+math `Resource` with no scene-tree access of its own, consistent with `MovementBehavior`/`TargetMovementBehavior` never calling `get_tree()`.
- `@export var speed` (default `400`, matching `TargetMovementBehavior`'s existing default).

Its `get_velocity(position)`:
- If `player` is `null` or no longer a valid instance (freed), returns `Vector2.ZERO`.
- Otherwise returns `position.direction_to(player.global_position) * speed` (no arrival threshold/stop distance — the enemy should keep closing until something else, e.g. the melee `HitArea`, takes over).

It does not override `is_finished` — it uses the base class's always-`false` default, since chasing the player is meant to be a permanent bottom layer (see Fallback Lifetime decision below).

### FR-04: `BossActivity` resolves the player once, for injection
`boss_activity.gd`'s `execute()` already runs with access to the scene (via `spawn_parent`, a `Node`). It resolves the player once per call — `spawn_parent.get_tree().get_first_node_in_group("player")` — and passes that reference into each `ChasePlayerMovementBehavior` it constructs (FR-06). This keeps tree/group access confined to the one place in the codebase (`BossActivity`) that already does this kind of scene-level wiring, rather than spreading it into the `Resource`-based behavior itself.

This still requires `Player` to be discoverable in a `"player"` group — `player.gd`'s `_ready()` calls `add_to_group("player")`, mirroring `enemy.gd`'s existing `add_to_group("enemy")`.

### FR-05: `Enemy` uses a `MovementStack` instead of a single `MovementBehavior`
`enemy.gd`'s `@export var movement_behavior: MovementBehavior` is replaced with `@export var movement_stack: MovementStack`. `_physics_process` calls `velocity = movement_stack.get_velocity(position)` instead of calling `get_velocity` directly on a single behavior.

`_on_died()` currently resets movement by assigning `movement_behavior = MovementBehavior.new()` (a behavior that always returns `Vector2.ZERO`) so the enemy stops moving on death. This is replaced with assigning a fresh, empty `MovementStack.new()` — an empty stack's `get_velocity` already returns `Vector2.ZERO` per FR-02, achieving the same "stop moving" effect without needing a sentinel behavior.

### FR-06: `BossActivity` builds the enemy's stack (target on top, chase-player at bottom)
`boss_activity.gd`'s `execute()` currently creates one `TargetMovementBehavior` and assigns it directly to `instance.movement_behavior`. It's changed to:
1. Resolve the player via `spawn_parent.get_tree().get_first_node_in_group("player")` (FR-04).
2. Create a `MovementStack`.
3. `push_behavior` a new `ChasePlayerMovementBehavior` with `player` set to the resolved reference (bottom of the stack).
4. `push_behavior` the existing `TargetMovementBehavior` (with its computed `target`) on top.
5. Assign the stack to `instance.movement_stack`.

If no player is found (e.g. a test context with no `Player` in the tree), `ChasePlayerMovementBehavior.player` stays `null` and it simply returns `Vector2.ZERO` once reached (per FR-03) rather than erroring.

Net effect: the enemy moves toward its randomly-chosen destination first; once within the existing 10-unit threshold, `TargetMovementBehavior` is popped and the enemy chases the player from then on.

## Acceptance Criteria
- [x] AC-01: `MovementBehavior.is_finished(position)` exists and returns `false` by default.
- [x] AC-02: `TargetMovementBehavior.is_finished(position)` returns `true` once `position` is within 10 units of `target`, `false` otherwise.
- [x] AC-03: A `MovementStack` with behaviors `[ChasePlayerMovementBehavior, TargetMovementBehavior]` (bottom to top) returns `TargetMovementBehavior`'s velocity while the target hasn't been reached.
- [x] AC-04: Once the position is within the `TargetMovementBehavior`'s threshold, calling `get_velocity` on that same stack pops `TargetMovementBehavior` and returns `ChasePlayerMovementBehavior`'s velocity (i.e. movement toward the player) instead, on that same call and every subsequent one.
- [x] AC-05: `MovementStack.get_velocity` on an empty stack returns `Vector2.ZERO`.
- [x] AC-06: `ChasePlayerMovementBehavior.get_velocity(position)` returns a vector of length `speed` pointed at the injected `player`'s `global_position` when `player` is set, and `Vector2.ZERO` when `player` is `null`.
- [x] AC-07: `Player._ready()` adds itself to the `"player"` group, and `BossActivity.execute()` resolves that group member and injects it into the `ChasePlayerMovementBehavior` it constructs.
- [x] AC-08: A `BossActivity`-spawned enemy's `movement_stack` moves it to its randomly-assigned target first, then toward the player afterward (integration-level behavior).
- [x] AC-09: An enemy's `_on_died()` still results in zero movement velocity immediately (same-frame), now via an empty `MovementStack` rather than a single no-op `MovementBehavior`.
- [x] AC-10: All existing tests that reference `enemy.movement_behavior` or construct a `MovementBehavior.new()` as a "movement stopped" sentinel are updated to the new `movement_stack`-based API and continue to pass.

## Technical Scope

### Affected Modules
- `components/movement/` (`movement_behavior.gd`, `target_movement_behavior.gd`, new `movement_stack.gd`, new `chase_player_movement_behavior.gd`)
- `scenes/enemy/enemy.gd`
- `scenes/player/player.gd`
- `components/activities/boss_activity.gd`

### New Components Required
- `MovementStack` (`components/movement/movement_stack.gd`)
- `ChasePlayerMovementBehavior` (`components/movement/chase_player_movement_behavior.gd`)

### Integration Points
- `BossActivity.execute()` — the only current call site that constructs an enemy's initial movement setup.
- `Enemy` scene/script — consumes `MovementStack` instead of a single `MovementBehavior`.
- Godot group system (`"enemy"` group already exists; this adds a `"player"` group) used for `ChasePlayerMovementBehavior` to find its target.
- Existing tests: `test/unit/movement/target_movement_behavior_test.gd`, `test/unit/enemy/enemy_movement_stop_test.gd`, `test/integration/enemy/enemy_death_test.gd`, and `test/integration/weapon/weapon_test_helpers.gd` (if it constructs an `Enemy` with a `movement_behavior`) all touch the API being changed and need updates during implementation.

## Non-Functional Requirements
- Performance: `get_first_node_in_group("player")` is called once per `ChasePlayerMovementBehavior.get_velocity` invocation (once per enemy per physics frame) — acceptable at this project's current scale (single player, a handful of enemies); no caching added in this feature.
- Security: not applicable (client-side game, no network/user-data surface).
- Scalability: not applicable beyond the performance note above.

## Out of Scope
- Re-triggering wandering behavior after an enemy has fallen through to chasing the player (per user decision: chase-player is a permanent bottom layer for this feature).
- Any actual "push a temporary override and later pop it back" gameplay effect (knockback, stun, charm, etc.) — this feature only builds the generic `push_behavior`/`pop_behavior` mechanism and its two permanent base-layer consumers (`TargetMovementBehavior` on top of `ChasePlayerMovementBehavior`); nothing in this feature pushes a truly temporary (later-restored) behavior.
- Extending `Player` to use a `MovementStack` for its own movement — `Player` only gains group membership (FR-04) so it can be located as a chase target; its own `movement_behavior` field/usage is untouched.
- Any change to `InputMovementBehavior` (player's own movement) beyond what FR-04 requires.
- Melee/attack range logic once the enemy reaches the player — `ChasePlayerMovementBehavior` only moves the enemy toward the player; actual damage is already handled by the existing `MeleeContactWeaponTrigger`/`HitArea` system and is untouched.

## Open Questions
- None outstanding — stack semantics, player lookup mechanism, and fallback lifetime were resolved with the user before this spec was written (explicit push/pop stack; `"player"` group lookup; chase-player is a permanent, non-reverting bottom layer). A later refinement pass also considered and rejected a `finished` signal in favor of the polled `is_finished(position)` approach (see Revision History) — no open question remains here either.

---

## Revision History

| Date | Change Summary |
|------|----------------|
| 2026-08-06 | Initial spec |
| 2026-08-06 | Considered replacing polled `is_finished(position)` (FR-01/FR-02) with a `finished` signal emitted by `MovementBehavior`; rejected in favor of keeping `is_finished` — a signal risks an arrival race (a behavior already past its threshold when pushed, e.g. spawn position already within `TargetMovementBehavior`'s target radius, would never fire since nothing was connected yet) and adds connect/disconnect bookkeeping with no benefit, since `MovementStack` is the sole, already-polling consumer. No functional requirements changed as a result. |
| 2026-08-06 | Changed `ChasePlayerMovementBehavior` (FR-03) from resolving the player itself via `get_tree().get_first_node_in_group("player")` to receiving an injected `@export var player: Node2D`, set by `BossActivity` (new FR-04) at construction time. Reason: `MovementBehavior` subclasses are `Resource`s with no `get_tree()`, so a self-resolving lookup would have needed an untested `Engine.get_main_loop()` pattern; injection keeps tree/group access confined to `BossActivity`, which already does this kind of scene-level wiring. FR-04/FR-06/AC-06/AC-07 updated accordingly; requirement numbering shifted (old FR-04 "Player joins the player group" folded into the new FR-04). |
