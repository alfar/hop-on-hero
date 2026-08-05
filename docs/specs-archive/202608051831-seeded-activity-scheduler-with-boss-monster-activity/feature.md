# Feature: Seeded Activity Scheduler with Boss Monster Activity

## Summary
Introduce a seeded, deterministic "activity" system that periodically triggers game events (spawns, weather, buffs/debuffs, etc.) during a level. A master seed drives a `RandomNumberGenerator` shared by the scheduler and every activity it triggers, so replaying the same seed reproduces the same sequence of activities, timings, and activity-internal random choices (positions, targets, etc.). The interval before the next activity is determined by the activity that just ran, not a single global cadence. This feature implements the scheduler infrastructure plus a single concrete activity: **Boss Monster**, which spawns an `Enemy` at a random position in the world and gives it a random patrol target (at least a minimum distance away) via the existing `TargetMovementBehavior`.

## User Stories
- As a player, I want unexpected events (like a boss appearing) to happen periodically during a run, so the level feels alive and escalating rather than static.
- As a player replaying a level with the same seed, I want the same activities to occur at the same times with the same outcomes (e.g. same boss spawn/target position), so seeded runs are fair and reproducible (e.g. for speedrunning or sharing seeds).
- As a developer, I want to add new activity types (trader caravan, weather, blessed/cursed times, item drops) later without modifying the scheduler itself, so the system stays extensible.

## Functional Requirements

### FR-01: ActivityManager node
A new `ActivityManager` node (regular `Node`, not an autoload) is added as a child of `Game` in `scenes/game.tscn`, mirroring how `Camera2D` is wired as a child under `Player`. It owns:
- `@export var level_seed: int = 0` — if `0` at `_ready()`, generate a random seed via `randi()` and print it (so a dev can copy it back in to replay a specific run).
- `@export var world: World` — direct reference to the `World` node, wired in the editor, used to read `world.world_size` for picking random positions/targets.
- `@export var spawn_parent: Node` — direct reference to `Game`, wired in the editor, used as the parent for any entities activities instantiate (e.g. the boss `Enemy`). Kept as an explicit export (rather than `get_parent()`) so spawn parenting doesn't silently depend on `ActivityManager`'s exact position in the scene tree.
- `@export var activities: Array[Activity]` — the pool of possible activities (initially containing one `BossActivity` resource instance).
- An internal `RandomNumberGenerator`, seeded from `level_seed` once at start.

