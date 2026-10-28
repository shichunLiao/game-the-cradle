class_name RynPlaceholderVisual
extends Node2D
## Flat-colour stand-in for Ryn's art, drawn with rectangles and lines only
## (no textures, no sprite pipeline). Replaced later by real animation.
##
## Origin is at Ryn's feet. Height comes from the same value that sizes the
## collider, so silhouette and collision shrink together by construction.
## Poses are drawn for silhouette readability: standing, crouched (low lump,
## head forward), climbing (limbs alternate).
##
## Usage:
##     visual.update_pose(14.0, 10.0, 1, false, 0.0)  # crouched, facing right

const BODY_COLOR: Color = Color("C8D4E0")
## 完全隐蔽时身体趋近的颜色。仍明显可辨 —— 玩家必须看得见自己在哪,
## 所以这不是背景色,只是暗到"融进去"。
const CONCEALED_COLOR: Color = Color("46607F")
## 隐蔽时眼睛的收敛色(高光消失)。
const CONCEALED_EYE_COLOR: Color = Color("16243C")
const EYE_COLOR: Color = Color("0B1220")
const LIMB_PX_PER_STEP: float = 8.0
## 隐蔽度每秒变化上限 —— 进出暗处是渐变,不是硬切。
const CONCEAL_RATE: float = 3.2
## 走完一个迈腿循环要多少 px。
const WALK_CYCLE_PX: float = 26.0
## 落地缓冲时长,秒。只是视觉屈膝,**不改变任何碰撞或操作** ——
## Story 001 的跳跃手感已由作者签字认可,这里不碰它。
const LAND_SQUASH_TIME: float = 0.13
## 触发缓冲所需的落地速度,px/s。轻轻落地不蹲。
const LAND_SQUASH_SPEED: float = 150.0
## 转身过渡时长,秒。
const TURN_TIME: float = 0.1
## 判定为"刹车"的减速度阈值,px/s^2。
const BRAKE_THRESHOLD: float = 900.0

var _height: float = 28.0
var _width: float = 10.0
var _facing: int = 1
var _climbing: bool = false
var _climb_step: int = 0
var _concealment: float = 0.0
var _shown_concealment: float = 0.0
var _walk_phase: float = 0.0
var _airborne: bool = false
var _vel_y: float = 0.0
var _vel_x: float = 0.0
var _prev_vel_x: float = 0.0
var _land_squash: float = 0.0
var _turn: float = 0.0
var _braking: bool = false


## Sets the pose to draw. Redraws only when something changed.
##
## `height` and `width` are the collider size in px; `facing` is -1 or 1;
## `climb_distance` is the signed distance climbed, driving limb alternation.
func update_pose(height: float, width: float, facing: int, climbing: bool, climb_distance: float) -> void:
	if facing != _facing and _facing != 0:
		_turn = TURN_TIME
	var step: int = int(floorf(climb_distance / LIMB_PX_PER_STEP)) & 1
	if height == _height and width == _width and facing == _facing \
			and climbing == _climbing and step == _climb_step:
		return
	_height = height
	_width = width
	_facing = facing
	_climbing = climbing
	_climb_step = step
	queue_redraw()


func _process(delta: float) -> void:
	# Draw on whole pixels so flat shapes do not shimmer at fractional positions.
	var parent := get_parent() as Node2D
	if parent != null:
		position = parent.global_position.round() - parent.global_position
	if _land_squash > 0.0:
		_land_squash = maxf(_land_squash - delta, 0.0)
		queue_redraw()
	if _turn > 0.0:
		_turn = maxf(_turn - delta, 0.0)
		queue_redraw()
	# Ease toward the target so stepping in and out of shadow is not a hard flick.
	if not is_equal_approx(_shown_concealment, _concealment):
		_shown_concealment = move_toward(_shown_concealment, _concealment, CONCEAL_RATE * delta)
		queue_redraw()


## 0 = 完全暴露, 1 = 完全隐蔽。由 `RynStealthVisual` 每帧驱动。
##
## **这个值必须对应真实的机制状态,不能只看是否蹲下。** 蹲在亮处照样会被发现,
## 若此时给出"藏好了"的视觉,就是在骗玩家 —— 潜行游戏里这是致命的。
##
## Usage: `visual.set_concealment(1.0)`
func set_concealment(value: float) -> void:
	_concealment = clampf(value, 0.0, 1.0)


## 行走/滞空状态,驱动迈腿与起跳姿态。
##
## `walked_px` 是本帧走过的水平距离 —— 相位按 **距离** 推进而不是时间,所以慢走
## 就慢迈腿、停下腿就停,不会出现原地踏步。
##
## Usage: `visual.set_motion(absf(velocity.x) * delta, not is_on_floor(), velocity.y, velocity.x, delta)`
func set_motion(walked_px: float, airborne: bool, vel_y: float, vel_x: float = 0.0, delta: float = 0.0) -> void:
	_walk_phase += walked_px / WALK_CYCLE_PX
	# 落地缓冲:从滞空变为着地,且下落够快
	if _airborne and not airborne and _vel_y > LAND_SQUASH_SPEED:
		_land_squash = LAND_SQUASH_TIME
	# 刹车:仍在动,但正在快速减速
	if delta > 0.0001:
		var accel: float = (absf(vel_x) - absf(_prev_vel_x)) / delta
		_braking = not airborne and accel < -BRAKE_THRESHOLD and absf(vel_x) > 12.0
		_prev_vel_x = vel_x
	_airborne = airborne
	_vel_y = vel_y
	_vel_x = vel_x
	queue_redraw()


