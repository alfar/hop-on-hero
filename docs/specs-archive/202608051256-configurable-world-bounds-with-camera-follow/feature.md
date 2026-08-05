# Feature: Configurable World Bounds with Camera Follow

## Summary
Introduce a configurable world size larger than the screen, and keep the player centered on screen as they move by having the camera follow them — except near the world's edges, where the camera stops at the boundary so it never shows anything outside the playable area. This requires restructuring the scene tree: the existing `world.tscn` (currently the main scene, containing the tilemap and directly instancing Player/Enemy) is split into a self-contained `World` scene (visuals + bounds only) and a new `Game` scene that composes `World` + `Player` + `Enemy` together. `Game.tscn` becomes the new main scene.

## User Stories
- As a player, I want the camera to follow me smoothly and keep me near the center of the screen, so that I can see my surroundings as I move through a world larger than my screen.
- As a player, I want the camera to stop at the edge of the world instead of showing empty space beyond it, so that the game world always looks intentional and bounded.
- As a game designer, I want to configure the world's size via an exported field, so that I can tune arena size per level without touching code.

## Functional Requirements

### FR-01: World scene with configurable size
Create `world.gd` (or reuse/rename the existing root script if one exists) attached to `World`'s root `Node2D`, exposing `@export var world_size: Vector2` (pixels, default matching the current tilemap's visual extent). `world.tscn` becomes self-contained: it owns the `TileMapLayer` (moved out of the current `world.tscn` root) and this `world_size` export, but no longer instances `Player` or `Enemy`.

### FR-02: Game scene composing World, Player, and Enemy
Create `game.tscn` with a root `Node2D` (`Game`) that instances `World`, `Player`, and `Enemy` as children, replicating the current positions/overrides found in today's `world.tscn` (Player at `Vector2(577, 340)`, Enemy at `Vector2(1038, 477)` with its `movement_behavior` override). `game.tscn` becomes the project's main scene (`project.godot`'s `run/main_scene`), replacing `world.tscn` in that role.

### FR-05: General-purpose game event bus with replay-to-late-subscribers
Add a generic, reusable `BehaviorSubject` class (`components/events/behavior_subject.gd`, `class_name BehaviorSubject extends RefCounted`) modeled on RxJS's `BehaviorSubject`: it wraps a value and a `signal value_changed(value)`, caching the most recently emitted value (`_value`, `_has_value`). Calling `emit(value)` updates the cached value and fires `value_changed`. Calling `subscribe(callable: Callable)` connects `callable` to `value_changed` **and immediately invokes `callable.call(_value)` if a value has already been emitted** — so a subscriber never misses the current state regardless of when it subscribes. `get_value()` and `has_value()` allow synchronous reads without subscribing.

Add an autoload singleton `GameEvents` (`components/events/game_events.gd`, registered in `project.godot` under `[autoload]`) exposing `var world_size_changed := BehaviorSubject.new()`. `world.gd` emits via `GameEvents.world_size_changed.emit(world_size)` from its `_ready()` — no `call_deferred` workaround is needed, since replay-on-subscribe means subscriber/emitter ordering no longer matters. `GameEvents` is deliberately named as a general-purpose, game-wide event bus rather than a world-specific one — `world_size_changed` is its first `BehaviorSubject`, but future cross-cutting events (e.g. wave started, tower built, score changed) are expected to live on the same autoload as the mission's tower-defense/wave mechanics come online, each as its own `BehaviorSubject` so every future signal gets late-subscriber replay for free. This decouples `World` from needing direct references to `Player`, `Camera2D`, or `Game` — any node that cares about world bounds simply subscribes to the bus instead of being wired together by a composition-root script, and can do so at any time (including after `World` has already emitted) without missing the current value.

**Resolves a design gap identified in code review** (`review.md`, MAJOR finding on the original `signal`-based design): a plain Godot `signal` only reaches subscribers connected before it fires, so anything spawned later (a boss, a tower, a reparented camera per the deferred retargeting feature) would silently never receive `world_size`. `BehaviorSubject`'s replay-on-subscribe eliminates this class of bug for `world_size_changed` and any future `GameEvents` entry.

### FR-06: Standalone, reusable Camera scene
Extract the camera into its own scene, `camera.tscn` (root `Camera2D` node) with a new script `components/camera/camera_bounds.gd` attached. `camera.tscn` keeps `position_smoothing_enabled = true` for centered-follow behavior. `camera_bounds.gd` calls `GameEvents.world_size_changed.subscribe(_on_world_size_changed)` in `_ready()` and sets its own `limit_left`, `limit_top`, `limit_right`, `limit_bottom` to `0, 0, size.x, size.y` whenever it's invoked (immediately on subscribe if a value already exists, and again on any future change) — the camera is fully self-contained and no longer needs `Game` or anyone else to configure it. `camera.tscn` is instanced as a child of `Player` in `game.tscn`, so it still follows the player via ordinary node parenting (Camera2D inherits its parent's transform); no target-tracking script is needed for this default case.

