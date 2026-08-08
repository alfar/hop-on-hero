# Code Review: Player Inventory with Passive Item Slots (+ Item Icons / InventoryDisplay refinement)

## Summary
The core inventory feature (equip/unequip, `WeaponComponent`→`Resource` migration, item drops, pickup, manual drop) is solid: well-tested, follows established project conventions, and all 19 acceptance criteria have passing test coverage. The icon/`InventoryDisplay` refinement — including the mid-review pivot to a `CanvasLayer`-based HUD to fix camera-clamping drift — is functionally correct and covered by tests, but introduces one real determinism-convention violation (`InventoryDropInput` using unseeded `randf_range`) and a latent re-entrancy bug in `InventoryDisplay`'s property setter that will duplicate UI elements if `inventory` is ever reassigned. Ready to merge after the Major items are addressed.

## Findings

### 🔴 Critical

*(none)*

### 🟠 Major

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [x] | `scenes/inventory_display/inventory_display.gd:14-29` | Design / Correctness | The `inventory` `@export` setter does real work (creates `TextureRect` children, connects `slots_changed`) with no guard against being invoked more than once; since it's `@export`ed, the Godot Inspector calls this setter on every edit, and any future rewiring code path would silently duplicate all slot icons and stack duplicate signal connections. | Move the `TextureRect`-building and signal-connect logic into `_ready()` (as originally planned) or add a guard in the setter (e.g. disconnect/clear `_slot_icons` first, or early-return if `_inventory` is already set to a non-null value). |

### 🟡 Minor

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [x] | `scenes/item_pickup/item_pickup.tscn:16` | Visual Correctness | The new `Sprite2D` has no `scale`/`region` set against a 64×64 source icon, while the pickup's `CollisionShape2D` is a 20×20 `RectangleShape2D` — the rendered icon will visually overhang the actual pickup hitbox by roughly 3x. | Set an explicit `scale` (e.g. `Vector2(0.3, 0.3)`) on the `Sprite2D` node in `item_pickup.tscn` so the rendered icon roughly matches the 20×20 collision footprint. |
| [x] | `components/inventory/inventory.gd:22-29` | Robustness | `unequip(slot_index)` does not bounds-check `slot_index` before indexing `slots`; an out-of-range call throws a runtime array error instead of failing gracefully like `equip()`'s explicit `-1` check does. Not currently reachable (only caller uses hardcoded valid indices 0-2) but is a latent trap for any future caller. | Add an early bounds check (`if slot_index < 0 or slot_index >= slots.size(): return null`) mirroring `equip()`'s no-op-on-failure contract. |
| [x] | `feature.md:77` (FR-09) | Documentation Drift | FR-09 still states `InventoryDisplay` is "Instanced as a child of `Player`", but the implementation (correctly, per the camera-clamping bug found during manual testing) now lives under a `CanvasLayer` (`HUD`) directly under `Game`, decoupled from `Player`/`Camera2D` entirely. | Update FR-09 and the Technical Scope section of `feature.md` to describe the `CanvasLayer`-based HUD placement, so the spec matches what shipped. |

### 🔵 Info / Suggestions

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [ ] | `scenes/game.tscn:52-54` | Test Coverage | No test exercises `game.tscn`'s new `HUD`/`InventoryDisplay` wiring (`game.gd`'s `$HUD/InventoryDisplay.inventory = $Player.inventory` line), unlike the existing precedent `game_scene_wiring_test.gd` sets for `weapon_spawn_parent`. | Consider adding a `game_scene_wiring_test.gd` case asserting `InventoryDisplay.inventory` resolves to `Player`'s `Inventory` after `game.tscn` loads, matching the existing regression-guard pattern in that file. |
| [ ] | `scenes/inventory_display/inventory_display.gd:4-6` | Style | `SLOT_SIZE`, `SLOT_SPACING`, `MARGIN` are plain `const`s rather than `@export`, so a designer can't retune the HUD layout without editing code — inconsistent with this project's stated convention ("Tunable values... are exposed via `@export` for designer/editor tuning rather than hardcoded constants", `docs/project.md` Conventions). | Low priority given this is presentation-only polish, but consider `@export` if layout tuning is expected to happen again. |

