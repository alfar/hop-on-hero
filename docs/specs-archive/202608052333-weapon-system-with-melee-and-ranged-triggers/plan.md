# Implementation Plan: Weapon System with Melee and Ranged Triggers

## Overview
Build the collision foundation (collision layers + `HitArea` nodes) first, since every later step depends on it. Then build the pure-logic pieces (`WeaponComponent`/`FixedDamageWeaponComponent`/`WeaponSystem`) and their unit tests, since they have no scene-tree dependencies and can be verified in isolation immediately — mirroring the order used for the Status feature. Then build the two trigger types and the `Projectile` scene, which do depend on the scene tree/physics. Finally wire everything into `Player`/`Enemy` and manually verify the full pipeline end-to-end, since GUT can't exercise physics/collision in this project (per the established Status/HealthBar precedent).

## Architecture Decisions
- **`WeaponComponent`/`WeaponSystem` are `Node`-based, mirroring `StatusComponent`/`Status`**: same rationale as the Status feature — the fold order is expressed by sibling position in the scene tree, which only actual child `Node`s can express via the editor's drag-to-reorder UI.
- **`WeaponTrigger` is also `Node`-based**, matching `MovementBehavior`'s strategy-pattern *role* but not its `Resource` *implementation*: unlike `MovementBehavior` (a stateless `Resource` swapped via `@export`), a `WeaponTrigger` owns runtime state (a `Timer` child, a `HitArea` signal connection) and needs its own `_ready()`/node lifecycle, so it must be a `Node`, added as a scene-tree child of `Player`/`Enemy` alongside `WeaponSystem`, and wired to it via a `node_paths` export (the same `NodePath` wiring pattern already used for `HealthBar.status`).
- **Enemies are found via a Godot group (`"enemy"`), not a scene-tree scan or a manual registry**: this project has no group or registry mechanism yet. `Enemy._ready()` calls `add_to_group("enemy")`; `TimerWeaponTrigger` uses `get_tree().get_nodes_in_group("enemy")` to find candidates for "nearest enemy," which is simpler than threading a shared `Enemies` container through export vars the way `ActivityManager.spawn_parent` does, and scales fine at this project's size (a handful of enemies on screen).
- **Collision layers**: `player` (bit 1, matches existing default physics layer usage by `CharacterBody2D`s — confirmed no conflicting layer use exists in `project.godot` currently), `enemy` (bit 2), `projectile` (bit 3), configured under Project Settings → Layer Names → 2D Physics. `HitArea` nodes and `Projectile` set `collision_layer`/`collision_mask` directly on the node in each `.tscn`, following the same `.tscn`-authored-properties convention as `movement_behavior`/`node_paths` wiring elsewhere in this project.
- **World-bounds check for `Projectile` reuses `GameEvents.world_size_changed`**, the same `BehaviorSubject` subscription pattern already used by `Player`/`CameraBounds` — no new mechanism introduced.
- **`Projectile` spawn parent is the `Game` root (`scenes/game.tscn`)**: mirrors `ActivityManager.spawn_parent = NodePath("..")`, wired the same way via a `node_paths` export on `TimerWeaponTrigger`.
- **Unit tests cover only `WeaponComponent`/`FixedDamageWeaponComponent`/`WeaponSystem`** (per FR-14/Out of Scope) — `HitArea` signals, `Timer`-based triggers, and `Projectile` physics motion all require a running scene tree and are verified by manual headless playtesting instead, consistent with how `Status`/`HealthBar` were handled.

## Implementation Steps

### Step 1: Collision layers (Project Settings)
- [x] Add three named 2D physics layers in `project.godot`: `player` (layer 2), `enemy` (layer 3), `projectile` (layer 4). Layer 1 (named `default`) is left untouched since `Player`/`Enemy`/`World`'s `TileMapLayer` all currently rely on Godot's default layer 1/mask 1 for physical blocking with no explicit `collision_layer`/`collision_mask` set anywhere — repurposing layer 1 would have silently broken existing collision.
- Files: `project.godot` (modified)

