# Implementation Plan: Game Modes for ActivityManager

## Overview
Introduce two new `Resource` strategy hierarchies — `GameMode` (scheduling + win-condition policy, one per round) and `ActivityGate` (per-`Activity` advance condition) — and rewire `ActivityManager` around a single `_physics_process` poll loop instead of its current one-shot `Timer`. Add weighted random activity selection. Extend `GameEvents.round_ended` with a `RoundOutcome` enum (`LOST`/`WON`/`PYRRHIC_VICTORY`) and thread it through `Player`, `Game`, and `SummaryScreen`. Resolve the feature spec's open "simultaneous win/loss" question with a concrete mutual-awareness + single-emission-guard mechanism, detailed in Architecture Decisions below.

## Architecture Decisions

- **`GameMode` base class defaults ARE `EndlessGameMode`'s behavior.** `GameMode.should_schedule_next_activity` returns `true` and `GameMode.is_round_won` returns `false` unconditionally in the base class. `EndlessGameMode` is therefore an empty subclass (`class_name EndlessGameMode extends GameMode`, no overrides) — it exists as a named, explicit choice for clarity/discoverability in the editor, not because it needs different code from the base. This keeps `PresetGameMode` the only class with real logic to test.

- **Weighted selection lives as a private method on `ActivityManager`** (`_pick_weighted_activity() -> Activity`), not a separate class. Feature.md doesn't call for a standalone abstraction here, and introducing one would be premature — `ActivityManager` already owns `activities`/`rng`, so the cumulative-weight-walk algorithm belongs there directly: sum each activity's `max(weight, 0.0)`, draw `rng.randf_range(0.0, total)`, walk cumulative sums to find the first activity whose cumulative weight exceeds the draw. A non-positive total is treated exactly like today's empty-pool case.

- **Resolving FR-09's "simultaneous win/loss" open question**: `Player` and `ActivityManager` each independently poll their own end condition every physics frame (as already specified), but each one also checks the *other's* condition at its own decision point, and a single per-round `ActivityManager.round_over: bool` guard (reset naturally every round since `ActivityManager` is torn down and recreated on scene reload, unlike an autoload) ensures only one of them actually emits `GameEvents.round_ended`:
  - `Player` gains `var is_dead: bool = false`, set `true` at the very top of `_on_died()` — before the death animation even starts — so any other system can synchronously observe "the player is dying" well before `Player`'s own animation-gated emission happens.
  - `ActivityManager`'s per-frame win-check, upon finding `game_mode.is_round_won(...) == true`, sets `round_over = true` and checks whether the player (found via the existing `"player"` group) has `is_dead == true` at that instant — if so, it emits `PYRRHIC_VICTORY` instead of plain `WON`.
  - `Player._on_died()`, after its animation `await` completes, checks `activity_manager.round_over` first. If `ActivityManager` already resolved the round (including the Pyrrhic case above), `Player` does nothing further — no double emission. Otherwise `Player` sets `round_over = true` itself and checks `game_mode.is_round_won(...)` directly — if it's true (a win became true during the animation wait but `ActivityManager`'s own poll hasn't run yet this exact frame), it emits `PYRRHIC_VICTORY`; otherwise plain `LOST`.
  
  This is the only correct design given `Player._on_died()`'s existing multi-frame `await animation_finished` delay (confirmed by reading the current code: the emission happens well after health hits zero, not in the same frame) — relying on incidental node-processing order without this mutual check would make the outcome depend on unrelated animation durations. `Player` reaches `ActivityManager` via `get_tree().get_first_node_in_group("game").get_node_or_null("ActivityManager")`, mirroring the exact lookup pattern `Player` already uses for `get_time_played_seconds()` (defensive `null` fallback preserved: no `game`/`ActivityManager` found → `LOST`, matching today's "no Game ancestor" test case).

