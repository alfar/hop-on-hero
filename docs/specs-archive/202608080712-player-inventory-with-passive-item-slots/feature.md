# Feature: Player Inventory with Passive Item Slots

## Summary
Adds an `Inventory` to `Player` with a fixed 3 slots, each holding at most one `Item`. This feature also migrates `WeaponComponent` from a `Node` (currently a `WeaponSystem` scene-tree child) to a `Resource`, matching `MovementBehavior`/`Activity`'s existing pattern — `WeaponSystem.get_total_damage()` folds over an `@export var components: Array[WeaponComponent]` instead of scene-tree children. This lets `Item` (also a `Resource`) directly hold one or more `WeaponComponent` `Resource`s (no `PackedScene`/scene-tree instantiation involved), which matters because items are intended to be procedurally generated in code. A new `InventoryWeaponComponent` (itself a `WeaponComponent`, added once to `Player`'s `WeaponSystem.components`) reads `Inventory.slots` at fold time and threads each equipped item's components into the running damage total — so equipping/unequipping an item is just an array mutation on `Inventory`, with no node instantiation, freeing, or child-tracking involved. Items spawn on the ground via a new `ItemDropActivity` (mirroring `BossActivity`'s existing `ActivityManager`-driven spawn pattern) and are auto-picked-up on contact if an empty slot exists. If the inventory is full, walking over a dropped item does nothing; the player must first press a number key (1/2/3) to drop that slot's item onto the ground at their current position, freeing the slot for the next pickup.

Each `Item` also carries an `icon` texture, reused for both its ground-pickup visual and a new `InventoryDisplay` presentation scene: a slot-count-flexible row of icons (3 slots for `Player`) that reflects `Inventory`'s live contents, reacting to a new `slots_changed` signal emitted whenever `equip()`/`unequip()` actually mutates a slot.

## User Stories
- As a player, I want to walk over dropped items to automatically add them to my inventory, so that collecting passive upgrades feels immediate and doesn't interrupt movement.
- As a player, I want to drop a specific item from my loadout when my inventory is full, so that I can choose which passive effect to give up in favor of a new one I want more.
- As a player, I want the items I'm carrying to visibly and immediately change how my character fights, so that inventory management feels meaningful rather than cosmetic.

## Functional Requirements

### FR-01: Migrate `WeaponComponent` from `Node` to `Resource`
Change `WeaponComponent` (`components/weapon/weapon_component.gd`) from `extends Node` to `extends Resource`. `FixedDamageWeaponComponent` (`components/weapon/fixed_damage_weapon_component.gd`) needs no logic change (still `@export var damage: int` and the same `modify_damage`), just inherits the new base.

`WeaponSystem` (`scenes/weapon_system/weapon_system.gd`) changes from folding over `Node` children to folding over an ordered `Resource` array, mirroring `MovementStack.behaviors`:
- Replace its child-iteration with `@export var components: Array[WeaponComponent] = []`.
- `get_total_damage()` folds over `components` in array order instead of `get_children()` — same fold semantics (start at `0`, thread each `modify_damage()` result into the next), just over an array instead of scene-tree children.
- `weapon_system.tscn`'s existing `FixedDamageWeaponComponent` child node is removed; the equivalent `FixedDamageWeaponComponent` `Resource` is instead assigned into `components` (as a sub-resource in the `.tscn`, same authoring experience as `TargetMovementBehavior`'s existing sub-resource usage in `game.tscn`).

This is a prerequisite for FR-02/FR-04: it lets `Item` (a `Resource`) directly hold `WeaponComponent` `Resource`s without any scene/node involvement, which matters because items are meant to be constructed procedurally in code, not authored as scenes.

