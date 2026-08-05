# Feature: Reorganize Scene Files into scenes/

## Summary
Move the project's root-level entity scene files (`player.tscn`/`player.gd`, `enemy.tscn`/`enemy.gd`, `world.tscn`/`world.gd`, `camera.tscn`) and the main scene (`game.tscn`) into a new top-level `scenes/` directory, mirroring the existing `components/<category>/` convention. Each entity gets its own subfolder pairing its scene with its root script (`scenes/player/`, `scenes/enemy/`, `scenes/world/`, `scenes/camera/`), and `game.tscn` moves to `scenes/game.tscn`. This is a pure file-organization refactor — no scene composition, node structure, script logic, or gameplay behavior changes. `components/` continues to hold only reusable, shared behaviors (movement, camera-bounds logic, events) and is not restructured by this feature.

## User Stories
- As a developer navigating this project, I want entity scenes grouped under `scenes/` the same way reusable behaviors are grouped under `components/`, so that the project root isn't cluttered with loose `.tscn`/`.gd` pairs and the organizational convention is consistent across the whole codebase.

## Functional Requirements

### FR-01: Create scenes/ directory structure
Create the following new paths, moving files from their current root-level locations:
- `scenes/player/player.tscn`, `scenes/player/player.gd`, `scenes/player/player.gd.uid`
- `scenes/enemy/enemy.tscn`, `scenes/enemy/enemy.gd`, `scenes/enemy/enemy.gd.uid`
- `scenes/world/world.tscn`, `scenes/world/world.gd`, `scenes/world/world.gd.uid`
- `scenes/camera/camera.tscn` (script stays at `components/camera/camera_bounds.gd` — see FR-03)
- `scenes/game.tscn`

### FR-02: Update all cross-references
Update every `ext_resource` path/uid reference across all `.tscn` files, and `project.godot`'s `run/main_scene`, to point at the new locations. Specifically:
- `scenes/game.tscn`'s `ext_resource` entries for `world.tscn`, `player.tscn`, `enemy.tscn`, `camera.tscn` (currently referencing root-level paths) must point to their new `scenes/<name>/` paths.
- `project.godot`'s `run/main_scene` must be updated from `res://game.tscn` to `res://scenes/game.tscn`.
- Any `uid=` references already present (e.g. `player.tscn`'s own scene uid, `player.gd`'s script uid) are content-addressed by Godot and do not need path updates — Godot re-resolves `uid://...` references by scanning, not by stored path. Only `path=`-only references (no `uid=`, if any remain — e.g. `camera.tscn`'s `ext_resource` for `camera_bounds.gd` at time of writing) need their literal path string updated if the referenced file's path is changing. Since `camera_bounds.gd` itself is NOT moving (it stays under `components/camera/`), that particular reference does not need a path change — only `camera.tscn`'s own new location changes, which is why FR-02 focuses on the four `ext_resource` entries inside `game.tscn` plus `project.godot`.

### FR-03: components/ is unaffected
No files under `components/` (movement, camera, events) are moved or renamed by this feature. `components/camera/camera_bounds.gd` remains in place; only `camera.tscn` (the scene that instances it) moves to `scenes/camera/camera.tscn`.

## Acceptance Criteria
- [x] AC-01: `player.tscn`, `player.gd`, `player.gd.uid` exist at `scenes/player/` and no longer exist at the project root.
- [x] AC-02: `enemy.tscn`, `enemy.gd`, `enemy.gd.uid` exist at `scenes/enemy/` and no longer exist at the project root.
- [x] AC-03: `world.tscn`, `world.gd`, `world.gd.uid` exist at `scenes/world/` and no longer exist at the project root.
- [x] AC-04: `camera.tscn` exists at `scenes/camera/` and no longer exists at the project root; `components/camera/camera_bounds.gd` is unchanged and unmoved.
- [x] AC-05: `game.tscn` exists at `scenes/game.tscn` and no longer exists at the project root.
- [x] AC-06: `project.godot`'s `run/main_scene` points to `res://scenes/game.tscn`.
- [x] AC-07: Running the project headless (`godot --headless --check-only`) produces no parse/load errors after the move.
- [x] AC-08: A headless run of `scenes/game.tscn` shows no runtime errors (regression check reusing the pattern from the previous feature's verification — confirms `GameEvents.world_size_changed` propagation, camera limits, and player position clamping all still work after the path changes).
- [x] AC-09: No files under `components/` are moved, renamed, or modified.

## Technical Scope

### Affected Modules
- All five entity/main scenes and their paired root scripts (`player`, `enemy`, `world`, `camera`, `game`).
- `project.godot` (`run/main_scene` path update).

### New Components Required
- None — this is a pure reorganization; no new classes, scripts, or scenes are created.

### Integration Points
- `scenes/game.tscn`'s `ext_resource` block is the primary place requiring reference updates, since it's the composition root instancing all four other moved scenes.
- `components/camera/camera_bounds.gd`'s reference from `scenes/camera/camera.tscn` — path/uid handling depends on whether that reference currently uses `uid=` or `path=` (to be confirmed by inspecting the file during implementation; per FR-02, no change needed if it already uses `uid=`).

## Non-Functional Requirements
- Performance: none — file relocation has no runtime performance impact.
- Security: not applicable.
- Scalability: establishes a consistent `scenes/<entity>/` convention that future entities (towers, bosses, projectiles) should follow, mirroring `components/<category>/`.

## Out of Scope
- Any change to scene composition, node structure, script logic, or gameplay behavior.
- Restructuring or renaming anything under `components/`.
- Renaming the entities themselves (`Player`, `Enemy`, `World`, `Game`, `Camera2D` node names are unchanged).
- Automated tests (none configured in this project yet) — verification is headless compile/run checks only, consistent with prior features.

## Open Questions
None — `game.tscn`'s destination, `camera.tscn`'s grouping, and `.uid` file handling were all confirmed with the user during spec analysis.