- **The "skip polling for one physics frame after triggering an activity" rule (FR-06/FR-08) is unified across both the gate poll and the win-check poll**, not just the gate. If `ActivityManager` triggers a new activity mid-`_physics_process` (because the previous gate just reported ready), it returns immediately from that frame's processing rather than falling through to the win-check — otherwise a `PresetGameMode` round whose *last* activity happens to spawn an enemy via a deferred `add_child` could see the `"enemy"` group as still-empty and falsely declare a win in the same frame, before that enemy exists. A single `_skip_poll_this_frame` flag (set whenever an activity is triggered, cleared and short-circuited at the top of the next `_physics_process` call) covers both the gate-start case and the win-check.

- **`Activity.gate` and `ActivityManager.game_mode` get inline `Resource` defaults** (`@export var gate: ActivityGate = TimerActivityGate.new()`, `@export var game_mode: GameMode = EndlessGameMode.new()`) rather than being left null and defaulting in code. This is standard Godot practice for exported `Resource` fields and means `game.tscn` doesn't need to explicitly wire either field to preserve current behavior, and bare `Activity.new()`/`ActivityManager.new()` instances in tests get working defaults for free (matching how existing tests already construct bare nodes).

- **New test subfolder `test/integration/activities/`** (mirroring `components/activities/`) holds the new `PresetGameMode`/`EnemiesDefeatedActivityGate`/win-outcome tests that need a live scene tree (group queries), per the project's existing unit-vs-integration split. Pure-logic pieces (`EndlessGameMode`, `TimerActivityGate`, weighted selection) stay under `test/unit/activities/`, extending the existing `activity_manager_test.gd`.

## Implementation Steps

### Step 1: `GameEvents.RoundOutcome` and `round_ended` Signature
- [x] Add `enum RoundOutcome { LOST, WON, PYRRHIC_VICTORY }` to `components/events/game_events.gd`.
- [x] Change `signal round_ended(time_played_seconds: float)` to `signal round_ended(time_played_seconds: float, outcome: RoundOutcome)`.
- Files: `components/events/game_events.gd`

### Step 2: `GameMode`, `EndlessGameMode`, `PresetGameMode`
- [x] Create `components/activities/game_mode.gd`:
  ```gdscript
  class_name GameMode
  extends Resource

  func should_schedule_next_activity(activities_triggered: int) -> bool:
      return true

  func is_round_won(activities_triggered: int, spawn_parent: Node) -> bool:
      return false
  ```
- [x] Create `components/activities/endless_game_mode.gd`:
  ```gdscript
  class_name EndlessGameMode
  extends GameMode
  ```
- [x] Create `components/activities/preset_game_mode.gd`:
  ```gdscript
  class_name PresetGameMode
  extends GameMode

  @export var activity_count: int = 5

  func should_schedule_next_activity(activities_triggered: int) -> bool:
      return activities_triggered < activity_count

  func is_round_won(activities_triggered: int, spawn_parent: Node) -> bool:
      if activities_triggered < activity_count:
          return false
      return spawn_parent.get_tree().get_nodes_in_group("enemy").is_empty()
  ```
- Files: `components/activities/game_mode.gd` (new), `components/activities/endless_game_mode.gd` (new), `components/activities/preset_game_mode.gd` (new)

### Step 3: `ActivityGate`, `TimerActivityGate`, `EnemiesDefeatedActivityGate`
- [x] Create `components/activities/activity_gate.gd`:
  ```gdscript
  class_name ActivityGate
  extends Resource

  func start(rng: RandomNumberGenerator, spawn_parent: Node) -> void:
      pass

  func is_ready(elapsed_time: float, spawn_parent: Node) -> bool:
      return true
  ```
