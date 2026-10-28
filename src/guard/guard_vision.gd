class_name GuardVision
extends RefCounted
## Pure line-of-sight predicates for a guard's vision cone.
##
## No scene, no node, no engine state: every input is a parameter, so these
## functions can be unit-tested without instancing anything. Implements the
## detection rule of `production/epics/the-cradle/story-002-guard-vision-cone.md`
## ("Ryn 进入视野锥且视线无遮挡时判定为发现" plus the wall-occlusion criterion).
##
## Occlusion and the Story-004 darkness rule are INJECTED as `Callable`s rather
## than coded in, so the geometry test stays pure and "Ryn is in shadow" can
## veto a sighting later without touching this class or `Guard`.
##
## Usage:
##     var seen: bool = GuardVision.can_see(
##             eye, target, Vector2.LEFT, deg_to_rad(28.0), 220.0,
##             func(a: Vector2, b: Vector2) -> bool: return _wall_between(a, b),
##             Callable())  # no darkness rule yet

## Below this squared distance the target is treated as sitting on the eye.
const COINCIDENT_EPSILON_SQ: float = 0.0001


## True when `target` lies inside the cone whose apex is `eye`, axis is
## `facing`, opening is `half_angle_rad` to each side of the axis, and reach is
## `range_px`. Geometry only — no occlusion, no darkness.
##
## `facing` need not be normalised. A zero `facing`, a non-positive range or a
## non-positive angle all mean "sees nothing".
##
## Usage:
##     GuardVision.is_in_cone(Vector2(0, 0), Vector2(50, 10), Vector2.RIGHT,
##             deg_to_rad(28.0), 220.0)  # true
static func is_in_cone(eye: Vector2, target: Vector2, facing: Vector2,
		half_angle_rad: float, range_px: float) -> bool:
	if range_px <= 0.0 or half_angle_rad <= 0.0:
		return false
	var to_target: Vector2 = target - eye
	var dist_sq: float = to_target.length_squared()
	if dist_sq > range_px * range_px:
		return false
	if dist_sq <= COINCIDENT_EPSILON_SQ:
		return true
	if half_angle_rad >= PI:
		return true
	var axis: Vector2 = facing.normalized()
	if axis == Vector2.ZERO:
		return false
	# dot / dist >= cos(half) rearranged to avoid a division; correct for
	# half-angles past 90 degrees because cos() goes negative there too.
	return to_target.dot(axis) >= sqrt(dist_sq) * cos(half_angle_rad)


## True when `target` is actually seen: inside the cone, not occluded, and not
## vetoed.
##
## `is_occluded` is `func(from: Vector2, to: Vector2) -> bool` — in the game it
## is a raycast against world geometry. `is_hidden` is
## `func(target: Vector2) -> bool` — the Story-004 darkness veto. An invalid
## `Callable` (the default) means "that rule does not apply", so tests can pass
## pure stubs and the live game can pass real queries.
##
## Usage:
##     GuardVision.can_see(eye, torso, Vector2.LEFT, half, reach,
##             func(_a, _b): return false, Callable())
static func can_see(eye: Vector2, target: Vector2, facing: Vector2,
		half_angle_rad: float, range_px: float,
		is_occluded: Callable = Callable(), is_hidden: Callable = Callable()) -> bool:
	if not is_in_cone(eye, target, facing, half_angle_rad, range_px):
		return false
	if is_occluded.is_valid() and bool(is_occluded.call(eye, target)):
		return false
	if is_hidden.is_valid() and bool(is_hidden.call(target)):
		return false
	return true
