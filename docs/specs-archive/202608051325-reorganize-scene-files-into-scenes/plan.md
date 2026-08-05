# Implementation Plan: Reorganize Scene Files into scenes/

## Overview
Move five root-level scene+script pairs (`player`, `enemy`, `world`, `camera`, `game`) into a new `scenes/<name>/` directory structure, mirroring the existing `components/<category>/` convention. Update `game.tscn`'s four `ext_resource` entries and `project.godot`'s `run/main_scene` to reflect the new paths. `components/` is untouched. This is a pure file-move refactor with no logic, composition, or behavior changes — the main risk is breaking a cross-reference during the move, so verification leans on headless compile + runtime checks reusing the pattern from the prior feature.

## Architecture Decisions
- **Mirror `components/<category>/` with `scenes/<entity>/`** — per `feature.md`'s User Story, this gives the project two parallel, consistent top-level conventions: `components/` for reusable behaviors, `scenes/` for entity/scene ownership. Future entities (towers, bosses, projectiles) should follow `scenes/<entity>/` from the start.
- **`camera.tscn` moves to `scenes/camera/`, but `camera_bounds.gd` stays at `components/camera/`** — confirmed in `feature.md` FR-03/AC-04. The scene is instanced as an entity (child of Player in `game.tscn`), while the script is a reusable, self-configuring behavior; splitting them across `scenes/`/`components/` is intentional, not an oversight.
- **Rely on Godot's `uid=` resolution, but still update `path=` strings for correctness.** Inspecting the current files confirms every `ext_resource` line already carries both `uid=` and `path=` attributes (e.g. `game.tscn:3` — `uid="uid://so61by00eisd" path="res://world.tscn"`). Godot resolves by uid first, so references would likely still work even with a stale `path=`, but leaving a stale path is misleading and untidy — this plan updates both attributes on every touched line rather than relying on uid resolution alone.
- **No `.uid` file renaming needed beyond moving them alongside their `.gd` files** — `.uid` sidecar files are named after their script (e.g. `player.gd.uid`) and contain the uid value, not a path; moving the pair together (`player.gd` + `player.gd.uid`) to the same new directory keeps them correctly associated.

## Implementation Steps

### Step 1: Move player.tscn/player.gd ✅
- [x] Create `scenes/player/` directory.
- [x] Move `player.tscn` → `scenes/player/player.tscn`.
- [x] Move `player.gd` → `scenes/player/player.gd`.
- [x] Move `player.gd.uid` → `scenes/player/player.gd.uid`.
- [x] Inspect `scenes/player/player.tscn`'s `ext_resource` line for `player.gd` (currently `uid="uid://b7j0u5fsvh52h" path="res://player.gd"`) — update `path=` to `res://scenes/player/player.gd"`. Leave `uid=` unchanged (it's a content identifier, not a path). The `input_movement_behavior.gd` reference is untouched since that file isn't moving.
- Files to move: `player.tscn`, `player.gd`, `player.gd.uid`

### Step 2: Move enemy.tscn/enemy.gd ✅
- [x] Create `scenes/enemy/` directory.
- [x] Move `enemy.tscn` → `scenes/enemy/enemy.tscn`.
- [x] Move `enemy.gd` → `scenes/enemy/enemy.gd`.
- [x] Move `enemy.gd.uid` → `scenes/enemy/enemy.gd.uid`.
- [x] Update `scenes/enemy/enemy.tscn`'s `ext_resource` line for `enemy.gd` (`uid="uid://c0qmc0ugxjtqe" path="res://enemy.gd"`) → `path="res://scenes/enemy/enemy.gd"`. The `icon.svg` texture reference is untouched since that file isn't moving.
- Files to move: `enemy.tscn`, `enemy.gd`, `enemy.gd.uid`

### Step 3: Move world.tscn/world.gd ✅
- [x] Create `scenes/world/` directory.
- [x] Move `world.tscn` → `scenes/world/world.tscn`.
- [x] Move `world.gd` → `scenes/world/world.gd`.
- [x] Move `world.gd.uid` → `scenes/world/world.gd.uid`.
- [x] Update `scenes/world/world.tscn`'s `ext_resource` line for `world.gd` to point at `res://scenes/world/world.gd`. Confirmed actual line was `uid="uid://doqf04wgc8l0i" path="res://world.gd"` — matched the plan's expectation.
- Files to move: `world.tscn`, `world.gd`, `world.gd.uid`

### Step 4: Move camera.tscn (script stays in components/) ✅
- [x] Create `scenes/camera/` directory.
- [x] Move `camera.tscn` → `scenes/camera/camera.tscn`.
- [x] `camera.tscn`'s `ext_resource` line for `camera_bounds.gd` (`uid="uid://4ylns0x44pk1" path="res://components/camera/camera_bounds.gd"`) needs **no change** — confirmed, `camera_bounds.gd` is not moving, so its path is already correct.
- [x] Confirmed `components/camera/camera_bounds.gd` and its `.uid` file are untouched (per AC-04/AC-09).
- Files to move: `camera.tscn` only

