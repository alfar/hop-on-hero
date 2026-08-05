## Implementation Complete

### Files Created
- `components/weapon/weapon_component.gd` — `WeaponComponent` base class, `modify_damage(current_damage: int) -> int`
- `components/weapon/fixed_damage_weapon_component.gd` — `FixedDamageWeaponComponent`
- `components/weapon/weapon_trigger.gd` — `WeaponTrigger` base class
- `components/weapon/melee_contact_weapon_trigger.gd` — `MeleeContactWeaponTrigger`
- `components/weapon/timer_weapon_trigger.gd` — `TimerWeaponTrigger`
- `scenes/weapon_system/weapon_system.gd` + `weapon_system.tscn` — `WeaponSystem`
- `scenes/projectile/projectile.gd` + `projectile.tscn` — `Projectile`
- `test/unit/weapon/weapon_component_test.gd`, `fixed_damage_weapon_component_test.gd`, `weapon_system_test.gd`
- `test/integration/weapon/melee_contact_weapon_trigger_test.gd`, `projectile_test.gd`, `timer_weapon_trigger_test.gd`

### Files Modified
- `project.godot` — added named collision layers: `default`(1, unchanged), `player`(2), `enemy`(3), `projectile`(4)
- `scenes/player/player.tscn` — added `HitArea`, `WeaponSystem`, `TimerWeaponTrigger`; `Player.collision_layer = 3` (default+player)
- `scenes/enemy/enemy.tscn` — added `HitArea`, `WeaponSystem`, `MeleeContactWeaponTrigger`; `Enemy.collision_layer = 5` (default+enemy)
- `scenes/enemy/enemy.gd` — `_ready()` calls `add_to_group("enemy")` for `TimerWeaponTrigger` targeting
- `scenes/game.tscn` — `TimerWeaponTrigger.spawn_parent` wired to `Game`'s root via `node_paths` override (mirrors `ActivityManager.spawn_parent`)
- `docs/project.md` — added Godot executable path (earlier session); no changes needed this feature beyond what's tracked in `feature.md`
- `.gutconfig.json` — added `res://test/integration` to `dirs`

### Acceptance Criteria
- [x] AC-01: Passed — `Player`/`Enemy` `HitArea` opposing layers/masks, verified via `melee_contact_weapon_trigger_test.gd`
- [x] AC-02: Passed — `weapon_component_test.gd#test_base_modify_damage_returns_input_unchanged`
- [x] AC-03: Passed — `fixed_damage_weapon_component_test.gd` (2/2)
- [x] AC-04: Passed — `weapon_system_test.gd#test_component_order_affects_the_result`
- [x] AC-05: Passed — `weapon_system_test.gd#test_returns_zero_with_no_components`
- [x] AC-06: Passed — `melee_contact_weapon_trigger_test.gd#test_enemy_colliding_with_player_damages_player_status`
- [x] AC-07: Passed — `melee_contact_weapon_trigger_test.gd#test_melee_trigger_does_not_error_when_colliding_with_a_status_less_body`
- [x] AC-08: Passed — `timer_weapon_trigger_test.gd` (fires-at-nearest + no-enemy-no-op)
- [x] AC-09: Passed — `projectile_test.gd` (movement + damage-and-self-destruct)
- [x] AC-10: Passed — `projectile_test.gd#test_projectile_self_destructs_when_hitting_a_status_less_body`
- [x] AC-11: Passed — `projectile_test.gd#test_projectile_despawns_when_leaving_world_bounds`
- [x] AC-12: Passed — `enemy.tscn` composition, exercised by melee integration tests
- [x] AC-13: Passed — `player.tscn` composition, exercised by timer integration tests
- [x] AC-14: Passed — full unit suite for `WeaponComponent`/`FixedDamageWeaponComponent`/`WeaponSystem`

Full suite: 13 scripts, 50 tests, 50 passing (run 3x consecutively to confirm no flakiness).

### Notes
- **Deviation from plan.md's Step 10**: the plan called for manual/ad-hoc debug-scene verification (matching this project's prior precedent). Mid-implementation the user asked to use GUT for integration testing instead (new `test/integration/` dir, added to `.gutconfig.json`). Switched to real physics-driven GUT integration tests, which is a strictly better outcome — they're repeatable regression coverage instead of throwaway scripts.
- **Real bug found and fixed**: `Player`/`Enemy` `CharacterBody2D`s were never actually placed on the new `player`/`enemy` collision layers — only their separate `HitArea` children were. Since `Area2D.body_entered` only fires for bodies whose own `collision_layer` matches the Area2D's `collision_mask`, melee contact detection silently never worked. Fixed by setting `Player.collision_layer = 3` (default+player) and `Enemy.collision_layer = 5` (default+enemy).
- **Real bug found and fixed**: `HitArea` shapes were originally sized identically to each entity's physical `CollisionShape2D`. When two physically-colliding `CharacterBody2D`s fully overlapped, Godot's `move_and_slide()` depenetration separated them within the same physics step, faster than `Area2D` could report the overlap — so melee contact was never detected in practice, not just in tests. Fixed by enlarging both `HitArea` shapes ~30% beyond their physical counterparts.
- **Test-authoring gotcha (not a source bug)**: several early integration test failures were caused by the test setup, not the implementation — e.g. asserting `HealthComponent.current_health` dropped without accounting for `ShieldComponent`'s default 50-capacity absorbing damage first (existing, correct behavior from the Status feature), and asserting a `Projectile` still existed several frames after spawning near its target, when self-destructing on contact is the correct, intended behavior. Fixed by boosting test damage past shield capacity and repositioning test targets far enough apart to inspect projectiles before they travel far enough to hit anything.
- **GDScript global class cache**: as in the prior testing feature, newly added `class_name` types weren't visible to GUT's headless CLI runner until the project's global script class cache was rebuilt once via `godot --headless --editor --quit`. One-time cost, not a code issue.
- `Status`'s existing `ShieldComponent`/`HealthComponent` pipeline required no changes — `MeleeContactWeaponTrigger`/`Projectile` both route damage through the existing `Status.apply_event(StatusEvent.new("physical_damage", amount))` API exactly as designed.
- Per `feature.md`'s Out of Scope: no inventory system, no movement-affected timer interval, no `TargetingBehavior` abstraction (nearest-enemy targeting is hardcoded in `TimerWeaponTrigger` for now), no projectile lifetime cap beyond world-bounds despawn, no homing projectiles.
