class_name DetectionReset
extends Node
## The whole failure path of The Cradle: a guard sees Ryn, control is taken
## away, the screen closes in, one fixed line shows, and Ryn fades in at the
## most recent checkpoint with control back.
##
## Implements `production/epics/the-cradle/story-003-detection-reset-loop.md`
## and 美术规格.md §5. There is no death, no combat and — by design —
## **no cost of any kind**: no health, no lives, no death counter, no dropped
## resources. Failure costs the player time and nothing else, so this script
## deliberately keeps no failure tally. (`叙事脚本.md`'s heavier-breathing idea
## from the 3rd consecutive failure is explicitly optional and out of scope.)
##
## ## Wiring
##
## Nothing is hand-connected. Sighting sources self-register in
## `GuardResetAdapter.SPOTTER_GROUP`; snapshot participants self-register in
## `CheckpointManager.RESETTABLE_GROUP`. Drop this node in a level with its three
## references and the loop works.
##
## ## Structure
##
## Timing lives in `FailSequence`, a plain RefCounted with no node access, so
## the phase machine is testable headlessly. This node is the thin adapter that
## maps phases onto Ryn, the overlay and the checkpoint manager.
##
## Thread safety: main thread only.
##
## Usage:
##     detection_reset.trigger(ryn, guard)       # same path a real sighting takes
##     detection_reset.phase_changed.connect(_on_phase)

## Emitted when a sighting starts a fail sequence. `guard` may be null when the
## sequence was triggered directly (dev tooling, tests).
signal fail_started(player: Node2D, guard: Node2D)
## Emitted on every phase transition, including the final return to IDLE.
signal phase_changed(phase: FailSequence.Phase)
## Emitted once control is back with the player.
signal control_restored

## Tuning. Required.
@export var config: DetectionResetConfig
## The player whose control is suspended. Required.
@export var ryn: Ryn
## Screen-space feedback. Required.
@export var overlay: FailOverlay
## Snapshot coordinator. Required.
@export var checkpoints: CheckpointManager

var _sequence: FailSequence


func _ready() -> void:
	assert(config != null, "DetectionReset.config must be set")
	assert(ryn != null, "DetectionReset.ryn must be set")
	assert(overlay != null, "DetectionReset.overlay must be set")
	assert(checkpoints != null, "DetectionReset.checkpoints must be set")
	_sequence = FailSequence.new(config.close_in_time, config.subtitle_fade_in_time,
			config.subtitle_hold_time, config.fade_in_time, config.respawn_grace_time)
	# Spotters join their group in their own `_ready`; wait for the whole tree.
	_connect_spotters.call_deferred()


func _process(delta: float) -> void:
	if _sequence == null or not _sequence.is_running():
		return
	if _sequence.advance(delta):
		_enter_phase(_sequence.phase)
	_sync_overlay()


## True while the sequence owns the screen and the player.
##
## Usage: `if reset.is_failing(): return`
func is_failing() -> bool:
	return _sequence != null and _sequence.is_running()


## Current phase of the fail sequence.
func phase() -> FailSequence.Phase:
	return FailSequence.Phase.IDLE if _sequence == null else _sequence.phase


## Starts the fail sequence. Ignored while one is running and during the
## post-respawn grace period, so a checkpoint inside a guard's cone cannot pin
## the player in an instant re-trigger loop.
##
## Returns true when the sequence actually started.
##
## Usage: `reset.trigger(ryn, guard)`
func trigger(player: Node2D = null, guard: Node2D = null) -> bool:
	if _sequence == null or not _sequence.start():
		return false
	if overlay != null:
		overlay.set_line(_line_for(guard))
	_enter_phase(_sequence.phase)
	_sync_overlay()
	fail_started.emit(player if player != null else ryn, guard)
	return true


## `Guard.Sense.HEARING` 的值。不直接引用 `Guard`:dev 脚本 `-s` 加载本类时会连带编译 Guard,而 Guard 用到 Audio 自动加载。
const _SENSE_HEARING: int = 1
## 第一次被「听」的守卫抓到的提示整个游戏只出一次(换关也不重出)。
static var _hearing_lesson_shown: bool = false


## 这次失败画面上那一句:第一次被「听」的守卫抓到时是 `first_hearing_caught_line`,其余是 `spotted_line`。
func _line_for(guard: Node2D) -> String:
	var sense: Variant = guard.get(&"sense") if guard != null else null   # 探照灯、门禁没有 sense
	if sense is int and sense == _SENSE_HEARING and not _hearing_lesson_shown \
			and not config.first_hearing_caught_line.is_empty():
		_hearing_lesson_shown = true
		return config.first_hearing_caught_line
	return config.spotted_line


## Subscribes to one sighting source. Call it for anything created after level
## load; group members are picked up automatically.
##
## Usage: `reset.register_spotter(adapter)`
func register_spotter(adapter: GuardResetAdapter) -> void:
	if adapter == null:
		return
	if not adapter.spotted.is_connected(_on_spotted):
		adapter.spotted.connect(_on_spotted)


func _connect_spotters() -> void:
	for node in get_tree().get_nodes_in_group(GuardResetAdapter.SPOTTER_GROUP):
		register_spotter(node as GuardResetAdapter)


func _on_spotted(player: Node2D, guard: Node2D) -> void:
	trigger(player, guard)


func _enter_phase(next: FailSequence.Phase) -> void:
	match next:
		FailSequence.Phase.CLOSING:
			_freeze_player()
		FailSequence.Phase.FADING:
			_respawn()
		FailSequence.Phase.GRACE:
			_thaw_player()
	phase_changed.emit(next)


## Takes control away immediately, on the same frame as the sighting
## (AC: 发现触发后 Ryn 立即失去控制).
func _freeze_player() -> void:
	ryn.input_enabled = false
	# A held key would otherwise keep driving Ryn: `intent` is only overwritten
	# while input is enabled.
	ryn.intent = RynIntent.new()
	ryn.velocity = Vector2.ZERO


func _thaw_player() -> void:
	ryn.intent = RynIntent.new()
	ryn.input_enabled = true
	control_restored.emit()


## Rolls the level back and puts Ryn on the respawn point. Everything resettable
## travels through `CheckpointManager`; the only player-specific step is the
## respawn placement, because "where you come back" is a checkpoint concept and
## not part of any snapshot.
func _respawn() -> void:
	# 躲在柜子/通风管里时被重置(脚本触发等):先出来,别把「躲着」带到存档点去
	if ryn.state == Ryn.State.HIDING:
		ryn.exit_hiding()
	checkpoints.restore()
	ryn.global_position = checkpoints.respawn_position()
	ryn.velocity = Vector2.ZERO
	ryn.intent = RynIntent.new()


func _sync_overlay() -> void:
	overlay.set_progress(_sequence.close_progress())
	overlay.set_subtitle_alpha(_sequence.subtitle_alpha())
