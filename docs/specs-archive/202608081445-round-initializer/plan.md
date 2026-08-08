# Implementation Plan: Round Initializer

## Overview
Add a new `RoundInitializer` node (`components/round/round_initializer.gd`), instanced as a static child of `Game` in `game.tscn`, ordered before `ActivityManager`. It becomes the single place that: resolves the round's seed (moved off `ActivityManager`), owns the seeded `RandomNumberGenerator`, computes a random `world_size` in 64×64 increments bounded by screen-size-minimum/1600-maximum, calls a new `World.fill_tiles(rng, tile_bounds)` method to paint the `TileMapLayer`, emits `GameEvents.world_size_changed`/`world_loaded` once sizing+filling are done, and finally calls `ActivityManager.start()` explicitly. `World` and `ActivityManager` both shed responsibilities they currently self-manage (`World` stops self-emitting on `_ready()`; `ActivityManager` stops self-resolving `level_seed` and stops self-subscribing to `world_loaded`), becoming callees driven by `RoundInitializer` instead. No change to the scene-reload-based round-reset mechanism — `RoundInitializer` re-runs its full sequence naturally on every reload, the same way `ActivityManager` does today.

> **Post-implementation update (2026-08-08):** Step 1 as originally planned (below) implemented `fill_tiles` via a manual 9-tile atlas-coordinate lookup table. Shortly after implementation, the user authored a proper Godot `Terrain` on the `TileSet` in `world.tscn`, and `fill_tiles` was revised to use `TileMapLayer.set_cells_terrain_connect` instead, letting Godot resolve tile placement from the terrain data. See the note under Step 1 for the actual final implementation.

## Architecture Decisions
- **`RoundInitializer` owns the round's single `RandomNumberGenerator`** and hands the same instance to `ActivityManager` (not a raw `level_seed: int`) — keeps one seeded stream threaded through explicitly, consistent with the existing 2026-08-05 architecture decision ("any system needing deterministic randomness must seed a single `RandomNumberGenerator`... and thread it explicitly").
- **`World.fill_tiles(rng, tile_bounds)` is a public method on `World`**, not logic living inside `RoundInitializer` reaching into `World`'s `TileMapLayer` child directly — keeps `World` self-contained (existing convention: `World` owns and encapsulates its `TileMapLayer`).
- **`World` no longer emits anything from `_ready()`.** `RoundInitializer` sets `world.world_size`, calls `world.fill_tiles(...)`, then emits `GameEvents.world_size_changed`/`world_loaded` itself. This mirrors the existing pattern where `GameEvents` is the cross-cutting broadcast point, not individual nodes reaching into each other.
- **`ActivityManager.start()` becomes an externally-invoked public method**, no longer self-triggered via `GameEvents.world_loaded.subscribe`. `ActivityManager` also drops its `level_seed` `@export`/self-resolution entirely; it receives the shared `RandomNumberGenerator` via a new `@export`-free public method/property set by `RoundInitializer` before `start()` is called (a plain `var rng: RandomNumberGenerator` assigned directly, not `@export`, since it's runtime-injected — same rationale as the existing `ChasePlayerMovementBehavior.player` precedent noted in `docs/project.md`'s architecture decisions: a `Resource` can't `@export` a `Node`, and even for `Node`-to-`Node` runtime injection here, a plain settable var avoids requiring editor wiring for a value that's only ever set programmatically).
- **Tile fill logic lives in `world.gd`** (`TileMapLayer.clear()` first to remove the existing hand-authored decorative path data). *Originally planned* as a nested-loop classifying each cell as corner/edge/interior and calling `TileMapLayer.set_cell(coords, source_id, atlas_coords)` against 9 hardcoded atlas alternatives; *actually implemented* (post-implementation update, 2026-08-08) as a call to `TileMapLayer.set_cells_terrain_connect(cells, terrain_set, terrain)` against a proper Godot `Terrain` the user authored on the `TileSet`, letting Godot resolve tile placement from terrain peering-bit data instead.
- **Screen size is read via `get_viewport().get_visible_rect().size`** inside `RoundInitializer._ready()` — the standard Godot 4 way to get the current viewport's visible size, working consistently in both editor test runs and exported builds (`DisplayServer.window_get_size()` was considered but reflects the OS window, not the render viewport, which is what actually needs to fit on screen).
- **New `components/round/` category**, following the existing `components/<category>/` convention (mirrors `components/activities/`, `components/movement/`, `components/camera/`).

