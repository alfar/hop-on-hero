class_name ActivityManager
extends Node

@export var level_seed: int = 0
@export var world: World
@export var spawn_parent: Node
@export var activities: Array[Activity]

var _rng := RandomNumberGenerator.new()
var _timer: Timer

func _ready() -> void:
	if level_seed == 0:
		level_seed = randi()
		print("ActivityManager seed: ", level_seed)
	_rng.seed = level_seed

	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)

	GameEvents.world_loaded.subscribe(func(_v): start())

func start() -> void:
	_trigger_next_activity()

func _trigger_next_activity() -> void:
	if activities.is_empty():
		push_error("ActivityManager: activities array is empty, cannot schedule an activity.")
		return

	var activity: Activity = activities[_rng.randi() % activities.size()]
	activity.execute(_rng, world.world_size, spawn_parent)
	_timer.wait_time = activity.get_next_interval(_rng)
	_timer.start()

func _on_timeout() -> void:
	_trigger_next_activity()
