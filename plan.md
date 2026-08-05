# Implementation Plan: Status Scene with Health and Shield Components (status_type/value_changed refactor)

## Overview
This feature's core implementation already exists and passed review (`review.md`, all 9 ACs covered, two rounds of minor fixes applied). `feature.md` was subsequently refined to change how a `StatusComponent` identifies itself and reports value changes: `status_type` moves from a per-subclass `var` (set via `_init()`, connected via `has_signal()` duck-typing + `.bind()`) to a per-subclass `const STATUS_TYPE`, with the `value_changed` signal itself moved onto the `StatusComponent` base class (carrying `status_type` as its first argument). This plan is a **refactor of existing, working code** to match the refined spec — no new files, no behavior change, and the previously-verified acceptance criteria must still hold afterward.

The `roundi()`-based precision fixes and the `maxi(max_value, 1)` clamp in `Status._on_component_value_changed()` (both applied after the original review) are preserved as-is; this refactor only touches the `status_type`/`value_changed` wiring mechanism.

## Architecture Decisions
- **`value_changed` declared once on `StatusComponent`, not per-subclass**: matches the refined FR-02 — every `StatusComponent` is now guaranteed (by inheritance, not convention) to expose the same signal with the same signature. This removes the last spot where a future subclass could accidentally get the signature wrong (previously only guarded by a code comment, per the original review's Info-level style note).
- **`STATUS_TYPE` as a per-subclass `const`, not an inherited `var`**: removes the `_init()`-based workaround entirely (the original review flagged this as an unusual pattern worth a comment; the refined design removes the need for the workaround altogether rather than just documenting it).
- **`Status._ready()` connects via `child is StatusComponent`, not `child.has_signal("value_changed")`**: since `value_changed` is now unconditionally present on every `StatusComponent` (inherited, not duck-typed), the existing `is StatusComponent` check already used in `apply_event()` is sufficient for wiring too — no separate `has_signal()` check or `.bind()` needed.
- **No change to `StatusEvent`, `HealthBar`, scene wiring, or the `roundi`/`maxi` fixes**: this refactor is scoped exactly to the `status_type`/`value_changed` mechanism inside `components/status/status_component.gd`, `health_component.gd`, `shield_component.gd`, and `scenes/status/status.gd`.

## Implementation Steps

### Step 1: StatusComponent base class
- [x] Modify `components/status/status_component.gd`:
  - Remove `var status_type: String = ""` and its doc comment.
  - Add `signal value_changed(status_type: String, current_value: int, max_value: int)`.
  - `handle_event()` stays unchanged.
- Files: `components/status/status_component.gd` (modified)

### Step 2: HealthComponent
- [x] Modify `components/status/health_component.gd`:
  - Remove `signal value_changed(current_value: int, max_value: int)` (now inherited from base).
  - Remove `func _init() -> void: status_type = "health"`.
  - Add `const STATUS_TYPE := "health"`.
  - In `handle_event()`, change `value_changed.emit(current_health, max_health)` to `value_changed.emit(STATUS_TYPE, current_health, max_health)`.
  - `died` signal, `max_health`, `current_health`, `_ready()`, and the `roundi()`-based damage calculation are unchanged.
- Files: `components/status/health_component.gd` (modified)

### Step 3: ShieldComponent
- [x] Modify `components/status/shield_component.gd`:
  - Remove `signal value_changed(current_value: int, max_value: int)` (now inherited from base).
  - Remove `func _init() -> void: status_type = "shield"`.
  - Add `const STATUS_TYPE := "shield"`.
  - In `handle_event()`, change `value_changed.emit(current_shield, max_shield)` to `value_changed.emit(STATUS_TYPE, current_shield, max_shield)`.
  - `max_shield`, `current_shield`, `_ready()`, and the `roundi()`-based absorption calculation are unchanged.
- Files: `components/status/shield_component.gd` (modified)

### Step 4: Status pipeline wiring
- [x] Modify `scenes/status/status.gd`:
  - In `_ready()`, change the connection loop from:
    ```
    if child.has_signal("value_changed"):
        child.value_changed.connect(_on_component_value_changed.bind(child.status_type))
    ```
    to:
    ```
    if child is StatusComponent:
        child.value_changed.connect(_on_component_value_changed)
    ```
  - Change `_on_component_value_changed`'s signature from `(current_value: int, max_value: int, status_type: String)` to `(status_type: String, current_value: int, max_value: int)` (matching the new signal's argument order — `status_type` first, no longer appended via `.bind()`).
  - The body (`status_update.emit(status_type, current_value, maxi(max_value, 1))`) is unchanged aside from parameter reordering.
  - `apply_event()` is unchanged.