### FR-02: `Item` resource
Add `Item` (`components/inventory/item.gd`, `class_name Item`, `extends Resource`):
- `@export var display_name: String`
- `@export var icon: Texture2D` — the sprite representing this item. Shared by both the ground-pickup visual (FR-06) and the `InventoryDisplay` presentation scene (FR-09), so an item's appearance is authored once regardless of where it's shown.
- `@export var components: Array[WeaponComponent] = []` — one or more `WeaponComponent`s this item grants while equipped (e.g. a `FixedDamageWeaponComponent`).
- `@export var pickup_scene: PackedScene` — the world-representation `PackedScene` (an `Area2D`-based pickup, see FR-05) spawned when this item is dropped/placed in the world. This is the one place `Item` still touches a scene, since a pickup is a real physical/visual object in the world — unrelated to FR-01's `WeaponComponent` migration.

`Item` itself carries no behavior beyond this data — equip/unequip logic lives in `Inventory` (FR-03), matching the project's existing pattern of putting behavior in the consuming system rather than the data `Resource` (c.f. `MovementBehavior` vs. `Activity` holding plain `@export` data).

### FR-03: `Inventory` component
Add `Inventory` (`components/inventory/inventory.gd`, `class_name Inventory`, `extends Node`) as a new reusable component under `components/inventory/`, instanced as a child of `Player` (mirroring how `Status`/`WeaponSystem` are instanced as children):
- `@export var slot_count: int = 3`
- Internal state: `var slots: Array[Item]` sized to `slot_count`, all `null` initially (an empty slot).
- `func equip(item: Item) -> bool` — finds the first `null` slot; if none exists, returns `false` without modifying state. Otherwise: stores `item` in that slot, emits `slots_changed`, and returns `true`. Does **not** touch `WeaponSystem` or any node — `InventoryWeaponComponent` (FR-04) reads `slots` directly whenever damage is computed, so there's nothing to instantiate or wire on equip.
- `func unequip(slot_index: int) -> Item` — if `slots[slot_index]` is `null`, returns `null` (no-op, no signal). Otherwise: sets `slots[slot_index] = null`, emits `slots_changed`, and returns the removed `Item`. Again, no node/child bookkeeping — the item's components simply stop being included the next time `InventoryWeaponComponent` folds over `slots`.
- `func has_empty_slot() -> bool` — `true` if any slot is `null`.
- `signal slots_changed` — emitted only when `equip()`/`unequip()` actually mutates a slot (not on the no-op paths above). Added for `InventoryDisplay` (FR-09) to know when to redraw; `InventoryWeaponComponent` still reads `slots` directly at fold time and does not need this signal.

### FR-04: `InventoryWeaponComponent`
Add `InventoryWeaponComponent` (`components/inventory/inventory_weapon_component.gd`, `class_name InventoryWeaponComponent`, `extends WeaponComponent`):
- `var inventory: Inventory` — **not** `@export`ed. `Inventory` is a `Node` (it needs a scene-tree lifecycle to be a child of `Player`), and per this project's established constraint (Movement Behavior Stack feature), a `Resource` script cannot `@export` a `Node`-derived type in Godot 4.7 — it must be a plain `var` injected in code, exactly like `ChasePlayerMovementBehavior.player`. `Player._ready()` (or equivalent setup step) assigns this reference once, after both `Inventory` and `WeaponSystem` exist as children.
- `func modify_damage(current_damage: int) -> int` — iterates `inventory.slots` in order; for each non-`null` `Item`, iterates that item's `components` in order, threading `modify_damage()` through each (nested fold: slot order outermost, each item's component order innermost). Skips `null` slots. If `inventory` itself is `null` (unwired), returns `current_damage` unchanged rather than erroring.

One `InventoryWeaponComponent` instance is placed in `Player.WeaponSystem.components` (FR-01) as a permanent entry, alongside any other `WeaponComponent`s `Player` has (e.g. its existing `FixedDamageWeaponComponent` base attack).