### Step 5: Move game.tscn and update its ext_resource paths ✅
- [x] Move `game.tscn` → `scenes/game.tscn`.
- [x] Update all four `ext_resource` lines in `scenes/game.tscn`:
  - `world.tscn`: `uid="uid://so61by00eisd" path="res://world.tscn"` → `path="res://scenes/world/world.tscn"`
  - `player.tscn`: `uid="uid://cwudhn0jxd4l6" path="res://player.tscn"` → `path="res://scenes/player/player.tscn"`
  - `enemy.tscn`: `uid="uid://cmaog850sk7dq" path="res://enemy.tscn"` → `path="res://scenes/enemy/enemy.tscn"`
  - `camera.tscn`: `uid="uid://bi28bpecb5fr" path="res://camera.tscn"` → `path="res://scenes/camera/camera.tscn"`
  - The `target_movement_behavior.gd` reference (line 6) is untouched — that file lives under `components/movement/` and isn't moving.
- Files to move: `game.tscn`

### Step 6: Update project.godot ✅
- [x] Change `run/main_scene="res://game.tscn"` to `run/main_scene="res://scenes/game.tscn"`.
- Files to modify: `project.godot`

### Step 7: Verification ✅
- [x] Ran `godot --headless --check-only --path .`. First attempt failed with "Cannot open file 'res://world.tscn'"/"'res://player.tscn'"/"'res://enemy.tscn'"/"'res://camera.tscn'" — Godot's `uid_cache.bin` still pointed those uids at the old root-level paths (same class of staleness seen twice before with the class cache and `.uid` generation in the prior feature). Fixed by running `godot --headless --editor --quit` once to force a full rescan; re-ran `--check-only` afterward with zero errors.
- [x] Ran `godot --headless --path . scenes/game.tscn --quit-after 60` — no runtime errors instantiating the relocated main scene.
- [x] Reused the headless verification-script pattern from the previous feature (`verify_bounds.gd`, deleted after use): instantiated `scenes/game.tscn` and confirmed `player.world_size = (1600, 1200)`, camera limits `= 0 0 1600 1200`, and a late subscriber still immediately received `(1600.0, 1200.0)` — the `GameEvents`/`BehaviorSubject` wiring is fully intact after the move.
- [x] Confirmed via `Glob` that no `.tscn`/`.gd`/`.gd.uid` file remains at the project root for `player`, `enemy`, `world`, `camera`, or `game` (per AC-01–05), and that `components/` still contains exactly its prior 12 files, unchanged (per AC-09).

## Acceptance Criteria Mapping
| AC | Verified By |
|----|-------------|
| AC-01: player files relocated, none left at root | Step 1 + Step 7's directory listing check |
| AC-02: enemy files relocated, none left at root | Step 2 + Step 7's directory listing check |
| AC-03: world files relocated, none left at root | Step 3 + Step 7's directory listing check |
| AC-04: camera.tscn relocated; camera_bounds.gd unmoved | Step 4 + Step 7's directory listing check |
| AC-05: game.tscn relocated, none left at root | Step 5 + Step 7's directory listing check |
| AC-06: project.godot main_scene updated | Step 6 — code inspection |
| AC-07: headless check-only produces no errors | Step 7 — headless `--check-only` run |
| AC-08: headless run of scenes/game.tscn shows no runtime errors, GameEvents wiring intact | Step 7 — headless scene run + verification script |
| AC-09: components/ unchanged | Step 4 + Step 7 — no files under `components/` touched in any step |

## Risks & Mitigations
- Risk: Missing or mistyping one of the four `ext_resource` path updates in `scenes/game.tscn` (Step 5) breaks the main scene, since it's the composition root referencing all other moved scenes. → Mitigation: Step 7's headless `--check-only` run will surface a "resource not found" error immediately if any path is wrong; each path is also individually listed in Step 5 for careful, one-at-a-time editing rather than a bulk find-replace that could miss a variant.
- Risk: Godot's editor may still hold cached references to the old root-level paths (similar to the `.uid`/class-cache staleness seen in the prior feature) and could prompt to "fix broken paths" or silently duplicate resources on next editor open. → Mitigation: the headless verification in Step 7 checks the CLI/engine's view of the project, which is authoritative for the move's correctness; if the editor later prompts about broken paths, that's expected and should be accepted (confirming the new paths), not a sign of a mistake in this plan.
- Risk: `world.tscn`'s exact `ext_resource` line for `world.gd` wasn't directly re-inspected during this planning pass (only inferred from the pattern seen in `player.tscn`/`enemy.tscn`) — Step 3 accounts for this by instructing to read the actual current content before editing, rather than assuming the exact uid string.
- Risk: Deleting old root-level files without confirming the move succeeded first could lose work if a move is interrupted. → Mitigation: use move operations (not copy+delete) so each file only exists in one place at a time, and verify each step's move succeeded (e.g. via a quick existence check) before proceeding to the next.

## Estimated Complexity
Low — this is a mechanical file-move refactor touching 5 directories, 5 scene files' `ext_resource` blocks (4 of them just self-referencing their own root script, 1 being the composition root with 4 references to update), and one line in `project.godot`. No new logic. The main diligence required is getting every path string exactly right and verifying headlessly rather than assuming the move is correct.
