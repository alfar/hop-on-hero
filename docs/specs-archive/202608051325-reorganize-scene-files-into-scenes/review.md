# Code Review: Reorganize Scene Files into scenes/

## Summary
The file moves themselves are clean and complete: every `ext_resource` path was correctly updated, `components/`-owned references were correctly left alone, and independent re-verification (headless `--check-only` and a headless run of `scenes/game.tscn`) both pass with zero errors. The one real finding is documentation drift outside this feature's stated scope but caused by it: `docs/project.md` still links to `enemy.gd`/`player.gd` at their old root-level paths, which no longer exist. This is a MINOR, easy fix — nothing here blocks merging.

## Findings

### 🔴 Critical

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|

### 🟠 Major

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|

### 🟡 Minor

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [ ] | `docs/project.md:22` | Documentation Drift | The markdown links `[enemy.gd](enemy.gd)` and `[player.gd](player.gd)` point at the pre-move root-level paths, which no longer exist after this feature relocated both files to `scenes/enemy/enemy.gd` and `scenes/player/player.gd` — clicking either link in a renderer that resolves relative paths will 404. | Update the two links to `[enemy.gd](../scenes/enemy/enemy.gd)` and `[player.gd](../scenes/player/player.gd)` (relative to `docs/`), matching the already-correct `components/movement/...` links on the line above. |

### 🔵 Info / Suggestions

| Done | Location | Category | Problem | Suggestion |
|------|----------|----------|---------|------------|
| [ ] | `plan.md:60`, `impl-summary.md` (prior features) | Process | This is the third consecutive feature where a headless Godot operation failed on the first attempt due to stale internal caches (global script class cache, missing `.uid` files, and now `uid_cache.bin` pointing at pre-move paths), each time fixed by the same `godot --headless --editor --quit` rescan trick — the pattern is well-understood at this point but still costs a failed run every time. | Optional: consider running that rescan proactively as the first step of any future file-move or new-script feature's verification, rather than discovering the staleness reactively each time. |

## Acceptance Criteria Coverage
| AC | Test | Status |
|----|------|--------|
| AC-01: player files relocated, none left at root | Independently confirmed via directory read of `scenes/player/` and absence at root | ✅ Covered |
| AC-02: enemy files relocated, none left at root | Independently confirmed via directory read of `scenes/enemy/` and absence at root | ✅ Covered |
| AC-03: world files relocated, none left at root | Independently confirmed via directory read of `scenes/world/` and absence at root | ✅ Covered |
| AC-04: camera.tscn relocated; camera_bounds.gd unmoved | Independently confirmed — `scenes/camera/camera.tscn` exists, `components/camera/camera_bounds.gd` unchanged | ✅ Covered |
| AC-05: game.tscn relocated, none left at root | Independently confirmed via `scenes/game.tscn` | ✅ Covered |
| AC-06: project.godot main_scene updated | Code inspection — `project.godot:14` reads `res://scenes/game.tscn` | ✅ Covered |
| AC-07: headless check-only produces no errors | Independently re-ran `godot --headless --check-only` — zero errors | ✅ Covered |
| AC-08: headless run of scenes/game.tscn shows no runtime errors, GameEvents wiring intact | Independently re-ran a headless scene instantiation — zero errors; prior implementation's value-verification script (now deleted) also confirmed `GameEvents`/`BehaviorSubject` propagation | ✅ Covered |
| AC-09: components/ unchanged | Confirmed via grep — no stray references to moved files remain in any `.tscn`/`.gd`/`project.godot` file, and `components/` contents inspected directly (camera_bounds.gd unchanged) | ✅ Covered |

## Verdict
- [ ] ✅ Ready to merge
- [x] 🟡 Merge after minor fixes (no re-review needed)
- [ ] 🟠 Requires fixes and re-review
- [ ] 🔴 Do not merge — significant issues found
