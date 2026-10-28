class_name DismantleProgress
extends RefCounted
## Pure hold-to-dismantle progress model: how long the action has been held and
## which of its steps are done. No nodes, no input, no engine state.
##
## Implements the timed half of
## `production/epics/the-cradle/story-005-dismantle-interaction.md`
## (AC: 拆解耗时／步骤为外部配置，不硬编码). Both numbers are injected by
## `configure()` from a `DismantleConfig`, so the model itself holds no tuning.
##
## 叙事脚本.md 塔 2 — 「拧三下，再撬」 — is why this is a HOLD and not a tap, and
## why it has STEPS: the four steps are the three twists and the pry. A step is
## pure feedback (the progress bar is drawn in `steps()` segments); the rule is
## the single continuous hold.
##
## Releasing early keeps NOTHING. `advance(delta, false)` zeroes the elapsed
## time, so a dismantle is one unbroken hold or it did not happen. That is a
## deliberate design choice, not an optimisation: partial credit would let a
## player chip away at a panel from inside a guard's patrol gap, which removes
## the risk the action is supposed to carry.
##
## Deterministic and allocation free — same deltas in, same ratio out.
##
## Usage:
##     var p := DismantleProgress.new()
##     p.configure(config.hold_duration, config.steps)
##     if p.advance(delta, holding):
##         open_the_passage()

## Floor on the configured duration. A zero or negative duration would make the
## action instant and divide by zero in `ratio()`.
const MIN_DURATION: float = 0.001

var _duration: float = MIN_DURATION
var _steps: int = 1
var _elapsed: float = 0.0
var _complete: bool = false


## Injects the tuning and clears all progress. `duration` is seconds of
## continuous hold; `steps` is how many segments that hold is reported in.
##
## Usage: `progress.configure(config.hold_duration, config.steps)`
func configure(duration: float, steps: int) -> void:
	_duration = maxf(duration, MIN_DURATION)
	_steps = maxi(steps, 1)
	reset()


## Advances by `delta` seconds when `holding`, and zeroes all progress when not.
## Returns true ONLY on the call that completes the action, so a caller can fire
## its one-shot effects without tracking an edge itself.
##
## Usage: `if progress.advance(delta, near and held): _complete()`
func advance(delta: float, holding: bool) -> bool:
	if _complete:
		return false
	if not holding:
		_elapsed = 0.0
		return false
	_elapsed = minf(_elapsed + maxf(delta, 0.0), _duration)
	if _elapsed >= _duration:
		_complete = true
		return true
	return false


## Progress as 0..1. 1 means dismantled.
func ratio() -> float:
	if _complete:
		return 1.0
	return clampf(_elapsed / _duration, 0.0, 1.0)


## How many steps are finished, 0..`steps()`. Drives the segmented bar and the
## `dismantle_step` signal.
func step_index() -> int:
	if _complete:
		return _steps
	return clampi(int(floorf(ratio() * float(_steps))), 0, _steps)


## Total number of steps this action is reported in.
func steps() -> int:
	return _steps


## Seconds of continuous hold a full dismantle takes.
func duration() -> float:
	return _duration


## True once the action has finished. Latched until `reset()`.
func is_complete() -> bool:
	return _complete


## True while there is progress worth drawing — i.e. the hold has begun and has
## not been thrown away. Used to detect an abort (started, then not started).
func is_started() -> bool:
	return _complete or _elapsed > 0.0


## Throws away all progress, including completion.
func reset() -> void:
	_elapsed = 0.0
	_complete = false


## Forces the model to an arbitrary 0..1 progress. Checkpoint rollback uses this
## to put a half-finished hold back exactly where the snapshot found it; nothing
## in normal play should call it.
##
## Usage: `progress.set_ratio(float(state.get(&"ratio", 0.0)))`
func set_ratio(value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	_complete = clamped >= 1.0
	_elapsed = _duration * clamped