- [x] Create `components/activities/timer_activity_gate.gd`:
  ```gdscript
  class_name TimerActivityGate
  extends ActivityGate

  @export var wait_min: float = 20.0
  @export var wait_max: float = 40.0

  var _target_duration: float = 0.0

  func start(rng: RandomNumberGenerator, spawn_parent: Node) -> void:
      _target_duration = rng.randf_range(wait_min, wait_max)

  func is_ready(elapsed_time: float, spawn_parent: Node) -> bool:
      return elapsed_time >= _target_duration
  ```
- [x] Create `components/activities/enemies_defeated_activity_gate.gd`:
  ```gdscript
  class_name EnemiesDefeatedActivityGate
  extends ActivityGate

  func is_ready(elapsed_time: float, spawn_parent: Node) -> bool:
      return spawn_parent.get_tree().get_nodes_in_group("enemy").is_empty()
  ```
- Files: `components/activities/activity_gate.gd` (new), `components/activities/timer_activity_gate.gd` (new), `components/activities/enemies_defeated_activity_gate.gd` (new)

### Step 4: `Activity` Base Class
- [x] In `components/activities/activity.gd`: remove `next_interval_min`, `next_interval_max`, `get_next_interval(rng)`. Add:
  ```gdscript
  @export var gate: ActivityGate = TimerActivityGate.new()
  @export var weight: float = 1.0
  ```
- Files: `components/activities/activity.gd`

### Step 5: `ActivityManager` Rewrite
- [x] In `components/activities/activity_manager.gd`, remove `_timer: Timer` and `_on_timeout()`; remove `_ready()` (nothing left to set up). Add:
  ```gdscript
  @export var game_mode: GameMode = EndlessGameMode.new()

  var round_over: bool = false
  var activities_triggered: int = 0

  var _current_gate: ActivityGate
  var _gate_elapsed_time: float = 0.0
  var _skip_poll_this_frame: bool = false

  func start() -> void:
      _trigger_next_activity()

  func _physics_process(delta: float) -> void:
      if _skip_poll_this_frame:
          _skip_poll_this_frame = false
          return

      if _current_gate != null:
          _gate_elapsed_time += delta
          if _current_gate.is_ready(_gate_elapsed_time, spawn_parent):
              _trigger_next_activity()
              return

      if not round_over and game_mode.is_round_won(activities_triggered, spawn_parent):
          _declare_win()

  func _trigger_next_activity() -> void:
      if not game_mode.should_schedule_next_activity(activities_triggered):
          _current_gate = null
          return

      var activity := _pick_weighted_activity()
      if activity == null:
          push_error("ActivityManager: activities array is empty or has no positive weight, cannot schedule an activity.")
          _current_gate = null
          return

      activity.execute(rng, world.world_size, spawn_parent)
      activities_triggered += 1

      _current_gate = activity.gate
      _gate_elapsed_time = 0.0
      _current_gate.start(rng, spawn_parent)
      _skip_poll_this_frame = true

  func _pick_weighted_activity() -> Activity:
      var total_weight := 0.0
      for activity in activities:
          total_weight += max(activity.weight, 0.0)
      if total_weight <= 0.0:
          return null

      var roll := rng.randf_range(0.0, total_weight)
      var cumulative := 0.0
      for activity in activities:
          cumulative += max(activity.weight, 0.0)
          if roll < cumulative:
              return activity
      return activities[-1]

  func _declare_win() -> void:
      round_over = true
      var player := spawn_parent.get_tree().get_first_node_in_group("player")
      var outcome := GameEvents.RoundOutcome.PYRRHIC_VICTORY if (player != null and player.is_dead) else GameEvents.RoundOutcome.WON
      var game := spawn_parent.get_tree().get_first_node_in_group("game")
      var time_played_seconds := game.get_time_played_seconds() if game != null else 0.0
      GameEvents.round_ended.emit(time_played_seconds, outcome)
  ```
- Files: `components/activities/activity_manager.gd`

