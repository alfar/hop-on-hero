# Code Review: Round Initializer

> **Post-review update (2026-08-08):** `World.fill_tiles`'s implementation changed after this review (manual 9-tile atlas lookup → `TileMapLayer.set_cells_terrain_connect` against a user-authored `Terrain`). This review's findings below still reflect the code as it stood at review time; see `impl-summary.md`'s "Post-Implementation Update" section for what actually shipped.

## Summary
The implementation matches `plan.md` closely and all 7 acceptance criteria have direct test coverage that passes (109/109 in the full GUT suite). The seed/size/tile-fill/activity-start sequencing is correct and relies on a verified Godot `_ready()` ordering guarantee rather than a fragile `await`. A few minor issues remain: an unused private `rng` alias pattern in `ActivityManager` versus the plan's stated intent, no guard against `RoundInitializer` running with a zero-sized `tile_bounds` if `MAX_WORLD_SIZE_PX`/`TILE_SIZE` are ever misconfigured, and test-fixture duplication (`_make_world()` reimplemented three times) that could be a small shared test helper. Nothing here blocks merging.

## Findings

### 🔴 Critical

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|

### 🟠 Major

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|

### 🟡 Minor

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [ ] | `components/round/round_initializer.gd:22` | Design | `world.fill_tiles(_rng, ...)` and `activity_manager.rng = _rng` share one `RandomNumberGenerator` instance, so any future activity execution that runs synchronously before `fill_tiles` finishes iterating (not currently possible, but not structurally prevented) would silently perturb tile-fill determinism. | Add a one-line comment on `_rng`'s declaration stating it must not be read from at the same call-stack depth by two different features simultaneously, to make the shared-instance contract explicit for the next person extending this file. |
| [ ] | `test/unit/round/round_initializer_test.gd:8-13`, `test/unit/round/world_fill_tiles_test.gd:3-8`, `test/unit/activities/activity_manager_test.gd:9-13` | Code Duplication | The `_make_world()` helper (construct a bare `World`, add a `TileMapLayer` child explicitly named `"TileMapLayer"`) is copy-pasted identically across three test files. | Extract a shared `test/unit/round/world_test_helpers.gd`-style static helper (matching the existing `WeaponTestHelpers` precedent used elsewhere in the suite) so the `$TileMapLayer`-name gotcha is fixed in one place. |
| [ ] | `components/round/round_initializer.gd:49-53` | Edge Case | `_pick_axis_size` never validates that `TILE_SIZE`/`MAX_WORLD_SIZE_PX` produce `max_tiles >= 1`; if `MAX_WORLD_SIZE_PX` were ever misconfigured below `TILE_SIZE`, `floori(...)` could yield `0`, making `_rng.randi_range(min_tiles, 0)` misbehave when `min_tiles > 0`. | Not urgent given both constants are fixed literals today, but worth a `push_error`/assert if these ever become `@export`-configurable. |
| [ ] | `test/integration/inventory/item_pickup_test.gd:8-9` | Test Quality | `before_each()` emits a real `GameEvents.world_size_changed` value as a workaround for cross-test shared `BehaviorSubject` state, which is a correct fix but means this test file now has an implicit, easy-to-miss dependency on `Player`'s clamp behavior rather than testing pickup logic in isolation. | Consider a short comment cross-referencing this pattern in `docs/project.md`'s "Architecture Decisions" table, since this is the second place (after `next_level_seed` resets) where a shared `GameEvents` autoload leaks test-to-test and needed a workaround — worth flagging as a recurring theme for future test authors. |

### 🔵 Info / Suggestions

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [ ] | `components/round/round_initializer.gd:34` | Observability | `print("RoundInitializer seed: ", level_seed)` matches the prior `ActivityManager` convention exactly, but the project has no structured logging layer, so this remains debug-console-only output with no log level distinction. | No action needed — consistent with existing codebase convention; flagging only for awareness if a logging framework is ever introduced. |
| [ ] | `components/round/round_initializer.gd:13` | Style | `level_seed` is documented as "exposed so Game can stage the same seed again on Retry," but the doc comment doesn't mention it also mirrors the pre-existing `ActivityManager.level_seed` contract that `round_end_test.gd` depends on. | Optional: mention the test dependency in the comment for future maintainers moving this field again. |
| [ ] | `scenes/world/world.gd:13` | Style | The `_rng` parameter of `fill_tiles` is prefixed with `_` (unused-by-convention) but still typed and documented as intentionally-unused-for-now; this is a slightly unusual pattern (an underscore-prefixed *public API* parameter). | Consider whether a future consumer reading the public method signature might find `_rng` confusing compared to Godot's usual meaning of `_`-prefix (silence "unused parameter" warnings on internal/private methods) — current inline comment already explains this well, so this is a non-blocking style note only. |

## Acceptance Criteria Coverage
| AC | Test | Status |
|----|------|--------|
| AC-01: random world_size, multiple of 64, screen/1600-bounded, seed printed on fallback | `round_initializer_test.gd#test_world_size_is_multiple_of_64_within_bounds`, `#test_falls_back_to_randomize_when_next_level_seed_is_unset` | ✅ Covered |
| AC-02: same seed → same world_size and tile fill across reloads | `round_initializer_test.gd#test_same_seed_produces_same_world_size` | ✅ Covered |
| AC-03: world_size_changed's cached value always reflects final post-fill size | `round_initializer_integration_test.gd#test_world_size_changed_reflects_final_post_fill_size` | ✅ Covered |
| AC-04: corners/edges/interior painted per the 3×3 atlas block *(superseded post-review — see impl-summary.md)* | `world_fill_tiles_test.gd#test_fill_tiles_paints_every_cell_within_bounds`, `#test_fill_tiles_does_not_paint_outside_bounds` | ✅ Covered |
| AC-05: ActivityManager has no self-resolving level_seed; starts only via RoundInitializer | `activity_manager_test.gd#test_start_triggers_first_activity_using_injected_rng` (structural: `level_seed`/self-subscribe removed from source) | ✅ Covered |
| AC-06: Retry/New Seed continue to work end-to-end | `round_end_test.gd#test_retry_stages_the_same_seed`, `#test_new_seed_stages_zero` | ✅ Covered |
| AC-07: existing seed-resolution tests updated/moved and pass under GUT | Full GUT suite: 109/109 passing | ✅ Covered |

## Verdict
- [x] ✅ Ready to merge
- [ ] 🟡 Merge after minor fixes (no re-review needed)
- [ ] 🟠 Requires fixes and re-review
- [ ] 🔴 Do not merge — significant issues found
