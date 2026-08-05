# Feature: Weapon System with Melee and Ranged Triggers

## Summary
Add a reusable `WeaponSystem` scene (instanced as a child of `Player`/`Enemy`, mirroring the existing `Status` scene pattern) that holds ordered `WeaponComponent` children. Each component receives the running damage total so far and returns a modified total (`modify_damage(current_damage)`), so `WeaponSystem` folds over its children in scene-tree order to compute a final damage amount — the same ordered-pipeline shape as `Status`/`StatusComponent`, rather than an independent-sum model. *How* a weapon system fires is a separate, swappable `WeaponTrigger` piece: `Enemy` uses a melee trigger that fires on physical contact with a non-enemy character and applies damage immediately via the target's `Status.apply_event()`; `Player` uses a timer trigger that fires at a fixed interval, aims at the nearest enemy, and spawns a `Projectile` scene carrying a pre-computed damage amount, which travels and applies damage later when it hits anything (or self-destructs on leaving the world bounds). This establishes the collision/hit-detection foundation (`Area2D` + collision layers) that this project has not needed until now, alongside the weapon component/trigger patterns themselves. Inventory-driven component/trigger swapping, movement-affected timer intervals, and a future `TargetingBehavior` abstraction are explicitly deferred to future features.

## User Stories
- As a player, I want enemies to deal damage to me when they touch me, so that avoiding them has stakes.
- As a player, I want my character to periodically fire a projectile that damages an enemy on impact, so that I can fight back without manual aiming/input (auto-shooter genre convention).
- As a developer, I want weapon damage to be computed by folding over an ordered list of swappable `WeaponComponent` children (mirroring `StatusComponent`'s pipeline), so that future components like a damage-multiplier can transform the running total (e.g. doubling it) rather than being limited to independent additive contributions.
- As a developer, I want the trigger mechanism (melee-on-contact vs. timer-based) to be a separate, swappable piece from the damage-calculation logic, so that `Enemy` and `Player` can share the same `WeaponSystem`/`WeaponComponent` code while differing only in when/how they fire.

## Functional Requirements

### FR-01: Collision/Hit-Detection Foundation
Introduce collision layers and a dedicated hit-detection `Area2D` so entities can detect contact independent of physical movement-blocking (`move_and_slide()` alone doesn't signal "touching an enemy"):
- Two new collision layers: `player` and `enemy` (named layers in Project Settings, alongside whatever default layer `CharacterBody2D`s already use for physical blocking).
- `Player` and `Enemy` each gain a child `Area2D` named `HitArea` (with its own `CollisionShape2D`) used purely for detecting overlap with the opposing side — separate from each `CharacterBody2D`'s own physical collision shape.
- `Player.HitArea`: collision layer `player`, collision mask `enemy` (detects enemies touching it).
- `Enemy.HitArea`: collision layer `enemy`, collision mask `player` (detects the player touching it).
- Both emit Godot's standard `body_entered(body: Node2D)` / `body_exited(body: Node2D)` signals, which `WeaponTrigger` implementations subscribe to as needed.

### FR-02: WeaponComponent (base class)
`components/weapon/weapon_component.gd`, mirroring `StatusComponent`'s pipeline shape:
- `class_name WeaponComponent extends Node`.
- `func modify_damage(current_damage: int) -> int`, base implementation returns `current_damage` unchanged (a no-op pass-through).
- No signals needed (unlike `StatusComponent`, there's no persistent "current value" to report to a UI — components are only invoked at the moment `WeaponSystem.get_total_damage()` runs).

### FR-03: FixedDamageWeaponComponent
`components/weapon/fixed_damage_weapon_component.gd`:
- `class_name FixedDamageWeaponComponent extends WeaponComponent`.
- `@export var damage: int = 10`.
- `modify_damage(current_damage)` returns `current_damage + damage` (adds its flat damage to the running total, rather than replacing it — so a `FixedDamageWeaponComponent` still behaves additively even though the pipeline itself supports transformation, e.g. a future doubling component).
- This is the "single component with a number of damage" the enemy setup needs, and also what the player uses for now (per scope decision — see Out of Scope).

### FR-04: WeaponSystem (scene)
`scenes/weapon_system/weapon_system.gd` + `.tscn`, mirroring `scenes/status/status.gd`:
- `class_name WeaponSystem extends Node2D`.
- `func get_total_damage() -> int`: starts `current_damage` at `0`, then iterates `WeaponComponent` children in scene-tree order (`if child is WeaponComponent`), calling `current_damage = child.modify_damage(current_damage)` on each and threading the result to the next child — an ordered fold, not an independent sum.
- Component order is load-bearing (mirrors `Status`'s Shield-before-Health ordering principle): e.g. a `FixedDamageWeaponComponent(10)` followed by a `DoubleDamageWeaponComponent` yields `20`, but the reverse order would not (a hypothetical multiplier placed first would double `0`, contributing nothing). This feature only ships `FixedDamageWeaponComponent`, so order isn't exercised by any acceptance criterion yet, but the fold's ordering must be correct and documented for future components to rely on.

### FR-05: WeaponTrigger (base class, swappable trigger mechanism)
`components/weapon/weapon_trigger.gd`:
- `class_name WeaponTrigger extends Node`.
- Exported/injected reference to the `WeaponSystem` it triggers (via `node_paths` export, matching the `HealthBar.status` wiring convention already used in `player.tscn`/`enemy.tscn`).
- Base class defines the shape but no default behavior; concrete triggers implement `_ready()` to wire up their own firing condition.

### FR-06: MeleeContactWeaponTrigger (enemy's trigger)
`components/weapon/melee_contact_weapon_trigger.gd`:
- `class_name MeleeContactWeaponTrigger extends WeaponTrigger`.
- Subscribes to its entity's `HitArea.body_entered`.
- On `body_entered(body)`: if `body` is a valid target (see FR-08 for how target validity/`Status` lookup works), immediately calls `weapon_system.get_total_damage()` and applies the result to the target's `Status` via `apply_event(StatusEvent.new("physical_damage", total_damage))`.
- Fires again on every new `body_entered` (re-entering after leaving re-triggers; staying in continuous contact without leaving does NOT repeatedly trigger, since `body_entered` only fires once per overlap start) — this is a deliberate, simple default; a "repeated damage over time while in contact" mechanic is out of scope for this feature.

### FR-07: TimerWeaponTrigger (player's trigger)
`components/weapon/timer_weapon_trigger.gd`:
- `class_name TimerWeaponTrigger extends WeaponTrigger`.
- `@export var interval: float = 1.0`.
- Owns a `Timer` child (created in `_ready()`, matching `ActivityManager`'s pattern), fires repeatedly at `interval`.
- On each timeout: finds the nearest `Enemy` currently in the scene tree (simplest viable targeting — see Out of Scope regarding a future `TargetingBehavior` extension point); if none exists, does not fire this tick (no projectile spawned, timer keeps running for the next tick).
- If a target exists: calls `weapon_system.get_total_damage()` **at fire time** (per user's clarification — damage must be calculated when the "arrow leaves", not when it later hits), then spawns a `Projectile` (FR-09) carrying that pre-computed amount, from the entity's position, aimed in the direction of the target's position at that instant (a straight-line shot, not homing — the projectile does not re-aim after spawning).
- Does not itself know or care whether the projectile ever hits anything; that's the projectile's job.

### FR-08: Target Resolution (finding the other side's Status)
Both trigger types need to go from "a `Node2D` I collided with" to "that entity's `Status` scene" to call `apply_event()`:
- Convention: `Player` and `Enemy` scenes both have a child node named exactly `Status` (already true today). A trigger resolves the target's status via `body.get_node("Status")`, guarded by `if body.has_node("Status")`.
- If the collided body has no `Status` child, the trigger does nothing (no error) — allows non-damageable bodies (e.g. world geometry, if any is ever added to these collision layers) to safely no-op.

### FR-09: Projectile (scene)
`scenes/projectile/projectile.gd` + `.tscn`:
- `class_name Projectile extends Area2D` (not `CharacterBody2D` — a projectile doesn't need physical movement-blocking, just to detect what it hits, matching the `HitArea` pattern).
- `@export var speed: float = 600.0`.
- `var damage: int` — set by whoever spawns it (`TimerWeaponTrigger`), not exported (it's a runtime value, not a designer-tunable default).
- `var direction: Vector2` — set by whoever spawns it.
- Collision layer: a new `projectile` layer; collision mask: `enemy` (a player-spawned projectile only hits enemies — matches the "enemy weapon triggers on non-enemy contact" asymmetry from the original request, just inverted for the player's projectile).
- Visual: a placeholder shape (e.g. a small `ColorRect` or `Sprite2D` using a built-in/simple texture), matching this project's existing placeholder-visual convention (`Player`'s `ColorRect`, `Enemy`'s `icon.svg`) — no dedicated art asset for this feature.
- `_physics_process(delta)`: moves by `direction * speed * delta`; after moving, if the new position falls outside `[0, world_size]` on either axis (world bounds obtained the same way `Player`/`CameraBounds` already do, via `GameEvents.world_size_changed`), the projectile `queue_free()`s itself immediately — a missed shot that leaves the playable area is discarded rather than persisting or wrapping.
- On `body_entered(body)`: applies `StatusEvent.new("physical_damage", damage)` to `body.get_node("Status")` if `body.has_node("Status")` (no-op, no error, if not), then unconditionally `queue_free()`s itself regardless of whether a `Status` was found — a projectile is single-use and is consumed by the first physical thing it touches, damageable or not.

## Acceptance Criteria
- [x] AC-01: `Player` and `Enemy` each have a `HitArea` child `Area2D` with correct, opposing collision layers/masks (`player`/`enemy`).
- [x] AC-02: A `WeaponComponent` base class exists with `modify_damage(current_damage: int) -> int` returning `current_damage` unchanged by default.
- [x] AC-03: `FixedDamageWeaponComponent.modify_damage(current_damage)` returns `current_damage + damage` for its configured `damage` value.
- [x] AC-04: `WeaponSystem.get_total_damage()` correctly folds over direct `WeaponComponent` children in scene-tree order, starting from `0` and threading each child's `modify_damage()` result into the next, ignoring any non-`WeaponComponent` children.
- [x] AC-05: `WeaponSystem.get_total_damage()` returns `0` when it has no `WeaponComponent` children.
- [x] AC-06: `MeleeContactWeaponTrigger`, wired to an `Enemy`'s `HitArea` and `WeaponSystem`, applies the correct total damage to a colliding `Player`'s `Status` (verified via `HealthComponent.current_health` decreasing by the expected amount) exactly once per contact start.
- [x] AC-07: `MeleeContactWeaponTrigger` does not error and does nothing if the colliding body has no `Status` child.
- [x] AC-08: `TimerWeaponTrigger` fires every `interval` seconds; when at least one `Enemy` exists in the scene tree, each fire computes damage at that moment (not when the projectile later hits), aims at the nearest `Enemy`'s position at that instant, and spawns a `Projectile` carrying that amount and direction. When no `Enemy` exists, no projectile is spawned that tick and no error occurs.
- [x] AC-09: A spawned `Projectile` moves in its configured direction at its configured speed, and applies its carried damage to a target's `Status` exactly once on first contact, then removes itself.
- [x] AC-10: A `Projectile` does not error, applies no damage, but still removes itself if it hits a body with no `Status` child.
- [x] AC-11: A `Projectile` that exits the world bounds (per `GameEvents.world_size_changed`) without hitting anything removes itself, rather than persisting indefinitely or leaving the playable area.
- [x] AC-12: `Enemy`'s weapon setup (in its `.tscn`) uses `WeaponSystem` + one `FixedDamageWeaponComponent` + `MeleeContactWeaponTrigger`.
- [x] AC-13: `Player`'s weapon setup (in its `.tscn`) uses `WeaponSystem` + one `FixedDamageWeaponComponent` + `TimerWeaponTrigger`, and manual playtesting confirms the player automatically fires at and damages the nearest enemy.
- [x] AC-14: Unit tests (GUT, per this project's established `test/unit/<category>/*_test.gd` convention) cover `WeaponComponent`/`FixedDamageWeaponComponent`/`WeaponSystem`'s pure fold logic (including that component order affects the result, using a test-only second component if needed to prove ordering). Trigger/collision/projectile behavior is scene-tree/physics-dependent and is verified via manual playtesting instead (consistent with this project's existing `Status`/`HealthBar` precedent of deferring scene-tree-dependent testing).

## Technical Scope

### Affected Modules
- `components/weapon/` (new category, mirrors `components/status/`)
- `scenes/weapon_system/` (new, mirrors `scenes/status/`)
- `scenes/projectile/` (new)
- `scenes/player/player.tscn`, `scenes/enemy/enemy.tscn` (modified: add `HitArea`, `WeaponSystem` + trigger + component children)
- Project Settings → Layer Names/2D Physics (modified: add `player`, `enemy`, `projectile` collision layers)

### New Components Required
- `components/weapon/weapon_component.gd` — `WeaponComponent` base class
- `components/weapon/fixed_damage_weapon_component.gd` — `FixedDamageWeaponComponent`
- `components/weapon/weapon_trigger.gd` — `WeaponTrigger` base class
- `components/weapon/melee_contact_weapon_trigger.gd` — `MeleeContactWeaponTrigger`
- `components/weapon/timer_weapon_trigger.gd` — `TimerWeaponTrigger`
- `scenes/weapon_system/weapon_system.gd` + `weapon_system.tscn` — `WeaponSystem`
- `scenes/projectile/projectile.gd` + `projectile.tscn` — `Projectile`

### Integration Points
- `Status`/`StatusEvent`/`HealthComponent` (existing) — both trigger types call `Status.apply_event(StatusEvent.new("physical_damage", amount))` on a resolved target.
- `Player`/`Enemy` scenes — gain new child nodes (`HitArea`, `WeaponSystem` instance + its trigger + component children).
- Godot's built-in `Area2D.body_entered`/`body_exited` signals and collision layer/mask system (new usage for this project — first time collision layers are configured beyond Godot's default).
- `scenes/game.tscn` (composition root) — `Projectile` instances will need a `spawn_parent`-equivalent to be added under, likely the same parent `BossActivity` already uses for spawning enemies (confirm exact node at implementation time).

## Non-Functional Requirements
- Performance: N/A at this scale — a handful of weapon components summed per trigger fire, occasional projectile spawns; no batching/pooling required yet.
- Security: N/A — client-side single-player game.
- Scalability: `WeaponComponent`/`WeaponTrigger` follow the same open-ended, swappable-child pattern as `StatusComponent`, so future inventory-driven component/trigger changes require no changes to `WeaponSystem` itself (mirrors AC-09 from the Status feature).

## Out of Scope
- Inventory system and inventory-driven weapon component/trigger swapping — explicitly deferred; `WeaponSystem`'s child-based design is intended to support this later without rework, but no inventory code is written now.
- Movement-affected timer intervals (e.g. faster/slower fire rate based on whether the player is moving) — explicitly deferred as a future extension of `TimerWeaponTrigger` (or a new trigger variant).
- A general `TargetingBehavior` abstraction (strategy pattern for how a trigger picks its target, mirroring `MovementBehavior`) — this feature hardcodes "nearest enemy" directly in `TimerWeaponTrigger`; extracting it into a swappable behavior is a likely near-future follow-up once a second targeting strategy is actually needed.
- "Repeated damage over time while in continuous melee contact" — `MeleeContactWeaponTrigger` only fires on `body_entered` (contact start), not continuously while overlapping.
- Player-side "more complex" multi-component weapon setups — per scope decision, the player uses the same single `FixedDamageWeaponComponent` as the enemy for now; multi-component player loadouts are future work once inventory exists.
- Visual/audio feedback for hits, projectile animations, damage numbers UI — not addressed by this feature beyond the placeholder projectile visual itself.
- Friendly fire / enemy-vs-enemy damage — collision layers are scoped strictly to player-vs-enemy and projectile-vs-enemy; enemy-vs-enemy contact is not configured to trigger anything.
- Homing or mid-flight re-aiming projectiles — a `Projectile` travels in a straight line from its spawn-time direction only.

## Open Questions
- None remaining — targeting (nearest enemy), projectile visual (placeholder), out-of-bounds despawn, and the `modify_damage`/fold pipeline shape were all confirmed via clarifying questions before finalizing this spec.

---

## Revision History

| Date | Change Summary |
|------|----------------|
| 2026-08-05 | Initial spec |
| 2026-08-05 | `WeaponComponent.get_damage()` replaced with `modify_damage(current_damage: int) -> int`; `WeaponSystem.get_total_damage()` now folds over components in scene-tree order instead of summing independently, enabling future order-dependent components (e.g. a damage multiplier). Projectile targeting resolved to "aim at nearest Enemy at fire time" (with a future `TargetingBehavior` extension point noted). Projectile now uses a placeholder visual, self-destructs on hitting anything (Status or not), and also self-destructs on leaving world bounds — removing the prior "no despawn handling" Out of Scope item. |
