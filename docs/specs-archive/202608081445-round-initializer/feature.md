# Feature: Round Initializer

## Summary
Introduce a `RoundInitializer` node, instanced as a child of `Game` and run first (before `World`'s size is trusted or `ActivityManager` starts), that owns the single seeded `RandomNumberGenerator` for a round. It resolves the round's seed (reusing today's `GameEvents.next_level_seed` → fallback-`randi()` priority, moved out of `ActivityManager`), randomly picks a world size in 64×64-tile increments from that seed, fills the `TileMapLayer` within that area using the `TileSet`'s authored terrain data (also using that same seeded RNG), then starts `ActivityManager`. It guarantees `GameEvents.world_size_changed` is emitted only after the world has actually been sized and tiled, and centralizes the "start a round" sequence so a future in-place reset (not just `reload_current_scene()`) has one place to call into.

> **Post-implementation update (2026-08-08):** FR-03 as originally written (below) specified a manual 9-tile corner/edge/interior lookup table. Before that version shipped, the user set up a proper Godot `Terrain` (terrain set 0, terrain 0) on the `TileSet` in `world.tscn`, with full peering-bit data across all 12 tile variants. `World.fill_tiles` was revised to call `TileMapLayer.set_cells_terrain_connect(cells, terrain_set, terrain)` instead, letting Godot resolve the correct tile per cell from the terrain data rather than duplicating that placement logic in GDScript. See FR-03 (updated) below; the original manual-lookup design is left in place in this archived copy for historical context but is no longer what's implemented.

## User Stories
- As a player, I want every new round (via "New Seed") to generate a differently-sized, differently-tiled arena, so each run feels fresh.
- As a player, I want "Retry" to reproduce the exact same arena size and tile layout as the round I just died in, so retries are fair/comparable.
- As a developer, I want one node responsible for the ordered round-startup sequence (seed → world size → tile fill → activities), so `World` and `ActivityManager` don't each need to independently guess when it's safe to act.

## Functional Requirements

### FR-01: Seed Resolution Moves to RoundInitializer
`RoundInitializer` owns the single `RandomNumberGenerator` for the round. On `_ready()`, it resolves the seed with the same priority `ActivityManager` uses today: if `GameEvents.next_level_seed != 0`, adopt it; otherwise generate one via the non-deterministic global `randi()` (and `print` it, matching today's behavior) and seed its own `RandomNumberGenerator` with the result. `ActivityManager.level_seed` is removed as a self-resolved `@export`; `ActivityManager` instead receives its seed (or the shared `RandomNumberGenerator`, see FR-05) from `RoundInitializer`.

### FR-02: Randomized World Size in 64×64 Increments
`RoundInitializer` picks a random `world_size` whose `x` and `y` are each a random multiple of 64, independently per axis, within a min/max range using its seeded RNG:
- **Minimum**: the current viewport/screen size (each axis rounded up to the nearest multiple of 64), so the world is never smaller than what's visible on screen at once.
- **Maximum**: 1600×1600 (each axis independently capped there).
- If the screen-size-derived minimum for an axis exceeds 1600, that axis's minimum and maximum both collapse to the screen size for that axis (i.e. the max is a floor of 1600, never allowed to go below the minimum).

It assigns the result directly to `World.world_size` (a plain property write — `World` keeps its existing `@export var world_size` as an editor-preview default/fallback, per architecture decision to keep size-selection logic outside `World`).

### FR-03: Tile Fill Using the Existing 3×3 Border Tile Block *(superseded — see update note above)*
The `TileMapLayer`'s existing `TileSet` already defines a 3×3 block of atlas tiles at source columns 5–7 / rows 0–2 (top-left, top-edge, top-right / left-edge, center, right-edge / bottom-left-corner, bottom-edge, bottom-right-corner). `World` exposes a `fill_tiles(rng: RandomNumberGenerator, tile_bounds: Vector2i)` method (or equivalent) that performs the fill against its own `TileMapLayer` child — `RoundInitializer` calls this rather than reaching into `World`'s internal node structure directly, keeping `World` self-contained per existing architecture convention. The fill covers every cell within the new `world_size`'s tile bounds:
- All interior cells (not touching any of the four outer edges) get the **center** tile.
- The four single-cell corners get their respective corner tile.
- The remaining edge cells (top/bottom rows and left/right columns, excluding corners) get their respective edge tile.
- Existing hand-authored `tile_map_data` baked into `world.tscn` (currently a decorative path unrelated to this feature) is fully overwritten/cleared by this fill — the runtime fill is the sole source of tile content once a round starts.
- "Randomly" (per the original request) means: the RNG is consumed as part of this deterministic seeded process (e.g. if/when future variation is added, such as picking between multiple center-tile alternatives), even though this first version's per-cell tile choice is fully determined by cell position, not randomized pick-among-options. This keeps the fill call sequenced through the same seeded `RandomNumberGenerator` for future extension without over-building randomness that doesn't exist yet.

### FR-03 (updated): Tile Fill Using the TileSet's Authored Terrain
The `TileMapLayer`'s `TileSet` defines a proper Godot `Terrain` (terrain set 0, terrain 0, `TERRAIN_MODE_MATCH_CORNERS_AND_SIDES`) with full peering-bit data across all 12 tile variants in the source atlas. `World.fill_tiles(rng: RandomNumberGenerator, tile_bounds: Vector2i)` clears the `TileMapLayer`, builds the full list of cells within `tile_bounds`, and calls `TileMapLayer.set_cells_terrain_connect(cells, terrain_set, terrain)` to paint them — Godot itself resolves which tile variant (corner/edge/interior) belongs at each cell from the terrain's peering-bit data, rather than the manual position-based lookup table originally specified in FR-03 above. `rng` is still accepted but unused, for the same forward-compatibility reason as before. This is simpler and more robust to future terrain art changes than the manual lookup, since tile selection now lives entirely in the `TileSet` resource rather than being duplicated in GDScript.

### FR-04: world_size_changed Emits Only After Full Initialization
`World` must not emit `GameEvents.world_size_changed` (or `world_loaded`) from its own `_ready()` anymore on its default/fallback size. Instead, `RoundInitializer` drives the sequence in `_ready()`: resolve seed → set `World.world_size` → call `World.fill_tiles(rng, tile_bounds)` → **then** emit `GameEvents.world_size_changed`/`world_loaded` (either `RoundInitializer` emits them directly, or calls a `World` method that does) so `world_size_changed` fires with the final, correct, post-fill size — never with `World`'s placeholder export default. `world_loaded` continues to signal "the world is fully ready," now meaning "sized and tiled," and must fire after `world_size_changed` in the same sequence, before `ActivityManager.start()` is invoked.

### FR-05: ActivityManager Starts From RoundInitializer, Not Self-Subscription
`ActivityManager` no longer subscribes to `GameEvents.world_loaded` itself to call `start()`. `RoundInitializer` calls `ActivityManager.start()` explicitly once seed/size/tile-fill are complete (still after `world_loaded` has fired, satisfying anything else that depends on that event). `ActivityManager` receives the seed to use — either as an injected `level_seed` value or the shared `RandomNumberGenerator` instance itself (implementer's choice, but must not re-resolve `GameEvents.next_level_seed` independently — single source of truth is `RoundInitializer`).

### FR-06: Round Reset Goes Through RoundInitializer
The existing `Game._on_retry_pressed()` / `_on_new_seed_pressed()` flow (stage `GameEvents.next_level_seed`, emit `resumed`, `get_tree().reload_current_scene()`) is preserved as the reset mechanism — this feature does not replace scene-reload with in-place reset. What changes: since `RoundInitializer` is a child of `Game` in `game.tscn`, the reload naturally re-runs the whole sequence (seed resolution → size → fill → activities) from scratch on the next load, the same way `ActivityManager` does today. `RoundInitializer` must correctly pick up `GameEvents.next_level_seed` again post-reload with no leaked state (mirroring existing test hygiene that resets `next_level_seed` to `0` in `after_each()`).

## Acceptance Criteria
- [x] AC-01: Loading `game.tscn` with `GameEvents.next_level_seed == 0` produces a `World.world_size` that is a random multiple of 64 on both axes, independently bounded per axis between the screen size (rounded up to 64) and 1600, and prints the generated seed, matching today's `ActivityManager` fallback behavior (now on `RoundInitializer`).
- [x] AC-02: Loading `game.tscn` twice with the same nonzero seed (`GameEvents.next_level_seed` staged both times, as "Retry" does) produces an identical `world_size` and identical tile fill both times.
- [x] AC-03: `GameEvents.world_size_changed`'s replayed/cached value (read via `get_value()` or a fresh `subscribe()`) always reflects the final post-fill `world_size`, never `World`'s exported default, at any point after `Game._ready()` completes.
- [x] AC-04 *(updated)*: The `TileMapLayer` is filled such that every cell within the world bounds is painted, and no cell outside the bounds is — verified via `TileMapLayer.set_cells_terrain_connect`'s terrain-based resolution rather than asserting specific atlas coordinates (which no longer applies now that tile selection is delegated to the `TileSet`'s terrain data; see FR-03 update).
- [x] AC-05: `ActivityManager` no longer has a `level_seed` `@export` that self-resolves from `GameEvents.next_level_seed`/`randi()`; it starts running (schedules its first activity) only after `RoundInitializer` has completed seed/size/tile-fill and explicitly calls into it.
- [x] AC-06: Existing "Retry"/"New Seed" flows in `SummaryScreen`/`Game` continue to work end-to-end (full scene reload, correct seed staged) with no behavior regression.
- [x] AC-07: Existing tests covering `ActivityManager`'s prior seed-resolution behavior are updated to reflect the moved responsibility (either moved to a new `round_initializer_test.gd` or adjusted to test the new injection point), and pass under GUT.

## Technical Scope

### Affected Modules
- `scenes/world/world.gd` / `scenes/world/world.tscn` — remove self-emission of `world_size_changed`/`world_loaded` from `_ready()` on the default size; add a `fill_tiles(rng: RandomNumberGenerator, tile_bounds: Vector2i)` method that paints the `TileMapLayer` (clearing any pre-existing hand-authored data first) using the 3×3 border/corner/center block described in FR-03.
- `components/activities/activity_manager.gd` — remove `level_seed` self-resolution and the `GameEvents.world_loaded.subscribe(func(_v): start())` line; accept seed/RNG injection and an explicit external `start()` call.
- `scenes/game.tscn` / `scenes/game.gd` — add `RoundInitializer` as a new static child node, wired to `World`, `TileMapLayer`, and `ActivityManager` via `@export`/`NodePath`, matching the existing `ActivityManager` wiring style.
- `components/events/game_events.gd` — no structural change expected (still consumes `next_level_seed`, still emits `world_size_changed`/`world_loaded`), but sequencing of who emits when changes.

### New Components Required
- `components/round/round_initializer.gd` (new category `components/round/`, following the `components/<category>/` convention) — `class_name RoundInitializer`, likely `extends Node`, owning the seeded `RandomNumberGenerator`, exported refs to `World` and `ActivityManager` (no direct `TileMapLayer` reference — it calls `World.fill_tiles(...)` instead).
- `World.fill_tiles(rng, tile_bounds)` on the existing `World` script, implementing the 3×3 border/corner/center placement logic described in FR-03 against its own child `TileMapLayer`.

### Integration Points
- `GameEvents` autoload (`world_size_changed`, `world_loaded`, `next_level_seed`) — existing integration point, sequencing changes only.
- `ActivityManager`'s existing `Activity` execution contract (`execute(rng, world_size, spawn_parent)`) is unaffected — activities still receive `world.world_size` and the seeded `rng`, just sourced/injected differently.
- `Camera2D`'s clamp-to-world-edges logic (reads `World.world_size` via `world_size_changed`) is a downstream consumer that must continue to receive the correct final size — covered by FR-04/AC-03.

## Non-Functional Requirements
- Performance: tile fill must complete synchronously within `Game._ready()`'s startup sequence for world sizes up to the configured max (e.g. 32×32 tiles = 1024 cells) without introducing a visible startup stall; no async/threaded fill required for this scope.
- Security: not applicable (client-side game, no external input).
- Scalability: not applicable beyond the configured max world-size tunables.

## Out of Scope
- Multiple terrain "kinds" or weighted random tile variety within the fill (explicitly deferred — this version places a fixed tile per cell based on border/corner/center position only, per the user's chosen scope).
- In-place round reset without a full scene reload — `Game` continues to use `get_tree().reload_current_scene()`.
- Any change to how `Activity` subclasses (`BossActivity`, `ItemDropActivity`) consume `world_size`/`rng` — their contract is unchanged.
- Obstacles, terrain collision, or gameplay-affecting tile types — the tile fill in this feature is purely visual/ground-cover.
- Changing `next_level_seed`'s type/shape or the Retry-vs-New-Seed UX in `SummaryScreen`.

## Open Questions
- Whether `ActivityManager` should receive a raw `level_seed: int` or the shared `RandomNumberGenerator` instance directly from `RoundInitializer` — passing the RNG instance avoids re-seeding a second generator and keeps a single seeded stream consistent with the project's "one RNG threaded explicitly" architecture decision (2026-08-05), so this is the likely direction, but worth confirming in `/sdd-plan`.
- How "screen size" is read at `RoundInitializer._ready()` time (e.g. `get_viewport().get_visible_rect().size` vs. `DisplayServer.window_get_size()`) — left to `/sdd-plan` to pick the call that correctly reflects the actual game viewport in both editor and exported builds.
