class_name ShadowQuery
extends RefCounted
## Pure predicates for the Story 004 darkness rule (暗处优先).
##
## No scene, no node, no engine state: every input is a parameter, exactly like
## `GuardVision`, so the whole truth table is unit-testable without instancing
## anything. Implements
## `production/epics/the-cradle/story-004-darkness-detection.md`.
##
## The rule is deliberately BOOLEAN, never a gradient. A soft falloff would
## destroy the teaching the game is built on (亮路危险、暗道才是正路): the
## player must be able to tell at a glance whether they are safe. Darkness wins
## outright — dead centre of the cone with a clear line of sight still counts
## as hidden.
##
## Usage:
##     var rects: Array[Rect2] = [Rect2(100.0, 0.0, 64.0, 32.0)]
##     ShadowQuery.covers(Vector2(120.0, 16.0), rects)   # true
##     ShadowQuery.is_detected(true, true)               # false — shadow wins

## True when `point` lies inside any of `zones`, after each zone is shrunk by
## `margin` px on every side.
##
## Zone rects are in the same space as `point` (global, in the live game).
## Edges count as inside, so a point exactly on the drawn boundary is hidden —
## the generous side of the only ambiguous case. A zone shrunk to nothing by
## `margin` hides nobody rather than inverting.
##
## Usage:
##     ShadowQuery.covers(guard.sight_point(ryn), registry.zone_rects(), 0.0)
static func covers(point: Vector2, zones: Array[Rect2], margin: float = 0.0) -> bool:
	for zone in zones:
		var box: Rect2 = zone.abs()
		if margin != 0.0:
			box = box.grow(-margin)
		if box.size.x <= 0.0 or box.size.y <= 0.0:
			continue
		# Written out rather than via Rect2.has_point so the inclusive-edge
		# behaviour is ours and cannot change under us.
		if point.x < box.position.x or point.x > box.position.x + box.size.x:
			continue
		if point.y < box.position.y or point.y > box.position.y + box.size.y:
			continue
		return true
	return false


## The complete detection truth table. Darkness vetoes a sighting.
##
##     in_cone | in_shadow | detected
##     --------|-----------|---------
##     false   | false     | false
##     false   | true      | false
##     true    | false     | TRUE     <- the only way to be seen
##     true    | true      | false    <- 暗处优先
##
## `in_cone` means Story 002's full geometric test already passed (inside the
## cone AND not occluded); this function adds only the darkness layer.
##
## Usage: `if ShadowQuery.is_detected(cone_ok, shadows.covers(p)): ...`
static func is_detected(in_cone: bool, in_shadow: bool) -> bool:
	return in_cone and not in_shadow
