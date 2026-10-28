class_name CameraShake
extends Node
## 被发现时的短震动(美术规格.md §1「被发现时短震动 + 压暗」)。
##
## Story 003 把这条标为"在美术规格里但不在任何 AC 中,未实现"。补上。
##
## 适配器式:挂在 FollowCamera 下,只改 `offset`,`follow_camera.gd` 一行不改。
## 震动是 **衰减** 的,不是等幅抖动 —— 等幅会读作"卡顿"而不是"冲击"。

@export var duration: float = 0.35
@export var strength: float = 5.0
## 每秒抖动次数。太高会糊成噪声,太低会读作掉帧。
@export var frequency: float = 26.0

var _camera: Camera2D
var _elapsed: float = 0.0
var _active: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_camera = get_parent() as Camera2D
	set_process(false)


## 触发一次震动。重复调用会重新开始,不叠加 —— 叠加会越抖越猛。
##
## Usage: `shake.shake()`
func shake(scale: float = 1.0) -> void:
	if _camera == null:
		return
	_elapsed = 0.0
	_active = true
	_rng.randomize()
	strength = absf(strength) * maxf(scale, 0.0) if scale != 1.0 else strength
	set_process(true)


func _process(delta: float) -> void:
	if not _active or _camera == null:
		return
	_elapsed += delta
	if _elapsed >= duration:
		_active = false
		_camera.offset = Vector2.ZERO
		set_process(false)
		return
	var fade: float = 1.0 - (_elapsed / maxf(duration, 0.0001))
	var amp: float = strength * fade * fade
	var phase: float = _elapsed * frequency
	_camera.offset = Vector2(
		sin(phase * TAU) * amp * _rng.randf_range(0.6, 1.0),
		cos(phase * TAU * 0.7) * amp * 0.5)