### FR-05: `ItemDropActivity`
Add `ItemDropActivity` (`components/activities/item_drop_activity.gd`, `class_name ItemDropActivity`, `extends Activity`), following `BossActivity`'s existing shape:
- `@export var items: Array[Item]` — the pool of possible items to drop; `execute()` picks one at random (via the seeded `rng` parameter, consistent with this project's seeded-randomness convention).
- `@export var min_spawn_distance: float = 0.0` — reuses `BossActivity`'s reachable-distance-from-a-random-point approach is *not* needed here since a dropped item doesn't move; instead `execute()` picks a uniformly random position within `world_size`, with no minimum-distance constraint (out of scope to add one — see Out of Scope).
- `execute(rng, world_size, spawn_parent)` instantiates the chosen item's `pickup_scene` at a random position within `world_size` and adds it via `spawn_parent.add_child.call_deferred(...)`, exactly like `BossActivity` does for its boss enemy.
- Registered alongside `BossActivity` in `ActivityManager.activities` (both are picked from by the existing random-activity-selection logic already in `activity_manager.gd` — no change needed there).

### FR-06: Item pickup scene and contact-based auto-pickup
Add a reusable pickup scene (`scenes/item_pickup/item_pickup.tscn` + `item_pickup.gd`, mirroring `scenes/camera/`-style standalone reusable scenes): an `Area2D` with a `CollisionShape2D`, a `Sprite2D` (replacing the placeholder `ColorRect`) whose `texture` is set from `item.icon`, `collision_layer` on a new `item` layer (see FR-08), `collision_mask` set to detect the `player` layer, and an `@export var item: Item` referencing which `Item` this pickup represents (set by `ItemDropActivity` at spawn time, and also settable in the editor for manually-placed pickups). Setting `item` (in the editor or in code, e.g. via a setter or in `_ready()`) updates the `Sprite2D.texture` to `item.icon`.

On `body_entered` (the `Player`):
- If `player.get_node("Inventory").has_empty_slot()` is `true`: call `equip(item)` on the player's `Inventory` and `queue_free()` this pickup node.
- If no empty slot: do nothing (the pickup remains in the world; per user decision, walking over a full-inventory pickup is a no-op).

### FR-07: Manual drop via number keys
`Player` (or a new small `Node` component under `components/inventory/`, e.g. `inventory_drop_input.gd`, to keep `player.gd` thin per this project's "thin entity script" convention) listens for number-key input (1, 2, 3 mapped to slot indices 0, 1, 2) and, on press, calls `inventory.unequip(slot_index)`. If a non-`null` `Item` is returned, instantiate that item's `pickup_scene` at the player's current `global_position` and add it to the world (via the same `spawn_parent`-style wiring `Player` already uses for `weapon_spawn_parent`/projectiles).

New Godot `InputMap` actions are required: `drop_slot_1`, `drop_slot_2`, `drop_slot_3`, bound to keys `1`, `2`, `3` respectively (see Non-Functional/Technical Scope — this touches `project.godot`, not just scripts).

### FR-08: New `item` collision layer
Add a 5th collision layer named `item` (this project currently has `default`/`player`/`enemy`/`projectile`) in `project.godot`'s `[layer_names]` section, used by item pickups' `collision_layer` (FR-06) so their `Area2D` detection is scoped correctly and doesn't collide with `enemy`/`projectile` logic.

### FR-09: `InventoryDisplay` presentation scene
Add a presentation-only scene (`scenes/inventory_display/inventory_display.tscn` + `inventory_display.gd`, `class_name InventoryDisplay`, `extends Node2D`), following the `HealthBar` precedent (a `scenes/<name>/` presentation scene that reactively reflects a component's state, per this project's presentation-vs-`components/<category>/` split — see Architecture Decisions in `docs/project.md`):
- `@export var inventory: Inventory`.
- Flexible slot count: on `_ready()`, builds one slot visual (a container holding a `TextureRect`/`Sprite2D` for the icon) per `inventory.slot_count` — not hardcoded to 3, so the same scene works for any `Inventory`, though `Player`'s instance is configured with 3 (matching FR-03's default).
- Connects to `inventory.slots_changed` (FR-03) and redraws all slot visuals on each emission: for each slot, shows `slots[i].icon` if non-`null`, or a blank/empty visual if `slots[i]` is `null`.
- Instanced under a `CanvasLayer` (`HUD`) directly under `Game` (`game.tscn`), not as a child of `Player`/`Camera2D` — a node parented under `Camera2D` inherits the camera's raw, unclamped transform, so once the camera itself gets clamped to the world edges (per `Camera2D.limit_*`), a child's on-screen position visibly drifts from where it should sit. A `CanvasLayer` renders in fixed screen space regardless of any `Camera2D` transform, zoom, or clamping, which is what a screen-anchored HUD element needs. `game.gd` wires `HUD/InventoryDisplay.inventory = Player.inventory` in `_ready()`.
- No independent logic beyond reflecting `Inventory` state — equip/unequip/drop behavior (FR-03/FR-06/FR-07) is unaffected and unaware this display exists.

## Acceptance Criteria
- [x] AC-01: `WeaponComponent` is `Resource`-based; `WeaponSystem.get_total_damage()` folds over `components: Array[WeaponComponent]` in array order (same fold semantics as before — starts at `0`, threads each `modify_damage()` result into the next), returning `0` for an empty array.
- [x] AC-02: A new `Inventory` with `slot_count = 3` has 3 `null` slots and `has_empty_slot()` returns `true`.
- [x] AC-03: Calling `equip(item)` on an `Inventory` with at least one empty slot stores the item in the first empty slot and returns `true`.
- [x] AC-04: Calling `equip(item)` on an `Inventory` with no empty slots (`slot_count` items already equipped) returns `false` and does not modify any slot.
- [x] AC-05: Calling `unequip(slot_index)` on a slot holding an item sets that slot back to `null` and returns the `Item` that was removed.
- [x] AC-06: Calling `unequip(slot_index)` on an already-empty slot returns `null` and does not error or modify other slots.
- [x] AC-07: `InventoryWeaponComponent.modify_damage()` folds over every component of every equipped item, in slot order then per-item component order, skipping `null` slots; with an unwired (`null`) `inventory`, it returns the input unchanged rather than erroring.
- [x] AC-08: An item equipped via `Inventory.equip()` is reflected in `Player`'s `WeaponSystem.get_total_damage()` on the very next call (i.e. it actually affects damage, proving the passive-effect wiring works end-to-end with no equip-time instantiation step needed).
- [x] AC-09: An item removed via `Inventory.unequip()` is no longer reflected in `WeaponSystem.get_total_damage()` on the next call.
- [x] AC-10: `ItemDropActivity.execute()` spawns an instance of the chosen item's `pickup_scene` within `world_size` bounds under `spawn_parent`.
- [x] AC-11: Walking the `Player` into an item pickup, when the inventory has an empty slot, equips the item and removes the pickup from the world.
- [x] AC-12: Walking the `Player` into an item pickup, when the inventory is full, leaves the pickup in the world and does not change any inventory slot.
- [x] AC-13: Pressing the number key mapped to a non-empty slot drops that slot's item (spawns its `pickup_scene` at the player's position, clears the slot).
- [x] AC-14: Pressing the number key mapped to an already-empty slot has no effect (no pickup spawned, no error).
- [x] AC-15: `Inventory.slots_changed` is emitted when `equip()` succeeds and when `unequip()` removes a non-`null` item; it is **not** emitted on the no-op paths (`equip()` failing because full, `unequip()` on an already-empty slot).
- [x] AC-16: A pickup spawned for an `Item` with a non-`null` `icon` renders that texture (not the old placeholder color) on its `Sprite2D`.
- [x] AC-17: An `InventoryDisplay` bound to an `Inventory` with `slot_count = 3` renders exactly 3 slot visuals, one per slot, in slot order.
- [x] AC-18: For each slot, `InventoryDisplay` shows the equipped item's `icon` when the slot holds an `Item`, and shows no icon (blank) when the slot is `null`.
- [x] AC-19: Equipping or unequipping an item via `Inventory` updates `InventoryDisplay`'s rendered slots to match the new state, without any scene reload.

