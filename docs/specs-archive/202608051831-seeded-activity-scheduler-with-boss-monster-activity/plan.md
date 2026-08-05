# Implementation Plan: Seeded Activity Scheduler with Boss Monster Activity

## Overview
Add a new `components/activities/` category following the existing `MovementBehavior` strategy-pattern convention: an `Activity` base `Resource` with a concrete `BossActivity` subclass, driven by a scheduler node (`ActivityManager`) added as a child of `Game` in `scenes/game.tscn`. All randomness flows through one `RandomNumberGenerator` owned by `ActivityManager` and passed into each `Activity.execute()` call, guaranteeing seeded determinism end-to-end. `ActivityManager` gates its start on a new `GameEvents.world_loaded` readiness signal rather than self-starting unconditionally, so it can never trigger an activity before the world is fully instanced. No changes to `enemy.gd`, `target_movement_behavior.gd`, or `player.gd` are required — the feature composes existing pieces plus two small additions to `game_events.gd`/`world.gd`.

Since this project has no test framework configured (per `docs/project.md`), verification is manual: running the game in the editor, inspecting the scene tree, and checking console output for the printed seed.

## Architecture Decisions
- **`Activity` as `Resource`, not `Node`**: matches the existing `MovementBehavior` pattern exactly (`components/movement/movement_behavior.gd`) — swappable, editor-configurable, no scene-tree overhead per activity type. `BossActivity` mirrors `TargetMovementBehavior` as the concrete subclass.
- **`ActivityManager` as a plain child `Node` of `Game`, not an autoload**: confirmed in feature refinement. It receives `world` and `spawn_parent` as `@export` references wired in the editor, avoiding new implicit global state (unlike `GameEvents`, which exists specifically for cross-cutting broadcast events — this is scoped, owned behavior instead).
- **Single seeded `RandomNumberGenerator` threaded explicitly through `execute()`**: rather than a global/autoload RNG, `ActivityManager` owns the only RNG instance and passes it as a parameter into every `Activity` call. This makes the determinism boundary explicit and impossible to bypass accidentally (no static `randi()` calls anywhere in `components/activities/`).
- **Deterministic target clamping (direction + distance) instead of retry loop**: per refinement, `BossActivity` picks an angle then a distance, clamping distance to the nearest world edge if `min_target_distance` isn't reachable — avoids any unbounded/retry logic entirely.
- **`GameEvents.world_loaded` as a new `BehaviorSubject`, not a plain `signal`**: consistent with the project's existing architecture decision for `world_size_changed` — a `BehaviorSubject` replays its last value to late subscribers, so `ActivityManager` cannot miss the readiness signal regardless of node ready-order in `scenes/game.tscn`. `world_size_changed` itself is left completely untouched, since it may need to fire again later (e.g. a future world-resizing activity) while `world_loaded` is a one-time-per-load signal.
- **Timer created in code (`Timer.new()`), not as a `.tscn` child node**: keeps `ActivityManager` a script-only addition to `game.tscn` (no new sub-scene needed), consistent with how simple the existing scenes are.

## Implementation Steps

### Step 1: GameEvents world_loaded signal
- [x] Modify `components/events/game_events.gd`: add `var world_loaded := BehaviorSubject.new()` alongside the existing `world_size_changed`.
- [x] Modify `scenes/world/world.gd`: in the existing `_ready()`, after the existing `GameEvents.world_size_changed.emit(world_size)` line, add `GameEvents.world_loaded.emit(true)`.
- Files: `components/events/game_events.gd` (modified), `scenes/world/world.gd` (modified)

### Step 2: Activity base resource
- [x] Create `components/activities/activity.gd`:
  - `class_name Activity extends Resource`
  - `@export var next_interval_min: float = 20.0`
  - `@export var next_interval_max: float = 40.0`
  - `func execute(rng: RandomNumberGenerator, world_size: Vector2, spawn_parent: Node) -> void` — empty/base, overridden by subclasses.
  - `func get_next_interval(rng: RandomNumberGenerator) -> float` — returns `rng.randf_range(next_interval_min, next_interval_max)`.
- Files: `components/activities/activity.gd` (new)

