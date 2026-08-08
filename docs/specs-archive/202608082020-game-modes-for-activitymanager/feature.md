# Feature: Game Modes for ActivityManager

## Summary
Refactor `ActivityManager` around two independent, swappable `Resource` strategies (mirroring the existing `MovementBehavior`/`Activity` pattern): a `GameMode` that decides whether to keep scheduling activities and whether the round has been won, and an `ActivityGate` — configured per-`Activity` — that decides *when* to advance to the next activity after the current one has executed. Today's behavior (always schedule another activity after a random timer interval) becomes the default combination of `EndlessGameMode` + `TimerActivityGate`. A new `PresetGameMode` schedules a fixed, exported number of activities and wins once that count is reached and every enemy has died. A new `EnemiesDefeatedActivityGate` makes an individual activity wait for every currently-alive enemy to die (rather than a timer) before the next activity fires — enabling wave-like pacing where each wave must be cleared before the next spawns. Activity selection itself also becomes weighted rather than uniform: each `Activity` gains a `weight`, so a pool can be tuned to spawn far more regular enemies than bosses, and fewer item drops than either. Critically, **both the win-check and the advance-condition are owned by the strategy objects, not `ActivityManager`** — a future mode (survive N minutes, protect a structure) or gate (wait for the player to reach a point, wait for a button press) plugs in without `ActivityManager`'s core loop changing. Winning reuses the existing `GameEvents.round_ended` → `SummaryScreen` flow (extended with an outcome enum). If the player dies in the same resolution window the round is won, the round counts as a win — a "Pyrrhic Victory" — surfaced as a distinct label on `SummaryScreen`.