### Step 6: `Player` — `is_dead` and Outcome Resolution
- [x] In `scenes/player/player.gd`: add `var is_dead: bool = false`, set `true` as the first line of `_on_died()`. Replace the tail of `_on_died()` (the `get_tree().get_first_node_in_group("game")` block and `GameEvents.round_ended.emit(...)` call) with a call to a new `_resolve_round_outcome()`:
  ```gdscript
  func _on_died() -> void:
      is_dead = true
      movement_behavior = StayStillMovementBehavior.new()
      _timer_weapon_trigger.stop()

      _animation_player.play("death")
      await _animation_player.animation_finished

      _resolve_round_outcome()

  func _resolve_round_outcome() -> void:
      var game := get_tree().get_first_node_in_group("game")
      if game == null:
          GameEvents.round_ended.emit(0.0, GameEvents.RoundOutcome.LOST)
          return

      var activity_manager: ActivityManager = game.get_node_or_null("ActivityManager")
      if activity_manager == null or activity_manager.round_over:
          return

      activity_manager.round_over = true
      var won := activity_manager.game_mode.is_round_won(activity_manager.activities_triggered, activity_manager.spawn_parent)
      var outcome := GameEvents.RoundOutcome.PYRRHIC_VICTORY if won else GameEvents.RoundOutcome.LOST
      GameEvents.round_ended.emit(game.get_time_played_seconds(), outcome)
  ```
  Note: if `activity_manager == null`, this silently does not emit `round_ended` at all — this matches the "no Game ancestor" fallback only when `game` itself is also null; a `game` node that exists without an `ActivityManager` child is not a real scenario in this project's only composition root (`game.tscn` always has one), so this is a defensive no-op, not expected to be hit outside of a contrived test.
- Files: `scenes/player/player.gd`

### Step 7: `SummaryScreen` and `Game` — Outcome Display
- [x] In `scenes/summary_screen/summary_screen.tscn`: add a new `Label` node `OutcomeLabel` as the first child of `CenterContainer/VBoxContainer` (above `TimeLabel`), `horizontal_alignment = 1`, placeholder `text = "You Died"`.
- [x] In `scenes/summary_screen/summary_screen.gd`: add `@onready var outcome_label: Label = $CenterContainer/VBoxContainer/OutcomeLabel`. Change `show_summary`:
  ```gdscript
  func show_summary(time_played_seconds: float, outcome: GameEvents.RoundOutcome) -> void:
      var minutes := int(time_played_seconds) / 60
      var seconds := int(time_played_seconds) % 60
      time_label.text = "%02d:%02d" % [minutes, seconds]
      outcome_label.text = _outcome_text(outcome)
      visible = true

  func _outcome_text(outcome: GameEvents.RoundOutcome) -> String:
      match outcome:
          GameEvents.RoundOutcome.WON:
              return "You Won!"
          GameEvents.RoundOutcome.PYRRHIC_VICTORY:
              return "Pyrrhic Victory!"
          _:
              return "You Died"
  ```
- [x] In `scenes/game.gd`: change `_on_round_ended(time_played_seconds: float)` to `_on_round_ended(time_played_seconds: float, outcome: GameEvents.RoundOutcome)`, forwarding `outcome` to `show_summary`.
- Files: `scenes/summary_screen/summary_screen.tscn`, `scenes/summary_screen/summary_screen.gd`, `scenes/game.gd`

