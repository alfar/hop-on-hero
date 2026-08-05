# Feature: Status Scene with Health and Shield Components

## Summary
Introduce a reusable `Status` scene that can be instanced as a child of any entity (`Player`, `Enemy`) to track its condition — health, shield, and (in the future) other resources like mana. `Status` is a generic event pipeline: it holds an ordered list of `StatusComponent` child nodes, and any incoming `StatusEvent` (e.g. physical damage) is passed through each child in scene-tree order via `handle_event()`, letting each component consume, reduce, or ignore it. This feature implements the pipeline mechanism itself plus two concrete components — `HealthComponent` and `ShieldComponent` (a depletable second health pool that absorbs damage before it reaches `HealthComponent`) — along with a `HealthBar` UI node that visually displays current health and is hidden at full health. The ordered, per-component interception design is explicitly built to support future components (e.g. an `InvulnerabilityStatusComponent` that can be placed before `ShieldComponent` to block damage from ever reaching it, or after it to let the shield still deplete while protecting only health) without changing the pipeline mechanism itself.

## User Stories
- As a player, I want to see a health bar appear over my character (or an enemy) once it takes damage, so I have visual feedback on how wounded it is.
- As a developer, I want to deal damage to any entity through one uniform call (`Status.apply_event(...)`), regardless of whether that entity has a shield, so damage sources don't need to know about an entity's specific defensive setup.
- As a developer, I want to add new status components (shield, future invulnerability, mana) by dropping a new child node into the `Status` scene in the right order, without modifying the pipeline or existing components' code.

## Functional Requirements

### FR-01: `StatusEvent`
A lightweight, non-persisted event class:
```
class_name StatusEvent
extends RefCounted

var type: String
var amount: float

func _init(p_type: String, p_amount: float) -> void:
    type = p_type
    amount = p_amount
```
`extends RefCounted` (not `Resource`) since these are short-lived, never saved/loaded, and should be garbage-collected as soon as nothing references them — matching how `BehaviorSubject` (`components/events/behavior_subject.gd`) is already `RefCounted`. For this feature, only one `type` value is defined: `"physical_damage"`. Future features (e.g. a Mana component) will introduce further types (e.g. `"mana_cost"`) without requiring changes to `StatusEvent` itself, since `type` is a free-form `String`.

