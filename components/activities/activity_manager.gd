class_name ActivityManager
extends Node

@export var world: World
@export var spawn_parent: Node
@export var activities: Array[Activity]

## Set by RoundInitializer before start() is called -- not @export since
## it's runtime-injected (the shared seeded RandomNumberGenerator for the
## round), not editor-configured.
var rng: RandomNumberGenerator
var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)

func start() -> void:
	_trigger_next_activity()

func _trigger_next_activity() -> void:
	if activities.is_empty():
		push_error("ActivityManager: activities array is empty, cannot schedule an activity.")
		return

	var activity: Activity = activities[rng.randi() % activities.size()]
	activity.execute(rng, world.world_size, spawn_parent)
	_timer.wait_time = activity.get_next_interval(rng)
	_timer.start()

func _on_timeout() -> void:
	_trigger_next_activity()