## User Stories
- As a player, I want an endless survival mode (today's behavior, unchanged) where I try to stay alive as long as possible against a never-ending stream of activities.
- As a player, I want a finite mode where a fixed set of activities plays out, and I win once I've cleared every enemy that spawned from them.
- As a player, I want wave-based pacing where the next wave of enemies doesn't spawn until I've cleared the current one, instead of (or in addition to) waiting on a timer.
- As a designer, I want to weight the activity pool so common activities (regular enemy spawns) happen far more often than rare ones (bosses, item drops), without touching each activity's own logic.
- As a developer, I want each game mode to own its own win condition, and each activity to own its own advance condition, so future modes/gates (survive a timer, protect a structure, wait for a button press or a location) don't require changing `ActivityManager`'s core loop.
- As a player, I want a small reward (a "Pyrrhic Victory" label) for the darkly funny edge case of dying at the exact moment I win.

## Functional Requirements

### FR-01: `GameMode` Strategy Resource
Introduce `components/activities/game_mode.gd` (`class_name GameMode`, `extends Resource`), the base class for `ActivityManager`'s scheduling *and win-condition* policy. `ActivityManager` gains `@export var game_mode: GameMode`, defaulting to an `EndlessGameMode` instance so `game.tscn`'s current behavior is preserved unless a scene explicitly overrides it. `GameMode` exposes two independent decisions:
- `should_schedule_next_activity(activities_triggered: int) -> bool` — does scheduling continue?
- `is_round_won(activities_triggered: int, spawn_parent: Node) -> bool` — has this mode's win condition been met? (`spawn_parent` gives tree access, the same way `Activity.execute` already receives it, so future modes can inspect whatever state they need: enemy counts, elapsed time, a tracked structure, etc.)

These two decisions are independent by design: a future "survive N minutes" mode might keep scheduling endlessly while still defining a win condition based on elapsed time, without needing to also bound the activity count.

### FR-02: `EndlessGameMode` (Current Behavior, Extracted)
`components/activities/endless_game_mode.gd`: `should_schedule_next_activity` always returns `true`; `is_round_won` always returns `false`. No win condition exists in this mode — the round only ends via the existing player-death path.

### FR-03: `PresetGameMode` (Fixed Count, Win on Last Enemy Dead)
`components/activities/preset_game_mode.gd` exposes `@export var activity_count: int` (a fixed, non-randomized count). `should_schedule_next_activity(activities_triggered)` returns `activities_triggered < activity_count` — activities themselves are still randomly picked from the existing `activities` pool via the same seeded `rng` as today. `is_round_won(activities_triggered, spawn_parent)` returns `true` only once `activities_triggered >= activity_count` **and** `spawn_parent.get_tree().get_nodes_in_group("enemy")` is empty — guaranteeing the round is never won prematurely between two scheduled activities just because zero enemies happen to be alive at that instant.

### FR-04: `ActivityGate` Strategy Resource (Per-Activity Advance Condition)
Introduce `components/activities/activity_gate.gd` (`class_name ActivityGate`, `extends Resource`), owned per-`Activity` (not per-`ActivityManager` — each activity type picks its own pacing). `Activity` gains `@export var gate: ActivityGate`, defaulting to a `TimerActivityGate` so existing configured activities keep their current timing behavior once migrated (see Technical Scope). `ActivityGate`'s interface:
- `start(rng: RandomNumberGenerator, spawn_parent: Node) -> void` — called once, immediately after the owning activity's `execute()` runs, so the gate can capture whatever it needs (e.g. a randomly-picked wait duration).
- `is_ready(elapsed_time: float, spawn_parent: Node) -> bool` — polled by `ActivityManager` once per physics frame while waiting; `elapsed_time` is seconds since `start()` was called (tracked and threaded through explicitly by `ActivityManager`, not read from a global clock, consistent with this project's existing "thread state explicitly" convention). Returns `true` once the next activity should be triggered.

This interface is deliberately poll-based (like `GameMode`, `Activity`, `MovementBehavior`) rather than Node-based, so `ActivityGate` stays a plain `Resource` — a `Resource` cannot `@export` a `Node`-derived type in this engine version (existing architecture decision), and a poll-based design means a gate never needs to *own* a Node to express "wait for an external condition": any future gate (e.g. a player-activator gate) can express itself as "check some queryable state via `spawn_parent`" rather than needing its own signal connection.

### FR-05: `TimerActivityGate` (Current Behavior, Extracted)
`components/activities/timer_activity_gate.gd` exposes `@export var wait_min: float = 20.0` and `@export var wait_max: float = 40.0` (moved from `Activity.next_interval_min`/`next_interval_max`, which are removed — this concern now belongs entirely to whichever gate an activity is configured with). `start(rng, spawn_parent)` picks `_target_duration := rng.randf_range(wait_min, wait_max)`; `is_ready(elapsed_time, spawn_parent)` returns `elapsed_time >= _target_duration`. This exactly reproduces today's random-interval-timer behavior.

### FR-06: `EnemiesDefeatedActivityGate` (Wave-Clear Gate)
`components/activities/enemies_defeated_activity_gate.gd`: `is_ready(elapsed_time, spawn_parent)` returns `true` once `spawn_parent.get_tree().get_nodes_in_group("enemy")` is empty. Because activities like `BossActivity` spawn their enemy via `add_child.call_deferred(...)`, the newly-spawned enemy is not guaranteed to be in the `"enemy"` group during the same physics frame the activity executed — `ActivityManager` must not poll `is_ready` on that same frame (see FR-08), otherwise this gate would falsely report "ready" before the enemy it's supposed to be waiting for even exists.

### FR-07: Weighted Activity Selection
`Activity` gains `@export var weight: float = 1.0`. Whenever `ActivityManager` selects the next activity to run from its `activities` pool — regardless of which `GameMode` is active, since picking *which* activity is orthogonal to *whether*/*how many* to schedule — it performs a weighted random pick using the shared seeded `rng`: each activity's probability of being chosen is proportional to its `weight` relative to the sum of all activities' weights in the pool, replacing today's uniform `rng.randi() % activities.size()`. This lets a pool contain, for example, many regular enemy-spawning activities, fewer boss activities, and even fewer item-drop activities, purely by adjusting each configured instance's `weight` — no change to individual `Activity` subclasses is needed, and populating the pool with new activity types to take advantage of this is a follow-up, not part of this feature. If every activity in the pool has a non-positive total weight, `ActivityManager` treats this the same as today's empty-pool case (`push_error`, no activity triggered) rather than picking arbitrarily.

### FR-08: `ActivityManager` Delegates Scheduling, Selection, Gating, and Win-Checking
`ActivityManager` is restructured around a single per-physics-frame poll loop rather than its current one-shot `Timer`/`timeout` mechanism:
- On triggering an activity: consult `game_mode.should_schedule_next_activity(activities_triggered)` first; if `false`, stop — no gate is started and no further activity ever runs. Otherwise weighted-pick an activity per FR-07, execute it, increment the triggered count, and call `activity.gate.start(rng, spawn_parent)`, resetting an internal elapsed-time accumulator to zero.
- Every `_physics_process(delta)` thereafter: accumulate `delta` into the elapsed-time counter; **skip polling on the same frame a gate just started** (see FR-06); once at least one frame has passed, poll the current gate's `is_ready(elapsed_time, spawn_parent)` — once `true`, trigger the next activity (looping back to the first bullet).
- Also every `_physics_process(delta)`: poll `game_mode.is_round_won(activities_triggered, spawn_parent)` (cheap for both current modes — `EndlessGameMode` short-circuits to `false`; `PresetGameMode` only bothers checking the enemy group once its count is reached); the first time it observes `true`, trigger the win resolution described in FR-09.

### FR-09: Round Outcome Replaces the `won: bool` Flag
`GameEvents.round_ended`'s signature becomes `round_ended(time_played_seconds: float, outcome: GameEvents.RoundOutcome)`, where `RoundOutcome` is a new enum on the `GameEvents` autoload: `{LOST, WON, PYRRHIC_VICTORY}`. `Player._on_died()`'s existing emission is updated to pass `GameEvents.RoundOutcome.LOST` — **unless** the active game mode's win condition is already true at that exact moment, in which case it emits `PYRRHIC_VICTORY` instead (see FR-10). `ActivityManager`'s win-resolution path (FR-08) emits `WON` under normal circumstances. `Game._on_round_ended` forwards `outcome` to `SummaryScreen.show_summary(time_played_seconds, outcome)`, which displays one of three distinct messages ("You Died", "You Won!", "Pyrrhic Victory!") while keeping the same elapsed-time display and Retry/New Seed buttons working identically across all three.

### FR-10: Simultaneous Win/Loss Resolves as a (Pyrrhic) Win
If the player's health reaches zero in the same resolution window (see Open Questions for the exact mechanism — e.g. the same physics frame) that the active `GameMode`'s win condition also becomes true, the round must resolve as a win, not a loss — specifically as `PYRRHIC_VICTORY` rather than plain `WON`. This must hold regardless of which code path (`Player`'s death handler vs. `ActivityManager`'s win poll) happens to execute first within that window.

## Acceptance Criteria
- [x] AC-01: With `game_mode` left at its default (`EndlessGameMode`) and every activity's `gate` left at its default (`TimerActivityGate`), a round behaves exactly as it does today — activities are scheduled indefinitely at random timer intervals, with no win condition ever triggering.
- [x] AC-02: With `game_mode` set to a `PresetGameMode` with `activity_count = N`, exactly `N` activities execute (verified by count, not wall-clock time) and no `(N+1)`-th activity is ever scheduled.
- [x] AC-03: In `PresetGameMode`, once all `N` activities have executed and every node in the `"enemy"` group has been freed, `GameEvents.round_ended` fires with `outcome == GameEvents.RoundOutcome.WON` and the correct elapsed time.
- [x] AC-04: In `PresetGameMode`, if enemies are still alive after all `N` activities have executed, `round_ended` does not fire until the last one dies (verified by asserting no emission while at least one enemy remains, then emission once the last one is removed from the group).
- [x] AC-05: `Player`'s existing death path still emits `round_ended` with `outcome == GameEvents.RoundOutcome.LOST` in the ordinary case (win condition not simultaneously true), and `SummaryScreen`/`Game`'s existing Retry/New Seed flow is unaffected by the signature change (all existing `round_end_test.gd` tests continue to pass with the signal's new second parameter type).
- [x] AC-06: `SummaryScreen.show_summary` displays three visibly distinct messages for `LOST`, `WON`, and `PYRRHIC_VICTORY`, while the elapsed-time label and Retry/New Seed buttons behave identically across all three.
- [x] AC-07: With the same seed, a `PresetGameMode` round reproduces the identical sequence of `N` activities (same picks, same order, same intervals) across two loads.
- [x] AC-08: If the player's death and the active `GameMode`'s win condition become true within the same resolution window, `round_ended` fires exactly once with `outcome == GameEvents.RoundOutcome.PYRRHIC_VICTORY` (not `LOST`, and not a duplicate `WON`+`LOST` double emission).
- [x] AC-09: Two different `Activity` instances in the same `activities` pool can be configured with different `gate` types (e.g. one `TimerActivityGate`, one `EnemiesDefeatedActivityGate`) within a single round, and each is honored independently when that activity is the one just triggered.
- [x] AC-10: An activity configured with `EnemiesDefeatedActivityGate` does not trigger the next activity until every node in the `"enemy"` group is gone — including correctly waiting for an enemy spawned via a deferred `add_child` call in the same frame the activity executed (i.e. no false-positive "ready" on that first frame).
- [x] AC-11: `TimerActivityGate`'s wait duration is picked from its own `wait_min`/`wait_max` via the shared seeded `rng`, exactly reproducing the interval range previously configured via `Activity.next_interval_min`/`next_interval_max`.
- [x] AC-12: With activities configured with different `weight` values (e.g. one weighted much higher than another), selection is proportionally biased toward the higher-weight activity — verified via a fixed seed producing a specific, pre-determined sequence of picks matching the expected weighted distribution, not via statistical sampling.
- [x] AC-13: With every activity in the pool left at the default `weight = 1.0`, selection remains an unbiased pick across the pool (equivalent in distribution to today's uniform selection, though not necessarily byte-for-byte identical to today's exact `randi() % size` sequence for a given seed, since the underlying algorithm changes).
- [x] AC-14: If every activity in the pool has a non-positive total weight, `ActivityManager` reports the same error and triggers no activity, matching today's empty-pool behavior.

## Technical Scope

### Affected Modules
- `components/activities/activity_manager.gd` — remove the internal one-shot `Timer`/`_on_timeout`; add `@export var game_mode: GameMode`; replace the uniform `activities[rng.randi() % activities.size()]` pick with weighted random selection (FR-07); add `_physics_process`-driven polling for the current activity's gate and for `game_mode.is_round_won`; track activities-triggered count and elapsed-time-since-gate-started.
- `components/activities/activity.gd` — remove `next_interval_min`, `next_interval_max`, `get_next_interval(rng)`; add `@export var gate: ActivityGate` and `@export var weight: float = 1.0`.
- `components/events/game_events.gd` — replace the (never-shipped) `won: bool` concept with `round_ended(time_played_seconds: float, outcome: RoundOutcome)` and a new `enum RoundOutcome { LOST, WON, PYRRHIC_VICTORY }`.
- `scenes/player/player.gd` — update `_on_died()`'s `GameEvents.round_ended.emit(...)` call site to determine and pass the correct `RoundOutcome` (including the simultaneous-win check from FR-09).
- `scenes/summary_screen/summary_screen.gd` / `.tscn` — `show_summary` takes the `outcome` enum and selects displayed text from three options.
- `scenes/game.gd` — `_on_round_ended` forwards `outcome` through to `SummaryScreen.show_summary`.
- `scenes/game.tscn` — existing configured `Activity` resources (the `BossActivity`/`ItemDropActivity` instances in `ActivityManager.activities`) need a `gate = TimerActivityGate.new()` assigned with their previous `next_interval_min`/`next_interval_max` values carried over as the new gate's `wait_min`/`wait_max`, so behavior is unchanged by default.

### New Components Required
- `components/activities/game_mode.gd` — base `GameMode` `Resource`.
- `components/activities/endless_game_mode.gd` — `EndlessGameMode`, extracted current scheduling behavior.
- `components/activities/preset_game_mode.gd` — `PresetGameMode`, fixed-count + self-contained win condition.
- `components/activities/activity_gate.gd` — base `ActivityGate` `Resource`.
- `components/activities/timer_activity_gate.gd` — `TimerActivityGate`, extracted current timing behavior.
- `components/activities/enemies_defeated_activity_gate.gd` — `EnemiesDefeatedActivityGate`, wave-clear gate.

### Integration Points
- The existing `"enemy"` group (`scenes/enemy/enemy.gd`'s `add_to_group("enemy")`, already consumed by `components/weapon/timer_weapon_trigger.gd`) is the source of truth both `PresetGameMode.is_round_won` and `EnemiesDefeatedActivityGate.is_ready` use for "is any enemy still alive" — no new tracking/counting mechanism is introduced.
- `GameEvents.round_ended` / `Game._on_round_ended` / `SummaryScreen.show_summary` — existing round-end pipeline, extended (new enum parameter) rather than replaced.
- `ActivityManager`'s existing seeded-`rng` threading (injected by `RoundInitializer`) is unchanged and now also flows into `ActivityGate.start(rng, ...)` the same explicit way it already flows into `Activity.execute(rng, ...)`.
- `Player`'s death handler needs a way to ask "did the active game mode just win?" — a new, small coupling from `Player` to `ActivityManager`/`GameMode` that doesn't exist today. Left to `/sdd-plan` to decide the cleanest reference path (e.g. via the existing `"game"` group node, mirroring how `Player` already looks up `get_tree().get_first_node_in_group("game")` for elapsed time).
- `BossActivity`'s use of `spawn_parent.add_child.call_deferred(instance)` directly motivates FR-06/FR-08's "skip the first frame" rule — any future activity that spawns enemies synchronously (not deferred) wouldn't need this, but `ActivityManager` can't tell the difference generically, so the one-frame skip applies uniformly to all gates for safety.

## Non-Functional Requirements
- Performance: the per-physics-frame polling (gate `is_ready` + `game_mode.is_round_won`) must stay cheap — no per-frame allocations, and group-emptiness checks only run when a mode/gate actually needs them (`EndlessGameMode`/`TimerActivityGate` never touch the `"enemy"` group at all).
- Security: not applicable (client-side game, no external input).
- Scalability: not applicable.

## Out of Scope
- Any menu/UI for selecting a game mode at runtime — mode/gate choice is made by which `Resource` is wired into the scene.
- Randomizing `PresetGameMode`'s activity count from the seed — it is a fixed export in this version.
- Future game modes themselves (survive-N-minutes, protect-a-structure) beyond building the `GameMode` abstraction and its first two implementations.
- A third `ActivityGate` that waits for a player-triggered activator (button press, reaching a point on the map) — the interface (FR-04) is deliberately shaped to support this later, but it is not built in this feature.
- Any loss condition beyond the existing player-death path.
- Tower-defense-style scoring, difficulty scaling, or per-mode reward differences.
- Changing what individual `Activity` subclasses (`BossActivity`, `ItemDropActivity`) actually spawn/do, or introducing new `Activity` subclasses (e.g. a dedicated regular-enemy "spawner" distinct from `BossActivity`) — this feature only adds the `weight` mechanism itself; populating the pool with more/varied activity types to actually take advantage of it is a follow-up.
- A full achievement/reward system — "Pyrrhic Victory" is a single hardcoded `SummaryScreen` label for this one specific outcome, not a generalized achievement mechanism.

## Open Questions
- Exact mechanism for guaranteeing the FR-10 tie-break is order-independent (not reliant on whether `Player`'s or `ActivityManager`'s code happens to run first within a physics frame) — left to `/sdd-plan`. One plausible direction: `Player._on_died()` checks the active `GameMode`'s `is_round_won(...)` synchronously before deciding its own outcome, since by the time `HealthComponent.died` fires, the frame's damage has already been applied. Needs verification during planning that this ordering assumption holds under Godot's physics-frame processing.
- Exact mechanism for skipping the first physics frame after a gate starts waiting (FR-06/FR-08) — e.g. a boolean flag checked in `_physics_process`, vs. requiring `elapsed_time > 0` — left to `/sdd-plan`.
- Whether `is_round_won`/`is_ready`'s `spawn_parent: Node` parameter is sufficient context for future modes/gates (e.g. a "survive N minutes" mode would also want elapsed round time, reachable via `spawn_parent.get_tree().get_first_node_in_group("game").get_time_played_seconds()`) or whether the signatures should be widened now — left to `/sdd-plan`.
- Migration approach for carrying existing `Activity` resources' `next_interval_min`/`next_interval_max` values (currently hand-tuned in `game.tscn`) into their new `TimerActivityGate.wait_min`/`wait_max` fields — a mechanical one-time edit, left to `/sdd-plan`/implementation to execute carefully so tuning isn't lost.
- Exact weighted-random-selection algorithm (e.g. cumulative-weight walk against a single `rng.randf_range(0, total_weight)` draw) — left to `/sdd-plan`; any standard weighted-pick approach that consumes the seeded `rng` deterministically is acceptable.
