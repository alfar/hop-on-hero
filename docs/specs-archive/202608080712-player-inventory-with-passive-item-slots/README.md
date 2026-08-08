# Player Inventory with Passive Item Slots

Implemented on: 2026-08-08

## What was built
`Player` gained a 3-slot `Inventory` (`Node`, pure `Array[Item]` state — no scene-tree bookkeeping) holding `Item` `Resource`s that each grant one or more passive `WeaponComponent`s while equipped. `WeaponComponent` was migrated from `Node` to `Resource` (folding over `WeaponSystem.components: Array[WeaponComponent]` instead of scene-tree children) so `Item` could hold weapon components directly, without any scene/node instantiation — a prerequisite for procedural item generation later. A new `InventoryWeaponComponent` reads `Inventory.slots` at fold time and threads each equipped item's components into the running damage total, so equip/unequip is just an array mutation.

Items spawn on the ground via a new `ItemDropActivity` (registered alongside `BossActivity` in `ActivityManager`) and are auto-picked-up on contact via a new `ItemPickup` scene if an empty slot exists; if the inventory is full, the player must press a number key (1/2/3) to manually drop that slot's item first, via a new `InventoryDropInput` component.

A follow-up refinement (same feature cycle) added `Item.icon` (a `Texture2D` shared by both the ground pickup and a new UI), a `Sprite2D`-based visual on `ItemPickup` (replacing a placeholder `ColorRect`), a new `Inventory.slots_changed` signal, and a new `InventoryDisplay` presentation scene — a flexible-slot-count row of item icons reflecting live inventory contents. Mid-implementation, `InventoryDisplay` was moved from a `Player`/`Camera2D` child to a `CanvasLayer` (`HUD`) directly under `Game`, after discovering that nodes parented under `Camera2D` inherit the camera's raw, unclamped transform and visibly drift once the camera itself gets clamped to world bounds.

## Key files
- `components/inventory/` — `Item`, `Inventory`, `InventoryWeaponComponent`, `InventoryDropInput`
- `components/weapon/weapon_component.gd` — migrated `Node` → `Resource`
- `scenes/weapon_system/weapon_system.gd` + `.tscn` — folds over `Array[WeaponComponent]` instead of child nodes
- `components/activities/item_drop_activity.gd` — new `Activity`
- `scenes/item_pickup/` — pickup scene (`Sprite2D`-based visual)
- `scenes/inventory_display/` — new presentation scene, instanced under `Game`'s `HUD` `CanvasLayer`
- `scenes/player/player.tscn`, `player.gd` — new `Inventory`, `InventoryDropInput` children; `InventoryWeaponComponent` wiring
- `scenes/game.tscn`, `game.gd` — new `HUD` `CanvasLayer`; wires `InventoryDisplay.inventory` to `Player.inventory`
- `project.godot` — new `item` collision layer, `drop_slot_1/2/3` input actions

## Notable decisions
- `WeaponComponent`'s `Node`→`Resource` migration reverses the project's prior `Node`-based choice specifically for damage-calculation components (not `WeaponTrigger`, which stays a `Node`) — see Architecture Decisions in `docs/project.md`.
- HUD/screen-anchored UI must live under a `CanvasLayer`, never as a child of `Camera2D` — a real bug found and fixed during this feature (see Architecture Decisions).
- Purely cosmetic randomness (e.g. `InventoryDropInput`'s drop-scatter direction) is exempt from the project's seeded-RNG-determinism rule, since it doesn't affect gameplay/replay outcomes — a deliberate, documented exception (see Architecture Decisions).
- Full test suite: 91/91 passing at archive time.
