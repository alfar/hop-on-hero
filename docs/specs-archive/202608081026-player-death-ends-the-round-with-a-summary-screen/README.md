# Player Death Ends the Round with a Summary Screen

Implemented on: 2026-08-08

## What was built
When `Player`'s `HealthComponent` reaches zero, `Player` now stops moving, disables its `TimerWeaponTrigger`, and plays a new `AnimationPlayer`-driven "death" animation (this project's first `AnimationPlayer` usage — chosen over a hardcoded tween specifically so the animation's content can be redesigned later without code changes). Once the animation finishes, `Player` emits a new `GameEvents.round_ended` signal.

`Game` reacts to `round_ended` by emitting `GameEvents.paused` (which it alone translates into the real `get_tree().paused = true`) and showing a new `SummaryScreen` — this project's first `Control`-based UI — displaying the elapsed round time (`mm:ss`) and two buttons: "Retry" (reload the same round with the same seed) and "New Seed" (reload with a freshly randomized seed). Both buttons stage the next seed via a new `GameEvents.next_level_seed` field (since `get_tree().reload_current_scene()` resets every `@export` default, including `ActivityManager.level_seed`) and emit `GameEvents.resumed` before reloading.

## Key files
- `scenes/player/player.gd`, `scenes/player/player.tscn` — `_on_died()` handler, new `AnimationPlayer` + "death" animation clip
- `components/weapon/timer_weapon_trigger.gd` — new `stop()` method
- `components/events/game_events.gd` — new `round_ended`, `paused`, `resumed` signals (all plain signals, not `BehaviorSubject`s) and `next_level_seed` field
- `scenes/game.gd`, `scenes/game.tscn` — round timer, pause/resume handling, `SummaryScreen` wiring, `stage_next_seed()`/`_restart()`
- `components/activities/activity_manager.gd` — reads `GameEvents.next_level_seed` before its existing randomize-on-zero fallback
- `scenes/summary_screen/` — new `SummaryScreen` presentation scene (`Control`-based)

## Notable decisions
- `round_ended`/`paused`/`resumed` are plain signals, not `BehaviorSubject`s — a `BehaviorSubject`'s replay-to-new-subscriber behavior would incorrectly re-fire on the very next round's fresh subscriber.
- Pause/resume is driven by signals with `Game` as the sole real `get_tree().paused` toggle — decouples pause intent from the actual flag so tests can assert intent without leaking real paused state across the GUT test run (this was a genuine, previously-undiscovered test-isolation hazard found and fixed mid-implementation).
- `AnimationPlayer` is now the preferred mechanism for entity state-transition animations going forward (vs. `Enemy`'s older `create_tween()`-based fade, left as-is).
- Found and documented: under `--headless`, `AnimationPlayer` idle-process playback can run far slower than wall-clock time — tests must await the relevant signal, never a fixed `wait_seconds` duration.
- Known, deliberately-unfixed, pre-existing gap surfaced (not caused) by this feature's tests: `GameEvents.world_size_changed`'s `BehaviorSubject` replay can leak real `World` bounds into later, unrelated inventory tests in a full headless run. Left for an upcoming "initialize the world for a new round" feature to fix properly.
- Full test suite: 102/103 passing at archive time (the 1 failure is the known gap above); all 12 acceptance criteria satisfied, with AC-08/AC-11/AC-12 verified manually (untestable under GUT's headless runner — `reload_current_scene()` and real click-while-paused behavior can't be exercised in that environment).
