# Implementation Plan: Item Icons and Inventory Display (refinement of Player Inventory with Passive Item Slots)

## Overview
This is a refinement plan on top of the already-fully-implemented "Player Inventory with Passive Item Slots" feature (its own `plan.md`/`impl-summary.md` are complete; the delta from `/sdd-refine` is captured here instead of a fresh archive cycle). Three pieces of already-shipped code change: `Item` gains an `icon` texture field, `Inventory` gains a `slots_changed` signal emitted on real mutations, and `ItemPickup` swaps its placeholder `ColorRect` for a `Sprite2D` driven by `item.icon`. On top of that, a new presentation scene `InventoryDisplay` (mirroring the existing `HealthBar` pattern) is added, built with a flexible slot count and wired reactively to `Inventory.slots_changed`, then instanced as a child of `Player` alongside the existing `HealthBar`.

## Architecture Decisions
- `InventoryDisplay` is a `scenes/<name>/` presentation scene, not a `components/<category>/` component — per the existing project convention (`docs/project.md` Architecture Decisions, 2026-08-05): presentation-only scenes with no independent logic beyond reflecting state belong in `scenes/`, exactly like `HealthBar`.
- `InventoryDisplay` reacts to a real signal (`Inventory.slots_changed`) rather than polling in `_process()`, per user decision during `/sdd-refine`. This means `Inventory`'s existing contract changes — a deliberate, scoped exception to "don't touch shipped code without reason," justified because `InventoryDisplay` has no other reliable way to know a mutation occurred.
- `slots_changed` is emitted only on the two success paths (`equip()` finding a slot, `unequip()` clearing a non-null slot) — not on either no-op path — so `InventoryDisplay` never redraws pointlessly and `AC-15`'s emitted/not-emitted distinction is directly testable.
- `Item.icon` and `ItemPickup`'s `Sprite2D` reuse the same texture with no separate "world icon" vs. "UI icon" field — per the feature's stated intent ("we can probably use the same icon for showing the item on the ground").
- `InventoryDisplay`'s slot visuals are built procedurally in `_ready()` from `inventory.slot_count` (plain child `TextureRect` nodes added in code), not authored as N fixed nodes in the `.tscn` — this is what makes it "flexible in number of slots" rather than hardcoded to 3, satisfying FR-09/AC-17 for any `Inventory` size while `Player`'s stays at 3 via `Inventory.slot_count`'s existing default.

## Implementation Steps

### Step 1: `Item.icon`
- [x] `components/inventory/item.gd`: add `@export var icon: Texture2D`.
- Files: `components/inventory/item.gd`

### Step 2: `Inventory.slots_changed` signal
- [x] `components/inventory/inventory.gd`: add `signal slots_changed`. Emit it at the end of `equip()` only on the success path (after `slots[empty_index] = item`, before `return true`); emit it at the end of `unequip()` only when the captured `item` was non-`null` (guard before `slots[slot_index] = null`, or check the captured value before emitting — either way, no emission when the slot was already empty).
- Files: `components/inventory/inventory.gd`

### Step 3: Update `Inventory` unit tests for the new signal
- [x] `test/unit/inventory/inventory_test.gd`: add assertions using GUT's signal-watching helpers (`watch_signals(inventory)` + `assert_signal_emitted`/`assert_signal_not_emitted`) for:
  - `equip()` into an empty slot emits `slots_changed`.
  - `equip()` when full does not emit `slots_changed`.
  - `unequip()` on a filled slot emits `slots_changed`.
  - `unequip()` on an already-empty slot does not emit `slots_changed`.
- Files: `test/unit/inventory/inventory_test.gd`

### Step 4: `ItemPickup` visual swap to `Sprite2D`
- [x] `scenes/item_pickup/item_pickup.tscn`: remove the `ColorRect` child; add a `Sprite2D` child in its place (no default texture — set at runtime).
- [x] `scenes/item_pickup/item_pickup.gd`: add `@onready var sprite: Sprite2D = $Sprite2D`; in `_ready()` (after the existing `body_entered.connect(...)` line), set `sprite.texture = item.icon` if `item != null`. Since `item` is a plain `@export` set before the node enters the tree (matching how `ItemDropActivity`/tests already set it), reading it in `_ready()` is sufficient — no setter needed.
- Files: `scenes/item_pickup/item_pickup.tscn`, `scenes/item_pickup/item_pickup.gd`

