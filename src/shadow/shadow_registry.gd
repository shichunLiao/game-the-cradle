class_name ShadowRegistry
extends Node
## Answers "is this point in darkness?" for a level, and hands that answer to
## every guard in it.
##
## Implements the wiring half of
## `production/epics/the-cradle/story-004-darkness-detection.md`. It is the same
## shape as `RynResetAdapter` / `GuardResetAdapter`: a plain scene-level node
## that connects two systems which do not know about each other. `Guard`
## publishes a `darkness_veto: Callable` hook and nothing else; this node fills
## it in with `covers`, so Story 004 lands without touching `guard.gd` or
## `guard_vision.gd` at all.
##
## The decision itself is NOT here — it is `ShadowQuery.covers`, a pure static.
## This node only collects rectangles and caches them.
##
## Caching: zone rects are built on the first query and kept, because the
## guard's detection path runs every physics tick for every overlapping body
## and must not allocate. Zones are static level geometry today. Call
## `refresh()` after adding, removing, moving or resizing one at runtime.
##
## Usage (in a scene): drop one in, set `config`. Leave `guards` empty and it
## finds every Guard under the scene root; fill it in to be explicit.
## Usage (in code):
##     var veto: Callable = registry.covers      # func(Vector2) -> bool
##     guard.darkness_veto = veto

## Guards to wire. Empty means "discover them under the scene root".
@export var guards: Array[Guard] = []
## Tuning. Only `hide_margin` is read here; an unset config means margin 0.
@export var config: ShadowConfig

var _rects: Array[Rect2] = []
var _cached: bool = false


func _ready() -> void:
	for guard in _resolve_guards():
		wire(guard)


## True when `point` is inside any shadow zone in this level — the predicate
## handed to `Guard.darkness_veto`, whose contract is
## `func(target_global: Vector2) -> bool` with true meaning "hidden, do not
## see it".
##
## Safe to call outside a physics callback: no space state, no raycast.
##
## Usage: `if registry.covers(guard.sight_point(ryn)): ...`
func covers(point: Vector2) -> bool:
	if not _cached:
		refresh()
	var margin: float = 0.0 if config == null else config.hide_margin
	return ShadowQuery.covers(point, _rects, margin)


## Rebuilds the cached zone rectangles from the live group. Call after changing
## zones at runtime.
##
## Usage: `registry.refresh()`
func refresh() -> void:
	_rects.clear()
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group(ShadowZone.GROUP):
			var zone := node as ShadowZone
			if zone == null:
				continue
			_rects.append(zone.global_rect())
	_cached = true


## The cached zone rectangles in world space. Copy; mutating it changes nothing.
##
## Usage: `ShadowQuery.covers(p, registry.zone_rects())`
func zone_rects() -> Array[Rect2]:
	if not _cached:
		refresh()
	return _rects.duplicate()


## How many zones this level registered. 0 with zones in the scene means the
## registry was queried before they entered the tree — a wiring bug worth
## printing in a demo log.
##
## Usage: `print(registry.zone_count())`
func zone_count() -> int:
	if not _cached:
		refresh()
	return _rects.size()


## Points one guard's darkness veto at this registry. Idempotent.
##
## Usage: `registry.wire(my_guard)`
func wire(guard: Guard) -> void:
	if guard == null:
		return
	guard.darkness_veto = covers


func _resolve_guards() -> Array[Guard]:
	var found: Array[Guard] = []
	for guard in guards:
		if guard != null:
			found.append(guard)
	if not found.is_empty():
		return found
	# `owner` is the root of the .tscn this node was saved in. Using it rather
	# than `get_tree().current_scene` avoids depending on when the SceneTree
	# assigns the current scene relative to `_ready`.
	var root: Node = owner if owner != null else get_parent()
	if root != null:
		_collect_guards(root, found)
	return found


func _collect_guards(node: Node, into: Array[Guard]) -> void:
	var guard := node as Guard
	if guard != null:
		into.append(guard)
	for child in node.get_children():
		_collect_guards(child, into)
