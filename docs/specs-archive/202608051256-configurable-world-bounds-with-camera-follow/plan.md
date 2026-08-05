# Implementation Plan: Configurable World Bounds with Camera Follow (BehaviorSubject Revision)

## Overview
Replace `GameEvents.world_size_changed`'s raw Godot `signal` with a generic, reusable `BehaviorSubject` class that caches its last emitted value and replays it immediately to any new subscriber — closing the MAJOR late-subscriber gap identified in `review.md`. This removes the need for the `call_deferred` workaround entirely, since subscribe/emit ordering no longer matters. While touching these files, also fix the two other review findings that are small and directly adjacent: the `player.gd` position-clamp using local `position` instead of `global_position` (MINOR), and generating the missing `.uid` files for `camera_bounds.gd`/`camera.tscn` (MINOR).

This plan only touches the event-bus plumbing and its three call sites (`world.gd`, `camera_bounds.gd`, `player.gd`) — no scene composition, main-scene, or movement-behavior changes from the prior revision are affected.

## Architecture Decisions
- **`BehaviorSubject` is a plain `RefCounted` value wrapper, not a `Node`**, since it doesn't need to live in the scene tree — it's held as a field on the `GameEvents` autoload `Node`. This matches Godot idioms where `Resource`/`RefCounted` types are used for data-holding objects and `Node` is reserved for things that need scene-tree lifecycle or per-frame processing (consistent with this project's existing `MovementBehavior extends Resource` pattern in `docs/project.md`).
- **`GameEvents` now holds `BehaviorSubject` instances instead of declaring raw `signal`s.** This is a deliberate general-purpose pattern per `feature.md` FR-05 — every future cross-cutting event on `GameEvents` (waves, towers, score) gets late-subscriber replay for free by using the same `BehaviorSubject` wrapper, rather than each new signal needing its own bespoke "did anyone miss this" fix.
- **`subscribe(callable)` is the only supported way to react to changes** — call sites no longer use `.connect(...)` directly on a signal, since the replay behavior lives in `BehaviorSubject.subscribe()`, not in the underlying `value_changed` signal itself (calling `.value_changed.connect(...)` directly would skip the replay).
- **`world.gd` no longer needs `call_deferred`** — emitting synchronously in `_ready()` is safe now because any subscriber, whenever it subscribes, receives the current value immediately via replay. This directly resolves the review's MAJOR finding, structurally rather than by reordering execution.
- **Fixing `player.gd`'s local-vs-global position clamp is in scope for this pass** — it's a one-line change (`position` → `global_position`) directly adjacent to the other edits in the same file, per the MINOR finding in `review.md:24`.

## Implementation Steps

### Step 1: Create the BehaviorSubject class ✅
- [x] Create `components/events/behavior_subject.gd`:
  ```gdscript
  class_name BehaviorSubject
  extends RefCounted

  signal value_changed(value)

  var _value
  var _has_value := false

  func _init(initial = null) -> void:
      _value = initial

  func emit(value) -> void:
      _value = value
      _has_value = true
      value_changed.emit(value)

  func get_value():
      return _value

  func has_value() -> bool:
      return _has_value

  func subscribe(callable: Callable) -> void:
      value_changed.connect(callable)
      if _has_value:
          callable.call(_value)
  ```
- Files to create: `components/events/behavior_subject.gd`

### Step 2: Update GameEvents to hold a BehaviorSubject ✅
- [x] Update `components/events/game_events.gd`:
  ```gdscript
  extends Node

  var world_size_changed := BehaviorSubject.new()
  ```
- Files to modify: `components/events/game_events.gd`

### Step 3: Simplify World's emission (remove call_deferred) ✅
- [x] Update `world.gd` to emit synchronously — the workaround is no longer needed:
  ```gdscript
  extends Node2D

  @export var world_size: Vector2 = Vector2(1600, 1200)

  func _ready() -> void:
      GameEvents.world_size_changed.emit(world_size)
  ```
- Files to modify: `world.gd`

### Step 4: Update camera_bounds.gd to subscribe instead of connect ✅
- [x] Update `components/camera/camera_bounds.gd`:
  ```gdscript
  extends Camera2D

  func _ready() -> void:
      GameEvents.world_size_changed.subscribe(_on_world_size_changed)

  func _on_world_size_changed(size: Vector2) -> void:
      limit_left = 0
      limit_top = 0
      limit_right = size.x
      limit_bottom = size.y
  ```
- Files to modify: `components/camera/camera_bounds.gd`

### Step 5: Update player.gd to subscribe instead of connect, and fix the position/global_position clamp bug ✅
- [x] Update `player.gd`:
  ```gdscript
  extends CharacterBody2D

  @export var movement_behavior: MovementBehavior

  var world_size: Vector2 = Vector2.ZERO
  var half_size := Vector2(20, 20)

  func _ready() -> void:
      GameEvents.world_size_changed.subscribe(_on_world_size_changed)

  func _on_world_size_changed(size: Vector2) -> void:
      world_size = size

  func _physics_process(delta: float) -> void:
      velocity = movement_behavior.get_velocity(position)
      move_and_slide()
      if world_size != Vector2.ZERO:
          global_position = global_position.clamp(half_size, world_size - half_size)
  ```
- Files to modify: `player.gd`

### Step 6: Generate missing .uid files ✅ (partial — script .uid files generated headlessly; camera.tscn's scene uid still needs the user's editor session)
- [x] Ran `godot --headless --editor --quit` to force a project rescan, which registered `BehaviorSubject` in the global class cache and generated `.uid` sidecar files for both new scripts: `components/camera/camera_bounds.gd.uid` and `components/events/behavior_subject.gd.uid` now exist (confirmed via directory listing).
- [ ] `camera.tscn` still has no `uid=` in its `[gd_scene]` header — unlike scripts, a scene only gets a uid assigned when Godot actually saves the `.tscn` file, which doesn't happen from a headless scan/import pass (confirmed: ran `--import` and a brief `-e --quit-after 2` editor launch, neither modified the file). Same as the prior revision, this needs the user to open and save (or just open, since Godot resaves on scene load in-editor) `camera.tscn` once in the graphical editor.
- Files created (headlessly): `components/camera/camera_bounds.gd.uid`, `components/events/behavior_subject.gd.uid`
- Files still needing the user's editor session: `camera.tscn` (uid assignment)

### Step 7: Verification ✅ (headless checks + late-subscriber proof passed; interactive playtest still recommended)
- [x] Ran the project headless (`--check-only`) to confirm all scripts/scenes parse without errors after the `BehaviorSubject` refactor. First attempt failed with "Identifier BehaviorSubject not declared" because a brand-new `class_name` needs Godot to register it in `.godot/global_script_class_cache.cfg`, which a plain `--check-only` run doesn't trigger; fixed by running `godot --headless --editor --quit` once to force the scan (this also generated the missing `.uid` sidecar files noted in Step 6). Re-ran `--check-only` afterward with no errors.
- [x] Wrote a temporary headless verification script (`verify_bounds.gd`, deleted after use) that:
  1. Instantiated `game.tscn` and confirmed `player.world_size = (1600, 1200)` and camera limits `= 0 0 1600 1200` — regression check passed, confirming propagation still works correctly without the `call_deferred` workaround.
  2. **Specifically tested the late-subscriber scenario this refactor exists to fix**: after `game.tscn` was fully ready (so `World` had already emitted), subscribed a brand-new dummy listener via `GameEvents.world_size_changed.subscribe(...)` and confirmed it immediately printed `late_subscriber received = (1600.0, 1200.0)` — proving `BehaviorSubject`'s replay-on-subscribe works for a genuinely late subscriber, not just the three call sites already in the scene tree at startup. This is the direct, positive proof that the MAJOR finding from `review.md` is now structurally resolved.
  3. Deleted the temporary script after use.
- [ ] In the editor, run the game and confirm camera-follow and edge-clamping behavior still looks correct — still outstanding, requires interactive input/visual confirmation not available in this environment.

## Acceptance Criteria Mapping
| AC | Verified By |
|----|-------------|
| AC-01/02/03: scene split, composition, main-scene switch | Unaffected by this revision — already satisfied |
| AC-04: `camera.tscn` instanced under Player, smoothing enabled, keeps player centered | Unaffected by this revision's changes to `camera_bounds.gd`'s internals — already satisfied; re-confirmed by Step 7's regression check |
| AC-05: `camera_bounds.gd` sets limits from `GameEvents.world_size_changed.subscribe(...)`, works regardless of emission timing | Steps 1–4 + Step 7 — code inspection, headless regression check, and the new late-subscriber test proving the ordering bug is now structurally impossible, not just avoided |
| AC-07: Player's position never exceeds world bounds | Step 5 + Step 7 — code inspection confirms the `global_position` fix; headless regression check confirms clamp still activates correctly |
| AC-06: No regressions to `enemy.gd`/`MovementBehavior`/`InputMovementBehavior` | Steps 1–5 — none of those files touched; `player.gd`'s `movement_behavior.get_velocity()`/`move_and_slide()` lines unchanged, only the clamp line changes from `position` to `global_position` |

## Risks & Mitigations
- Risk: `BehaviorSubject.emit()`'s `value_changed.emit(value)` still only reaches subscribers connected *before* this particular emission — replay only helps subscribers that join after the *first* emission with a cached value, not necessarily every subsequent emission if a subscriber joins mid-stream between two emissions and expects to have seen the first one. → Mitigation: for this feature, `world_size` is expected to be set once at `_ready()` and not change again during a play session, so this distinction doesn't matter in practice; note it in the `BehaviorSubject` class as a known characteristic if it's reused for values that change more frequently (e.g. `score_changed`) in the future.
- Risk: `BehaviorSubject.subscribe()`'s replay call (`callable.call(_value)`) happens synchronously and immediately, which means if a subscriber's `_on_...` callback has side effects that assume they're always running in response to an actual "change" (e.g. playing a sound effect), the replay could trigger that side effect unexpectedly on first subscribe. → Mitigation: not a concern for `world_size_changed`'s current listeners (`camera_bounds.gd`, `player.gd`), which only set local state; worth keeping in mind for future `GameEvents` entries with side-effectful listeners.
- Risk: Godot's language server may not immediately recognize `BehaviorSubject` as a valid type for `GameEvents.world_size_changed`'s declaration if the project isn't reloaded, similar to the `GameEvents` autoload false-alarm diagnostic seen in the prior revision. → Mitigation: verify with the actual Godot headless engine (`--check-only`), not just IDE diagnostics, as was done previously.
- Risk: Step 6 (generating `.uid` files) may not be automatable headlessly in this environment (the prior revision's `.uid` gap was resolved by the user opening the editor themselves, not by the agent). → Mitigation: attempt a headless approach first; if unavailable, clearly flag this step as needing the user's editor session, consistent with how it was handled last time.

## Estimated Complexity
Low — this is a small, self-contained refactor of the event-bus's internals (one new ~25-line class, two one-line call-site changes from `.connect()` to `.subscribe()`, one line reverted in `world.gd`, one `position`→`global_position` fix). No scene structure or composition changes. The main rigor required is in Step 7's verification, specifically proving the late-subscriber scenario now works, since that's the entire point of the change.
