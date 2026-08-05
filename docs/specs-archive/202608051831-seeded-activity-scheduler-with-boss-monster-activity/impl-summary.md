## Implementation Complete

### Files Created
- `components/activities/activity.gd` — `Activity` base `Resource`, seeded interval calculation
- `components/activities/boss_activity.gd` — `BossActivity`, spawns boss `Enemy` with seeded position/target
- `components/activities/activity_manager.gd` — `ActivityManager` scheduler node

### Files Modified
- `components/events/game_events.gd` — added `world_loaded` `BehaviorSubject`
- `scenes/world/world.gd` — emits `GameEvents.world_loaded` in `_ready()`; added `class_name World` (see Notes)
- `scenes/game.tscn` — added `ActivityManager` child node under `Game`, wired `world`/`spawn_parent` exports, added one `BossActivity` sub-resource pointed at `scenes/enemy/enemy.tscn`

### Acceptance Criteria
- [x] AC-01: Passed — fixed `level_seed=12345`, ran twice headless, identical spawn `(9.746082, 623.8782)` and target `(20.40112, 875.4634)` both times
- [x] AC-02: Passed — `level_seed=0` prints `ActivityManager seed: <random>` on every run
- [x] AC-03: Passed — with `next_interval_min/max=1.0/2.0`, measured trigger gaps (1.908s, 1.628s, 1.774s) all fell within range and matched the logged `next_interval`
- [x] AC-04: Passed — `BossActivity.execute` instantiates exactly one `Enemy`, spawn position within world bounds, target at/above `min_target_distance`
- [x] AC-05: Passed — no changes made to `enemy.gd`/`target_movement_behavior.gd`; spawned boss uses them unmodified
- [x] AC-06: Passed (structural) — `ActivityManager` depends only on the `Activity` base type and `activities` array; adding a future subclass requires no `ActivityManager` change
- [x] AC-07: Passed — headless scene-tree dump confirmed spawned boss is a direct child of `Game` (sibling of `World`/`Player`/`Enemy`/`ActivityManager`), not of `ActivityManager`
- [x] AC-08: Passed — with `min_target_distance=999999.0`, target clamped to world edge `(34.14575, 1200.0)`, no error/hang
- [x] AC-09: Passed — reordered `ActivityManager` before `World` in `game.tscn`, re-ran, boss still spawned correctly with no null-reference errors, confirming `BehaviorSubject` replay makes it ready-order-independent

### Notes
- **Deviation from plan**: `scenes/world/world.gd` had no `class_name World` before this feature, even though `feature.md`/`plan.md` assumed one existed (needed for `@export var world: World` to type-check). Added `class_name World` — a one-line, low-risk addition consistent with the project's existing `class_name` convention (`MovementBehavior`, `TargetMovementBehavior`, etc.).
- **Deviation from plan**: Godot 4 requires `node_paths=PackedStringArray("world", "spawn_parent")` on the `[node ...]` line for `world`/`spawn_parent` (Node-typed exports) to auto-resolve from their stored `NodePath` values at scene load — a plain `NodePath(...)` property assignment alone leaves the export `null`. Discovered and fixed via a real Godot 4.7.1 headless run that surfaced the null-reference error, then confirmed against an editor-saved reference. Plan's Step 5 didn't anticipate this Godot-specific serialization detail.
- **Deviation from plan**: `BossActivity.execute()` uses `spawn_parent.add_child.call_deferred(instance)` instead of a direct `add_child()`. Direct `add_child` failed with "Parent node is busy setting up children" because `World._ready()` (which fires `world_loaded`) runs while `Game` is still instantiating its own children; deferring the call to the next idle frame resolves this safely. Confirmed via headless run before/after the fix.
- `activities` array in `game.tscn` is a plain `[SubResource(...)]` literal (no `Array[Activity](...)` type-wrapper needed) — Godot infers the element type from the script's static `Array[Activity]` declaration.
- All verification was done via Godot's headless CLI (`Godot_v4.7.1-stable_win64.exe --headless`) since no interactive editor session was available in this environment; temporary `print()` statements used for AC checks were added and removed, leaving no permanent debug code.
