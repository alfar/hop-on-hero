# Project: HopOnHero

## Mission
A casual top-down dodge/auto-shooter (in the vein of Archero) with tower defense elements. The player navigates a 2D arena avoiding or outmaneuvering enemies while combat and enemy waves layer in tower-defense-style strategy.

## Tech Stack
- Language: GDScript (Godot 4.7)
- Framework: Godot Engine 4.7 (Mobile rendering method)
- Build tool: Godot Editor / project.godot
- Database: none
- ORM: none
- Migrations: none
- Messaging: none
- Testing: none configured yet
- Other: Jolt Physics (3D physics engine, enabled even though gameplay is currently 2D)

## Architecture
Component/behavior-based design built on Godot's node and Resource system.

- Entities are `CharacterBody2D` scenes (`scenes/player/player.tscn`, `scenes/enemy/enemy.tscn`) driven by attached scripts.
- Movement logic is factored out into `MovementBehavior` Resources (strategy pattern) rather than being hardcoded per entity: [movement_behavior.gd](components/movement/movement_behavior.gd) defines the base class with `get_velocity(position)`, and [target_movement_behavior.gd](components/movement/target_movement_behavior.gd) implements a concrete "move toward target" behavior.
- All entities use the behavior pattern (e.g. [enemy.gd](scenes/enemy/enemy.gd), [player.gd](scenes/player/player.gd)): each holds an `@export var movement_behavior: MovementBehavior` and delegates velocity calculation to it each physics frame, keeping the node script thin. Player input handling lives in [input_movement_behavior.gd](components/movement/input_movement_behavior.gd).
- Reusable behaviors live under `components/<category>/`, e.g. `components/movement/`. Follow this convention for future component categories (e.g. `components/combat/`, `components/ai/`).
- `scenes/world/world.tscn` is self-contained: it owns the `TileMapLayer` and an exported `world_size: Vector2`, but does not instance `Player` or `Enemy`. `scenes/game.tscn` is the project's main scene and the composition root — it instances `World`, `Player`, and `Enemy` together, including `scenes/camera/camera.tscn` (a standalone, reusable `Camera2D` scene) as a child of `Player`.
- Cross-cutting game-wide state is broadcast via the `GameEvents` autoload (`components/events/game_events.gd`), where each event is a `BehaviorSubject` (`components/events/behavior_subject.gd`) rather than a plain Godot `signal` — see Architecture Decisions below.

## Conventions
- Package/folder naming: lowercase snake_case for files and folders (`movement_behavior.gd`, `components/movement/`).
- Class naming: PascalCase via `class_name` (e.g. `MovementBehavior`, `TargetMovementBehavior`).
- Reusable, swappable logic (movement, and future AI/combat/etc.) should be extracted into `Resource`-based behavior scripts under `components/<category>/`, configured via `@export`, rather than hardcoded into entity scripts.
- Entity/scene-owning files (a scene paired with its root script) live under `scenes/<entity>/`, e.g. `scenes/player/`, `scenes/enemy/`, `scenes/world/`, `scenes/camera/` — mirroring the `components/<category>/` convention. Follow this for future entities (towers, bosses, projectiles). `scenes/game.tscn` (the main scene) is the composition root and lives directly under `scenes/`, not in its own subfolder.
- Tunable values (speed, targets, thresholds) are exposed via `@export` for designer/editor tuning rather than hardcoded constants buried in logic.
- No centralized error handler, REST API, or auth — not applicable to this client-side game project.

