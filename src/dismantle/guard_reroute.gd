class_name GuardReroute
extends Node
## Rewrites one guard's patrol bounds when a `Dismantlable` opens, and puts them
## back when it is restored. Add it as a child of the Dismantlable.
##
## Implements the 改道 half of
## `production/epics/the-cradle/story-005-dismantle-interaction.md`
## (AC: 守卫导航随之改变：坠落**或**改道). The 坠落 half needs no code at all —
## removing a floor panel removes the floor, and `Guard` already has gravity —
## so this node is what makes the OTHER option exist and be configurable.
##
## Same shape as `GuardResetAdapter` and `ShadowRegistry`: a plain scene node
## that joins two systems which do not know about each other, so `guard.gd`
## stays untouched.
##
## `Guard` exposes `patrol_offset` but computes its real bounds
## (`_min_x` / `_max_x`) once in `_ready`, and the file is read-only for this
## story, so the two privates are written through `set()` — exactly the
## precedent `GuardResetAdapter.restore_state` set for the phase timers. If
## `guard.gd` ever gains a `set_patrol_bounds()`, this is the one place to
## switch over.
##
## Usage (in a scene):
##     [node name="Reroute" type="Node" parent="FenceGrate" node_paths=...]
##     script = res://src/dismantle/guard_reroute.gd
##     guard = NodePath("../../Guard")
##     open_patrol_offset = 340.0

## The guard whose route changes. Required; an unset guard makes this inert.
@export var guard: Guard
## Signed patrol offset (px from the spawn point, as `Guard.patrol_offset`) to
## use once the panel is gone. The value a designer tunes to decide WHERE the
## guard goes when the way opens.
@export var open_patrol_offset: float = 0.0

var _closed_offset: float = 0.0
var _origin_x: float = 0.0
var _ready_done: bool = false
var _applied: bool = false


func _ready() -> void:
	# Deferred: `Guard._ready` computes `_min_x` / `_max_x` from its spawn
	# position, and this node may be readied before it. Reading the bounds back
	# out after the whole tree is ready is the only way to learn the guard's
	# route origin without assuming node order.
	_capture.call_deferred()


## True while the opened route is in force.
func is_applied() -> bool:
	return _applied


## Switches the guard to the opened route.
##
## Usage: `reroute.apply()`
func apply() -> void:
	_applied = true
	_write_bounds(open_patrol_offset)


## Puts the guard back on its original route.
##
## Usage: `reroute.revert()`
func revert() -> void:
	_applied = false
	_write_bounds(_closed_offset)


## Applies or reverts to match `opened`. Checkpoint rollback uses this so the
## route and the geometry can never disagree.
##
## Usage: `reroute.set_opened(is_dismantled)`
func set_opened(opened: bool) -> void:
	if opened:
		apply()
	else:
		revert()


## The patrol offset currently written on the guard. Diagnostics and demos.
func current_offset() -> float:
	if guard == null or not is_instance_valid(guard):
		return 0.0
	return guard.patrol_offset


## The guard's patrol span in world x, as the guard itself sees it. Demos print
## this to prove the route really moved.
func bounds() -> Vector2:
	if guard == null or not is_instance_valid(guard):
		return Vector2.ZERO
	return Vector2(float(guard.get(&"_min_x")), float(guard.get(&"_max_x")))


func _capture() -> void:
	if guard == null or not is_instance_valid(guard):
		return
	_closed_offset = guard.patrol_offset
	var min_x: float = float(guard.get(&"_min_x"))
	var max_x: float = float(guard.get(&"_max_x"))
	# The spawn end of the route is whichever bound the offset points away from.
	_origin_x = min_x if _closed_offset >= 0.0 else max_x
	_ready_done = true


func _write_bounds(offset: float) -> void:
	if guard == null or not is_instance_valid(guard):
		return
	if not _ready_done:
		_capture()
	guard.patrol_offset = offset
	guard.set(&"_min_x", minf(_origin_x, _origin_x + offset))
	guard.set(&"_max_x", maxf(_origin_x, _origin_x + offset))
