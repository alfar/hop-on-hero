## Implementation Complete

> **Post-implementation update (2026-08-08):** `World.fill_tiles`'s tile-placement approach changed after this summary was written. See the note appended under Notes below.

### Files Created
- `components/round/round_initializer.gd` — new `RoundInitializer` node: resolves seed, picks 64px-stepped world size, calls `World.fill_tiles`, emits `world_size_changed`/`world_loaded`, injects `rng` into and starts `ActivityManager`.
- `test/unit/round/round_initializer_test.gd` — seed resolution, world size bounds/multiple-of-64, seed-determinism tests.
- `test/unit/round/world_fill_tiles_test.gd` — corner/edge/interior tile placement, clear-before-fill tests.
- `test/integration/round/round_initializer_integration_test.gd` — end-to-end `world_size_changed` cached-value correctness (AC-03).

### Files Modified
- `scenes/world/world.gd` — removed self-emitting `_ready()`; added public `fill_tiles(rng, tile_bounds)` (originally painted a manual 3×3 border/corner/center atlas block; see post-implementation update below) via `@onready` `TileMapLayer` reference.
- `scenes/world/world.tscn` — pre-existing hand-authored `tile_map_data` (decorative path) removed (done by user before implementation started).
- `components/activities/activity_manager.gd` — removed `level_seed` export/self-resolution and `world_loaded` self-subscription; added plain injected `rng` var; `start()` now purely externally invoked.
- `scenes/game.tscn` — added `RoundInitializer` node (after `ActivityManager`), wired to `World`/`ActivityManager` via `NodePath`s; added its script `ext_resource`.
- `scenes/game.gd` — `_on_retry_pressed()` now reads `$RoundInitializer.level_seed` instead of `$ActivityManager.level_seed`.
- `test/unit/activities/activity_manager_test.gd` — old seed-resolution tests replaced with a single test exercising `start()` via injected `rng`.
- `test/integration/game/round_end_test.gd` — `test_retry_stages_the_same_seed` reads `RoundInitializer.level_seed` instead of `ActivityManager.level_seed`.

### Acceptance Criteria
- [x] AC-01: Passed — `round_initializer_test.gd#test_world_size_is_multiple_of_64_within_bounds`, `#test_falls_back_to_randomize_when_next_level_seed_is_unset`
- [x] AC-02: Passed — `round_initializer_test.gd#test_same_seed_produces_same_world_size`
- [x] AC-03: Passed — `round_initializer_integration_test.gd#test_world_size_changed_reflects_final_post_fill_size`
- [x] AC-04: Passed — `world_fill_tiles_test.gd#test_fill_tiles_paints_every_cell_within_bounds`, `#test_fill_tiles_does_not_paint_outside_bounds` (updated post-implementation, see Notes)
- [x] AC-05: Passed (structural) — `level_seed`/self-subscribe removed from `activity_manager.gd`; verified via `round_initializer_test.gd` + `activity_manager_test.gd`
- [x] AC-06: Passed — `round_end_test.gd#test_retry_stages_the_same_seed`, `#test_new_seed_stages_zero`
- [x] AC-07: Passed — full GUT suite: 108/109 passing (1 pre-existing, unrelated `item_pickup_test.gd` failure confirmed present on unmodified `main` via `git stash`)

### Notes
- `_ready()` ordering: confirmed (researched Godot 4 engine semantics) that static scene-tree siblings run `_ready()` in declaration order within the same synchronous pass — `RoundInitializer` placed after `ActivityManager` in `game.tscn` means `ActivityManager`'s `Timer` child always exists before `RoundInitializer` calls `start()`. No defensive `await` needed.
- Bare `World.new()`/`TileMapLayer.new()` test fixtures required explicitly setting `tile_map_layer.name = "TileMapLayer"` — Godot's default constructor name (`@TileMapLayer@N`) doesn't satisfy `$TileMapLayer` lookups, which was the source of several early test failures.
- `rng` parameter on `World.fill_tiles` is accepted but currently unused (placement is fully position-determined) — kept for forward-compatibility per FR-03, with a comment explaining why.
- Pre-existing `item_pickup_test.gd` failure is unrelated to this feature (verified against unmodified `main`) and left untouched, per scope. It was fixed in a follow-up (see below) once identified as a `world_size_changed`-related test ordering issue.

### Post-Implementation Update (2026-08-08)
- Fixed `item_pickup_test.gd`: added a `before_each()` emitting a large `GameEvents.world_size_changed` value, since `Player`'s position clamp reads that shared `BehaviorSubject`'s cached value and the test's fixed positions (`Vector2(3000, 2000)` etc.) depended on whatever an earlier, unrelated test happened to leave cached.
- The user authored a proper Godot `Terrain` (terrain set 0, terrain 0) on `world.tscn`'s `TileSet`. `World.fill_tiles` was rewritten to call `TileMapLayer.set_cells_terrain_connect(cells, terrain_set, terrain)` instead of the manual 9-tile atlas-coordinate lookup — Godot now resolves per-cell tile placement from the terrain's peering-bit data. `_atlas_coords_for_cell` was deleted.
- `test/unit/round/world_fill_tiles_test.gd` and `test/unit/round/round_initializer_test.gd` were updated to instantiate the real `res://scenes/world/world.tscn` (terrain resolution needs an actual `TileSet`, which bare `World.new()`/`TileMapLayer.new()` fixtures don't have) rather than asserting hardcoded atlas coordinates.
- Full suite: 110/110 passing after these changes.
