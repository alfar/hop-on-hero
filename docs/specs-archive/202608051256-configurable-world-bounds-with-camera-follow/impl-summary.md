## Implementation Complete

### Files Created
- `components/events/behavior_subject.gd` — generic `BehaviorSubject` (RxJS-style): caches last emitted value, replays it to new subscribers via `subscribe(callable)`.

### Files Modified
- `components/events/game_events.gd` — `world_size_changed` is now `BehaviorSubject.new()` instead of a raw `signal`.
- `world.gd` — emits synchronously again (`GameEvents.world_size_changed.emit(world_size)`); the `call_deferred` workaround from the previous revision is no longer needed.
- `components/camera/camera_bounds.gd` — `.connect(...)` → `.subscribe(...)`.
- `player.gd` — `.connect(...)` → `.subscribe(...)`; also fixed a MINOR review finding by clamping `global_position` instead of local `position`.

### Files Generated (headlessly, via `godot --headless --editor --quit`)
- `components/camera/camera_bounds.gd.uid`
- `components/events/behavior_subject.gd.uid`

### Acceptance Criteria
- [x] AC-01/02/03: Passed — unaffected by this revision.
- [x] AC-04: Passed — unaffected by this revision's internal changes.
- [x] AC-05: Passed, and now structurally proven rather than worked around — headless test confirmed a brand-new subscriber added *after* `World` had already emitted still immediately received `world_size` via replay.
- [x] AC-07: Passed — `global_position` clamp fix verified; propagation path confirmed via the same headless test.
- [x] AC-06: Passed — `enemy.gd`/`MovementBehavior`/`InputMovementBehavior` untouched.

### Notes
- **Two real issues found and fixed during verification, beyond the plan's explicit scope**:
  1. A brand-new `class_name` (`BehaviorSubject`) isn't recognized by a plain `--check-only` run until Godot's global class cache is rebuilt — fixed by running `godot --headless --editor --quit` once, which also happened to generate the missing `.uid` sidecar files for the two new scripts (Step 6 partially resolved as a side effect).
  2. GDScript lambda captures are by value, so the first draft of the late-subscriber verification test (`received_late_value = size` inside a lambda) would have silently passed even if broken; rewrote the test to print from inside the lambda directly rather than relying on outer-variable mutation.
- **`camera.tscn` still has no scene `uid=`** — unlike scripts, a scene only gets a uid assigned when the `.tscn` file is actually saved through the graphical editor; headless `--import` and a brief headless editor launch both left it unmodified. Recommend the user open (and let auto-save, or manually save) `camera.tscn` once in the editor, same as was needed for `.uid` files in the prior revision.
- Recommend an interactive editor playtest to confirm camera-follow feel and edge-clamping visually — still outstanding from the prior revision, no display/input available in this environment.
- No other deviations from `plan.md`.