### Step 5: Example `Item` icon assignment
- [x] `scenes/game.tscn`: assign an existing placeholder icon asset (e.g. `res://assets/TinySwords/UI Elements/UI Elements/Icons/Icon_01.png`, confirmed present under `assets/TinySwords/UI Elements/UI Elements/Icons/`) as an `ext_resource` `Texture2D`, and set it on the `Resource_ring_of_damage` sub-resource's new `icon` field.
- Files: `scenes/game.tscn`

### Step 6: `InventoryDisplay` presentation scene
- [x] Create `scenes/inventory_display/inventory_display.gd`: `class_name InventoryDisplay`, `extends Node2D`.
  - `@export var inventory: Inventory`
  - `const SLOT_SIZE := Vector2(32, 32)` and `const SLOT_SPACING := 8.0` (tunable layout constants, not `@export` — internal presentation detail, no design need to expose them yet).
  - `var _slot_icons: Array[TextureRect] = []`
  - `_ready()`: for `i in range(inventory.slot_count)`, create a `TextureRect` (`expand_mode = EXPAND_FIT_WIDTH_PROPORTIONAL` or `stretch_mode = STRETCH_KEEP_ASPECT_CENTERED`, sized to `SLOT_SIZE`, positioned at `Vector2(i * (SLOT_SIZE.x + SLOT_SPACING), 0)`), `add_child(rect)`, append to `_slot_icons`. Connect `inventory.slots_changed` to `_on_slots_changed`. Call `_on_slots_changed()` once immediately after connecting, so the initial (all-empty) state renders without waiting for a mutation.
  - `_on_slots_changed() -> void`: for `i in range(_slot_icons.size())`, set `_slot_icons[i].texture = inventory.slots[i].icon if inventory.slots[i] != null else null`.
- [x] Create `scenes/inventory_display/inventory_display.tscn`: `Node2D` root with the script attached, no fixed children (all slot visuals are built in code per the Architecture Decision above — mirrors how `MovementStack`/other array-driven components need no fixed `.tscn` authoring for their variable-length contents).
- Files: `scenes/inventory_display/inventory_display.gd`, `scenes/inventory_display/inventory_display.tscn`

