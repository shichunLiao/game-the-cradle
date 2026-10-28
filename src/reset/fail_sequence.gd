class_name FailSequence
extends RefCounted
## The pure timing core of the detection fail sequence — no nodes, no engine
## singletons, no presentation. Injected with durations and advanced by delta,
## so it is testable headlessly (same split as `src/guard/guard_vision.gd`).
##
## Phase order, each entered exactly once per run:
##
##     IDLE -> CLOSING -> SUBTITLE -> FADING -> GRACE -> IDLE
##
## The owner reacts to the phase it is told about:
##  - CLOSING  : take control away
##  - SUBTITLE : (nothing; the line is already fading in)
##  - FADING   : restore the world and move the player to the checkpoint
##  - GRACE    : give control back, keep ignoring sightings
##  - IDLE     : accept sightings again
##
## Usage:
##     var seq := FailSequence.new(0.45, 0.2, 1.1, 0.6, 0.8)
##     seq.start()
##     while seq.is_running():
##         if seq.advance(1.0 / 60.0):
##             print(FailSequence.Phase.keys()[seq.phase])

enum Phase {
	## Nothing happening. The only phase that accepts a trigger.
	IDLE,
	## Screen edges closing in and darkening.
	CLOSING,
	## Closed screen holding the subtitle.
	SUBTITLE,
	## Fading back in at the respawn point.
	FADING,
	## Control is back but sightings are still ignored.
	GRACE,
}

## Current phase. Read-only from outside; drive it with `start()`/`advance()`.
var phase: Phase = Phase.IDLE

var _close_in: float
var _subtitle_fade_in: float
var _subtitle_hold: float
var _fade_in: float
var _grace: float
var _elapsed: float = 0.0


func _init(close_in_time: float, subtitle_fade_in_time: float,
		subtitle_hold_time: float, fade_in_time: float,
		respawn_grace_time: float) -> void:
	_close_in = maxf(close_in_time, 0.0)
	_subtitle_hold = maxf(subtitle_hold_time, 0.0)
	_subtitle_fade_in = clampf(subtitle_fade_in_time, 0.0, _subtitle_hold)
	_fade_in = maxf(fade_in_time, 0.0)
	_grace = maxf(respawn_grace_time, 0.0)


## True while a sighting should be acted on (i.e. nothing is running and the
## grace period is over).
##
## Usage: `if seq.accepts_trigger(): seq.start()`
func accepts_trigger() -> bool:
	return phase == Phase.IDLE


## True while the sequence owns the screen and the player.
func is_running() -> bool:
	return phase != Phase.IDLE


## Begins the sequence. Returns false (and changes nothing) when one is already
## running or the grace period has not expired.
##
## Usage: `if not seq.start(): return`
func start() -> bool:
	if not accepts_trigger():
		return false
	phase = Phase.CLOSING
	_elapsed = 0.0
	return true


## Advances the clock. Returns true when this call entered a NEW phase, which is
## the owner's cue to read `phase` and act on it.
##
## Usage: `if seq.advance(delta): _on_phase(seq.phase)`
func advance(delta: float) -> bool:
	if phase == Phase.IDLE:
		return false
	_elapsed += maxf(delta, 0.0)
	var duration: float = _phase_duration()
	if _elapsed < duration:
		return false
	_elapsed -= duration
	match phase:
		Phase.CLOSING:
			phase = Phase.SUBTITLE
		Phase.SUBTITLE:
			phase = Phase.FADING
		Phase.FADING:
			phase = Phase.GRACE
		_:
			phase = Phase.IDLE
			_elapsed = 0.0
	return true


## 0 (screen clear) .. 1 (edges fully closed, screen at peak darkness).
func close_progress() -> float:
	match phase:
		Phase.CLOSING:
			return _ratio(_close_in)
		Phase.SUBTITLE:
			return 1.0
		Phase.FADING:
			return 1.0 - _ratio(_fade_in)
		_:
			return 0.0


## 0 (hidden) .. 1 (fully opaque) for the subtitle.
func subtitle_alpha() -> float:
	match phase:
		Phase.SUBTITLE:
			if is_zero_approx(_subtitle_fade_in):
				return 1.0
			return clampf(_elapsed / _subtitle_fade_in, 0.0, 1.0)
		Phase.FADING:
			return 1.0 - _ratio(_fade_in)
		_:
			return 0.0


## Seconds spent in the current phase. Mainly for logging and tests.
func phase_elapsed() -> float:
	return _elapsed


func _phase_duration() -> float:
	match phase:
		Phase.CLOSING:
			return _close_in
		Phase.SUBTITLE:
			return _subtitle_hold
		Phase.FADING:
			return _fade_in
		Phase.GRACE:
			return _grace
		_:
			return 0.0


func _ratio(duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(_elapsed / duration, 0.0, 1.0)