## Implementation Steps

### Step 1: `World.fill_tiles` Method
- [x] Add `fill_tiles(rng: RandomNumberGenerator, tile_bounds: Vector2i) -> void` to `scenes/world/world.gd`.
  - Get the `TileMapLayer` child (add an `@onready var tile_map_layer: TileMapLayer = $TileMapLayer` if not already accessible).
  - Call `tile_map_layer.clear()` first.
  - Loop `x` in `0..<tile_bounds.x`, `y` in `0..<tile_bounds.y`; for each cell determine which of the 9 atlas alternatives to paint:
    - Corners: `(0,0)` → top-left atlas coord `(5,0)`; `(tile_bounds.x-1,0)` → top-right `(7,0)`; `(0,tile_bounds.y-1)` → bottom-left `(5,2)`; `(tile_bounds.x-1,tile_bounds.y-1)` → bottom-right `(7,2)`.
    - Edges (non-corner): `y==0` → top `(6,0)`; `y==tile_bounds.y-1` → bottom `(6,2)`; `x==0` → left `(5,1)`; `x==tile_bounds.x-1` → right `(7,1)`.
    - Interior: center `(6,1)`.
  - Call `tile_map_layer.set_cell(Vector2i(x, y), 0, <atlas_coords>)` (source id `0`, matching `sources/0` in `world.tscn`).
  - The `rng` parameter is accepted now (per FR-03's forward-compatibility note) but unused in this version's placement logic — no `rng.randi()`/`randf()` calls needed since placement is fully position-determined; document this with a one-line comment explaining why the parameter exists unused.
  - Remove `world.gd`'s current `_ready()` body (the two `GameEvents.emit(...)` lines) entirely — `World` no longer self-emits.
- [x] Remove the pre-existing hand-authored `tile_map_data` from `scenes/world/world.tscn`'s `TileMapLayer` node (the decorative path) — `fill_tiles`'s `clear()` call makes it dead weight at runtime, and leaving it in the editor risks confusion about what's actually shown at runtime. (If the user wants to preserve it for editor-preview purposes, flag this during implementation rather than deleting silently — default to removing since it will never render as-is once `RoundInitializer` runs.)
- Files: `scenes/world/world.gd`, `scenes/world/world.tscn`

**Update (2026-08-08, post-implementation):** the manual atlas-coordinate lookup above was replaced. The user authored a proper Godot `Terrain` (terrain set 0, terrain 0, `TERRAIN_MODE_MATCH_CORNERS_AND_SIDES`) on `world.tscn`'s `TileSet`, with peering-bit data across all 12 tile variants. `fill_tiles` now:
  - Calls `_tile_map_layer.clear()`.
  - Builds a flat `Array[Vector2i]` of every cell in `tile_bounds`.
  - Calls `_tile_map_layer.set_cells_terrain_connect(cells, TERRAIN_SET, TERRAIN)` (both constants `0`), letting Godot resolve the correct corner/edge/interior tile per cell from the terrain data.
  - `_atlas_coords_for_cell` and the manual corner/edge/interior branching were deleted entirely — no longer needed.
  - Tests in `test/unit/round/world_fill_tiles_test.gd` were changed from asserting specific hardcoded atlas coordinates to instancing the real `world.tscn` (needed since terrain resolution requires an actual `TileSet` — a bare `TileMapLayer.new()` has none) and asserting every cell within bounds is painted (`get_cell_source_id != -1`) and nothing outside bounds is.

### Step 2: `ActivityManager` Sheds Self-Seeding and Self-Starting
- [x] Remove `@export var level_seed: int = 0` from `components/activities/activity_manager.gd`; replace with a plain `var rng: RandomNumberGenerator` (not exported — runtime-injected by `RoundInitializer`).
- [x] Remove the seed-resolution block from `_ready()` (`GameEvents.next_level_seed` check, `randi()` fallback, `print`, `_rng.seed = level_seed`) — this logic moves to `RoundInitializer` (Step 3).
- [x] Remove `GameEvents.world_loaded.subscribe(func(_v): start())` from `_ready()` — `start()` becomes purely externally invoked.
- [x] Keep `_ready()` responsible only for constructing/adding the internal `Timer` and connecting `timeout`; `start()` remains public and unchanged in behavior (`_trigger_next_activity()` still reads `_rng`, now sourced from the injected `rng` var instead of a self-owned one seeded from `level_seed`).
- [x] Rename the private `_rng` field usage to use the injected `rng` var directly (or keep `_rng` as an internal alias set from the injected `rng` in `_ready()`/`start()` — implementer's choice, but the injected value must fully replace the old self-seeded generator).
- Files: `components/activities/activity_manager.gd`

### Step 3: `RoundInitializer` Node
- [x] Create `components/round/round_initializer.gd`:
  ```gdscript
  class_name RoundInitializer
  extends Node

  @export var world: World
  @export var activity_manager: ActivityManager
  @export var min_world_size_px: float = 1600.0  # fallback if larger than screen; see _resolve axis logic
  @export var max_world_size_px: float = 1600.0
  const TILE_SIZE := 64

  var rng := RandomNumberGenerator.new()

  func _ready() -> void:
      _resolve_seed()
      var size := _pick_world_size()
      world.world_size = size
      world.fill_tiles(rng, Vector2i(size.x / TILE_SIZE, size.y / TILE_SIZE))
      GameEvents.world_size_changed.emit(size)
      GameEvents.world_loaded.emit(true)
      activity_manager.rng = rng
      activity_manager.start()

  func _resolve_seed() -> void:
      var seed_value := GameEvents.next_level_seed
      if seed_value == 0:
          seed_value = randi()
          print("RoundInitializer seed: ", seed_value)
      rng.seed = seed_value

  func _pick_world_size() -> Vector2:
      var screen_size := get_viewport().get_visible_rect().size
      return Vector2(
          _pick_axis_size(screen_size.x),
          _pick_axis_size(screen_size.y)
      )

  func _pick_axis_size(screen_axis_size: float) -> float:
      var min_tiles := ceili(screen_axis_size / TILE_SIZE)
      var max_tiles := floori(max_world_size_px / TILE_SIZE)
      if min_tiles > max_tiles:
          max_tiles = min_tiles
      return rng.randi_range(min_tiles, max_tiles) * TILE_SIZE
  ```
  (Exact field/method names may be adjusted slightly during implementation, but the sequencing — resolve seed, size world, fill tiles, emit events, inject rng into ActivityManager, start ActivityManager — must be preserved exactly in this order, per FR-04/FR-05.)
- [x] Note: `level_seed` as an externally-readable value (used today by `Game.stage_next_seed($ActivityManager.level_seed)` and by `round_end_test.gd`'s `activity_manager.level_seed`) must still be readable from somewhere — expose it as `RoundInitializer.level_seed` (a `var` set alongside `rng.seed` in `_resolve_seed()`) so `Game`/tests can read `$RoundInitializer.level_seed` instead of `$ActivityManager.level_seed`. Add this field to the script above.
- Files: `components/round/round_initializer.gd` (new)

### Step 4: Wire `RoundInitializer` into `game.tscn`
- [x] Add `RoundInitializer` as a new child node of `Game` in `scenes/game.tscn`, positioned before `ActivityManager` in the node list (Godot doesn't guarantee `_ready()` order strictly by tree order across siblings for cross-references, so this is for readability — the actual ordering guarantee comes from `RoundInitializer._ready()` explicitly driving `ActivityManager.start()`, not from `_ready()` call order).
- [x] Wire its `@export var world: World` to `NodePath("../World")` and `@export var activity_manager: ActivityManager` to `NodePath("../ActivityManager")`, matching `ActivityManager`'s existing `NodePath("../World")` wiring style.
- [x] Update `Game.gd`'s `_on_retry_pressed()`: change `stage_next_seed($ActivityManager.level_seed)` to `stage_next_seed($RoundInitializer.level_seed)`.
- Files: `scenes/game.tscn`, `scenes/game.gd`

### Step 5: Update Existing Tests for Moved Responsibilities
- [x] `test/unit/activities/activity_manager_test.gd`: remove `test_uses_next_level_seed_when_set` and `test_falls_back_to_randomize_when_next_level_seed_is_unset` (this behavior no longer exists on `ActivityManager`) — replace with a `test/unit/round/round_initializer_test.gd` covering the same two cases against `RoundInitializer.level_seed`/`rng.seed` instead (see Step 6).
- [x] `test/integration/game/round_end_test.gd`: update `test_retry_stages_the_same_seed` to read `game.get_node("RoundInitializer").level_seed` instead of `game.get_node("ActivityManager").level_seed`.
- [x] `test/integration/weapon/game_scene_wiring_test.gd`: check whether it reads `activity_manager.world.world_size` before or after a manual `RoundInitializer`-equivalent setup step; since `world.world_size` is no longer meaningful until `RoundInitializer._ready()` has run, confirm this test (which instances `game.tscn` via the existing `add_child_autofree` + `wait_physics_frames(1)` idiom) still gets a fully-initialized `world_size` by the time it runs its assertions — adjust only if it currently assumed `World`'s static export default.
- Files: `test/unit/activities/activity_manager_test.gd`, `test/integration/game/round_end_test.gd`, `test/integration/weapon/game_scene_wiring_test.gd`

### Step 6: New Tests for `RoundInitializer`
- [x] `test/unit/round/round_initializer_test.gd` (new, mirrors `components/round/` per convention):
  - `test_uses_next_level_seed_when_set`: set `GameEvents.next_level_seed = 12345`, instance a `RoundInitializer` with `world`/`activity_manager` stubbed (lightweight `World.new()`/`ActivityManager.new()` added via `add_child_autofree`, matching the existing bare-node instancing idiom from `activity_manager_test.gd`), assert `round_initializer.level_seed == 12345`.
  - `test_falls_back_to_randomize_when_next_level_seed_is_unset`: set `GameEvents.next_level_seed = 0`, assert `round_initializer.level_seed != 0`.
  - `test_world_size_is_multiple_of_64_within_bounds`: force a known seed, assert `fmod(world.world_size.x, 64) == 0` and `fmod(world.world_size.y, 64) == 0`, and that both axes fall within `[min_tiles*64, 1600]` (or the screen-size-collapsed range).
  - `test_same_seed_produces_same_world_size`: instance two `RoundInitializer`s with the same staged seed, assert identical resulting `world.world_size`.
  - `after_each()`: reset `GameEvents.next_level_seed = 0` (matching existing convention in every test file that touches this autoload var).
- [x] `test/unit/round/world_fill_tiles_test.gd` (or fold into the above — implementer's choice), covering `World.fill_tiles`:
  - Instance a bare `World` (`World.new()`, `add_child_autofree`), call `fill_tiles(rng, Vector2i(5, 4))` (a small deterministic bound), then assert via `tile_map_layer.get_cell_atlas_coords(...)` that the four corners, edge cells, and at least one interior cell match the expected atlas coordinates from Step 1.
- [x] `test/integration/game/round_end_test.gd` or a new `test/integration/round/` test: verify end-to-end that loading `game.tscn` results in `GameEvents.world_size_changed`'s cached value (`get_value()`) matching `world.world_size` exactly (guards against AC-03 — the BehaviorSubject must never be caught holding `World`'s stale export default).
- Files: `test/unit/round/round_initializer_test.gd` (new), `test/unit/round/world_fill_tiles_test.gd` (new), possibly `test/integration/round/round_initializer_integration_test.gd` (new)

## Acceptance Criteria Mapping
| AC | Verified By |
|----|-------------|
| AC-01: random world_size, multiple of 64, within screen/1600 bounds, seed printed on fallback | `round_initializer_test.gd#test_world_size_is_multiple_of_64_within_bounds`, `#test_falls_back_to_randomize_when_next_level_seed_is_unset` |
| AC-02: same seed → same world_size and tile fill across reloads | `round_initializer_test.gd#test_same_seed_produces_same_world_size`; tile-fill determinism follows structurally since placement is position-only (no rng branching) per Step 1 |
| AC-03: world_size_changed's cached value always reflects final post-fill size | `round_initializer_integration_test.gd` (new end-to-end check on `GameEvents.world_size_changed.get_value()`) |
| AC-04 *(updated)*: every cell within bounds painted via the TileSet's terrain, none outside | `world_fill_tiles_test.gd#test_fill_tiles_paints_every_cell_within_bounds`, `#test_fill_tiles_does_not_paint_outside_bounds` |
| AC-05: ActivityManager has no self-resolving level_seed; starts only after RoundInitializer completes and calls into it | `activity_manager_test.gd` (old seed tests removed), structurally verified by Step 2's removal + `round_initializer_test.gd` exercising the injected-rng path |
| AC-06: Retry/New Seed continue to work end-to-end | `round_end_test.gd#test_retry_stages_the_same_seed` (updated), `#test_new_seed_stages_zero` (unchanged) |
| AC-07: existing seed-resolution tests updated/moved and pass under GUT | Step 5 (test file updates) + Step 6 (new test files) — verified by running the full GUT suite after implementation |

## Risks & Mitigations
- **Risk**: Removing `World._ready()`'s self-emission could break any other late subscriber (besides `ActivityManager`/`CameraBounds`) that assumed `world_size_changed`/`world_loaded` fire unconditionally on `World`'s own readiness, independent of `RoundInitializer` existing in the scene tree. → **Mitigation**: grep for all `GameEvents.world_size_changed`/`world_loaded` subscribers before removing (`components/camera/camera_bounds.gd` and `components/activities/activity_manager.gd` are the only two found in this planning pass); re-verify no others exist during implementation, and ensure any standalone `World.tscn` instancing in tests that doesn't also instance a `RoundInitializer` is updated to call `fill_tiles`/emit manually if it needs those signals.
- **Risk**: `ActivityManager`'s `Timer` child is still constructed in its own `_ready()`, but `start()` is now called externally from `RoundInitializer._ready()` — if node `_ready()` ordering ever put `RoundInitializer` before `ActivityManager` in a way that calls `start()` before `ActivityManager._ready()` has run (i.e., before its `Timer` exists), `_trigger_next_activity()` would crash on a null `_timer`. → **Mitigation**: Godot guarantees all siblings' `_ready()` calls complete (bottom-up, then parent) before any sibling's post-ready code (like a manually-invoked method from another node) runs in response to input/frame processing — but `RoundInitializer._ready()` calling `activity_manager.start()` directly *during the ready phase* could race if `ActivityManager`'s own `_ready()` hasn't run yet depending on tree order. Mitigate by having `RoundInitializer` wait one frame (`await get_tree().process_frame`) before calling `start()`, or — more robustly — building the `Timer` in `ActivityManager`'s constructor path lazily inside `start()` itself rather than relying on `_ready()` order. Confirm actual Godot `_ready()` ordering semantics (children-first, depth-first, sibling order = scene tree order) during implementation and add an explicit safeguard if needed.
- **Risk**: Deleting the existing hand-authored decorative `tile_map_data` from `world.tscn` is a one-way content loss if that data was intentionally curated art rather than a placeholder. → **Mitigation**: flag explicitly to the user during implementation before deleting (per Step 1's note) rather than assuming it's dead weight.
- **Risk**: `min_world_size_px`/`max_world_size_px` as flat floats don't obviously express "screen size" as the real minimum (screen size isn't a fixed constant, it's computed at runtime) — a naive reading of the exported fields could mislead a future editor user into thinking 1600 is always both bounds. → **Mitigation**: name the exported max field clearly (`max_world_size_px`) and document via a code comment that the effective minimum is always `max(screen_size, this value)`'s inverse — i.e., screen size always wins as the floor; consider dropping the min export entirely since FR-02 defines it as always-screen-size, not tunable.

## Estimated Complexity
**Medium.** No new external dependencies, no data/schema layer, and the seeding/RNG-threading pattern is already well-established in this codebase (`ActivityManager`/`Activity` precedent) — most of the complexity is in getting the `_ready()`-ordering handoff between `RoundInitializer` and `ActivityManager` correct (see Risks) and in the tile-fill loop being genuinely new, unprecedented territory (no existing `TileMapLayer` scripting in the codebase to follow). Test coverage is straightforward given strong existing conventions to mirror (`activity_manager_test.gd`, `round_end_test.gd`).