## 与 `RynSpriteVisual.set_intent` 同签名。占位图不画顶墙/边缘/抬头,忽略。
func set_intent(_move_x: float, _look_up: bool, _sprint: bool, _pushing: bool, _at_edge: bool) -> void:
	pass


## 与 `RynSpriteVisual.set_action` 同签名。占位图没有动作帧,忽略。
func set_action(_action: StringName) -> void:
	pass


## 与 `RynSpriteVisual.current_action` 同签名。
func current_action() -> StringName:
	return &""


## 当前绘制用的身体颜色。
func body_color() -> Color:
	return BODY_COLOR.lerp(CONCEALED_COLOR, _shown_concealment)


## 当前绘制用的眼睛颜色。
func eye_color() -> Color:
	return EYE_COLOR.lerp(CONCEALED_EYE_COLOR, _shown_concealment)


func _draw() -> void:
	var half_w: float = _width * 0.5
	if _climbing:
		_draw_climbing(half_w)
	elif _height < 20.0:
		_draw_crouched(half_w)
	else:
		_draw_standing(half_w)


func _draw_standing(half_w: float) -> void:
	var BODY_COLOR := body_color()
	var EYE_COLOR := eye_color()
	# 落地缓冲:整体压扁、变宽。纯绘制,碰撞体不变。
	var squash: float = _land_squash / LAND_SQUASH_TIME
	var sq_y: float = 1.0 - squash * 0.22
	var sq_x: float = 1.0 + squash * 0.18
	# 转身:身体短暂变窄,像侧过去
	var turning: float = _turn / TURN_TIME
	sq_x *= 1.0 - turning * 0.35
	half_w *= sq_x
	var head: float = 8.0 * sq_y
	var leg: float = 8.0 * sq_y
	# 腿:走路时前后错开;滞空时收起(起跳收腿、下落伸腿)
	var swing: float = sin(_walk_phase * TAU) * 2.5
	# 刹车:双腿前撑,身体后仰
	if _braking:
		swing = -2.5 * signf(_vel_x)
	var lift_a: float = 0.0
	var lift_b: float = 0.0
	if _airborne:
		# 上升收腿,下落伸腿 —— 一个最小的滞空姿态
		var tuck: float = clampf(-_vel_y / 220.0, -1.0, 1.0)
		lift_a = maxf(tuck, 0.0) * 3.0
		lift_b = lift_a * 0.6
		swing = 0.0
	draw_rect(Rect2(-half_w + swing, -leg + lift_a, 4.0, leg - lift_a), BODY_COLOR)
	draw_rect(Rect2(half_w - 4.0 - swing, -leg + lift_b, 4.0, leg - lift_b), BODY_COLOR)
	# 躯干:随迈腿上下 1px 起伏,人就"走"起来了
	var bob: float = 0.0 if _airborne else roundf(absf(sin(_walk_phase * TAU)) * 1.0)
	var h: float = _height * sq_y
	var w: float = _width * sq_x
	# 刹车时身体后仰 1px
	var lean: float = -signf(_vel_x) * 1.0 if _braking else 0.0
	draw_rect(Rect2(-half_w + lean, -(h - head) + bob, w, h - head - leg), BODY_COLOR)
	draw_rect(Rect2(-4.0 * sq_x + lean, -h + bob, 8.0 * sq_x, head), BODY_COLOR)
	if turning < 0.5:
		draw_rect(Rect2((1.0 if _facing > 0 else -3.0) + lean, -h + 3.0 + bob, 2.0, 2.0), EYE_COLOR)


func _draw_crouched(half_w: float) -> void:
	var BODY_COLOR := body_color()
	var EYE_COLOR := eye_color()
	var head: float = 7.0
	var lump_h: float = _height - 5.0
	# Low lump (folded legs and torso), slightly wider than standing
	draw_rect(Rect2(-half_w - 1.0, -lump_h, _width + 2.0, lump_h), BODY_COLOR)
	# Head pushed forward, tucked on top
	var head_x: float = -3.5 + 2.0 * float(_facing)
	draw_rect(Rect2(head_x, -_height, 7.0, head), BODY_COLOR)
	draw_rect(Rect2(head_x + (4.0 if _facing > 0 else 1.0), -_height + 3.0, 2.0, 2.0), EYE_COLOR)


func _draw_climbing(_half_w: float) -> void:
	var BODY_COLOR := body_color()
	var head: float = 8.0
	var a: float = 1.0 if _climb_step == 0 else -1.0
	# Torso and head (facing the ladder: no eye)
	draw_rect(Rect2(-3.0, -(_height - head), 6.0, 12.0), BODY_COLOR)
	draw_rect(Rect2(-4.0, -_height, 8.0, head), BODY_COLOR)
	# Arms reach up and out, alternating high/low
	var shoulder: Vector2 = Vector2(0.0, -(_height - head) + 2.0)
	draw_line(shoulder, shoulder + Vector2(-5.0, -4.0 * a - 1.0), BODY_COLOR, 2.0, false)
	draw_line(shoulder, shoulder + Vector2(5.0, 4.0 * a - 1.0), BODY_COLOR, 2.0, false)
	# Legs alternate bent/straight
	var hip: Vector2 = Vector2(0.0, -8.0)
	draw_line(hip, hip + Vector2(-4.0, 8.0 if a > 0.0 else 4.0), BODY_COLOR, 2.0, false)
	draw_line(hip, hip + Vector2(4.0, 4.0 if a > 0.0 else 8.0), BODY_COLOR, 2.0, false)