### Step 3: BossActivity
- [x] Create `components/activities/boss_activity.gd`:
  - `class_name BossActivity extends Activity`
  - `@export var boss_scene: PackedScene`
  - `@export var min_target_distance: float = 200.0`
  - `func execute(rng, world_size, spawn_parent) -> void`:
    1. Compute spawn position: `Vector2(rng.randf_range(0, world_size.x), rng.randf_range(0, world_size.y))`.
    2. Compute a random direction: `var angle = rng.randf_range(0, TAU)`, `var direction = Vector2.RIGHT.rotated(angle)`.
    3. Compute max reachable distance along that ray within `[0, world_size.x] x [0, world_size.y]` from the spawn position (ray-vs-AABB distance-to-edge calculation — handle `direction.x`/`direction.y` == 0 to avoid division by zero).
    4. If `max_reachable_distance < min_target_distance`: target distance = `max_reachable_distance` (clamped, per AC-08).
       Else: target distance = `rng.randf_range(min_target_distance, max_reachable_distance)`.
    5. `var target = spawn_position + direction * target_distance`.
    6. Instantiate `boss_scene`, set `position = spawn_position`.
    7. Create `var behavior = TargetMovementBehavior.new()`, set `behavior.target = target`, assign to the instance's `movement_behavior` before `add_child`.
    8. `spawn_parent.add_child(instance)`.
- Files: `components/activities/boss_activity.gd` (new)

### Step 4: ActivityManager scheduler
- [x] Create `components/activities/activity_manager.gd`:
  - `class_name ActivityManager extends Node`
  - `@export var level_seed: int = 0`
  - `@export var world: World`
  - `@export var spawn_parent: Node`
  - `@export var activities: Array[Activity]`
  - Private: `var _rng := RandomNumberGenerator.new()`, `var _timer: Timer`, `var _last_activity: Activity`.
  - `func _ready() -> void`: resolve `level_seed` (if `0`, `level_seed = randi(); print("ActivityManager seed: ", level_seed)`), `_rng.seed = level_seed`, create `_timer = Timer.new()`, `_timer.one_shot = true`, `add_child(_timer)`, connect `_timer.timeout` to `_on_timeout`, then subscribe to world readiness: `GameEvents.world_loaded.subscribe(func(_v): start())`.
  - `func start() -> void`: `_trigger_next_activity()`.
  - `func _trigger_next_activity() -> void`: pick `var activity = activities[_rng.randi() % activities.size()]`, call `activity.execute(_rng, world.world_size, spawn_parent)`, set `_last_activity = activity`, `_timer.wait_time = activity.get_next_interval(_rng)`, `_timer.start()`.
  - `func _on_timeout() -> void`: `_trigger_next_activity()`.
  - Note: because `GameEvents.world_loaded` is a `BehaviorSubject`, the `subscribe()` call in `_ready()` immediately invokes the callback (and thus `start()`) if `world_loaded` has already fired by the time `ActivityManager._ready()` runs — this is what makes the gating safe regardless of node ready-order, per FR-02/FR-06 and AC-09.
- Files: `components/activities/activity_manager.gd` (new)

### Step 5: Scene wiring
- [x] Open `scenes/game.tscn` in the Godot editor:
  - Add a new child node of type `Node` under `Game`, name it `ActivityManager`, attach `components/activities/activity_manager.gd`.
  - Set `world` export to the existing `World` node.
  - Set `spawn_parent` export to the `Game` node itself.
  - Leave `level_seed` at `0` for now (auto-generates + prints).
  - Add one `BossActivity` resource instance to the `activities` array; set its `boss_scene` export to `res://scenes/enemy/enemy.tscn`; leave `min_target_distance` at the default `200.0` and `next_interval_min`/`next_interval_max` at defaults (`20.0`/`40.0`), or tune during manual testing.
  - Note: the existing static `Enemy` node already present in `game.tscn` (with its own hardcoded `TargetMovementBehavior`, per current `game.tscn` contents) is left untouched — it is a separate, pre-existing entity unrelated to this feature's dynamically spawned bosses. No requirement to remove it; flag to the user during review if its continued presence is confusing during manual testing.
- Files: `scenes/game.tscn` (modified)

