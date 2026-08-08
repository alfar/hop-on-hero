# Game Modes for ActivityManager

Implemented on: 2026-08-08

Refactored `ActivityManager` around two independent, swappable `Resource` strategies: `GameMode` (decides whether to keep scheduling activities and whether the round is won) and `ActivityGate` (per-`Activity`, decides when to advance to the next one). Today's behavior became the default combination of `EndlessGameMode` + `TimerActivityGate`. A new `PresetGameMode` schedules a fixed number of activities and wins once that count is reached and every enemy is dead; a new `EnemiesDefeatedActivityGate` enables wave-clear pacing (wait for enemies dead instead of a timer). Activities also gained a `weight` field for non-uniform random selection. `ActivityManager` itself moved from a `Timer`/`timeout` mechanism to a unified `_physics_process` poll loop to support both time-based and non-time-based gates/win-checks.

`GameEvents.round_ended` gained a `RoundOutcome` enum (`LOST`/`WON`/`PYRRHIC_VICTORY`), threaded through `Player`, `Game`, and `SummaryScreen` (which now shows a distinct message per outcome). If the player dies at the same moment the round is won, the outcome resolves as `PYRRHIC_VICTORY` — a small easter egg for that edge case — via a mutual-awareness check between `Player` and `ActivityManager` rather than relying on incidental processing order.

Key files:
- `components/activities/game_mode.gd`, `endless_game_mode.gd`, `preset_game_mode.gd` (new)
- `components/activities/activity_gate.gd`, `timer_activity_gate.gd`, `enemies_defeated_activity_gate.gd` (new)
- `components/activities/activity_manager.gd` — full rewrite (removed `Timer`, added polling loop, weighted selection, win declaration)
- `components/activities/activity.gd` — `gate`, `weight` added; `next_interval_min/max` removed (moved to `TimerActivityGate`)
- `components/events/game_events.gd` — `RoundOutcome` enum; `round_ended` gains `outcome` param; `emit_round_ended`/`emit_paused`/`emit_resumed` wrapper methods added
- `scenes/player/player.gd` — `is_dead` flag; `_resolve_round_outcome()` mutual tie-break logic
- `scenes/summary_screen/summary_screen.gd`/`.tscn`, `scenes/game.gd` — outcome display/forwarding
- `scenes/game.tscn` — migrated `BossActivity`/`ItemDropActivity`'s old interval config into `TimerActivityGate` sub-resources

Notable decisions:
- `GameMode`/`ActivityGate` are both poll-based `Resource`s (not `Node`s), consistent with the existing constraint that a `Resource` can't `@export` a `Node`-derived type.
- Simultaneous win/loss resolves as `PYRRHIC_VICTORY`, determined via `Player` and `ActivityManager` each checking the other's condition at its own decision point, guarded by a shared `ActivityManager.round_over` flag to prevent a double `round_ended` emission.
- `GameEvents`' plain signals now require a corresponding `emit_<name>()` wrapper method (not `.emit()` called directly from other scripts), established to satisfy Godot's editor linter and applied retroactively to `round_ended`/`paused`/`resumed`.