### FR-02: Explicit start, gated on world readiness
`ActivityManager` does **not** auto-schedule in `_ready()`. Instead, in its own `_ready()`, it subscribes to the new `GameEvents.world_loaded` event (see FR-06) and calls its own `func start() -> void` only when that event fires:
```
func _ready() -> void:
    GameEvents.world_loaded.subscribe(func(_v): start())
```
Because `world_loaded` is a `BehaviorSubject` (caches its last value and replays it immediately to new subscribers, per the project's existing `GameEvents` convention), it is not possible for `ActivityManager` to miss it or start before the world is fully instanced, regardless of node ready-order within `scenes/game.tscn`. No new `game.gd` root script is required — `ActivityManager` remains self-contained.

### FR-03: Activity base resource
A new `Activity` base class (`Resource`), under a new `components/activities/` folder (mirrors `components/movement/` convention):
```
class_name Activity
extends Resource

@export var next_interval_min: float = 20.0
@export var next_interval_max: float = 40.0

func execute(rng: RandomNumberGenerator, world_size: Vector2, spawn_parent: Node) -> void:
    pass # overridden per activity type

func get_next_interval(rng: RandomNumberGenerator) -> float:
    return rng.randf_range(next_interval_min, next_interval_max)
```
Each concrete activity type overrides `execute()`. `get_next_interval()` is called on the activity that **just ran** to determine the delay before the next activity fires (satisfies "interval is based on the preceding activity").

### FR-04: Scheduling loop
`ActivityManager` maintains a `Timer` (created in code or as a scene child) that:
1. On `start()`, picks a random activity from `activities` (seeded via the manager's `RandomNumberGenerator`), executes it, then starts the timer for `get_next_interval()` on that same activity.
2. On timeout, repeats: pick next random activity (seeded), execute it, restart the timer using the interval from the activity that just ran.
- Activity selection: uniform random pick among `activities` via the seeded RNG (`rng.randi() % activities.size()`). No weighting system yet — out of scope.
- All randomness (activity selection, timer interval, and anything an activity needs internally, e.g. spawn/target position) must draw from the single seeded `RandomNumberGenerator` owned by `ActivityManager` and passed into `execute()`, so nothing bypasses the seed.

### FR-05: BossActivity
A new `BossActivity` (`Resource`, extends `Activity`) under `components/activities/`:
```
class_name BossActivity
extends Activity

@export var boss_scene: PackedScene
@export var min_target_distance: float = 200.0

func execute(rng, world_size, spawn_parent):
    # instantiate boss_scene, place at random position in world_size,
    # assign a TargetMovementBehavior with a random target at least
    # min_target_distance away from the spawn position, add as child of spawn_parent
```
- `boss_scene` will be configured (in the editor) to point at the existing `res://scenes/enemy/enemy.tscn` — no new Boss scene is created in this feature.
- Spawn position: random point within `[0, world_size.x] x [0, world_size.y]`, drawn from the seeded `rng`.
- Target position: computed deterministically with no retry loop:
  1. Pick a random direction (angle) from the seeded `rng`.
  2. Compute the maximum distance travelable from the spawn position in that direction before hitting a world bound (i.e. the distance to the nearest edge of `[0, world_size.x] x [0, world_size.y]` along that ray).
  3. If that max reachable distance is `< min_target_distance`, clamp the target to that farthest reachable point in the chosen direction (i.e. the world edge) rather than enforcing the minimum — this guarantees termination with no re-rolling, per confirmed refinement.
  4. Otherwise, pick a random distance from the seeded `rng` in `[min_target_distance, max_reachable_distance]` and set the target at that distance along the chosen direction from the spawn position.
- The instanced `Enemy` gets a new `TargetMovementBehavior` resource (created in code, not shared/mutated from an exported template) with `target` set to the computed target position, assigned to `movement_behavior` before `add_child`.
- Spawned enemy is added as a child of `spawn_parent` (`Game`, per FR-01's exported reference) — **not** as a child of `ActivityManager` itself.

### FR-06: `GameEvents.world_loaded`
A new `BehaviorSubject` is added to the `GameEvents` autoload (`components/events/game_events.gd`), alongside the existing `world_size_changed`:
```
var world_loaded := BehaviorSubject.new()
```
`scenes/world/world.gd` emits it once, in `_ready()`, alongside the existing `world_size_changed` emit:
```
func _ready() -> void:
    GameEvents.world_size_changed.emit(world_size)
    GameEvents.world_loaded.emit(true)
```
`world_size_changed` is unchanged and kept exactly as-is — it remains the mechanism for a world size that may change over time (e.g. a future activity resizing the world); `world_loaded` is a separate, one-time-per-load "everything is instanced" readiness signal and is not intended to fire again after its initial emission in this feature's scope.

## Acceptance Criteria
- [x] AC-01: Adding an `ActivityManager` node (with `world` and `activities` wired) under `Game` and setting `level_seed` to a fixed non-zero value, then running the game twice, produces the boss spawning at the identical position with the identical target both times.
- [x] AC-02: Leaving `level_seed` at `0` generates a random seed at runtime and prints it to the console/output.
- [x] AC-03: The first activity fires, and the delay before the second activity is a value between that first activity's `next_interval_min`/`next_interval_max` (verifiable via prints/logs or debugger during manual testing).
- [x] AC-04: A `BossActivity` execution instantiates exactly one `Enemy` inside the configured world bounds, with a `TargetMovementBehavior` whose `target` is at least `min_target_distance` from the enemy's spawn position.
- [x] AC-05: The spawned boss Enemy visibly moves toward its assigned target using existing `TargetMovementBehavior`/`enemy.gd` physics-process logic (no changes needed to `enemy.gd` or `target_movement_behavior.gd`).
- [x] AC-06: Adding a second `Activity` subclass later requires no changes to `ActivityManager` beyond adding an instance to the `activities` export array (extensibility check — can be verified structurally, not necessarily by building a second activity now).
- [x] AC-07: The spawned boss `Enemy` is a direct child of the `Game` node (`spawn_parent`), not of `ActivityManager`, visible in the running scene tree.
- [x] AC-08: When `min_target_distance` exceeds the maximum reachable distance from the spawn position in the chosen direction within world bounds, the target is clamped to the farthest point inside the world in that direction — no error, no retry loop, no infinite loop.
- [x] AC-09: `ActivityManager` does not trigger any activity until `GameEvents.world_loaded` has fired at least once; it fires correctly regardless of whether `ActivityManager._ready()` or `World._ready()` runs first.

## Technical Scope

### Affected Modules
- `scenes/game.tscn` — add `ActivityManager` child node, with `spawn_parent` wired to the `Game` node itself.
- `scenes/enemy/enemy.tscn` — reused as-is, no changes.
- `components/movement/target_movement_behavior.gd` — reused as-is, no changes.

### New Components Required
- `components/activities/activity.gd` — `class_name Activity`, base `Resource`.
- `components/activities/activity_manager.gd` — `class_name ActivityManager`, `extends Node`, the scheduler.
- `components/activities/boss_activity.gd` — `class_name BossActivity`, `extends Activity`.
- `components/events/game_events.gd` — **modified**: add `var world_loaded := BehaviorSubject.new()`.
- `scenes/world/world.gd` — **modified**: emit `GameEvents.world_loaded.emit(true)` in `_ready()`, alongside the existing `world_size_changed` emit.
- Editor wiring: `ActivityManager` node added under `Game` in `scenes/game.tscn`, with `world` exported reference set to the existing `World` node, and `activities` containing one `BossActivity` sub-resource with `boss_scene` pointed at `res://scenes/enemy/enemy.tscn`.

### Integration Points
- `GameEvents.world_loaded` (subscribed to by `ActivityManager` to gate its `start()` call — new dependency on `GameEvents`).
- `World.world_size` (still read directly via the exported `world` reference once started, not via `world_size_changed`).
- `scenes/enemy/enemy.tscn` (instanced by `BossActivity`).
- `components/movement/target_movement_behavior.gd` (instantiated and configured by `BossActivity`).

## Non-Functional Requirements
- **Determinism**: every source of randomness reachable from the activity system (activity selection, interval timing, spawn position, target position, and any future activity's internal randomness) must originate from the single `RandomNumberGenerator` seeded from `level_seed`. No use of the global `randi()`/`randf()` free functions (which are not independently seedable per-instance) inside activity logic — only inside the one-time fallback seed generation in `ActivityManager` itself.
- **Performance**: negligible — one timer and infrequent (tens-of-seconds interval) node instancing.
- **Extensibility**: new activity types must be addable as new `Activity` subclasses + resource instances without modifying `ActivityManager`.

## Out of Scope
- Monster spawner, trader caravan, item appearance, weather change, blessed/cursed time activities — only `BossActivity` is implemented now; the `Activity` base class exists to support them later.
- Weighted/non-uniform activity selection probabilities.
- A distinct Boss scene/stats/visuals — the existing generic `Enemy` scene is reused unmodified.
- Persisting/loading seeds across sessions (save games, level select UI) — the seed is only an editor-set or runtime-printed value for this feature.
- Pausing/stopping/resetting the scheduler mid-run.
- Any UI displaying the seed, upcoming activity, or countdown to the player.
- Concurrent/overlapping activities (only one activity is ever "in flight" being scheduled at a time in this design).

## Open Questions
- None outstanding.

---

## Revision History

| Date | Change Summary |
|------|----------------|
| 2026-08-05 | Initial spec |
| 2026-08-05 | Spawned entities now explicitly parented to `Game` via a new `spawn_parent` export (not `ActivityManager`); target-position selection redefined as a deterministic direction+distance calculation that clamps to the farthest reachable world edge when `min_target_distance` can't be satisfied, removing the retry-loop risk entirely. |
| 2026-08-05 | Added `GameEvents.world_loaded` (new `BehaviorSubject`, emitted once by `World._ready()` alongside the existing, unchanged `world_size_changed`) as an explicit world-readiness signal; `ActivityManager` now gates its `start()` call on this event instead of self-starting unconditionally in `_ready()`. |