### FR-07: Player position stays within world bounds
`player.gd` also calls `GameEvents.world_size_changed.subscribe(_on_world_size_changed)` in `_ready()`, storing the received size in a local `var world_size: Vector2` (default `Vector2.ZERO`, meaning "unconstrained/not yet known") — the subscribe call immediately delivers the current value if one exists, so `player.gd` is correctly initialized even if `World` emitted before `player.gd` connected. After `move_and_slide()` in `_physics_process`, if `world_size` is non-zero, clamp `position` to `[half_size, world_size - half_size]` using a `Vector2(20, 20)` half-size margin (matching the player's visual/collision extents), so the player's collision shape can never cross the world boundary — independent of and in addition to the camera's own clamping.

## Acceptance Criteria
- [x] AC-01: `world.tscn` is self-contained — it owns the `TileMapLayer` and an exported `world_size: Vector2`, and no longer instances `Player` or `Enemy`.
- [x] AC-02: `game.tscn` exists, instances `World`, `Player`, and `Enemy`, and reproduces the current player/enemy positions and the enemy's `movement_behavior` override from today's `world.tscn`.
- [x] AC-03: `project.godot`'s `run/main_scene` points to `game.tscn`.
- [x] AC-04: `camera.tscn` (with `position_smoothing_enabled = true`) is instanced as a child of `Player` in `game.tscn`; running the game, the camera keeps the player near the center of the screen while moving through open world space. (Structurally and value-verified via headless script; interactive visual confirmation still recommended — see review.md.)
- [x] AC-05: `camera_bounds.gd` sets the camera's limits from `GameEvents.world_size_changed.subscribe(...)` (not from `game.gd`), receiving the current value immediately on subscribe regardless of emission timing, and moving the player to any edge of the world does not scroll the camera past that edge — no space outside the world bounds is ever visible. (Value-verified via headless script; the original `signal`-based design's `_ready()`-ordering bug is now structurally eliminated by `BehaviorSubject`'s replay-on-subscribe rather than worked around — interactive edge-clamp confirmation still recommended — see review.md.)
- [x] AC-07: The player's position (accounting for its `Vector2(20, 20)` half-size margin) never exceeds world bounds — moving toward any of the four edges stops the player's collision shape exactly at that edge instead of letting it pass through or off-screen. (Propagation path value-verified; interactive edge-to-edge confirmation still recommended — see review.md.)
- [x] AC-06: No regressions to existing enemy movement or player input handling — `enemy.gd`, `player.gd`'s `movement_behavior` delegation, and the `MovementBehavior`/`InputMovementBehavior` interface are unchanged by this camera/clamping work (player.gd gains new bounds-clamping logic, but its existing movement delegation is untouched).

## Technical Scope

### Affected Modules
- `world.tscn` (restructured — loses Player/Enemy instances, keeps TileMapLayer)
- `player.gd` (gains `GameEvents` listener + post-move position clamping)
- `game.tscn` (Player gains `camera.tscn` as a child instance)
- `project.godot` (main_scene changes; new `[autoload]` entry for `GameEvents`)

### New Components Required
- `game.tscn` (new main scene, composes World + Player + Enemy)
- `game.gd` (script on Game's root — pure scene composition only; no longer wires camera limits, since that's now handled by the event bus)
- `world.gd` (script on World's root, exposes `@export var world_size: Vector2`, emits `GameEvents.world_size_changed`)
- `components/events/behavior_subject.gd` (generic, reusable `BehaviorSubject` class — caches its last emitted value and replays it to new subscribers, modeled on RxJS's `BehaviorSubject`)
- `components/events/game_events.gd` (autoload singleton, general-purpose game event bus; currently exposes `var world_size_changed := BehaviorSubject.new()`)
- `camera.tscn` (standalone reusable Camera2D scene, instanced under Player)
- `components/camera/camera_bounds.gd` (script on `camera.tscn`'s root, subscribes to `GameEvents` and sets its own limits)

### Integration Points
- `world.gd` emits `GameEvents.world_size_changed`; `camera_bounds.gd` and `player.gd` each independently subscribe and react, receiving the current value immediately on subscribe regardless of emission timing — no direct references between `World`, `Player`, and the camera are needed.
- `game.gd`'s role shrinks back to pure scene composition (instancing World/Player/Enemy at their positions) — it no longer reads `World.world_size` or reaches into `Player`'s children.
- Existing `MovementBehavior` resources and their consumers (`player.gd`, `enemy.gd`) are relocated but not modified; `player.gd`'s new bounds-clamping code runs after `movement_behavior.get_velocity()`/`move_and_slide()`, not inside the `MovementBehavior` interface.

## Non-Functional Requirements
- Performance: negligible — `Camera2D` limits/smoothing are engine-native, no per-frame custom script logic required.
- Security: not applicable.
- Scalability: `world_size` being exported per-`World`-instance allows different arenas/levels to define different sizes without code changes, supporting the mission's tower-defense/wave-based direction.

## Out of Scope
- Camera zoom, rotation, or shake effects.
- Dead-zone/margin-based centering (explicitly declined — using Camera2D's built-in hard clamp at world edges).
- Camera retargeting/reparenting to non-Player targets (e.g. a boss enemy or a tower under construction) — `camera.tscn` is built as a standalone, reusable scene now to enable this later, but the reparenting/focus-switching API itself is deferred to a future feature.
- Enemy AI awareness of camera or world bounds (enemies do not currently check world bounds; not addressed here).
- Multiple simultaneous cameras or split-screen.
- Automated tests (none configured in this project yet).

## Open Questions
None — scene restructuring, camera approach, and edge behavior were confirmed with the user during spec analysis. The event-bus architecture, standalone camera scene, and player position-clamping were added in a subsequent refinement after initial implementation surfaced a gap (see Revision History).

---

## Revision History

| Date | Change Summary |
|------|----------------|
| 2026-08-05 | Initial spec |
| 2026-08-05 | Refined after implementation/review: replaced direct `Game`→`Camera2D` wiring with a `WorldEvents` event bus; extracted the camera into a standalone reusable `camera.tscn`; added player position-clamping (AC-07) after discovering the original design only clamped the camera's view, not the player's actual position, letting the player walk off-screen |
| 2026-08-05 | Renamed the `WorldEvents` autoload/script to `GameEvents` (`components/events/game_events.gd`) — reframed as a general-purpose game event bus rather than world-specific, anticipating future cross-cutting events (waves, towers, score) |
| 2026-08-05 | Replaced `GameEvents.world_size_changed`'s raw `signal` with an RxJS-style `BehaviorSubject` (`components/events/behavior_subject.gd`) that caches its last value and replays it to new subscribers — resolves a MAJOR finding from code review where late-joining listeners (a boss/tower spawned after `World` had already emitted, or a reparented camera) would have silently never received `world_size` |
