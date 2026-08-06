# Implementation Plan: Enemy Death Sequence (Stop, Disable, Fade, Free)

## Overview
Add a single new method to `scenes/enemy/enemy.gd` that reacts to `HealthComponent.died`, wired up in `_ready()`. The reaction performs four steps in order — swap `movement_behavior` to a stopped state, disable `HitArea` monitoring, tween `modulate.a` to `0`, then `queue_free()` — all inside `enemy.gd` with no new classes, scenes, or components, per `feature.md`'s Enemy-only scope decision. No changes to `HealthComponent`, `Status`, `MeleeContactWeaponTrigger`, or `MovementBehavior` are needed; this is purely a new listener.

## Architecture Decisions
- **No new class/component**: the death sequence is ~10 lines of script-level reaction in `enemy.gd`, not extracted into a reusable behavior/resource. Matches `feature.md`'s explicit "Enemy-only for now" scope decision — a shared death-behavior abstraction is deferred until Player (or another entity type) actually needs equivalent handling, avoiding speculative generalization.
- **`movement_behavior = MovementBehavior.new()`, not a boolean "is_dead" flag branching `_physics_process()`**: keeps `_physics_process()` completely unchanged (it already calls `movement_behavior.get_velocity(position)` every frame), consistent with the project's existing strategy-pattern convention — "stopped" is just another `MovementBehavior`, not a special case.
- **`HitArea.monitoring = false`, not removing/freeing `HitArea` or `MeleeContactWeaponTrigger`**: the simplest way to stop new contact-damage events without touching the Weapon System feature's existing wiring (`hit_area`/`weapon_system` `node_paths`, signal connections) — no risk of dangling references before `queue_free()` runs.
- **`create_tween()` for the fade**: Godot's standard, recommended tweening API (introduced in Godot 4, replacing the old `Tween` node). This is the project's first use of any tween — establishes the pattern for future visual-effect work rather than hand-rolling a `_process()`-based lerp.
- **Single `_on_died()` handler doing all four steps synchronously (movement, `HitArea`, tween-start) before `await`ing the tween's completion, then `queue_free()`**: keeps the whole sequence in one readable method, matches AC-05's "all begins within the same frame" requirement (only the tween's completion, not its start, is deferred).

## Implementation Steps

### Step 1: Wire up the died signal and implement the death sequence
- [x] Modify `scenes/enemy/enemy.gd`:
  - Add `@export var death_fade_duration: float = 1.0`.
  - In `_ready()` (already exists for `add_to_group("enemy")`), also connect `$Status/HealthComponent.died` to a new `_on_died()` method.
  - Implement `_on_died() -> void`:
    - `movement_behavior = MovementBehavior.new()`
    - `$HitArea.monitoring = false`
    - `var tween := create_tween()`
    - `tween.tween_property(self, "modulate:a", 0.0, death_fade_duration)`
    - `await tween.finished`
    - `queue_free()`
- Files: `scenes/enemy/enemy.gd` (modified)

### Step 2: Unit test — movement stop logic
- [x] Create `test/unit/enemy/enemy_movement_stop_test.gd` (new `test/unit/enemy/` category folder, mirroring the `scenes/enemy/` source location per this project's test-placement convention): verifies that replacing a `MovementBehavior`-holding object's `movement_behavior` with a fresh base `MovementBehavior` instance makes `get_velocity()` return `Vector2.ZERO` regardless of what the prior behavior was (e.g. swap out a `TargetMovementBehavior` mid-flight, confirm the new behavior's `get_velocity()` returns zero). This isolates the "MovementBehavior.new() means stopped" contract as pure logic, without needing a live `Enemy` scene instance.
- Files: `test/unit/enemy/enemy_movement_stop_test.gd` (created)

### Step 3: Integration test — full death sequence against the real Enemy scene
- [x] Create `test/integration/enemy/enemy_death_test.gd`: instances the real `scenes/enemy/enemy.tscn`, sets `death_fade_duration` to a short value (e.g. `0.1`) for fast test execution, then:
  - Emits/triggers `died` on the enemy's `$Status/HealthComponent` (either via `health_component.died.emit()` directly, or by driving `HealthComponent` to `0` health via `apply_event()` — prefer emitting `died` directly, since this feature's own logic doesn't care how `died` fired, only that it reacts correctly).
  - Asserts `movement_behavior` is a `MovementBehavior` instance (base class, not a subclass) immediately after the signal fires.
  - Asserts `$HitArea.monitoring == false` immediately after the signal fires.
  - Waits out `death_fade_duration` (e.g. `wait_seconds(0.15)`), then asserts the enemy node is no longer in the tree / `is_queued_for_deletion()` or `not is_instance_valid(enemy)`.
  - A second test verifies a live `Player`/`HitArea` overlapping a dead (already-faded-but-not-yet-freed, or mid-fade) enemy's `HitArea` does not deal further contact damage — reuses the `WeaponTestHelpers`/collision-approach patterns already established in `test/integration/weapon/melee_contact_weapon_trigger_test.gd`.
- Files: `test/integration/enemy/enemy_death_test.gd` (created)

### Step 4: Full suite verification
- [x] Run the full GUT suite headlessly (`godot --headless -s addons/gut/gut_cmdln.gd -gexit`) and confirm all tests (existing + new) pass, run at least twice consecutively to rule out flakiness (consistent with how the Weapon System feature's integration tests were verified). Result: 56/56 passing, stable across 2 consecutive runs.
- [x] Rebuild the project's global script class cache (`godot --headless --editor --quit`) if any new `class_name` is introduced (not expected — this feature adds no new classes) or if GUT fails to resolve `MovementBehavior`/`Enemy` in the new test files. Not needed — no new `class_name` was introduced, and all new test files resolved existing types on the first run without any cache issues.
- Files: none (verification step)

## Acceptance Criteria Mapping
| AC | Verified By |
|----|-------------|
| AC-01 | `test/integration/enemy/enemy_death_test.gd` (movement_behavior replacement assertion) + `test/unit/enemy/enemy_movement_stop_test.gd` (pure-logic proof of the zero-velocity contract) |
| AC-02 | `test/integration/enemy/enemy_death_test.gd` (`HitArea.monitoring == false` assertion + no-further-damage-on-overlap test) |
| AC-03 | `test/integration/enemy/enemy_death_test.gd` (`modulate.a` reaches `0.0` after waiting out `death_fade_duration`) |
| AC-04 | `test/integration/enemy/enemy_death_test.gd` (node freed/invalid after the fade completes) |
| AC-05 | `test/integration/enemy/enemy_death_test.gd` (movement_behavior + `HitArea.monitoring` assertions taken immediately after `died` fires, same frame, before any `await`) |
| AC-06 | Not applicable to automated testing — satisfied by construction, since this feature only adds a signal connection inside `enemy.gd`; `player.gd`/`Status`/`HealthComponent` are untouched. No test needed beyond confirming (via code review) that no shared code path was introduced. |
| AC-07 | Step 2 (unit) + Step 3 (integration) collectively |

## Risks & Mitigations
- **Risk**: `await tween.finished` inside `_on_died()` means `_on_died()` itself doesn't return until the fade completes — if `HealthComponent.died` is ever connected to by anything else in the future expecting a synchronous handler, this could introduce unexpected async ordering. → **Mitigation**: not a concern for this feature (only `Enemy` connects to `died`), and GDScript signal handlers are allowed to be `async`-style (using `await`) without blocking other connected handlers — Godot fires all connected slots regardless of whether one of them awaits internally.
- **Risk**: Tests using very short `death_fade_duration` values (e.g. `0.1s`) to keep test runtime low could be flaky if a single physics/process frame takes longer than expected under CI/headless load. → **Mitigation**: use a still-short-but-comfortable margin (e.g. wait `0.15`-`0.2`s for a `0.1s` tween) and GUT's own `wait_seconds`/`wait_physics_frames` helpers, which are frame-accurate rather than wall-clock sleeps.
- **Risk**: If a future feature reintroduces a reason to keep a "dead" enemy in the tree longer (e.g. death animation beyond a fade, loot drop timing), this straight-line `_on_died()` → `queue_free()` sequence will need revisiting. → **Mitigation**: explicitly out of scope per `feature.md`; no action needed now, flagged only for awareness.
- **Risk**: `$HitArea` and `$Status/HealthComponent` are accessed by hardcoded relative `NodePath`-style `$` lookups in `enemy.gd`, which will silently break (null reference at runtime) if `enemy.tscn`'s node names/structure ever change. → **Mitigation**: this matches the existing convention already used elsewhere in this codebase (e.g. `HealthBar.status = NodePath("../Status")`), so no new risk is introduced beyond what already exists; the new integration test (Step 3) would catch a broken reference immediately via a runtime error.

## Estimated Complexity
**Low** — a single new method in an already-simple entity script, no new classes/scenes, reusing entirely existing patterns (`MovementBehavior`, `HitArea.monitoring`, `queue_free()`) plus one new but standard Godot API (`create_tween()`). The bulk of the effort is in the test coverage (Steps 2-3), not the implementation itself (Step 1).
