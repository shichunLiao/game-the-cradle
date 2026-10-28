class_name CheckpointManager
extends Node
## Tracks the most recently activated checkpoint and snapshots/restores every
## resettable thing in the level.
##
## Implements `production/epics/the-cradle/story-003-detection-reset-loop.md`.
##
## ## The resettable interface
##
## Anything that must roll back on a failure implements two methods and joins
## `RESETTABLE_GROUP`:
##
##     func capture_state() -> Dictionary
##     func restore_state(state: Dictionary) -> void
##
## That is the whole contract — duck-typed, no base class, no registration call.
## Participants are collected from the group AT CAPTURE TIME, so anything that
## joins later (Story 005's dismantled floor panels, doors, levers) is picked up
## by the next checkpoint activation with no change here. Ryn and the guards go
## through the same interface via the adapters in this directory; nothing is
## special-cased.
##
## A snapshot is taken on every checkpoint activation and once at level start,
## so there is always something to restore to even before the first checkpoint
## is touched (AC: 如无已激活检查点，用 Ryn 关卡起始位置).
##
## Thread safety: main thread only.
##
## Usage:
##     manager.checkpoint_activated.connect(_on_cp)
##     manager.restore()                      # roll the level back
##     ryn.global_position = manager.respawn_position()

## Group every snapshot participant joins.
const RESETTABLE_GROUP: StringName = &"resettable"
## Group every checkpoint joins (mirrors `Checkpoint.GROUP`).
const CHECKPOINT_GROUP: StringName = &"checkpoint"

## Emitted when a checkpoint becomes the active respawn point.
signal checkpoint_activated(checkpoint: Checkpoint)
## Emitted after a full rollback, before the player is repositioned.
signal state_restored

## The player, used only for the pre-checkpoint fallback respawn position.
## Required.
@export var ryn: Node2D

## The checkpoint respawn currently uses, or null while none has been touched.
var active_checkpoint: Checkpoint = null

var _fallback_position: Vector2 = Vector2.ZERO
var _snapshot: Array[Dictionary] = []


func _ready() -> void:
	# Deferred: sibling checkpoints and adapters join their groups in their own
	# `_ready`, and dev scripts may reposition Ryn there too. Running after the
	# whole tree is ready makes the level-start snapshot the real start state.
	_initialise.call_deferred()


## Snapshots every participant in `RESETTABLE_GROUP`, discarding the previous
## snapshot. Called automatically on checkpoint activation.
##
## Usage: `manager.capture()`
func capture() -> void:
	_snapshot.clear()
	for node in get_tree().get_nodes_in_group(RESETTABLE_GROUP):
		if not node.has_method(&"capture_state"):
			push_warning("CheckpointManager: %s is in the resettable group but has no capture_state()" % node)
			continue
		var state: Variant = node.call(&"capture_state")
		if typeof(state) != TYPE_DICTIONARY:
			push_warning("CheckpointManager: %s.capture_state() did not return a Dictionary" % node)
			continue
		_snapshot.append({&"node": node, &"state": state})


## Rolls every participant back to the last snapshot. Participants that have
## since left the tree are skipped. Emits `state_restored`.
##
## Usage: `manager.restore()`
func restore() -> void:
	for entry in _snapshot:
		var node: Object = entry.get(&"node")
		if node == null or not is_instance_valid(node):
			continue
		node.call(&"restore_state", entry.get(&"state"))
	state_restored.emit()


## Where Ryn's feet go on respawn: the active checkpoint, or her level start
## position while no checkpoint has been touched.
##
## Usage: `ryn.global_position = manager.respawn_position()`
func respawn_position() -> Vector2:
	if active_checkpoint != null and is_instance_valid(active_checkpoint):
		return active_checkpoint.respawn_position()
	return _fallback_position


## True once any checkpoint in the level has been touched.
func has_activated_checkpoint() -> bool:
	return active_checkpoint != null


## Number of participants in the current snapshot. Diagnostics and tests.
func snapshot_size() -> int:
	return _snapshot.size()


## Makes `checkpoint` the respawn point and snapshots the level. Re-touching the
## already-active checkpoint is a no-op, so standing in one does not re-snapshot
## every frame.
##
## Usage: called by the manager from `Checkpoint.checkpoint_touched`.
func activate(checkpoint: Checkpoint) -> void:
	if checkpoint == null or checkpoint == active_checkpoint:
		return
	active_checkpoint = checkpoint
	capture()
	checkpoint_activated.emit(checkpoint)


func _initialise() -> void:
	if ryn != null:
		_fallback_position = ryn.global_position
	for node in get_tree().get_nodes_in_group(CHECKPOINT_GROUP):
		var checkpoint := node as Checkpoint
		if checkpoint == null:
			continue
		if not checkpoint.checkpoint_touched.is_connected(activate):
			checkpoint.checkpoint_touched.connect(activate)
	# Level start counts as checkpoint zero.
	capture()
