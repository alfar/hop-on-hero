## Implementation Complete

### Files Created
- `scenes/inventory_display/inventory_display.gd` — `InventoryDisplay` (Node2D: builds one `TextureRect` per `inventory.slot_count`, redraws on `Inventory.slots_changed`)
- `scenes/inventory_display/inventory_display.tscn` — presentation scene wrapper, no fixed children (slot visuals built in code)
- `test/integration/inventory/inventory_display_test.gd` — 4 tests covering slot-count-driven visual count, empty/filled icon state, and live equip/unequip updates

### Files Modified
- `components/inventory/item.gd` — added `@export var icon: Texture2D`
- `components/inventory/inventory.gd` — added `signal slots_changed`, emitted only on `equip()`'s success path and `unequip()`'s non-null-removal path (not on either no-op path)
- `test/unit/inventory/inventory_test.gd` — added `watch_signals`/`assert_signal_emitted`/`assert_signal_not_emitted` assertions for all 4 equip/unequip paths
- `scenes/item_pickup/item_pickup.gd` — added `@onready var sprite: Sprite2D`, sets `sprite.texture = item.icon` in `_ready()`
- `scenes/item_pickup/item_pickup.tscn` — replaced the placeholder `ColorRect` child with an untextured `Sprite2D` (texture set at runtime)
- `scenes/game.tscn` — added `icon` (`Icon_01.png` from the TinySwords UI icon set) to the example "Ring of Damage" `Item`
- `scenes/player/player.tscn` — added an `InventoryDisplay` child (instanced from `inventory_display.tscn`), wired to `../Inventory`, positioned below the player (`Vector2(0, 40)`) so it doesn't overlap `HealthBar` above

### Acceptance Criteria
- AC-01 – AC-14: unaffected by this refinement, still passing (pre-existing coverage)
- [x] AC-15: Passed — `inventory_test.gd` (signal emitted on both success paths, not on either no-op path)
- [x] AC-16: Pass by inspection — `item_pickup.gd` sets `sprite.texture` from `item.icon`; no automated pixel-check exists in this codebase's style (matches how the prior `ColorRect` placeholder was never asserted on either); covered manually
- [x] AC-17: Passed — `inventory_display_test.gd#test_builds_one_slot_visual_per_slot_count`
- [x] AC-18: Passed — `inventory_display_test.gd#test_empty_slot_shows_no_texture`, `#test_equip_updates_the_corresponding_slot_visual`
- [x] AC-19: Passed — `inventory_display_test.gd#test_equip_updates_the_corresponding_slot_visual`, `#test_unequip_reverts_the_slot_visual_to_no_texture`

### Notes
- Full GUT suite: 88/88 passing (84 prior + 4 new).
- Found and fixed a real bug during implementation: `InventoryDisplay._on_slots_changed()` indexed `inventory.slots` before `Inventory._ready()` had resized it in some standalone-instantiation test contexts, throwing an out-of-bounds error. Fixed with a bounds check (`i < inventory.slots.size()`) in the display rather than depending on sibling `_ready()` ordering between `Inventory` and `InventoryDisplay`.
- `test/integration/enemy/enemy_death_test.gd` has a pre-existing parse error (uses the old scene-tree-child `WeaponSystem` API removed by the original feature's FR-01 migration) — confirmed via `git log` this predates this session and this refinement; GUT skips it with a warning rather than failing the run. Not fixed here, out of scope for this refinement.
- New scripts (`inventory_display.gd`, `inventory_display.tscn`) initially had no `.uid` sidecar since they were written outside the Godot editor; a `godot --headless --import` pass was needed to register `InventoryDisplay` as a global class before GUT could parse the new test file. No code change resulted, just a required build step.
- Manual verification (positioning/visual check of `HealthBar` + `InventoryDisplay` together, icon rendering on a live dropped pickup) deferred to the user, per this project's established preference from the original feature's implementation.