- Files: `scenes/status/status.gd` (modified)

### Step 5: Regression verification (no test framework configured)
- [x] Recompile/check the full project (`godot --headless --check-only --quit`) — confirm no parse errors from the removed `var status_type` / re-declared signals.
- [x] Re-run the same manual verification matrix used in the original implementation, since the wiring mechanism changed even though behavior shouldn't:
  - AC-01/AC-02/AC-03: fixed-value damage scenarios (30 dmg no shield → health 70; 30 dmg w/ shield → shield 20/health 100; 70 dmg fresh w/ shield → shield 0/health 80).
  - AC-04: oversized damage clamps health to 0, not negative.
  - AC-05: `died` fires exactly once at 0 health, node stays in tree.
  - AC-06/AC-07: `HealthBar` (via the actual wired `Player`/`Enemy` scenes) stays hidden at full health, becomes visible when damaged, fill proportion matches `current/max`.
  - AC-08: unknown event `type` is ignored by both components, no error.
  - AC-09 (structural): confirm neither `status_component.gd`, `health_component.gd`, `shield_component.gd`, nor `status.gd` reference each other's concrete class names (`is HealthComponent`/`is ShieldComponent`) — grep-verify, same check as the original review.
  - Precision regression: re-verify `roundi()` behavior still applies correctly post-refactor (e.g. `30.6` damage → `31` applied), since `handle_event()`'s damage-math lines are untouched but worth confirming after the surrounding signal-emission line changed.
- Files: none permanent — temporary debug scripts/scenes created and deleted during verification, consistent with the original implementation's approach.

## Acceptance Criteria Mapping
| AC | Verified By |
|----|-------------|
| AC-01–AC-09 | Step 5 regression pass — re-running the exact same manual checks from the original implementation against the refactored wiring, since no behavior is intended to change |

## Risks & Mitigations
- **Risk**: Removing `var status_type` from `StatusComponent` could break anything else in the codebase that reads `status_type` externally (e.g. if `HealthBar` or another script referenced `component.status_type` directly). → **Mitigation**: grep confirms `status_type` is only read internally by `Status._ready()`'s old `.bind(child.status_type)` call (being removed in this same step) and set by each component's own `_init()` (being removed) — no external readers exist. Verify with a final grep for `status_type` across the project after the refactor to confirm zero remaining references outside the removed code.
- **Risk**: Argument-order regression — `_on_component_value_changed`'s parameter order must be updated to match the new signal's argument order (`status_type` first now, not last via `.bind()`); mixing up the old vs. new order would silently pass the wrong value as `status_type`/`current_value`/`max_value` (both are typed but `String`/`int` mismatches would still surface as a runtime type error, not a silent bug, since GDScript signals type-check connected callback parameters). → **Mitigation**: Step 4 spells out the exact new signature; Step 5's regression pass re-verifies real values end-to-end (e.g. confirming `HealthBar` still shows `"health"`-tagged updates correctly), which would catch an argument-order mistake immediately.
- **Risk**: No automated tests means this refactor's correctness rests entirely on manual re-verification. → **Mitigation**: consistent with the project's existing lack of a test framework; Step 5 explicitly re-runs the full original AC verification matrix rather than assuming the refactor is behavior-preserving without checking.

## Estimated Complexity
**Low** — a pure internal-wiring refactor across 4 already-small, already-reviewed files; no new files, no scene changes, no behavior change. The only care needed is getting the new signal's parameter order right in `Status._on_component_value_changed` and re-verifying the full AC matrix to confirm nothing silently broke.
