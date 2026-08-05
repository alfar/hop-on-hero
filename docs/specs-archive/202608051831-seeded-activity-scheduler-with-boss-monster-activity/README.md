# Seeded Activity Scheduler with Boss Monster Activity

Implemented on: 2026-08-05

Added a new `components/activities/` category (mirroring the existing `components/movement/` strategy pattern) providing a seeded, deterministic scheduler for periodic in-game "activities." An `ActivityManager` node (child of `Game` in `scenes/game.tscn`) owns a single seeded `RandomNumberGenerator`, threads it through every `Activity.execute()` call, and picks the next activity's timing from the activity that just ran — so a fixed `level_seed` reproduces an identical sequence of activities, timings, and internal random choices on replay.

Only one concrete activity is implemented: `BossActivity`, which spawns the existing `Enemy` scene at a random position within world bounds and assigns it a random `TargetMovementBehavior` target (clamped to the farthest reachable world edge if `min_target_distance` can't be satisfied, guaranteeing termination without a retry loop).

Key files:
- `components/activities/activity.gd` — `Activity` base `Resource`
- `components/activities/boss_activity.gd` — `BossActivity` concrete implementation
- `components/activities/activity_manager.gd` — scheduler node
- `components/events/game_events.gd` / `scenes/world/world.gd` — new `GameEvents.world_loaded` readiness signal
- `scenes/game.tscn` — `ActivityManager` wired as a child of `Game`

Notable decisions:
- `ActivityManager` gates its start on the new `GameEvents.world_loaded` `BehaviorSubject` rather than self-starting unconditionally, so it can never trigger before the world is fully instanced, regardless of node ready-order.
- Spawned entities are parented directly under `Game` (via an explicit `spawn_parent` export), not under `ActivityManager`, and use `add_child.call_deferred(...)` since `world_loaded` can fire synchronously while `Game` is still instantiating its own children.
- `scenes/world/world.gd` gained a `class_name World` it previously lacked, needed for `ActivityManager`'s typed `@export var world: World` reference.
- No automated tests exist in this project yet; all 9 acceptance criteria were verified manually via Godot's headless CLI (fixed-seed repeat runs, scene-tree dumps, timing logs).