### Step 8: Migrate `game.tscn`'s Configured Activities
- [x] Add an `ext_resource` for `timer_activity_gate.gd`.
- [x] Add two new `sub_resource` blocks (one per existing activity instance), each a `TimerActivityGate` with `wait_min = 5.0` / `wait_max = 10.0` (the exact values currently on `Resource_boss_activity`/`Resource_item_drop_activity`'s `next_interval_min`/`next_interval_max`).
- [x] On `Resource_boss_activity` and `Resource_item_drop_activity`: remove `next_interval_min`/`next_interval_max` lines, add `gate = SubResource(...)` pointing at each one's new gate sub-resource.
- [x] Leave `ActivityManager`'s node block in `game.tscn` without an explicit `game_mode` override — it uses the script's `EndlessGameMode` default, preserving current gameplay exactly.
- Files: `scenes/game.tscn`

### Step 9: Update Existing Tests for Changed Contracts
- [x] `test/unit/events/game_events_test.gd`: update both `GameEvents.round_ended.emit(...)` calls and connected callables to include/accept the new `outcome` parameter (e.g. `emit(42.0, GameEvents.RoundOutcome.LOST)`, callable `func(time, outcome): received.append([time, outcome])`).
- [x] `test/integration/player/player_death_test.gd`: update `test_died_emits_round_ended_with_zero_time_when_no_game_node_exists`'s callable/assertion to expect `[[0.0, GameEvents.RoundOutcome.LOST]]` (or equivalent two-arg capture).
- [x] `test/unit/activities/activity_manager_test.gd`: replace `test_start_triggers_first_activity_using_injected_rng` (which asserts on the now-removed `_timer`) with tests against the new poll-based flow — see Step 10 for the full new test list; the existing file's single test is superseded, not preserved as-is.
- [x] `test/integration/weapon/game_scene_wiring_test.gd`: no code changes expected (`Activity.execute`'s signature is unchanged, `activities` array shape is unchanged) — re-run to confirm.
- [x] `test/unit/round/round_initializer_test.gd`, `test/integration/game/round_end_test.gd`: no direct signature dependency on `round_ended`'s new parameter (the former doesn't touch it; the latter goes through `Game._on_round_ended`, updated in Step 7) — re-run to confirm no regressions, in particular that `Player`'s new `ActivityManager` lookup doesn't break `round_end_test.gd`'s full-`game.tscn` death flow.
- Files: `test/unit/events/game_events_test.gd`, `test/integration/player/player_death_test.gd`, `test/unit/activities/activity_manager_test.gd`

### Step 10: New Tests
- [x] `test/unit/activities/endless_game_mode_test.gd`: `should_schedule_next_activity` returns `true` for several `activities_triggered` values; `is_round_won` returns `false` regardless of input (a bare `Node.new()` `add_child_autofree`'d as a stand-in `spawn_parent` is enough since `is_round_won` never touches it).
- [x] `test/integration/activities/preset_game_mode_test.gd` (new folder): `should_schedule_next_activity` cuts off at `activity_count`; `is_round_won` is `false` before the count is reached (regardless of enemy state), `false` after the count is reached while a dummy `Node2D` tagged `"enemy"` is still in the tree, and `true` once that dummy is removed — using a plain `add_child_autofree`'d `Node` as `spawn_parent` and manually adding/freeing group members.
- [x] `test/unit/activities/timer_activity_gate_test.gd`: seed a `RandomNumberGenerator`, call `start(rng, null)`, assert `is_ready` is `false` just under the picked duration and `true` at/after it; assert the picked duration falls within `wait_min`/`wait_max`.
- [x] `test/integration/activities/enemies_defeated_activity_gate_test.gd` (new folder): `is_ready` is `false` while a dummy `"enemy"`-grouped node exists, `true` once it's removed.
- [x] `test/unit/activities/activity_manager_test.gd` (rewritten — replaces the removed timer-based test):
  - `test_start_executes_the_first_activity_and_starts_its_gate`: a spy `Activity` (small inline `class` in the test file) recording `execute()` calls; assert it was called exactly once after `start()`, and `activities_triggered == 1`.
  - `test_advances_once_the_current_gate_reports_ready`: a gate whose `is_ready` becomes true after a controlled number of `_physics_process` ticks (`wait_physics_frames`); assert a second activity fires only after that.
  - `test_does_not_advance_before_the_gate_is_ready`: same setup, asserting no second activity fires on earlier frames.
  - `test_stops_scheduling_once_game_mode_says_so`: `PresetGameMode` with `activity_count = 1`; after the first activity's gate completes, assert no further activity ever triggers even after many more physics frames.
  - `test_declares_win_and_emits_round_ended_once_game_mode_reports_won`: a fake `GameMode` whose `is_round_won` returns `true` immediately; assert `GameEvents.round_ended` fires exactly once with `outcome == WON` (no player/game node present, so the defensive `PYRRHIC_VICTORY`/time-lookup paths correctly fall back to `WON`/`0.0`).
  - `test_pick_weighted_activity_favors_higher_weight_with_a_fixed_seed`: two spy activities with distinct `weight`s, a fixed `rng.seed`, asserting `_pick_weighted_activity()` returns the expected pre-determined sequence across several consecutive calls (per AC-12/13's deterministic-not-statistical guidance).
  - `test_pick_weighted_activity_treats_non_positive_total_weight_as_empty`: both activities' `weight = 0`; assert `_pick_weighted_activity()` returns `null` and (via `start()`) `push_error` fires with no activity executed (matching the existing empty-pool error path's observable behavior).
- [x] `test/integration/activities/enemies_defeated_gate_deferred_spawn_test.gd` (new folder) — regression test for FR-06's race: an inline fake `Activity` subclass whose `execute()` does `spawn_parent.add_child.call_deferred(dummy_enemy)` (mirroring `BossActivity`'s real pattern), configured with `EnemiesDefeatedActivityGate`; assert the gate is **not** ready on the same physics frame the activity executed (before the deferred `add_child` resolves), and **is** ready once the dummy is later removed from the group.
- [x] `test/integration/activities/round_outcome_test.gd` (new folder) — full `game.tscn`-based outcome tests:
  - `test_preset_game_mode_wins_once_count_reached_and_enemies_cleared` (AC-03/AC-04): swap `ActivityManager.game_mode` to a `PresetGameMode` with a small count and dummy enemies; assert no `round_ended` while an enemy remains, then `round_ended(WON, ...)` once the last is removed.
  - `test_same_seed_reproduces_the_same_activity_sequence_under_preset_mode` (AC-07): two separate `game.tscn` loads with the same staged seed and a `PresetGameMode`; assert both produce the same count/order of activity picks (via spy activities or by asserting identical resulting world state).
  - `test_simultaneous_win_and_player_death_resolves_as_pyrrhic_victory` (AC-08): force both `game_mode.is_round_won(...)` to become true and the player's `HealthComponent.died` to fire within the same physics-frame window; assert `round_ended` fires **exactly once** with `outcome == PYRRHIC_VICTORY`.
- Files (new): `test/unit/activities/endless_game_mode_test.gd`, `test/unit/activities/timer_activity_gate_test.gd`, `test/integration/activities/preset_game_mode_test.gd`, `test/integration/activities/enemies_defeated_activity_gate_test.gd`, `test/integration/activities/enemies_defeated_gate_deferred_spawn_test.gd`, `test/integration/activities/round_outcome_test.gd`

## Acceptance Criteria Mapping
| AC | Verified By |
|----|-------------|
| AC-01: default EndlessGameMode+TimerActivityGate behaves like today | `activity_manager_test.gd#test_advances_once_the_current_gate_reports_ready` + `#test_does_not_advance_before_the_gate_is_ready` (default gate/mode never overridden in these tests) |
| AC-02: PresetGameMode schedules exactly N activities | `activity_manager_test.gd#test_stops_scheduling_once_game_mode_says_so` |
| AC-03: round_ended fires WON once count reached + enemies cleared | `round_outcome_test.gd#test_preset_game_mode_wins_once_count_reached_and_enemies_cleared` |
| AC-04: no premature win while enemies remain | same test, asserting no emission mid-scenario |
| AC-05: Player's ordinary death path still emits LOST; existing round_end_test.gd tests pass | `player_death_test.gd` (updated), full `round_end_test.gd` suite re-run |
| AC-06: SummaryScreen shows 3 distinct messages | new `summary_screen_test.gd`-style assertions or covered inline in `round_outcome_test.gd`/`round_end_test.gd` reading `OutcomeLabel.text` |
| AC-07: same seed reproduces the same PresetGameMode activity sequence | `round_outcome_test.gd#test_same_seed_reproduces_the_same_activity_sequence_under_preset_mode` |
| AC-08: simultaneous win+loss resolves as PYRRHIC_VICTORY, exactly once | `round_outcome_test.gd#test_simultaneous_win_and_player_death_resolves_as_pyrrhic_victory` |
| AC-09: different Activity instances can use different gates in the same pool | `activity_manager_test.gd#test_advances_once_the_current_gate_reports_ready` using two differently-gated spy activities |
| AC-10: EnemiesDefeatedActivityGate doesn't false-positive on a deferred spawn's own frame | `enemies_defeated_gate_deferred_spawn_test.gd` |
| AC-11: TimerActivityGate reproduces the old interval range | `timer_activity_gate_test.gd` |
| AC-12: weighted selection biases toward higher weight (deterministic seed) | `activity_manager_test.gd#test_pick_weighted_activity_favors_higher_weight_with_a_fixed_seed` |
| AC-13: default weight=1.0 stays unbiased | same test file, default-weight case |
| AC-14: non-positive total weight behaves like empty pool | `activity_manager_test.gd#test_pick_weighted_activity_treats_non_positive_total_weight_as_empty` |

## Risks & Mitigations
- **Risk**: The `Player`/`ActivityManager` mutual tie-break logic (Architecture Decisions) is the most novel, least-precedented part of this plan — a subtle bug could cause a missed `PYRRHIC_VICTORY`, a double `round_ended` emission, or a hard crash on a null lookup. → **Mitigation**: `round_outcome_test.gd#test_simultaneous_win_and_player_death_resolves_as_pyrrhic_victory` directly exercises this path with deterministic dummy state (not relying on real animation timing), and `_resolve_round_outcome()`/`_declare_win()` both use defensive `null` checks matching existing fallback conventions.
- **Risk**: Migrating `game.tscn`'s hand-tuned `next_interval_min`/`next_interval_max` (both currently `5.0`/`10.0`) into new `TimerActivityGate` sub-resources could silently lose or misapply tuning if the `.tscn` edit is done carelessly. → **Mitigation**: Step 8 records the exact current values to carry over; `AC-11`'s test independently verifies `TimerActivityGate`'s own min/max contract regardless of the `.tscn` migration's correctness.
- **Risk**: Replacing `activities[rng.randi() % activities.size()]` with a weighted cumulative-sum draw consumes the seeded `rng` differently, so any previously-recorded seed will now produce a *different* (but still fully deterministic) sequence of activities than before this feature. → **Mitigation**: no persisted replay data exists in this project; this is called out explicitly in `feature.md`'s AC-13 as an accepted, non-regression side effect.
- **Risk**: Moving from a `Timer`/`timeout` signal to per-`_physics_process` polling changes timing granularity from "exact `Timer` callback" to "next physics tick after the target elapses" — a sub-frame timing difference, immaterial to gameplay but worth noting if any future test asserts exact sub-frame timing. → **Mitigation**: none needed; NFR already accepts this.

## Estimated Complexity
**High.** This touches `ActivityManager`'s core scheduling loop (a full rewrite from `Timer`-driven to `_physics_process`-driven), introduces six new `Resource` classes across two new strategy hierarchies, changes a signal signature consumed by three existing files (`Player`, `Game`, `SummaryScreen`, plus two test files), and requires a genuinely new cross-component synchronization mechanism (the win/loss tie-break) that `feature.md` explicitly left as an open question rather than fully specifying — more design work fell to this planning step than in prior features of similar file-count.
