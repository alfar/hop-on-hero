# Configurable World Bounds with Camera Follow

Implemented on: 2026-08-05

Made the game world configurable in size and larger than the screen, with the camera following the player and clamping to world edges. Required restructuring `world.tscn` (previously the main scene, directly instancing Player/Enemy) into a self-contained `World` scene, composed together with `Player` and `Enemy` by a new `game.tscn`, which became the project's main scene.

Went through several design iterations after initial implementation and review:
- The camera was extracted into its own standalone, reusable scene (`camera.tscn` + `components/camera/camera_bounds.gd`), anticipating a future feature where the camera can be reparented to other targets (bosses, towers).
- A `GameEvents` autoload (`components/events/game_events.gd`) was introduced as a general-purpose, game-wide event bus, replacing direct `Game`→`Camera2D` wiring.
- The player's own position is also clamped to world bounds (not just the camera's view), after review caught that the player could otherwise walk off-screen past the world edge.
- `GameEvents`'s events are `BehaviorSubject`s (`components/events/behavior_subject.gd`, RxJS-style: caches the last value and replays it to new subscribers) rather than plain Godot signals — this was a direct fix for a MAJOR review finding where a plain signal-based design silently failed to notify listeners that connected after the initial emission (e.g. a boss/tower spawned later). A headless test specifically proved the fix: a subscriber connecting after emission still receives the current value immediately.

All acceptance criteria passed; final review verdict was Ready to Merge with no blocking findings.