## Technical Scope

### Affected Modules
- `components/inventory/` (new category, following the `components/<category>/` convention)
- `components/weapon/` (`weapon_component.gd` migrated to `Resource`; `fixed_damage_weapon_component.gd` re-bases on it unchanged)
- `scenes/weapon_system/weapon_system.gd` + `.tscn` (child-node fold → `Array[WeaponComponent]` fold)
- `components/activities/` (new `ItemDropActivity`)
- `scenes/item_pickup/` (new reusable scene; `ColorRect` placeholder replaced with a `Sprite2D` driven by `item.icon`)
- `scenes/inventory_display/` (new presentation scene)
- `scenes/player/player.tscn`, `player.gd` (new `Inventory` child, `InventoryWeaponComponent` wiring, drop-input wiring)
- `scenes/game.tscn`, `game.gd` (new `HUD` `CanvasLayer` holding `InventoryDisplay`, wired to `Player.inventory` in `_ready()`)
- `scenes/enemy/enemy.tscn` (its `WeaponSystem` also needs its existing damage component migrated from a child node to the new `components` array — same mechanical change as `Player`'s, no behavior change)
- `project.godot` (new `item` collision layer, new `drop_slot_1/2/3` input actions)

### New Components Required
- `Item` (`components/inventory/item.gd`)
- `Inventory` (`components/inventory/inventory.gd`)
- `InventoryWeaponComponent` (`components/inventory/inventory_weapon_component.gd`)
- `ItemDropActivity` (`components/activities/item_drop_activity.gd`)
- Item pickup scene (`scenes/item_pickup/item_pickup.tscn`, `item_pickup.gd`)
- Drop-input component (`components/inventory/inventory_drop_input.gd`) — exact placement (own `Node` vs. logic inline in `player.gd`) to be finalized in `/sdd-plan`, but should not bloat `player.gd` per this project's "thin entity script" convention.
- `InventoryDisplay` presentation scene (`scenes/inventory_display/inventory_display.tscn`, `inventory_display.gd`)
- At least one concrete example `Item` resource (holding a `FixedDamageWeaponComponent` and a placeholder `icon` texture), so AC-08/AC-11/AC-16/AC-18 are demonstrably testable.

### Integration Points
- `WeaponSystem` / `WeaponComponent` (existing fold-over-children pipeline, migrated per FR-01 to fold over a `Resource` array instead) — `InventoryWeaponComponent` plugs into this exactly like any other `WeaponComponent`; `Inventory` itself never touches `WeaponSystem` directly.
- `ActivityManager` / `Activity` (existing seeded-activity-scheduler pattern) — `ItemDropActivity` is a new `Activity` registered alongside `BossActivity`.
- Collision layers (existing `player`/`enemy`/`projectile` layers) — adds a 4th gameplay layer, `item`.
- `Player` scene — gains an `Inventory` child, one `InventoryWeaponComponent` entry in `WeaponSystem.components`, code that wires `InventoryWeaponComponent.inventory` at `_ready()`, and (likely) a small drop-input `Node` child.
- Existing tests touching the pre-migration `WeaponComponent`/`WeaponSystem` API (`test/unit/weapon/weapon_system_test.gd`, `weapon_component_test.gd`, `fixed_damage_weapon_component_test.gd`, and `test/integration/weapon/melee_contact_weapon_trigger_test.gd`'s `enemy.get_node("WeaponSystem").get_node("FixedDamageWeaponComponent")` lookup) will need updating during implementation to use the new `components` array instead of `add_child`/`get_node`.
- `HealthBar` (existing presentation-scene precedent, `scenes/health_bar/`) — `InventoryDisplay` follows the same shape: a `Node2D` presentation scene holding a typed `@export` reference to a component (`Status`/`Inventory`) and redrawing reactively off that component's signal, rather than owning any game logic itself.
- Already-implemented `Inventory`/`ItemPickup` code and their existing unit/integration tests (`test/unit/inventory/inventory_test.gd`, `test/integration/inventory/item_pickup_test.gd`, etc.) — this refinement changes `Inventory`'s emitted-signal contract and `ItemPickup`'s visual, both of which are already shipped and tested; existing tests need new assertions (signal emission) and any test relying on the placeholder `ColorRect` should be checked for pickup-visual assumptions.

## Non-Functional Requirements
- Performance: negligible — inventory operations are O(slot_count) array scans over at most 3 elements; item pickups are ordinary `Area2D` contact detection, identical in cost to the existing melee `HitArea` pattern.
- Security: not applicable (client-side game, no user input trust boundary beyond existing local-input handling).
- Scalability: `slot_count` is a plain `@export int`, so raising it later (e.g. via a future upgrade) requires no structural change, only re-sizing the `slots` array. Because `Item`/`WeaponComponent` are now pure `Resource` data with no scene instantiation step, procedurally generating new items at runtime (constructing `Item.new()` and populating `components` in code) requires no scene-loading or `PackedScene` authoring. `InventoryDisplay` builds its slot visuals from `inventory.slot_count` at `_ready()`, so it scales with `Inventory` without any change to the display scene itself.

## Out of Scope
- Any UI beyond the flat icon-grid `InventoryDisplay` in FR-09 — no tooltips, hover states, item names/stats on screen, drag-and-drop rearrangement, or indication of which number key maps to which slot. `InventoryDisplay` shows icons only.
- Item rarity, stacking, multiple items per slot, or any economy/currency system.
- Actual procedural item generation logic (random stat rolls, rarity tiers, etc.) — this feature only makes `Item`/`WeaponComponent` shaped correctly (plain `Resource` data) to support that later; `ItemDropActivity.items` for this feature is a hand-authored pool.
- `Enemy` having an inventory, or enemies dropping items directly on death (items come only from `ItemDropActivity`, per user decision).
- A minimum-spawn-distance-from-player constraint on `ItemDropActivity` (unlike `BossActivity`'s `min_target_distance`) — dropped items spawn at a uniformly random world position with no distance guarantee; can be added later if playtesting shows items spawning too close/far.
- Visual/audio feedback for equip, drop, or pickup (tweens, sound effects, particle bursts) — purely functional wiring for this feature.
- Persisting inventory contents across scenes/sessions (no save system exists in this project).
- Swapping/reordering items between slots, or any drag-and-drop-style manipulation.

## Open Questions
- None outstanding. The original deferred detail (how `Inventory.unequip()` finds "the `WeaponComponent` child that corresponds to this slot") is resolved by this revision: there is no child-tracking at all, since `InventoryWeaponComponent` reads `Inventory.slots` directly at fold time rather than `Inventory` instantiating/freeing scene-tree nodes on equip/unequip.
- One implementation detail deferred to `/sdd-plan`: the exact code path that assigns `InventoryWeaponComponent.inventory` at startup (e.g. `Player._ready()` reaching into `weapon_system.components` to find the `InventoryWeaponComponent` instance, vs. `Player` holding its own separate typed reference to the same shared `Resource` instance also placed in `components`) — functionally equivalent options exist and don't affect this spec's acceptance criteria.
- Exact slot-visual layout/sizing/spacing for `InventoryDisplay` (horizontal row vs. grid, pixel dimensions, background/border per slot) is deferred to `/sdd-plan`/implementation — functionally any layout satisfies AC-17/AC-18 as long as each slot's icon-or-empty state is visually distinguishable.
- Placeholder icon art for the example `Item`(s) is deferred to implementation — this spec only requires `icon` be a non-`null` `Texture2D` so AC-16/AC-18 are testable; actual art direction is out of scope.

---

## Revision History

| Date | Change Summary |
|------|----------------|
| 2026-08-07 | Initial spec |
| 2026-08-07 | Added `Item.icon`, a new `InventoryDisplay` presentation scene (FR-09) showing a flexible-slot-count row of item icons reflecting live `Inventory` state, a `Sprite2D`-based visual for `ItemPickup` (replacing the placeholder `ColorRect`), and a new `Inventory.slots_changed` signal so `InventoryDisplay` can react to equip/unequip. |