### Step 7: Wire `InventoryDisplay` into `Player`
- [x] `scenes/player/player.tscn`: add an `InventoryDisplay` node (instanced from `inventory_display.tscn`), as a sibling of the existing `HealthBar` node, with `inventory = NodePath("../Inventory")` wired the same way `HealthBar.status = NodePath("../Status")` already is. Position it distinctly from `HealthBar` (e.g. `position = Vector2(0, 40)`, below the player, mirroring `HealthBar`'s `Vector2(0, -40)` above it) so the two don't visually overlap.
- Files: `scenes/player/player.tscn`

### Step 8: Unit test for `InventoryDisplay`'s pure logic (if any isolable) / integration test for the full reactive behavior
- [x] `test/integration/inventory/inventory_display_test.gd` (new — `InventoryDisplay` needs a live `Inventory` node and its own `_ready()` to run, so this is scene-tree-dependent like `item_pickup_test.gd`, not a pure-logic unit test):
  - Instancing an `InventoryDisplay` bound to an `Inventory` with `slot_count = 3` results in 3 slot visuals (`_slot_icons.size() == 3`).
  - A slot with a `null` item shows no texture (`_slot_icons[i].texture == null`) after initial `_ready()`.
  - Calling `inventory.equip(item)` (with a non-`null` `item.icon`) updates the corresponding slot visual's `texture` to that icon, without any additional scene reload/re-instancing.
  - Calling `inventory.unequip(slot_index)` afterward reverts that slot's visual `texture` back to `null`.
- Files: `test/integration/inventory/inventory_display_test.gd`

### Step 9: Full regression pass
- [x] Run the full GUT suite headlessly. Result: 88/88 passing (84 pre-existing/updated + 4 new `inventory_display_test.gd`). Found and fixed a real bug during this run: `InventoryDisplay._on_slots_changed()` indexed `inventory.slots` before `Inventory._ready()` had resized it in some sibling-ordering/standalone-instantiation cases, throwing "Out of bounds get index" — fixed with a bounds check (`i < inventory.slots.size()`) rather than relying on `_ready()` ordering between siblings. Also confirmed `test/integration/enemy/enemy_death_test.gd` has a pre-existing parse error (unrelated to this refinement, predates this session per `git log`) — GUT skips it with a warning; not fixed here as it's out of scope.; confirm the pre-existing 83 tests still pass alongside the new/modified ones from Steps 3 and 8. Pay particular attention to `test/integration/inventory/item_pickup_test.gd` and `test/integration/activities/item_drop_activity_test.gd` — neither currently asserts on the pickup's visual, so Step 4's `ColorRect` → `Sprite2D` swap should not break them, but re-verify after the change since both construct `Item.new()` with no `icon` set (i.e. `sprite.texture = null` is a valid, error-free state to confirm).
- Files: none (verification checkpoint)

### Step 10: Manual verification
- [ ] Launch the game; confirm the `HealthBar` and new `InventoryDisplay` both render below/above the player without overlapping; confirm a dropped "Ring of Damage" pickup shows its icon sprite (not a plain colored square); walk into it and confirm a slot in `InventoryDisplay` lights up with that same icon; press its drop key and confirm the slot visual clears and the ground pickup reappears with the icon still visible. (Per this project's established preference, manual verification is deferred to the user to run themselves.)

## Acceptance Criteria Mapping
| AC | Verified By |
|----|-------------|
| AC-01 – AC-14 | Unaffected by this refinement — already verified by existing tests (see prior `impl-summary.md`) |
| AC-15: `slots_changed` emitted only on success paths | `test/unit/inventory/inventory_test.gd` (Step 3) |
| AC-16: pickup renders `item.icon` on its `Sprite2D` | Covered manually (Step 10) + indirectly by Step 8's display test using the same icon-assignment pattern; no dedicated automated pixel-check exists in this codebase's testing style (consistent with how visual placeholders were never asserted on before) |
| AC-17: `InventoryDisplay` renders exactly `slot_count` visuals | `test/integration/inventory/inventory_display_test.gd` (Step 8) |
| AC-18: slot visual shows icon or blank per slot state | `test/integration/inventory/inventory_display_test.gd` (Step 8) |
| AC-19: display updates live on equip/unequip | `test/integration/inventory/inventory_display_test.gd` (Step 8) |

## Risks & Mitigations
- Risk: adding `slots_changed` changes `Inventory`'s contract after it already shipped with tests and an `impl-summary.md` marking it done — any other already-written code assuming silent mutation (there is none currently, per a review of `ItemPickup`/`InventoryDropInput`) could be affected. Mitigation: Step 9's full regression run is a hard checkpoint before considering this refinement complete.
- Risk: building `InventoryDisplay`'s slot visuals procedurally in code (rather than as fixed `.tscn` nodes) is less common in this codebase's existing presentation scenes (`HealthBar`'s two `ColorRect`s are fixed `.tscn` children) — slightly more code, but required for genuine slot-count flexibility (FR-09's explicit requirement). Mitigation: keep the procedural-build logic in `_ready()` short and isolated (a single loop), matching the simplicity of `HealthBar`'s own `_ready()`.
- Risk: `TextureRect` sizing/stretch settings can look wrong (stretched, cropped) depending on the source icon texture's native size relative to `SLOT_SIZE`. Mitigation: `STRETCH_KEEP_ASPECT_CENTERED` avoids distortion; exact visual polish is explicitly deferred (Open Questions in `feature.md` already flag layout as an implementation detail, not an AC).
- Risk: forgetting to call `_on_slots_changed()` once at startup would leave `InventoryDisplay` showing stale/uninitialized `TextureRect`s (all default-null, which happens to be correct for a fresh `Inventory`, but would be wrong if `InventoryDisplay` were ever instanced against an `Inventory` that already has items equipped before `InventoryDisplay._ready()` runs, e.g. save/load in the future). Mitigation: Step 6 explicitly calls for an initial `_on_slots_changed()` invocation, not just the signal connection.

## Estimated Complexity
Low — three small, mechanical edits to already-shipped, well-tested files (`Item`, `Inventory`, `ItemPickup`), plus one new presentation scene that closely mirrors the existing `HealthBar` precedent. The only genuinely new pattern is building a variable number of child visuals procedurally, which is straightforward GDScript.
