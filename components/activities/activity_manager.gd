class_name ActivityManager
extends Node

@export var world: World
@export var spawn_parent: Node
@export var activities: Array[Activity]
@export var game_mode: GameMode = EndlessGameMode.new()

## Set by RoundInitializer before start() is called -- not @export since
## it's runtime-injected (the shared seeded RandomNumberGenerator for the
## round), not editor-configured.
var rng: RandomNumberGenerator

## True once this round's outcome has been declared (by this ActivityManager
## or by Player, whichever resolves it first) -- read by Player to avoid a
## double round_ended emission on a simultaneous win/loss. Reset naturally
## every round since ActivityManager itself is recreated on scene reload.
var round_over: bool = false
var activities_triggered: int = 0

var _current_gate: ActivityGate
var _gate_elapsed_time: float = 0.0

## Guards both the current gate's is_ready poll and the win-check poll for
## one physics frame after an activity is triggered, since activities like
## BossActivity spawn via a deferred add_child -- polling in the same frame
## could see an empty "enemy" group before that spawn has actually resolved.
var _skip_poll_this_frame: bool = false

func start() -> void:
	_trigger_next_activity()

func _physics_process(delta: float) -> void:
	if _skip_poll_this_frame:
		_skip_poll_this_frame = false
		return

	if _current_gate != null:
		_gate_elapsed_time += delta
		if _current_gate.is_ready(_gate_elapsed_time, spawn_parent):
			_trigger_next_activity()
			return

	if not round_over and game_mode.is_round_won(activities_triggered, spawn_parent):
		_declare_win()

func _trigger_next_activity() -> void:
	if not game_mode.should_schedule_next_activity(activities_triggered):
		_current_gate = null
		return

	var activity := _pick_weighted_activity()
	if activity == null:
		push_error("ActivityManager: activities array is empty or has no positive weight, cannot schedule an activity.")
		_current_gate = null
		return

	activity.execute(rng, world.world_size, spawn_parent)
	activities_triggered += 1

	_current_gate = activity.gate
	_gate_elapsed_time = 0.0
	_current_gate.start(rng, spawn_parent)
	_skip_poll_this_frame = true

func _pick_weighted_activity() -> Activity:
	var total_weight := 0.0
	for activity in activities:
		total_weight += max(activity.weight, 0.0)
	if total_weight <= 0.0:
		return null

	var roll := rng.randf_range(0.0, total_weight)
	var cumulative := 0.0
	for activity in activities:
		cumulative += max(activity.weight, 0.0)
		if roll < cumulative:
			return activity
	return activities[-1]

func _declare_win() -> void:
	round_over = true
	var player := spawn_parent.get_tree().get_first_node_in_group("player")
	var outcome := GameEvents.RoundOutcome.PYRRHIC_VICTORY if (player != null and player.is_dead) else GameEvents.RoundOutcome.WON
	var game := spawn_parent.get_tree().get_first_node_in_group("game")
	var time_played_seconds: float = game.get_time_played_seconds() if game != null else 0.0
	GameEvents.emit_round_ended(time_played_seconds, outcome)