## Features
- **Player Input Movement Behavior**: player movement is driven by an `InputMovementBehavior` Resource (reads `Input.get_vector` and scales by speed) instead of inline input handling in `player.gd`, aligning it with the same component pattern already used by enemies (`docs/specs-archive/202608051109-player-input-movement-behavior/`)
- **Configurable World Bounds with Camera Follow**: world size is configurable via `World.world_size` and can be larger than the screen; a reusable `camera.tscn` follows the player and clamps its view to the world's edges, and the player's own position is likewise clamped so they can never leave the playable area (`docs/specs-archive/202608051256-configurable-world-bounds-with-camera-follow/`)
- **Reorganize Scene Files into scenes/**: entity scenes and their root scripts (player, enemy, world, camera) moved from the project root into `scenes/<entity>/`, and the main scene moved to `scenes/game.tscn`, establishing a convention that mirrors `components/<category>/` (`docs/specs-archive/202608051325-reorganize-scene-files-into-scenes/`)
- **Seeded Activity Scheduler with Boss Monster Activity**: a new `ActivityManager` node periodically triggers randomly-selected `Activity` resources (currently just `BossActivity`, which spawns a boss `Enemy` at a random position with a random `TargetMovementBehavior` target) at intervals determined by the activity that just ran, with all randomness seeded from a single `level_seed` so a run can be replayed deterministically (`docs/specs-archive/202608051831-seeded-activity-scheduler-with-boss-monster-activity/`)
- **Status Scene with Health and Shield Components**: a new reusable `Status` scene, instanced as a child of `Player`/`Enemy`, holds ordered `StatusComponent` children (`HealthComponent`, `ShieldComponent`) that each get a chance to intercept/reduce an incoming `StatusEvent` (e.g. physical damage) in scene-tree order before it reaches the next component, with a `HealthBar` UI node visually reflecting current health (`docs/specs-archive/202608052127-status-scene-with-health-and-shield-components/`)

## Architecture Decisions

| Date | Decision | Rationale | Feature |
|------|----------|-----------|---------|
| 2026-08-05 | Cross-cutting game-wide events (starting with `world_size_changed`) are broadcast via a `GameEvents` autoload where each event is a `BehaviorSubject` (RxJS-style: caches its last value, replays it immediately to new subscribers) rather than a plain Godot `signal`. | A plain `signal` only reaches listeners connected before it fires; this silently breaks for anything that starts listening later (e.g. a boss/tower spawned mid-game, or a camera reparented after the fact), which is a scenario this project's tower-defense/wave direction and deferred camera-retargeting plans both anticipate. | [Configurable World Bounds with Camera Follow](docs/specs-archive/202608051256-configurable-world-bounds-with-camera-follow/) |
| 2026-08-05 | Any system needing deterministic, replayable randomness (starting with the activity scheduler) must seed a single `RandomNumberGenerator` from one master seed and thread it explicitly through every call site that needs randomness, rather than using per-component or global RNG state. | Global `randi()`/`randf()` calls aren't independently seedable per-instance, so mixing them into activity logic would silently break seed-replayability; threading one seeded RNG through explicit parameters makes the determinism boundary visible and enforceable. | [Seeded Activity Scheduler with Boss Monster Activity](docs/specs-archive/202608051831-seeded-activity-scheduler-with-boss-monster-activity/) |
| 2026-08-05 | Added `GameEvents.world_loaded`, a new `BehaviorSubject` that fires once when the world is fully instanced, as a distinct "readiness" signal separate from `world_size_changed` (which may fire again later, e.g. if a future activity resizes the world). | Systems that must not act before the world exists (e.g. the activity scheduler) need a one-time "everything is ready" signal; reusing `world_size_changed` for this would conflate a value-change event with a lifecycle event and break if world size changes post-load. | [Seeded Activity Scheduler with Boss Monster Activity](docs/specs-archive/202608051831-seeded-activity-scheduler-with-boss-monster-activity/) |
| 2026-08-05 | `StatusComponent` (and its subclasses `HealthComponent`/`ShieldComponent`) is `Node`-based, not `Resource`-based like `MovementBehavior`/`Activity`. | The interception pipeline's ordering mechanism is the position of sibling nodes in the scene tree itself, which only actual child `Node`s can express (a `Resource` array can't be reordered by dragging in the scene tree editor the same way). | [Status Scene with Health and Shield Components](docs/specs-archive/202608052127-status-scene-with-health-and-shield-components/) |
| 2026-08-05 | Presentation-only scenes (a visual with no independent logic beyond reflecting state, e.g. `HealthBar`) belong under `scenes/<name>/`, not `components/<category>/`, even when conceptually paired with a behavior component. | Keeps the presentation/behavior split clean: `components/<category>/` is reserved for reusable logic pieces, while `scenes/` holds anything that owns its own visual scene tree, regardless of how tightly it's paired with a specific component. | [Status Scene with Health and Shield Components](docs/specs-archive/202608052127-status-scene-with-health-and-shield-components/) |

## Approved Dependencies
- Godot Engine 4.7 built-in modules/classes
- Jolt Physics (3D physics engine, built into Godot 4.7)

Anything beyond core Godot and Jolt Physics (e.g. addons, asset packs, plugins) requires a flag before adding.
