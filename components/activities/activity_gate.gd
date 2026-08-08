class_name ActivityGate
extends Resource

## Called once, immediately after the owning Activity's execute() runs, so
## the gate can capture whatever it needs (e.g. a randomly-picked wait
## duration).
func start(_rng: RandomNumberGenerator, _spawn_parent: Node) -> void:
	pass

## Polled by ActivityManager once per physics frame while waiting. elapsed_time
## is seconds since start() was called, threaded through explicitly rather
## than read from a global clock. Returns true once the next activity should
## be triggered.
func is_ready(_elapsed_time: float, _spawn_parent: Node) -> bool:
	return true