### FR-02: `StatusComponent` base class
A new base class all status components extend, under `components/status/`:
```
class_name StatusComponent
extends Node

signal value_changed(status_type: String, current_value: int, max_value: int)

func handle_event(event: StatusEvent) -> void:
    pass # overridden per component; may mutate event.amount or leave it untouched
```
`StatusComponent` extends `Node` (not `Resource`), since components need their own scene-tree presence, signals, and lifecycle — per confirmed design, this differs from the `MovementBehavior`/`Activity` `Resource`-strategy pattern used elsewhere in this codebase, because here the *ordering of sibling nodes in the scene tree* is itself the mechanism (a `Resource` array couldn't express "this component's own node order determines the pipeline").

`value_changed` is declared once on the base class (not re-declared per subclass) and carries `status_type` as its first argument. Each concrete subclass identifies itself via its own `const STATUS_TYPE` (not an inherited/overridden `var`) and passes that constant when it emits `value_changed`. This means every `StatusComponent` is guaranteed to expose the same `value_changed` signal with the same signature simply by inheritance — no `has_signal()` duck-typing or a separate `status_type` field lookup is needed by `Status` to wire things up (see FR-03).

### FR-03: `Status` scene — the event pipeline
A new scene `scenes/status/status.tscn` (script `status.gd`), instanced as a child of `Player`/`Enemy`:
```
class_name Status
extends Node2D

signal status_update(type: String, current_value: int, max_value: int)

func _ready() -> void:
    for child in get_children():
        if child is StatusComponent:
            child.value_changed.connect(_on_component_value_changed)

func apply_event(event: StatusEvent) -> void:
    for child in get_children():
        if child is StatusComponent:
            child.handle_event(event)

func _on_component_value_changed(status_type: String, current_value: int, max_value: int) -> void:
    status_update.emit(status_type, current_value, max_value)
```
- `apply_event(event)` walks `get_children()` **in scene-tree order** (the order children appear under `Status` in the editor), calling `handle_event(event)` on each `StatusComponent`. The same `event` object (and its possibly-mutated `amount`) is passed to each subsequent child — this is the entire "interception" mechanism: a component earlier in the list can reduce `event.amount` (down to `0`) before a later component ever sees it.
- Because `value_changed` (with `status_type` as its first argument) is declared once on the `StatusComponent` base class (see FR-02), `Status` connects to it directly on every `StatusComponent` child in `_ready()` — no `has_signal()` duck-typing, no `.bind()`, and no separate `status_type` field lookup. `Status` re-emits a single unified `status_update(type, current_value, max_value)` signal — this way any listener (e.g. `HealthBar`) needs only one connection to `Status`, regardless of how many components exist underneath it.
- Damage sources call `Status.apply_event(StatusEvent.new("physical_damage", amount))` directly on the target entity's `Status` child node — no new autoload or global damage bus is introduced.

### FR-04: `HealthComponent`
A new `StatusComponent` subclass under `components/status/`:
```
class_name HealthComponent
extends StatusComponent

const STATUS_TYPE := "health"

signal died

@export var max_health: int = 100
var current_health: int

func _ready() -> void:
    current_health = max_health

func handle_event(event: StatusEvent) -> void:
    if event.type != "physical_damage":
        return
    current_health = clampi(current_health - int(event.amount), 0, max_health)
    value_changed.emit(STATUS_TYPE, current_health, max_health)
    if current_health == 0:
        died.emit()
```
`value_changed` is inherited from `StatusComponent` (FR-02), not re-declared here; `STATUS_TYPE` is a plain `const`, not an inherited/overridden `var`.
- Only reacts to `"physical_damage"` events; ignores any other `type` value (forward-compatible with future event types this component doesn't care about, e.g. a future `"mana_cost"`).
- Emits `died` when `current_health` reaches `0`. Per confirmed scope, this feature only emits the signal — no entity removal, respawn, or game-over handling is implemented; that is left for a future feature to consume.
- `current_health` is clamped to `[0, max_health]`; damage cannot reduce it below `0`, healing (a future event type) cannot raise it above `max_health`.

### FR-05: `ShieldComponent`
A new `StatusComponent` subclass under `components/status/`:
```
class_name ShieldComponent
extends StatusComponent

const STATUS_TYPE := "shield"

@export var max_shield: int = 50
var current_shield: int

func _ready() -> void:
    current_shield = max_shield

func handle_event(event: StatusEvent) -> void:
    if event.type != "physical_damage" or current_shield <= 0:
        return
    var absorbed: int = mini(int(event.amount), current_shield)
    current_shield -= absorbed
    event.amount -= absorbed
    value_changed.emit(STATUS_TYPE, current_shield, max_shield)
```
`value_changed` is inherited from `StatusComponent` (FR-02), not re-declared here; `STATUS_TYPE` is a plain `const`, not an inherited/overridden `var`.
- Acts as a second, depletable health pool: absorbs incoming `"physical_damage"` up to its `current_shield`, reducing `event.amount` by the absorbed portion before passing the (possibly now-zero) remaining amount on to the next sibling in the pipeline (typically `HealthComponent`).
- If `current_shield` is already `0`, `handle_event` is a no-op and the event passes through unmodified — this is what allows `HealthComponent` (placed after `ShieldComponent` in the scene tree) to still take damage once the shield is depleted.
- No regeneration logic in this feature (out of scope) — once depleted, `ShieldComponent` stays at `0` for the rest of the entity's lifetime unless a future feature adds a heal/recharge event type.

### FR-06: `HealthBar`
A new UI node, `scenes/health_bar/health_bar.tscn`, instanced as a **child of the character** (`Player`/`Enemy`), a sibling of `Status` rather than a child of it. It lives under `scenes/` (not `components/status/`) because it is a presentation concern — a visual, no independent behavior/logic of its own beyond reflecting state — whereas `components/<category>/` is reserved for reusable behavior/logic pieces (`StatusComponent` and its subclasses, `MovementBehavior`, `Activity`, etc.); this presentation-vs-behavior split is worth carrying forward as a general project convention when this feature is archived.
- Subscribes to its sibling `Status` node's `status_update` signal.
- On `status_update("health", current_value, max_value)`, updates its fill/progress display.
- Ignores `status_update` calls for any other `type` (e.g. `"shield"`) in this feature — a future feature may add a separate `ShieldBar` following the same pattern.
- Visible only when `current_value < max_value` (i.e. hidden at full health, appears once damage has been taken), per confirmed design. No auto-hide-after-delay or re-hide-on-heal-to-full nuance is specified beyond this — see Acceptance Criteria.

## Acceptance Criteria
- [x] AC-01: Instancing `Status` as a child of `Player` (or `Enemy`), with a `HealthComponent` child (default `max_health = 100`), and calling `status.apply_event(StatusEvent.new("physical_damage", 30))` reduces `HealthComponent.current_health` to `70`.
- [x] AC-02: With a `ShieldComponent` (default `max_shield = 50`) placed before `HealthComponent` in the scene tree, applying a `"physical_damage"` event of `30` reduces `ShieldComponent.current_shield` to `20` and leaves `HealthComponent.current_health` unchanged at `100`.
- [x] AC-03: With the same setup as AC-02, applying a `"physical_damage"` event of `70` fully depletes `ShieldComponent.current_shield` to `0` and reduces `HealthComponent.current_health` to `80` (50 absorbed by shield, 20 passed through to health).
- [x] AC-04: `HealthComponent.current_health` never drops below `0`, even if a single event's `amount` exceeds remaining health.
- [x] AC-05: When `HealthComponent.current_health` reaches `0`, the `died` signal is emitted exactly once; no node is removed/freed as a result (no entity-removal logic in this feature).
- [x] AC-06: `HealthBar` is hidden when `HealthComponent.current_health == max_health`, and becomes visible after any `"physical_damage"` event reduces it below `max_health`.
- [x] AC-07: `HealthBar` visually reflects the current `status_update("health", ...)` value (i.e. its fill/progress matches `current_value / max_value`) after each applied event.
- [x] AC-08: A `StatusEvent` with a `type` not handled by a given component (e.g. `handle_event` called on `HealthComponent` with `type = "unknown_type"`) is ignored by that component with no error and no state change.
- [x] AC-09: Adding a third `StatusComponent` subclass in the future requires no changes to `Status`, `HealthComponent`, or `ShieldComponent` — verified structurally (the pipeline only depends on the `StatusComponent` base type and child scene-tree order).

## Technical Scope

### Affected Modules
- `scenes/player/player.tscn` — add a `Status` child instance (with a `HealthComponent` child, and a `HealthBar` sibling child of `Player`).
- `scenes/enemy/enemy.tscn` — add a `Status` child instance (with a `HealthComponent` child, and a `HealthBar` sibling child of `Enemy`).
- No changes to `player.gd`/`enemy.gd` scripts themselves are required by this feature — `Status` and `HealthBar` are purely additive scene children with their own scripts; nothing currently in `player.gd`/`enemy.gd` calls `apply_event` (see Out of Scope — no damage source is wired up in this feature).

### New Components Required
- `components/status/status_event.gd` — `class_name StatusEvent`, `extends RefCounted`.
- `components/status/status_component.gd` — `class_name StatusComponent`, base `Node`.
- `components/status/health_component.gd` — `class_name HealthComponent`, `extends StatusComponent`.
- `components/status/shield_component.gd` — `class_name ShieldComponent`, `extends StatusComponent`.
- `scenes/status/status.tscn` + `status.gd` — `class_name Status`, `extends Node2D`, the event pipeline scene, containing `HealthComponent`/`ShieldComponent` as children.
- `scenes/health_bar/health_bar.tscn` + `health_bar.gd` — the visual health bar UI node.

### Integration Points
- None with existing systems in this feature — `Status.apply_event()` is a new public entry point with no current caller. Wiring a real damage source (e.g. a future projectile/melee-attack feature) to call it is explicitly out of scope; this feature only builds and manually verifies the pipeline + components + visual bar.

## Non-Functional Requirements
- **Extensibility**: new `StatusComponent` subclasses must be addable purely by creating a new script/node and placing it as a child of `Status` in the desired pipeline position — no changes to `Status`, `StatusEvent`, or existing components' code.
- **Performance**: negligible — `apply_event` is a simple loop over a small number of children, invoked only when an event actually occurs (not every frame).
- **Memory**: `StatusEvent` instances are `RefCounted` and expected to be short-lived (created, passed through `apply_event`, then discarded) — no pooling or reuse required in this feature.

## Out of Scope
- Wiring any real damage source (projectiles, melee attacks, enemy contact damage) to call `Status.apply_event()` — this feature only builds the pipeline and components themselves, verified via direct manual/editor calls.
- `InvulnerabilityStatusComponent` (or any other component beyond `HealthComponent`/`ShieldComponent`) — documented above as a motivating future example of the pipeline's ordering flexibility, but not implemented in this feature.
- `ManaComponent` and any `"mana_cost"` (or other non-`"physical_damage"`) event types — mentioned as future direction only.
- Shield regeneration/recharge logic — once depleted, `ShieldComponent` stays at `0` for this feature's scope.
- Healing events/logic (raising `current_health`/`current_shield` back up) — no `"heal"` event type is defined in this feature.
- Entity death/removal, respawn, or game-over handling in reaction to `HealthComponent.died` — only the signal emission is implemented.
- A `ShieldBar` or any other component-specific visual UI beyond `HealthBar` for `"health"`.
- Damage falloff, armor formulas, critical hits, or any other combat-math beyond a flat `amount` passed straight through (or reduced by absorption).

## Open Questions
- Visual specifics of `HealthBar` (a Godot `TextureProgressBar`, a custom `ColorRect`-based bar, exact size/position offset above the character) are left to implementation-time judgment/manual tuning, consistent with this project's existing placeholder-visual style (e.g. `Enemy`'s plain `Sprite2D`/`icon.svg`, `Player`'s plain `ColorRect`).

---

## Revision History

| Date | Change Summary |
|------|----------------|
| 2026-08-05 | Initial spec |
| 2026-08-05 | `HealthBar` relocated from `components/status/` to `scenes/health_bar/`, since it is a presentation concern (no independent behavior/logic) rather than a reusable behavior piece — resolves the prior Open Question on its placement. |
| 2026-08-05 | `status_type` moved from a per-subclass `var`/`.bind()` mechanism to a plain per-subclass `const STATUS_TYPE`; `value_changed` signal (now carrying `status_type` as its first argument) moved onto the `StatusComponent` base class instead of being re-declared per subclass. `Status._ready()` now connects to `child.value_changed` directly via `child is StatusComponent`, with no `has_signal()` duck-typing or `.bind()` needed. |
