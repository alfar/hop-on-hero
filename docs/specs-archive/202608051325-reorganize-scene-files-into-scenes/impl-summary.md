## Implementation Complete

### Files Moved
- `player.tscn`, `player.gd`, `player.gd.uid` → `scenes/player/`
- `enemy.tscn`, `enemy.gd`, `enemy.gd.uid` → `scenes/enemy/`
- `world.tscn`, `world.gd`, `world.gd.uid` → `scenes/world/`
- `camera.tscn` → `scenes/camera/` (script `components/camera/camera_bounds.gd` stays in place, unmoved)
- `game.tscn` → `scenes/game.tscn`

### Files Modified
- `scenes/player/player.tscn`, `scenes/enemy/enemy.tscn`, `scenes/world/world.tscn` — each self-referencing `ext_resource` path updated to the new location of its own root script.
- `scenes/game.tscn` — all four `ext_resource` paths (world/player/enemy/camera) updated to their new `scenes/<name>/` locations; the `target_movement_behavior.gd` reference (under `components/movement/`) left untouched.
- `project.godot` — `run/main_scene` changed to `res://scenes/game.tscn`.

### Acceptance Criteria
- [x] AC-01/02/03: Passed — confirmed via `Glob`, files relocated and none left at root.
- [x] AC-04: Passed — `camera.tscn` relocated; `components/camera/camera_bounds.gd` confirmed untouched.
- [x] AC-05: Passed — `game.tscn` relocated.
- [x] AC-06: Passed — `project.godot` updated.
- [x] AC-07: Passed (after fixing a real issue — see Notes).
- [x] AC-08: Passed — headless scene run + value-verification script confirm no regressions.
- [x] AC-09: Passed — `components/` confirmed unchanged (same 12 files).

### Notes
- **Real issue found and fixed during verification**: Godot's `uid_cache.bin` still resolved the moved scenes' uids to their old root-level paths after the move, causing `--check-only` to fail with "Cannot open file" errors even though every `path=` string in the `.tscn` files was correctly updated. This is the same class of staleness seen twice before (global script class cache, `.uid` file generation) in the prior feature. Fixed identically: ran `godot --headless --editor --quit` once to force a full project rescan, which updated the uid cache; re-ran `--check-only` afterward with zero errors.
- No other deviations from `plan.md`.
