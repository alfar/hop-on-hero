# Reorganize Scene Files into scenes/

Implemented on: 2026-08-05

Moved the project's five root-level entity/main scenes (`player.tscn`, `enemy.tscn`, `world.tscn`, `camera.tscn`, `game.tscn`) and their paired root scripts into a new top-level `scenes/<entity>/` directory structure, mirroring the existing `components/<category>/` convention. `camera.tscn` moved to `scenes/camera/` while its script (`camera_bounds.gd`) stayed in `components/camera/`, since the scene is entity-owned but the script is a reusable, self-configuring behavior. `components/` was otherwise untouched. Pure file-organization refactor — no scene composition, node structure, or gameplay logic changes.

Verification hit the same class of stale-cache issue seen in prior features: Godot's `uid_cache.bin` still resolved the moved scenes' uids to their old root-level paths after the move, causing `--check-only` to fail even though every `path=` string was correctly updated. Fixed by forcing a headless editor rescan (`godot --headless --editor --quit`). Re-verified with a headless scene run and a reused value-verification script confirming `GameEvents`/`BehaviorSubject` wiring still works correctly after the move.

Code review caught one MINOR documentation-drift issue outside this feature's stated scope but caused by it: `docs/project.md` still linked to `enemy.gd`/`player.gd` at their old root-level paths. Fixed by updating those two links to their new `scenes/` locations.
