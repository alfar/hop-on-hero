# Code Review: Weapon System with Melee and Ranged Triggers

## Summary
Solid implementation that correctly mirrors the `Status`/`StatusComponent` pipeline pattern, and the process itself was notably rigorous: two real, non-obvious physics bugs (missing collision-layer assignment on the physical bodies, and `HitArea` shapes sized identically to the physical shapes) were found and fixed via actual GUT integration tests rather than assumed away. All 14 acceptance criteria are covered and pass (50/50 tests, verified stable across repeated runs). Findings below are Minor/Info polish items — none block merging.

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
| [x] | `components/weapon/melee_contact_weapon_trigger.gd:10-14`, `scenes/projectile/projectile.gd:24-26` | Code Duplication / Efficiency | Both call `body.has_node("Status")` and then immediately `body.get_node("Status")` again, doing the same tree lookup twice on every hit. | Cache the result once, e.g. `var status := body.get_node_or_null("Status"); if status: status.apply_event(...)`. **Fixed**: both now use `get_node_or_null("Status")` once. |
| [x] | `test/integration/weapon/melee_contact_weapon_trigger_test.gd:3-11`, `projectile_test.gd:3-7`, `timer_weapon_trigger_test.gd:3-7` | Code Duplication | The `_make_enemy()` helper (load scene, `add_child_autofree`, set a no-op `MovementBehavior`) is copy-pasted near-identically across all three integration test files. | Extract a shared test helper (e.g. `test/integration/weapon/weapon_test_helpers.gd` with a static/class-level function, or a common base `GutTest` subclass) if a fourth weapon integration test file is added; not urgent at only 3 copies. **Fixed**: extracted `WeaponTestHelpers.make_enemy(test_context)` into `test/integration/weapon/weapon_test_helpers.gd`; all three files now call it (the melee-trigger test keeps a thin local wrapper for its extra `damage` override). |
| [x] | `scenes/player/player.tscn:40-41`, `scenes/enemy/enemy.tscn:32-33` | Design | `HitArea.collision_layer` (2 on Player, 4 on Enemy) is now dead configuration — nothing needs to detect the `HitArea` `Area2D` itself as a body, since only the parent `CharacterBody2D`'s own `collision_layer` (added this feature: `3`/`5`) is what the opposing `HitArea`'s `collision_mask` actually matches against. | Either remove `HitArea.collision_layer` entirely (leave at Godot's default `1`, unused) or add a one-line comment noting it's currently inert, to save the next reader from re-deriving the same layer-bit trace this review just did. **Fixed**: removed the dead `collision_layer` line from both `HitArea` nodes; `collision_mask` (the load-bearing property) is unchanged. |

### 🔵 Info / Suggestions

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [ ] | `components/weapon/timer_weapon_trigger.gd:31-42` | Design | `_find_nearest_enemy()` hardcodes "nearest enemy in the `enemy` group" directly in `TimerWeaponTrigger`, exactly as `feature.md`'s Out of Scope anticipated deferring to a future `TargetingBehavior` strategy resource (mirroring `MovementBehavior`). | No action needed now — flagging only so the extraction point is easy to find later, per the feature's own documented intent. |
| [ ] | `scenes/projectile/projectile.gd:9,15-16` | Design | A `Projectile` with `direction == Vector2.ZERO` (e.g. spawned exactly on top of its target, as several tests do) never moves and never trips the world-bounds check, so it would persist indefinitely if it somehow missed on-contact detection; not currently reachable in production (`TimerWeaponTrigger` always computes a real direction toward a live target) but worth knowing if a future caller ever passes a zero vector. | No action needed — `feature.md`'s Out of Scope already excludes general projectile lifetime handling; noting only for awareness. |
| [ ] | `scenes/weapon_system/weapon_system.tscn:1`, `scenes/projectile/projectile.tscn:1` | Style | `load_steps=3` in both files' header doesn't match the actual resource count (2 `ext_resource`/`sub_resource` entries each) — Godot tolerates this and will silently correct it on next editor save, so purely cosmetic. | No action needed; will self-correct next time either scene is opened and saved in the editor. |

## Acceptance Criteria Coverage
| AC | Test | Status |
|----|------|--------|
| AC-01 | `melee_contact_weapon_trigger_test.gd` (exercises `HitArea` layers/masks indirectly via successful contact detection) | ✅ Covered |
| AC-02 | `weapon_component_test.gd#test_base_modify_damage_returns_input_unchanged` | ✅ Covered |
| AC-03 | `fixed_damage_weapon_component_test.gd` (2 tests) | ✅ Covered |
| AC-04 | `weapon_system_test.gd#test_component_order_affects_the_result` | ✅ Covered |
| AC-05 | `weapon_system_test.gd#test_returns_zero_with_no_components` | ✅ Covered |
| AC-06 | `melee_contact_weapon_trigger_test.gd#test_enemy_colliding_with_player_damages_player_status` | ✅ Covered |
| AC-07 | `melee_contact_weapon_trigger_test.gd#test_melee_trigger_does_not_error_when_colliding_with_a_status_less_body` | ✅ Covered |
| AC-08 | `timer_weapon_trigger_test.gd` (`test_fires_at_nearest_enemy_and_spawns_a_projectile`, `test_does_not_fire_when_no_enemy_exists`) | ✅ Covered |
| AC-09 | `projectile_test.gd` (`test_projectile_moves_in_configured_direction`, `test_projectile_damages_target_status_on_contact_and_self_destructs`) | ✅ Covered |
| AC-10 | `projectile_test.gd#test_projectile_self_destructs_when_hitting_a_status_less_body` | ✅ Covered |
| AC-11 | `projectile_test.gd#test_projectile_despawns_when_leaving_world_bounds` | ✅ Covered |
| AC-12 | `scenes/enemy/enemy.tscn` composition, exercised by `melee_contact_weapon_trigger_test.gd` | ✅ Covered |
| AC-13 | `scenes/player/player.tscn` composition, exercised by `timer_weapon_trigger_test.gd` | ✅ Covered |
| AC-14 | Full unit suite (`test/unit/weapon/*`) | ✅ Covered |

## Verdict
- [ ] ✅ Ready to merge
- [x] 🟡 Merge after minor fixes (no re-review needed)
- [ ] 🟠 Requires fixes and re-review
- [ ] 🔴 Do not merge — significant issues found
