## Implementation Complete

### Files Created
- `test/unit/enemy/enemy_movement_stop_test.gd` — proves swapping to a fresh `MovementBehavior` mid-flight zeroes velocity
- `test/integration/enemy/enemy_death_test.gd` — full death sequence against the real `Enemy` scene (3 tests)

### Files Modified
- `scenes/enemy/enemy.gd` — added `@export var death_fade_duration: float = 1.0`; `_ready()` connects `$Status/HealthComponent.died` to a new `_on_died()`; `_on_died()` swaps `movement_behavior` to a base `MovementBehavior`, disables `$HitArea.monitoring`, tweens `modulate:a` to `0.0` over `death_fade_duration`, then `queue_free()`s the node

### Acceptance Criteria
- [x] AC-01: Passed — `enemy_movement_stop_test.gd` + `enemy_death_test.gd#test_died_stops_movement_and_disables_hit_area_immediately`
- [x] AC-02: Passed — `enemy_death_test.gd#test_died_stops_movement_and_disables_hit_area_immediately`, `#test_dead_enemy_deals_no_further_contact_damage`
- [x] AC-03: Passed — `enemy_death_test.gd#test_died_fades_out_and_frees_the_enemy`
- [x] AC-04: Passed — `enemy_death_test.gd#test_died_fades_out_and_frees_the_enemy`
- [x] AC-05: Passed — `enemy_death_test.gd#test_died_stops_movement_and_disables_hit_area_immediately` (asserted before any `await`)
- [x] AC-06: Satisfied by construction — only `enemy.gd` changed; `player.gd`/`Status`/`HealthComponent` untouched
- [x] AC-07: Passed — unit test + 3 integration tests

Full suite: 16 scripts, 56 tests, 56 passing (run twice consecutively, no flakiness).

### Notes
- No deviations from `plan.md`. All 4 steps implemented exactly as planned; no new classes, no changes to `HealthComponent`/`Status`/`MeleeContactWeaponTrigger`.
- No global script class cache rebuild was needed this time (no new `class_name` introduced), unlike prior features.
- `_on_died()` performs movement-stop and `HitArea` disabling synchronously (verified same-frame in tests), then `await`s the tween before `queue_free()` — matches AC-05's "begins within the same frame" requirement, since only the fade's *completion* is asynchronous.
