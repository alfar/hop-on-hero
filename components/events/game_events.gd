extends Node

var world_size_changed := BehaviorSubject.new()
var world_loaded := BehaviorSubject.new()

## Plain signal, not a BehaviorSubject: fired once per round by Player on
## death. A BehaviorSubject would replay its cached "round ended" value to
## the next round's fresh subscriber the moment it subscribes, instantly
## re-freezing/re-showing the summary screen -- nothing re-emits a fresh
## "not ended" value on the next load the way World re-emits
## world_size_changed/world_loaded every load.
signal round_ended(time_played_seconds: float)

## One-shot carry-through value for the seed to use on the next scene load
## (set by Game before calling get_tree().reload_current_scene()). Not a
## BehaviorSubject/signal -- just an autoload-scoped var, since it only
## needs to survive the reload, not broadcast to anything.
var next_level_seed: int = 0

## Plain signals (same rationale as round_ended -- no replay-to-late-
## subscriber behavior wanted). Game is the sole subscriber that actually
## toggles get_tree().paused; nothing else needs to react to these directly.
## Kept separate from round_ended (rather than Game just calling
## get_tree().paused = true straight from its round_ended handler) so tests
## can assert the intent to pause/resume fired without ever touching the
## real SceneTree.paused state -- which, if actually set true during a GUT
## test run, leaks into every subsequent test in the same run since nothing
## un-pauses it except that test's own teardown running to completion first.
signal paused
signal resumed