### Step 6: Manual verification (no test framework configured)
- [x] Run the game with `level_seed = 0`: confirm a seed value is printed to the Godot output console, and that a boss still spawns (confirms `world_loaded` gating doesn't block startup).
- [x] Set `level_seed` to a fixed value (e.g. `12345`), run twice, confirm (via print statements temporarily added to `BossActivity.execute`, or breakpoints) that spawn position and target position are identical across both runs.
- [x] Confirm the boss `Enemy` appears at a valid in-bounds position and visibly moves toward its target using the existing movement/physics logic, with no changes needed in `enemy.gd`/`target_movement_behavior.gd`.
- [x] Inspect the running scene tree (Remote tab in Godot editor) to confirm the spawned `Enemy` is parented directly under `Game`, not under `ActivityManager`.
- [x] Temporarily set `min_target_distance` larger than the world diagonal, confirm the target clamps to a world edge instead of erroring or hanging.
- [x] Confirm the delay between the first and second activity trigger falls within `next_interval_min`/`next_interval_max` (observable via timestamps in temporary print statements).
- [x] Temporarily reorder `ActivityManager` to be the first child of `Game` (before `World`) in `scenes/game.tscn`, re-run, and confirm the boss still spawns correctly (verifies `world_loaded`'s `BehaviorSubject` replay makes `ActivityManager` immune to node ready-order); revert the reorder afterward.
- Files: none permanent — temporary `print()` statements added/removed during verification, or use the debugger; no test files created since no framework exists.

## Acceptance Criteria Mapping
| AC | Verified By |
|----|-------------|
| AC-01: identical seed → identical spawn/target across runs | Step 6 manual repeat-run check |
| AC-02: `level_seed = 0` generates and prints a random seed | Step 6 manual console check |
| AC-03: interval between activities falls within min/max | Step 6 manual timestamp check |
| AC-04: `BossActivity` spawns one in-bounds `Enemy` with valid `TargetMovementBehavior` target | Step 6 manual scene tree + position check |
| AC-05: spawned boss moves toward target via existing movement code, unmodified | Step 6 manual visual check |
| AC-06: adding a future `Activity` subclass requires no `ActivityManager` changes | Structural — satisfied by `ActivityManager`'s use of the `Activity` base type and `activities` array (Step 4); no code change needed to verify beyond design review |
| AC-07: spawned boss is a child of `Game`, not `ActivityManager` | Step 6 manual Remote scene tree check |
| AC-08: target clamps to farthest reachable point when `min_target_distance` unreachable | Step 3 clamping logic + Step 6 manual oversized-distance check |
| AC-09: `ActivityManager` does not trigger any activity until `world_loaded` has fired, regardless of ready-order | Step 1/4 `BehaviorSubject`-based gating + Step 6 manual node-reorder check |

## Risks & Mitigations
- **Risk**: Ray-vs-AABB max-distance calculation (Step 3.3) has edge cases when `direction.x` or `direction.y` is exactly `0` (division by zero). → **Mitigation**: guard each axis check (skip axis contribution when the corresponding direction component is `~0`, using a small epsilon or explicit `if direction.x != 0` branching), only take the `min()` of valid axis distances.
- **Risk**: A future activity that needs `world_loaded` to fire more than once (e.g. after a world resize) would not be served by the current one-shot emission from `World._ready()`. → **Mitigation**: explicitly out of scope per FR-06 — `world_loaded` is defined as a one-time-per-load signal in this feature; a future feature can revisit if a "world reloaded" scenario emerges. `world_size_changed` remains the mechanism for size changes over time.
- **Risk**: No automated tests means regressions in future activity types could silently break determinism. → **Mitigation**: out of scope for this feature per `docs/project.md` (no testing framework configured yet); manual verification steps in Step 6 are the accepted mitigation for now.

## Estimated Complexity
**Low** — three new small script files following an already-established pattern (`MovementBehavior`/`TargetMovementBehavior`) in the codebase, two small additions to existing `GameEvents`/`World` scripts (mirroring the existing `world_size_changed` pattern), one editor scene-wiring step, and no changes to existing entity scripts. The only non-trivial logic is the ray-vs-AABB clamping calculation in `BossActivity`, which is self-contained and easily verified manually.
