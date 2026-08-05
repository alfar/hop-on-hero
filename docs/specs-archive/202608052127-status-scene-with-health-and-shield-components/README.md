# Status Scene with Health and Shield Components

Implemented on: 2026-08-05

Added a new `Status` scene (instanced as a child of `Player`/`Enemy`) implementing a generic, order-dependent event pipeline: `Status.apply_event(StatusEvent)` walks its `StatusComponent` children in scene-tree order, calling `handle_event()` on each so a component earlier in the list (e.g. `ShieldComponent`) can reduce or fully absorb an event's `amount` before a later component (e.g. `HealthComponent`) ever sees it. Two concrete components were built: `ShieldComponent` (a depletable second health pool) and `HealthComponent` (clamped `[0, max_health]`, emits `died` at zero). A `HealthBar` UI node (a sibling of `Status`, not nested under it) listens to `Status`'s unified `status_update` signal and stays hidden until the entity takes damage.

Key files:
- `components/status/status_event.gd` — `StatusEvent`, a `RefCounted` carrying `type`/`amount`
- `components/status/status_component.gd` — `StatusComponent` base `Node`, declares the shared `value_changed(status_type, current_value, max_value)` signal
- `components/status/health_component.gd`, `shield_component.gd` — concrete components, each with a `const STATUS_TYPE`
- `scenes/status/status.gd` + `status.tscn` — the pipeline scene
- `scenes/health_bar/health_bar.gd` + `health_bar.tscn` — the visual health bar
- `scenes/player/player.tscn`, `scenes/enemy/enemy.tscn` — wired with `Status` + `HealthBar` children

Notable decisions:
- `StatusComponent` is `Node`-based (not `Resource`-based like `MovementBehavior`/`Activity`) since the pipeline's ordering mechanism is scene-tree child position itself.
- `value_changed` is declared once on the `StatusComponent` base class (carrying `status_type` as an argument) rather than re-declared per subclass — this was a mid-implementation refinement that replaced an earlier design using a per-subclass `status_type` var set via `_init()` and connected via `has_signal()` duck-typing + `.bind()`. The refactor makes every subclass's signal signature structurally guaranteed by inheritance rather than by convention.
- `HealthBar` lives under `scenes/`, not `components/status/`, establishing a project-wide presentation-vs-behavior placement convention (see `docs/project.md` Architecture Decisions).
- No damage source is wired up in this feature — `Status.apply_event()` is a new public entry point with no caller yet; wiring a real projectile/melee-attack source is left for a future feature.
- No automated tests exist in this project; all 9 acceptance criteria (including a post-refactor regression pass) were verified manually via Godot's headless CLI against the actual wired `Player`/`Enemy` scenes.