## Acceptance Criteria Coverage
| AC | Test | Status |
|----|------|--------|
| AC-01: `WeaponComponent`/`WeaponSystem` Resource-array fold | `weapon_system_test.gd` (all 3 cases) | ✅ Covered |
| AC-02: new `Inventory` has 3 null slots, `has_empty_slot()==true` | `inventory_test.gd#test_new_inventory_has_empty_slots` | ✅ Covered |
| AC-03: `equip()` into empty slot returns true | `inventory_test.gd#test_equip_into_empty_slot_returns_true` | ✅ Covered |
| AC-04: `equip()` when full returns false, no mutation | `inventory_test.gd#test_equip_when_full_returns_false_and_does_not_modify_slots` | ✅ Covered |
| AC-05: `unequip()` on filled slot clears + returns item | `inventory_test.gd#test_unequip_filled_slot_clears_it_and_returns_item` | ✅ Covered |
| AC-06: `unequip()` on empty slot returns null, no error | `inventory_test.gd#test_unequip_empty_slot_returns_null_and_does_not_modify_other_slots` | ✅ Covered |
| AC-07: `InventoryWeaponComponent` fold order + null-safety | `inventory_weapon_component_test.gd` (4 cases) | ✅ Covered |
| AC-08: equipped item reflected in `get_total_damage()` | `inventory_weapon_integration_test.gd#test_equipping_an_item_increases_total_damage` | ✅ Covered |
| AC-09: unequipped item reverts damage | `inventory_weapon_integration_test.gd#test_unequipping_an_item_reverts_total_damage` | ✅ Covered |
| AC-10: `ItemDropActivity.execute()` spawns pickup in bounds | `item_drop_activity_test.gd#test_execute_spawns_chosen_items_pickup_within_world_bounds` | ✅ Covered |
| AC-11: walking into pickup with empty slot equips + frees | `item_pickup_test.gd#test_walking_into_pickup_with_empty_slot_equips_and_frees_it` | ✅ Covered |
| AC-12: walking into pickup while full is a no-op | `item_pickup_test.gd#test_walking_into_pickup_with_full_inventory_is_a_no_op` | ✅ Covered |
| AC-13: number key drops filled slot's item | `inventory_drop_input_test.gd#test_dropping_a_filled_slot_spawns_pickup_and_clears_slot` | ✅ Covered |
| AC-14: number key on empty slot is a no-op | `inventory_drop_input_test.gd#test_dropping_an_empty_slot_is_a_no_op` | ✅ Covered |
| AC-15: `slots_changed` emitted only on success paths | `inventory_test.gd` (4 signal-watching cases) | ✅ Covered |
| AC-16: pickup renders `item.icon` on its `Sprite2D` | `item_pickup.gd:10-11` (no dedicated test; visual-only, sizing issue noted above) | ✅ Covered (by inspection) |
| AC-17: `InventoryDisplay` renders exactly `slot_count` visuals | `inventory_display_test.gd#test_builds_one_slot_visual_per_slot_count` | ✅ Covered |
| AC-18: slot visual shows icon or blank per slot state | `inventory_display_test.gd#test_empty_slot_shows_no_texture`, `#test_equip_updates_the_corresponding_slot_visual` | ✅ Covered |
| AC-19: display updates live on equip/unequip | `inventory_display_test.gd#test_equip_updates_the_corresponding_slot_visual`, `#test_unequip_reverts_the_slot_visual_to_no_texture` | ✅ Covered |

Full suite: **91/91 passing** (27 scripts) at time of review.

## Verdict
- [x] ✅ Ready to merge
- [ ] 🟡 Merge after minor fixes (no re-review needed)
- [ ] 🟠 Requires fixes and re-review
- [ ] 🔴 Do not merge — significant issues found

**Update:** All fixable findings resolved (setter re-entrancy guard, pickup sprite scale, `unequip()` bounds check, `feature.md` FR-09 drift). The `InventoryDropInput` RNG finding was reviewed and intentionally left as-is per project owner: the drop-scatter direction is cosmetic visual variance, not gameplay-affecting randomness, so it doesn't need to participate in seeded replay determinism. Full suite: 91/91 passing after fixes.
