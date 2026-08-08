# Feature: Player Death Ends the Round with a Summary Screen

## Summary
When the player's `HealthComponent` reaches zero, the round ends: the player plays a short death sequence (mirroring `Enemy`'s existing stop/disable/animate pattern, but driven by a new `AnimationPlayer` instead of a hardcoded tween, so the animation itself can be redesigned later without code changes), the game world then freezes, and a summary screen appears showing how long the round lasted. The summary screen offers two actions — retry the same round with the same `level_seed` (for practicing a specific layout/seed), or start a new round with a freshly randomized seed. This establishes the project's first `Control`-based UI, its first `AnimationPlayer` usage, and its first scene-restart mechanism, all of which are expected to be reused/extended later.

## User Stories
- As a player, when I die I want clear feedback that the round is over and how long I survived, so that I understand the outcome and have something to measure my next attempt against.
- As a player, I want to retry the exact same round after dying, so that I can practice against a specific layout of enemies and item drops I just saw.
- As a player, I want to start a fresh round with a new layout after dying, so that I'm not stuck replaying the same seed if I'd rather see something different.

## Functional Requirements

### FR-01: Player death sequence
`Player` (`scenes/player/player.gd`) connects to `$Status/HealthComponent.died` in `_ready()` (mirroring `Enemy.gd`'s existing `$Status/HealthComponent.died.connect(_on_died)` — `Player` currently has no such connection at all, so `HealthComponent.died` fires into the void for `Player` today). On `died`:
- Swap `movement_behavior` to a `MovementBehavior` that produces zero velocity (reuse `StayStillMovementBehavior`, the same one `Enemy._on_died()` already uses), so the player stops moving immediately.
- Disable further player weapon fire: since `Player` uses `TimerWeaponTrigger` (a `Node`, not gated by a `HitArea` the way `Enemy`'s melee trigger is), stop `$TimerWeaponTrigger`'s firing — e.g. `_timer_weapon_trigger.set_process(false)` or an equivalent stop method added to `TimerWeaponTrigger` — so a dead player can't keep shooting.
- Play a death animation via a new `AnimationPlayer` child on `Player` (`scenes/player/player.tscn`), rather than a hardcoded `create_tween()` fade — this project's first use of `AnimationPlayer`, chosen specifically so the death animation's content (fade, squash, rotation, whatever comes later) can be redesigned entirely in the editor without touching `player.gd`. The initial "death" animation clip fades `modulate:a` to `0.0`, matching the visual result `Enemy`'s tween-based fade currently produces, but the mechanism is swappable independent of this spec. `Player._on_died()` calls `$AnimationPlayer.play("death")` then `await $AnimationPlayer.animation_finished` — the animation's own authored length is the single source of truth for how long the death sequence takes (no separate duration `@export` to keep in sync).
- After `animation_finished` fires, emit a new signal/event indicating the round has ended (see FR-02) — do **not** `queue_free()` the player (unlike `Enemy`, the player node must still exist so the summary screen's "time played" and any future stats can be read from it, and so the round-end flow has a stable point to hang off).

### FR-02: Round-end signal and world freeze
Add `GameEvents.round_ended` (`components/events/game_events.gd`) as a **plain Godot `signal`**, not a `BehaviorSubject` — a deliberate deviation from this project's general convention that cross-cutting `GameEvents` state broadcasts via `BehaviorSubject` (per `docs/project.md` Architecture Decisions, 2026-08-05). Rationale: a `BehaviorSubject` replays its last cached value immediately to every new subscriber; since nothing re-emits a fresh "not ended" value on the next round the way `World` re-emits `world_size_changed`/`world_loaded` every load, a `BehaviorSubject` here would incorrectly instantly re-fire "round ended" to the very next round's fresh `game.gd` subscriber the moment it connects. A plain `signal`, connected fresh each `game.gd._ready()`, has no replay behavior and avoids this trap.

`Player` emits `GameEvents.round_ended` once, after its death animation finishes (FR-01). `scenes/game.gd` subscribes to `GameEvents.round_ended` and, on fire:
- Emits `GameEvents.paused` (also a new plain signal, see below), which sets `get_tree().paused = true` to freeze all gameplay (enemies stop moving/attacking, `ActivityManager`'s `Timer` stops counting down, projectiles stop moving) — this relies on `Player`, `Enemy`, `ActivityManager`, `Projectile`, etc. all having default `process_mode` (`PROCESS_MODE_INHERIT`), which they currently do (none of them override `process_mode` today).
- Shows the summary screen (FR-03), which must itself run while the tree is paused — its root `CanvasLayer`/`Control` needs `process_mode = PROCESS_MODE_ALWAYS` (or `PROCESS_MODE_WHEN_PAUSED`) so its buttons remain clickable and responsive after `get_tree().paused = true`.

`GameEvents` also gains `paused` and `resumed` (both plain signals, same rationale as `round_ended`). `Game` is the sole subscriber that translates this pause/resume *intent* into the real `get_tree().paused` toggle, rather than any code calling `get_tree().paused = true/false` directly — this indirection exists specifically so tests can assert the intent to pause/resume fired without ever touching the real `SceneTree.paused` flag, which (if set for real during a test run) leaks into every subsequent test in the same run since nothing un-pauses it except that test's own teardown running to completion first.

### FR-03: Round timer
Add round-elapsed-time tracking, since none exists anywhere in the project today. Add a new `@export var round_start_time: float` — actually, track via `Time.get_ticks_msec()`: `scenes/game.gd` records `var _round_start_ticks_msec: int` in `_ready()` (via `Time.get_ticks_msec()`), and computes elapsed seconds (`(Time.get_ticks_msec() - _round_start_ticks_msec) / 1000.0`) when `GameEvents.round_ended` fires, to pass to the summary screen (FR-04). Using `Time.get_ticks_msec()` rather than a `_process(delta)` accumulator avoids needing a new per-frame hook and is unaffected by `get_tree().paused` (ticks keep advancing even while the tree is paused, which doesn't matter here since we read the value once, at the moment of death, before pausing).

### FR-04: Summary screen (`Control`-based)
Add a new presentation scene `scenes/summary_screen/summary_screen.tscn` + `summary_screen.gd` (`class_name SummaryScreen`, `extends Control`) — this project's first `Control`-based UI (existing presentation scenes `HealthBar`/`InventoryDisplay` are `Node2D`-based). Plain default Godot theme, no custom styling (explicitly deferred — see Out of Scope).

- Root `Control` sized to fill the viewport (full-rect anchors), `process_mode = PROCESS_MODE_ALWAYS` (FR-02), `visible = false` by default.
- A `Label` showing elapsed round time, formatted `mm:ss` (e.g. `"02:47"`).
- Two `Button`s: **"Retry"** and **"New Seed"**.
- `func show_summary(time_played_seconds: float) -> void`: formats and sets the time label, sets `visible = true`. Called by `game.gd`'s `GameEvents.round_ended` handler (FR-02).
- `signal retry_pressed` and `signal new_seed_pressed`, emitted by each button's `pressed` handler — `game.gd` connects to both (see FR-05) rather than `SummaryScreen` knowing how to restart the game itself, keeping the presentation scene free of restart logic (mirrors this project's existing presentation-scene convention: `HealthBar`/`InventoryDisplay` only reflect state, they don't drive behavior).
- Instanced under `game.tscn`'s existing `HUD` `CanvasLayer` (alongside `InventoryDisplay`), matching the established convention that screen-anchored UI lives under a `CanvasLayer` (per `docs/project.md` Architecture Decisions, 2026-08-08).

### FR-05: Restart mechanism (retry same seed / new seed)
Since reloading `game.tscn` resets every `@export` default (including `ActivityManager.level_seed`), the seed to use on the *next* load must be carried across the reload externally. Add a new field to the `GameEvents` autoload (`components/events/game_events.gd`) — a plain `var next_level_seed: int = 0` (not a `BehaviorSubject`; this is a one-shot carry-through value, not an ongoing broadcast state) — since `GameEvents` is already the project's one autoload and persists across `get_tree().reload_current_scene()` (autoloads are not part of the scene being reloaded).

- On **"Retry"**: `game.gd` sets `GameEvents.next_level_seed = <the current run's level_seed>` (read from `$ActivityManager.level_seed`, which holds the actual seed used — either the `@export`ed value or the `randi()` fallback `ActivityManager._ready()` already generates), then calls `get_tree().reload_current_scene()`.
- On **"New Seed"**: `game.gd` sets `GameEvents.next_level_seed = 0`, then calls `get_tree().reload_current_scene()` — `0` is `ActivityManager`'s existing sentinel for "generate a random seed" (`activity_manager.gd`'s current `if level_seed == 0: level_seed = randi()` logic), so this reuses existing behavior with no change to `ActivityManager` needed.
- `game.tscn`'s `Game._ready()` (or a new step early in `game.gd`) sets `$ActivityManager.level_seed = GameEvents.next_level_seed` **before** `ActivityManager._ready()` runs — since `Game` is the parent and Godot calls `_ready()` bottom-up (children before parents), this requires either setting it in `Game._ready()` before `ActivityManager` would have already read it in its own `_ready()` (a real ordering hazard — see Open Questions), or, more simply, reordering so `ActivityManager` reads `GameEvents.next_level_seed` itself directly inside its own `_ready()` instead of relying on `Game` to inject it first. The latter is simpler and removes the ordering hazard entirely: `ActivityManager._ready()` becomes `if GameEvents.next_level_seed != 0: level_seed = GameEvents.next_level_seed` before its existing `if level_seed == 0: level_seed = randi()` check.
- After reload, `get_tree().paused` must also be reset to `false` — confirm whether Godot already resets `SceneTree.paused` to `false` automatically on `reload_current_scene()`/scene change (this is Godot's documented default behavior for a fresh scene tree state, but must be verified during implementation — see Open Questions) or whether `game.gd` must explicitly set it in `_ready()`.

## Acceptance Criteria
- [x] AC-01: When `Player`'s `HealthComponent` emits `died`, the player's movement stops immediately (velocity becomes zero on the next physics frame).
- [x] AC-02: When `Player`'s `HealthComponent` emits `died`, the player's `TimerWeaponTrigger` no longer fires (no further projectiles spawn).
- [x] AC-03: When `Player`'s `HealthComponent` emits `died`, the player's `AnimationPlayer` plays the "death" animation and `modulate:a` reaches `0.0` by the time it finishes.
- [x] AC-04: After the player's death fade completes, `GameEvents.round_ended` fires exactly once.
- [x] AC-05: When `GameEvents.round_ended` fires, `get_tree().paused` becomes `true`.
- [x] AC-06: When `GameEvents.round_ended` fires, the summary screen becomes visible.
- [x] AC-07: The summary screen displays the correct elapsed round time (measured from round start to the moment of death), formatted as `mm:ss`.
- [x] AC-08: While the summary screen is visible and the tree is paused, both "Retry" and "New Seed" buttons remain clickable/responsive.
- [x] AC-09: Pressing "Retry" reloads the game scene such that `ActivityManager.level_seed` after reload equals the `level_seed` that was actually in effect during the round that just ended.
- [x] AC-10: Pressing "New Seed" reloads the game scene such that `ActivityManager.level_seed` after reload is freshly randomized (not equal to `0`, and not required to equal the previous run's seed).
- [x] AC-11: After either restart path, `get_tree().paused` is `false` and the player can move again.
- [x] AC-12: After either restart path, the summary screen is hidden and the round-elapsed timer restarts from zero.

## Technical Scope

### Affected Modules
- `scenes/player/player.gd`, `scenes/player/player.tscn` (new `died` handling, new `AnimationPlayer` child + "death" animation clip, `round_ended` emission)
- `components/events/game_events.gd` (new `round_ended`, `paused`, `resumed` plain signals; new `next_level_seed` plain field)
- `components/activities/activity_manager.gd` (reads `GameEvents.next_level_seed` in `_ready()` before its existing seed-fallback logic)
- `scenes/game.gd`, `scenes/game.tscn` (round-start-time tracking, `round_ended` subscription → pause + show summary, wiring `SummaryScreen.retry_pressed`/`new_seed_pressed` → reload logic, new `SummaryScreen` child under `HUD`)
- `components/weapon/timer_weapon_trigger.gd` (needs a way to be stopped/disabled — exact mechanism, e.g. a `set_process(false)` call from outside vs. a new `stop()` method, deferred to `/sdd-plan`)
- `scenes/summary_screen/` (new, this project's first `Control`-based presentation scene)

### New Components Required
- `SummaryScreen` (`scenes/summary_screen/summary_screen.gd` + `.tscn`)
- `GameEvents.round_ended`, `GameEvents.paused`, `GameEvents.resumed` (plain signals — see FR-02 for why not `BehaviorSubject`)
- `GameEvents.next_level_seed` (plain carry-through field)

### Integration Points
- `HealthComponent.died` (existing signal, currently only consumed by `Enemy`) — `Player` becomes a second consumer.
- `StayStillMovementBehavior` (existing, currently only used by `Enemy._on_died()`) — reused for `Player`'s death movement stop.
- `GameEvents` autoload (existing pattern, mostly `BehaviorSubject`-based) — gains `round_ended`/`paused`/`resumed` (plain signals, a deliberate deviation — see FR-02) and `next_level_seed`.
- `ActivityManager`'s existing `level_seed` seed-or-randomize logic (`activity_manager.gd:12-16`) — extended to first check `GameEvents.next_level_seed` before falling back to its current `0`-means-randomize behavior; no change to the randomize behavior itself.
- `game.tscn`'s existing `HUD` `CanvasLayer` (currently holds only `InventoryDisplay`) — gains `SummaryScreen` as a second child.
- Godot's `SceneTree.paused` / `Node.process_mode` — first use of pause-based freezing in this project; requires confirming every gameplay node's `process_mode` default (`PROCESS_MODE_INHERIT`) actually produces the desired "everything freezes except the summary screen" behavior with no per-node overrides needed (expected to be the case, since nothing currently sets `process_mode` anywhere in the project, but to be confirmed in `/sdd-plan`/implementation).
- `get_tree().reload_current_scene()` — first use of scene reload/restart in this project.

## Non-Functional Requirements
- Performance: negligible — one additional signal subscription, one `Time.get_ticks_msec()` read, and a full scene reload (an already-supported Godot operation) on button press.
- Security: not applicable (client-side game).
- Scalability: `SummaryScreen.show_summary(time_played_seconds)` is written to make adding more stats later straightforward (per the user's stated "we'll have more stats later") — e.g. `show_summary` could later take a small data struct/dictionary instead of a single float, without changing the round-end signal flow in FR-02. This feature only wires up "time played," but the summary screen's structure (one `Label` per stat, populated from data passed in at `show_summary` time) is meant to extend without rework.

## Out of Scope
- Any visual styling/theme for `SummaryScreen` — plain default Godot `Control`/`Button`/`Label` appearance only, per user decision.
- Any stats beyond time played (kills, damage dealt, items collected, etc.) — explicitly deferred by the user ("we'll have more stats later"); this feature only establishes the plumbing (round-end signal, pause, summary screen, restart) and the one "time played" stat.
- A main menu, pause menu (player-triggered, not death-triggered), or any other menu screen — this feature only adds the post-death summary screen.
- Persisting best times, run history, or any stats across sessions (no save system exists in this project).
- Any confirmation dialog or "are you sure" step before retry/new-seed — pressing either button restarts immediately.
- Player health/death balance tuning (how much damage kills the player, etc.) — this feature only wires up what happens *when* health reaches zero, not how quickly that happens.
- Enemy/activity behavior changes on round end beyond the blanket `get_tree().paused = true` freeze — no special enemy "victory" animation or similar.

## Open Questions
- Whether `SceneTree.paused` is automatically reset to `false` by `get_tree().reload_current_scene()`, or must be explicitly reset in `game.gd._ready()` after reload — needs verification during `/sdd-plan`/implementation (Godot's docs suggest a freshly loaded scene tree starts unpaused, but this project has never used pause before, so it should be confirmed with a quick manual/test check rather than assumed).
- Exact mechanism for stopping `TimerWeaponTrigger` from firing on player death (a new public `stop()`/`enabled` flag on `TimerWeaponTrigger` vs. `set_process(false)` from `Player._on_died()`) — deferred to `/sdd-plan`, does not affect this spec's acceptance criteria.
- Whether `Player`'s death-fade should also disable `Player`'s own collision (so a dead-but-not-yet-reloaded player can't still block/collide with enemies during the pause) — not called out by the user and `get_tree().paused = true` already stops all physics processing project-wide, so this is likely moot, but worth a sanity check during implementation.