### Step 2: HitArea on Player and Enemy
- [x] Add a child `Area2D` named `HitArea` (with a `CollisionShape2D` sized to roughly match each entity's existing physical `CollisionShape2D`) to `scenes/player/player.tscn`: `collision_layer = player`, `collision_mask = enemy`.
- [x] Add the same to `scenes/enemy/enemy.tscn`: `collision_layer = enemy`, `collision_mask = player`.
- [x] Add `Enemy.gd`: call `add_to_group("enemy")` in `_ready()` (needed by Step 5's targeting; doing it now keeps all `Enemy`-identity changes in one place).
- Files: `scenes/player/player.tscn`, `scenes/enemy/enemy.tscn`, `scenes/enemy/enemy.gd` (all modified)

### Step 3: WeaponComponent, FixedDamageWeaponComponent, WeaponSystem (pure logic)
- [x] Create `components/weapon/weapon_component.gd`: `WeaponComponent extends Node`, `func modify_damage(current_damage: int) -> int: return current_damage`.
- [x] Create `components/weapon/fixed_damage_weapon_component.gd`: `FixedDamageWeaponComponent extends WeaponComponent`, `@export var damage: int = 10`, `modify_damage()` returns `current_damage + damage`.
- [x] Create `scenes/weapon_system/weapon_system.gd`: `WeaponSystem extends Node2D`, `func get_total_damage() -> int` folding over `WeaponComponent` children in `get_children()` order (matches `Status.apply_event()`'s iteration pattern exactly).
- [x] Create `scenes/weapon_system/weapon_system.tscn`: root `WeaponSystem` node (`Node2D`), following the same precedent as `status.tscn` (which bakes in `ShieldComponent`+`HealthComponent` as fixed children) — `weapon_system.tscn` ships with one `FixedDamageWeaponComponent` child pre-added, since both `Player` and `Enemy` need exactly that for now. Per-entity `damage` values are then overridden directly as instance property overrides in `player.tscn`/`enemy.tscn`, the same way scene instances already override exported values elsewhere in this project.
- Files: `components/weapon/weapon_component.gd`, `components/weapon/fixed_damage_weapon_component.gd`, `scenes/weapon_system/weapon_system.gd`, `scenes/weapon_system/weapon_system.tscn` (all created)

### Step 4: Unit tests for WeaponComponent/FixedDamageWeaponComponent/WeaponSystem
- [x] Create `test/unit/weapon/weapon_component_test.gd`: base `modify_damage()` returns input unchanged.
- [x] Create `test/unit/weapon/fixed_damage_weapon_component_test.gd`: `modify_damage(current_damage)` returns `current_damage + damage` for a couple of `damage`/`current_damage` combinations.
- [x] Create `test/unit/weapon/weapon_system_test.gd`: no components → `get_total_damage() == 0`; one `FixedDamageWeaponComponent` → correct total; order-dependence proof using a small test-only double component (e.g. a locally-defined component in the test file that doubles `current_damage`) placed before/after a `FixedDamageWeaponComponent` child, asserting the two orderings produce different totals (`10 -> 20` vs `0 -> 0 -> 10`). Use `add_child_autofree()` for the `WeaponSystem` node itself (mirrors `HealthComponent`/`ShieldComponent` test setup).
- [x] Run the full GUT suite headlessly and confirm all tests (existing + new) pass. Note: the project's global script class cache needed a one-time rebuild (`godot --headless --editor --quit`) before GUT could resolve the newly created `class_name` types — a first-run quirk, not a code issue.
- Files: `test/unit/weapon/weapon_component_test.gd`, `test/unit/weapon/fixed_damage_weapon_component_test.gd`, `test/unit/weapon/weapon_system_test.gd` (all created)

### Step 5: WeaponTrigger base class + MeleeContactWeaponTrigger
- [x] Create `components/weapon/weapon_trigger.gd`: `WeaponTrigger extends Node`, `@export var weapon_system: WeaponSystem` (wired via `node_paths` in each entity's `.tscn`, matching `HealthBar.status`). No default `_ready()` behavior — an empty base class establishing the shape.
- [x] Create `components/weapon/melee_contact_weapon_trigger.gd`: `MeleeContactWeaponTrigger extends WeaponTrigger`, `@export var hit_area: Area2D` (wired via `node_paths`). In `_ready()`, connects to `hit_area.body_entered`. On `body_entered(body)`: if `body.has_node("Status")`, computes `weapon_system.get_total_damage()` and calls `body.get_node("Status").apply_event(StatusEvent.new("physical_damage", total_damage))`; otherwise no-ops.
- Files: `components/weapon/weapon_trigger.gd`, `components/weapon/melee_contact_weapon_trigger.gd` (both created)

### Step 6: TimerWeaponTrigger
- [x] Create `components/weapon/timer_weapon_trigger.gd`: `TimerWeaponTrigger extends WeaponTrigger`, `@export var interval: float = 1.0`, `@export var projectile_scene: PackedScene`, `@export var spawn_parent: Node` (wired via `node_paths`, mirrors `ActivityManager.spawn_parent`).
  - `_ready()`: creates a repeating `Timer` child (`one_shot = false`, matching the interval-based repeat need — unlike `ActivityManager`'s `one_shot = true` re-armed timer, since this trigger's interval is constant, not activity-dependent), starts it.
  - On timeout: find nearest `Enemy` via `get_tree().get_nodes_in_group("enemy")`, computing distance from the trigger's own global position to each candidate's `global_position`; if the group is empty, return early (no fire this tick).
  - If a target exists: compute `weapon_system.get_total_damage()`, instantiate `projectile_scene`, set its `global_position` to the trigger's entity position, `direction` to the normalized vector toward the target's current `global_position`, `damage` to the computed total, then `spawn_parent.add_child.call_deferred(instance)` (matches `BossActivity`'s deferred-add pattern, safe to call from a signal callback mid-physics-frame).
- Files: `components/weapon/timer_weapon_trigger.gd` (created)

### Step 7: Projectile scene
- [x] Create `scenes/projectile/projectile.gd`: `Projectile extends Area2D`, `@export var speed: float = 600.0`, `var damage: int`, `var direction: Vector2`, `var _world_size: Vector2 = Vector2.ZERO`.
  - `_ready()`: subscribe to `GameEvents.world_size_changed` (same pattern as `Player`/`CameraBounds`) to populate `_world_size`; connect own `body_entered`.
  - `_physics_process(delta)`: `position += direction * speed * delta`; if `_world_size != Vector2.ZERO` and `global_position` falls outside `Rect2(Vector2.ZERO, _world_size)`, `queue_free()`.
  - `_on_body_entered(body)`: if `body.has_node("Status")`, apply `StatusEvent.new("physical_damage", damage)`; unconditionally `queue_free()` afterward regardless of whether `Status` was found.
- [x] Create `scenes/projectile/projectile.tscn`: root `Projectile` (`Area2D`) with a `CollisionShape2D` (small circle/rectangle) and a placeholder visual child (a small `ColorRect`, matching `Player`'s placeholder convention). `collision_layer = projectile`, `collision_mask = enemy`.
- Files: `scenes/projectile/projectile.gd`, `scenes/projectile/projectile.tscn` (both created)

### Step 8: Wire Enemy's weapon setup
- [x] Modify `scenes/enemy/enemy.tscn`: instance `weapon_system.tscn` as a child (its pre-baked `FixedDamageWeaponComponent.damage` can be left at the default or tuned per-instance); add a `MeleeContactWeaponTrigger` child node, wired (`node_paths`) to the `WeaponSystem` instance and the existing `HitArea`.
- Files: `scenes/enemy/enemy.tscn` (modified)

### Step 9: Wire Player's weapon setup
- [x] Modify `scenes/player/player.tscn`: instance `weapon_system.tscn` as a child; add a `TimerWeaponTrigger` child node, wired (`node_paths`) to the `WeaponSystem` instance and `projectile_scene = ExtResource(...)` pointing at `res://scenes/projectile/projectile.tscn`. Left `spawn_parent` unset in `player.tscn` itself.
- [x] Modify `scenes/game.tscn`: added a `node_paths` override on the `TimerWeaponTrigger` node (nested under the `Player` instance node) setting `spawn_parent = NodePath("../..")` (from `Player/TimerWeaponTrigger` — `..` is `Player`, `../..` is `Game`) — mirrors how `ActivityManager.spawn_parent = NodePath("..")` is wired at the composition-root level rather than hardcoded inside a self-contained entity scene (see Risk below). Verified via a temporary debug scene (created and deleted, per this project's established manual-verification practice) that `spawn_parent` resolves to the exact `Game` instance at runtime.
- Files: `scenes/player/player.tscn`, `scenes/game.tscn` (both modified)

### Step 10: End-to-end verification (superseded: GUT integration tests, not manual debug scenes)
- [x] Deviation from plan: rather than manual/ad-hoc debug scenes, the user asked to use GUT for integration testing (a new `test/integration/` directory, added to `.gutconfig.json`'s `dirs`). Wrote real, physics-driven GUT integration tests instead:
  - `test/integration/weapon/melee_contact_weapon_trigger_test.gd`: AC-01, AC-06, AC-07 — enemy/player `HitArea` collision, contact damage, Status-less no-op, re-entering contact re-triggers.
  - `test/integration/weapon/projectile_test.gd`: AC-09, AC-10, AC-11 — movement, damage-and-self-destruct on contact, self-destruct on a Status-less body, despawn on leaving world bounds.
  - `test/integration/weapon/timer_weapon_trigger_test.gd`: AC-08, AC-12/AC-13 (partial) — fires at the nearest enemy with correct aim, no-op with no enemy target, spawned projectile carries damage computed at fire time.
  - `scenes/enemy/enemy.tscn`/`scenes/player/player.tscn`: full weapon setup composition verified as a side effect of the above tests instancing the real scenes directly.
- [x] Fixed real issues found by these tests (not test bugs): `Player`/`Enemy` `CharacterBody2D`s were never actually put on the new `player`/`enemy` collision layers (only their separate `HitArea` children were), so `Area2D.body_entered` never fired for the opposing `HitArea` — fixed by setting `Player.collision_layer = 3` (default+player) and `Enemy.collision_layer = 5` (default+enemy). Also enlarged both `HitArea` shapes beyond their physical `CollisionShape2D` size, since identical-sized shapes let `move_and_slide()`'s depenetration separate two touching bodies before `Area2D` overlap could be detected in the same physics step.
- [x] Full suite (unit + integration) run 3x consecutively headlessly to confirm no flakiness: 50/50 passing every time.
- Files: `test/integration/weapon/melee_contact_weapon_trigger_test.gd`, `test/integration/weapon/projectile_test.gd`, `test/integration/weapon/timer_weapon_trigger_test.gd` (created); `.gutconfig.json`, `scenes/player/player.tscn`, `scenes/enemy/enemy.tscn` (modified, collision layer/HitArea sizing fixes)

## Acceptance Criteria Mapping
| AC | Verified By |
|----|-------------|
| AC-01 | Step 10 manual verification (collision layer/mask inspection) |
| AC-02 | `test/unit/weapon/weapon_component_test.gd` |
| AC-03 | `test/unit/weapon/fixed_damage_weapon_component_test.gd` |
| AC-04 | `test/unit/weapon/weapon_system_test.gd` (order-dependence case) |
| AC-05 | `test/unit/weapon/weapon_system_test.gd` (empty-children case) |
| AC-06 | Step 10 manual verification |
| AC-07 | Step 10 manual verification |
| AC-08 | Step 10 manual verification |
| AC-09 | Step 10 manual verification |
| AC-10 | Step 10 manual verification |
| AC-11 | Step 10 manual verification |
| AC-12 | Step 8 + Step 10 (scene composition + live confirmation) |
| AC-13 | Step 9 + Step 10 (scene composition + live confirmation) |
| AC-14 | Step 4 (unit tests) |

## Risks & Mitigations
- **Risk**: Collision layer bit numbering could silently collide with an existing default layer if `CharacterBody2D`s currently rely on layer 1 for physical blocking, breaking existing movement collision. → **Mitigation**: Step 1 explicitly checks `project.godot`'s current layer configuration before assigning `player`/`enemy`/`projectile` to specific bits, and leaves any pre-existing default layer untouched; verify physical movement-blocking (e.g. `Player` bumping into `Enemy`) still works unchanged after Step 2.
- **Risk**: `TimerWeaponTrigger` needs a `spawn_parent` reference to `Game`'s root, but `Player`/`Enemy` scenes are designed to be self-contained (instanced independently in `game.tscn`) — hardcoding a relative `NodePath` from deep inside `Player`'s tree to its eventual parent is fragile if `Player`'s instancing depth ever changes. → **Mitigation**: wire `spawn_parent` as a `node_paths`-exported property set at the `game.tscn` level (like `ActivityManager.spawn_parent`), not hardcoded inside `player.tscn`/`player.gd` itself — this keeps `Player`'s own scene self-contained and pushes the wiring decision to the composition root, consistent with existing convention.
- **Risk**: `get_tree().get_nodes_in_group("enemy")` on every timer tick is a linear scan; harmless at this project's current scale (a handful of enemies) but could become a hot-path cost if enemy counts grow significantly (e.g. via future wave/horde features). → **Mitigation**: explicitly out of scope for this feature per its Non-Functional Requirements section; flag as a future optimization if enemy counts ever grow large enough to matter.
- **Risk**: `MeleeContactWeaponTrigger` and `TimerWeaponTrigger` both need a `WeaponSystem` sibling reference and their own auxiliary node (`HitArea` or `Timer`+`projectile_scene`+`spawn_parent`) wired via `node_paths` — getting any of these `NodePath`s wrong at the `.tscn` authoring level (Steps 8/9) fails silently or errors at runtime rather than at compile time. → **Mitigation**: Step 10's manual verification explicitly checks the full fire-and-hit loop for both entities before considering the feature done, which would surface a broken wiring immediately.
- **Risk**: No automated coverage exists for triggers, `HitArea` collision, or `Projectile` physics motion — correctness of the "real" gameplay loop rests entirely on manual verification. → **Mitigation**: consistent with this project's existing precedent (Status/HealthBar were handled the same way); Step 10 explicitly walks through every scene/physics-dependent AC rather than assuming it works.

## Estimated Complexity
**Medium** — mirrors the Status feature's component/pipeline pattern (low complexity on its own), but this feature also introduces an entirely new mechanism for the project (collision layers, `Area2D` hit detection, groups, a spawned `Projectile` with its own physics and lifecycle) with no existing precedent to copy directly, and touches both `Player` and `Enemy` scenes plus the composition root (`game.tscn`). The unit-testable surface (Step 3/4) is small and low-risk; most of the real risk and effort is in Steps 5-10 (scene wiring and manual verification of physics/collision behavior).
