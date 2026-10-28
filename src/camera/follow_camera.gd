class_name FollowCamera
extends Camera2D
## Camera that follows Ryn with a slight look-ahead in the facing direction.
##
## Does its own smoothing (Camera2D's built-in smoothing is left off) so the
## final position can be rounded to whole pixels: no sub-pixel shimmer at the
## 640x360 viewport. Place it AFTER the target in the scene tree so it updates
## after the target has moved. Use Camera2D `limit_*` for level bounds.
##
## Usage:
##     camera.target = ryn
##     camera.config = load("res://assets/data/follow_camera.tres")
##     camera.snap_to_target()   # after teleporting the target

## Node to follow. Its `facing` drives the look-ahead.
@export var target: Ryn
## Follow tuning. Required.
@export var config: FollowCameraConfig

## 远景镜头拉远 / 拉回的速度(1/秒,指数趋近)。
@export var vista_blend: float = 1.8

var _focus: Vector2 = Vector2.ZERO
var _look_ahead: float = 0.0
var _fall_look: float = 0.0
## 远景镜头(`VistaZone`):平时 = 场景里设的 zoom;拉远时换成 `set_vista` 给的。
var _base_zoom: float = 2.0
var _zoom_goal: float = 2.0
var _offset_goal: Vector2 = Vector2.ZERO
var _offset_now: Vector2 = Vector2.ZERO


func _ready() -> void:
	position_smoothing_enabled = false
	_base_zoom = zoom.x
	_zoom_goal = _base_zoom
	snap_to_target()


## 远景:镜头慢慢拉到 `zoom_level`(比如 1 = 看到四倍的面积),中心往 `offset` 偏(世界像素,
## 一般往上,多看天)。只在安全的地方用(塔顶出口、坑口)—— 拉远能看到守卫,用在潜行段就成了作弊。
func set_vista(zoom_level: float, offset: Vector2 = Vector2.ZERO) -> void:
	_zoom_goal = zoom_level
	_offset_goal = offset


## 回到平时的镜头。
func clear_vista() -> void:
	_zoom_goal = _base_zoom
	_offset_goal = Vector2.ZERO


## 正在远景里吗(拉远了,或正在拉)。
func is_vista() -> bool:
	return not is_equal_approx(_zoom_goal, _base_zoom) or not is_equal_approx(zoom.x, _base_zoom)


func _physics_process(delta: float) -> void:
	if target == null or config == null:
		return
	# 前瞻随速度增加 —— 跑起来看得更远,蹲行慢走时不晃。
	var speed_ratio: float = clampf(absf(target.velocity.x) / maxf(config.speed_look_full, 0.0001), 0.0, 1.0)
	var reach: float = config.look_ahead_distance + config.speed_look_ahead * speed_ratio
	var look_target: float = float(target.facing) * reach
	_look_ahead += (look_target - _look_ahead) * _blend(config.look_ahead_smoothing, delta)

	# 下落时镜头下移,给出落点。进场快、退场慢:落地时猛弹回比看不见落点更难受。
	var fall_ratio: float = clampf(target.velocity.y / maxf(config.fall_look_speed, 0.0001), 0.0, 1.0)
	var fall_target: float = config.fall_look_down * fall_ratio
	var rate: float = config.fall_look_in_rate if fall_target > _fall_look else config.fall_look_out_rate
	_fall_look += (fall_target - _fall_look) * _blend(rate, delta)

	# 远景:缩放和偏移一起慢慢过去
	var vb: float = _blend(vista_blend, delta)
	var z: float = lerpf(zoom.x, _zoom_goal, vb)
	if absf(z - _zoom_goal) < 0.002:
		z = _zoom_goal
	zoom = Vector2(z, z)
	_offset_now = _offset_now.lerp(_offset_goal, vb)

	var goal: Vector2 = Vector2(
		target.global_position.x + _look_ahead,
		target.global_position.y + config.vertical_offset + _fall_look) + _offset_now
	_focus.x += (goal.x - _focus.x) * _blend(config.follow_smoothing_x, delta)
	_focus.y += (goal.y - _focus.y) * _blend(config.follow_smoothing_y, delta)
	global_position = _focus.round()


## Jumps straight to the target with the current look-ahead, no easing.
func snap_to_target() -> void:
	if target == null or config == null:
		return
	_look_ahead = float(target.facing) * config.look_ahead_distance
	_focus = Vector2(
		target.global_position.x + _look_ahead,
		target.global_position.y + config.vertical_offset)
	global_position = _focus.round()


## Frame-rate independent exponential blend factor for a rate in 1/s.
func _blend(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)
