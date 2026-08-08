# Round Initializer

Implemented on: 2026-08-08

Introduced a new `RoundInitializer` node (`components/round/round_initializer.gd`), instanced as a static child of `Game` in `game.tscn` (after `ActivityManager`). It centralizes the round-startup sequence: resolves the seed (moved off `ActivityManager`, same `GameEvents.next_level_seed` → fallback `randi()` priority), picks a random `World.world_size` in 64×64-tile increments bounded between the current screen size and 1600×1600, calls a new `World.fill_tiles(rng, tile_bounds)` method to paint the `TileMapLayer`, emits `GameEvents.world_size_changed`/`world_loaded` only once sizing and filling are complete, then injects the shared `RandomNumberGenerator` into and starts `ActivityManager`.

Key files:
- `components/round/round_initializer.gd` (new)
- `scenes/world/world.gd` — added `fill_tiles`, removed self-emitting `_ready()`
- `components/activities/activity_manager.gd` — removed `level_seed` self-resolution and `world_loaded` self-subscription; `start()` is now purely externally invoked
- `scenes/game.tscn` / `scenes/game.gd` — wired `RoundInitializer`; `Game` now reads `$RoundInitializer.level_seed` for Retry

Notable decisions:
- Seed/RNG ownership centralized in `RoundInitializer` rather than split across `World`/`ActivityManager`.
- Relies on Godot's guaranteed depth-first, declaration-order `_ready()` propagation for static scene-tree siblings (no defensive `await`) to ensure `ActivityManager`'s `Timer` exists before `RoundInitializer` calls `start()`.
- Existing hand-authored decorative tile data in `world.tscn` was removed, since `fill_tiles` clears and repaints the `TileMapLayer` at runtime.
- `World.fill_tiles` paints tiles via `TileMapLayer.set_cells_terrain_connect` against a proper Godot `Terrain` (terrain set 0, terrain 0) the user authored on the `TileSet`, letting Godot resolve the correct corner/edge/interior tile per cell from terrain peering-bit data — this replaced an initial manual 9-tile atlas-coordinate lookup table shortly after the feature was first archived (see `impl-summary.md`'s post-implementation update).
- `test/integration/inventory/item_pickup_test.gd` was also fixed as a follow-up: it depended on whatever `GameEvents.world_size_changed` (a shared `BehaviorSubject`) happened to be cached from an unrelated earlier test; it now seeds its own value in `before_each()`.
