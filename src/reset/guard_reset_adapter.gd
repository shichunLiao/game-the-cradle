class_name GuardResetAdapter
extends Node
## Plugs one Guard into the fail loop without touching `src/guard/guard.gd`.
## Add it as a child of the Guard node.
##
## Two jobs, both "connect this guard to the reset system":
##  1. Relays the guard's `player_spotted` as `spotted` and joins `SPOTTER_GROUP`
##     so `DetectionReset` finds it with no hand wiring.
##  2. Implements the resettable interface (see `CheckpointManager`) so the
##     guard's position and alert state roll back with everything else
##     (AC: 守卫位置与可拆物件状态一并回到检查点时的状态).
##
## Usage (in a scene):
##     [node name="ResetAdapter" type="Node" parent="Guard"]
##     script = res://src/reset/guard_reset_adapter.gd

## Group every sighting source joins.
const SPOTTER_GROUP: StringName = &"spotter"

## Relayed sighting. `DetectionReset` is the only listener by design.
signal spotted(player: Node2D, guard: Node2D)

## The guard. Defaults to the parent node when left unset.
@export var guard: Guard


var _pursuit: Node


func _ready() -> void:
	if guard == null:
		guard = get_parent() as Guard
	assert(guard != null, "GuardResetAdapter must be a child of a Guard (or have `guard` set)")
	add_to_group(CheckpointManager.RESETTABLE_GROUP)
	add_to_group(SPOTTER_GROUP)
	guard.player_spotted.connect(_on_player_spotted)
	# 若这个守卫挂了 GuardPursuit 且开启追击,则由"追上"而不是"看见"触发重置。
	_pursuit = guard.get_node_or_null(^"Pursuit")
	if _pursuit != null and _pursuit.get(&"chase_enabled"):
		_pursuit.connect(&"player_caught", _on_player_caught)


## Snapshots the guard's placement and alert state.
##
## Usage: `var s: Dictionary = adapter.capture_state()`
func capture_state() -> Dictionary:
	return {
		&"position": guard.global_position,
		&"velocity": guard.velocity,
		&"facing": guard.facing,
		&"state": int(guard.state),
	}


## Puts the guard back on its route exactly as the snapshot found it.
##
## `guard.gd` is read-only for this story, so the two private phase timers are
## zeroed through `set()` rather than a method: restoring `state` without them
## would leave a guard holding a stale SUSPICIOUS clock that expires instantly.
##
## Usage: `adapter.restore_state(s)`
func restore_state(state: Dictionary) -> void:
	if guard == null or not is_instance_valid(guard):
		return
	guard.global_position = state.get(&"position", guard.global_position)
	guard.velocity = state.get(&"velocity", Vector2.ZERO)
	guard.facing = int(state.get(&"facing", guard.facing))
	# `set()` not assignment: the dictionary holds a plain int and `Guard.state`
	# is a typed enum, which refuses an untyped int at compile time.
	guard.set(&"state", int(state.get(&"state", Guard.State.PATROL)))
	guard.set(&"_state_time", 0.0)
	guard.set(&"_wait_left", 0.0)


func _on_player_caught(player: Node2D, by_guard: Guard) -> void:
	spotted.emit(player, by_guard)


func _on_player_spotted(player: Node2D, by_guard: Guard) -> void:
	# 追击接管时,看见只是开始追,不立刻重置。
	if _pursuit != null and _pursuit.get(&"chase_enabled"):
		return
	spotted.emit(player, by_guard)
