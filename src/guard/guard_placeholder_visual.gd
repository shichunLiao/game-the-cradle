class_name GuardPlaceholderVisual
extends Node2D
## Flat-colour stand-in for the guard's art: a silhouette soldier drawn with
## rectangles and lines only (`美术规格.md` §3, "剪影士兵"). Replaced later by
## real animation.
##
## Origin is at the guard's feet. Colours are passed in from GuardConfig so the
## spotted flash is data-driven; the PROPORTIONS below are placeholder art, the
## same convention `RynPlaceholderVisual` uses, not gameplay tuning.
##
## ## 状态要「看得出来」(2026-10-10,参考 Mark of the Ninja / 潜龙谍影)
##
## 之前三种状态只靠锥子换颜色。现在剪影本身也会演:
##
##   | 状态 | 头顶 | 姿势 |
##   |---|---|---|
##   | 巡逻 | 无 | 走路迈腿;停下时缓慢呼吸;转身那一下头朝镜头(没有帽檐) |
##   | 起疑 | 黄色「?」弹出 | 身体前倾、头往前探(侧耳听),枪口压低 |
##   | 发现 | 红色「!」弹出 | 举枪平端到眼睛高度,两脚分开站稳 |
##
## 头顶记号是颜色之外的第二条线索:色弱玩家、或者锥子被挡住时,仍然一眼知道守卫的状态。
##
## Usage:
##     visual.update_pose(32.0, 12.0, -1, Color("1A2A44"), Color("3D6B8A"))
##     visual.set_alert(guard.state, time_in_state)

## 下面这些比例是按 BASE_HEIGHT 高的守卫画的;实际身高不同时等比缩放。
const BASE_HEIGHT: float = 32.0
const HEAD_H: float = 9.0
const LEG_H: float = 11.0
const LEG_W: float = 4.0
const SHOULDER_FLARE: float = 2.0
const HELMET_BRIM: float = 4.0
const WEAPON_LEN: float = 11.0
## 走完一个迈腿循环要多少 px。比 Ryn 长一点 —— 守卫块头大,步子沉。
const WALK_CYCLE_PX: float = 32.0
## 停下多久算「站着」,开始呼吸,秒。
const STAND_AFTER: float = 0.25
## 呼吸一次的时长,秒。比 Ryn 慢 —— 成年人,而且在站岗。
const BREATH_PERIOD: float = 1.8
## 转身时头朝镜头的时长,秒。
const TURN_TIME: float = 0.14
## 头顶记号弹出的时长,秒,以及弹起的高度,px。
const POP_TIME: float = 0.14
const POP_HEIGHT: float = 4.0
## 头顶记号离头盔顶的距离,px。
const MARK_GAP: float = 3.0
const MARK_SUSPICIOUS: Color = Color("D6B53C")
const MARK_SPOTTED: Color = Color("E05A3A")
const MARK_OUTLINE: Color = Color("0B1220")
## 像素字:「?」5x7,「!」4x7(两像素宽,比问号更重)。
const GLYPH_QUESTION: Array[String] = [".###.", "#...#", "....#", "..##.", "..#..", ".....", "..#.."]
const GLYPH_BANG: Array[String] = [".##.", ".##.", ".##.", ".##.", ".##.", "....", ".##."]

var _height: float = 32.0
var _width: float = 12.0
var _facing: int = 1
var _fill: Color = Color("1A2A44")
var _rim: Color = Color("3D6B8A")
var _walk_phase: float = 0.0
var _clock: float = 0.0
var _still_for: float = 0.0
var _turn_left: float = 0.0
var _state: int = Guard.State.PATROL
var _state_time: float = 0.0
## 查看扣件的动作:0 一般、1 蹲着低头看、2 伸手捡、3 站起来拿着看(`GuardPursuit` 设)。
var _inspect: int = 0


## Sets the pose and colours to draw.
##
## `height` and `width` are the collider size in px; `facing` is -1 or 1.
func update_pose(height: float, width: float, facing: int, fill: Color, rim: Color) -> void:
	if facing != _facing:
		_turn_left = TURN_TIME
	_height = height
	_width = width
	_facing = facing
	_fill = fill
	_rim = rim


## 守卫当前状态(`Guard.State`)和进入这个状态多久了。由 `Guard` 每帧调。
func set_alert(state: int, state_time: float) -> void:
	_state = state
	_state_time = state_time


## 查看扣件的动作(见 `_inspect`)。方块造型不画这个,只有像素造型画。
func set_inspect(pose: int) -> void:
	_inspect = pose


func set_walk(walked_px: float) -> void:
	if walked_px > 0.01:
		_walk_phase += walked_px / WALK_CYCLE_PX
		_still_for = 0.0


func _process(delta: float) -> void:
	# Draw on whole pixels so flat shapes do not shimmer at fractional positions.
	var parent := get_parent() as Node2D
	if parent != null:
		position = parent.global_position.round() - parent.global_position
	_clock += delta
	_still_for += delta
	_turn_left = maxf(_turn_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	# 比例按 32px 高的原稿画,身高变了整体等比放大(2026-10-10 起守卫 48px)
	var k: float = _height / BASE_HEIGHT
	var head_h: float = roundf(HEAD_H * k)
	var leg_h: float = roundf(LEG_H * k)
	var leg_w: float = roundf(LEG_W * k)
	var flare: float = roundf(SHOULDER_FLARE * k)
	var head_w: float = roundf(8.0 * k)
	var half_w: float = _width * 0.5
	var f: float = float(_facing)
	var alert: bool = _state == Guard.State.SPOTTED
	var listening: bool = _state == Guard.State.SUSPICIOUS
	var walking: bool = _still_for < STAND_AFTER

	# 腿:走路时前后错开;发现时两脚分开站稳
	var swing: float = roundf(sin(_walk_phase * TAU) * 2.0 * k) if walking else 0.0
	var stance: float = roundf(1.0 * k) if alert else 0.0
	draw_rect(Rect2(-half_w + swing - stance, -leg_h, leg_w, leg_h), _fill)
	draw_rect(Rect2(half_w - leg_w - swing + stance, -leg_h, leg_w, leg_h), _fill)

	# 起伏:走路随步子,站着时慢慢呼吸
	var bob: float = 0.0
	if walking:
		bob = roundf(absf(sin(_walk_phase * TAU)) * 1.0)
	elif fposmod(_clock, BREATH_PERIOD) < BREATH_PERIOD * 0.5:
		bob = 1.0
	# 起疑:身体前倾、头再往前探 —— 侧耳听
	var lean: float = f * (1.0 if listening else 0.0)
	var head_lean: float = f * (2.0 if listening else 0.0)

	var torso_top: float = -(_height - head_h) + bob
	draw_rect(Rect2(-half_w - flare + lean, torso_top,
			_width + flare * 2.0, _height - head_h - leg_h - bob), _fill)
	# 头和头盔。转身那一下头朝镜头:不画帽檐
	var head_x: float = -head_w * 0.5 + head_lean
	var head_y: float = -_height + bob
	draw_rect(Rect2(head_x, head_y, head_w, head_h), _fill)
	if _turn_left <= 0.0:
		var brim: float = roundf(HELMET_BRIM * k)
		var brim_x: float = head_x + head_w if f > 0.0 else head_x - brim
		draw_rect(Rect2(brim_x, head_y + 1.0, brim, 2.0), _fill)

	# 枪:巡逻平端在胸前;起疑压低;发现时举到眼睛高度瞄准
	var gun_len: float = roundf(WEAPON_LEN * k)
	var chest := Vector2(f * half_w + lean, torso_top + roundf(4.0 * k))
	var muzzle: Vector2 = chest + Vector2(f * gun_len, 0.0)
	if listening:
		muzzle = chest + Vector2(f * roundf(gun_len * 0.85), roundf(gun_len * 0.45))
	elif alert:
		chest = Vector2(f * half_w + lean, head_y + roundf(head_h * 0.6))
		muzzle = chest + Vector2(f * (gun_len + roundf(2.0 * k)), 0.0)
	if _turn_left > 0.0 and not alert:
		muzzle = chest + Vector2(0.0, roundf(gun_len * 0.6))     # 转身时枪收在身前
	draw_line(chest, muzzle, _fill, 2.0, false)

	# 1 px rim light along the helmet top and the facing edge of the torso
	draw_rect(Rect2(head_x, head_y, head_w, 1.0), _rim)
	var edge_x: float = half_w + flare - 1.0 + lean if f > 0.0 else -half_w - flare + lean
	draw_rect(Rect2(edge_x, torso_top, 1.0, _height - head_h - leg_h - bob), _rim)

	if listening or alert:
		_draw_mark(GLYPH_BANG if alert else GLYPH_QUESTION,
				MARK_SPOTTED if alert else MARK_SUSPICIOUS, Vector2(head_lean, head_y))


## 头顶记号:进入状态时弹起再落下,深色描边,整数像素。
func _draw_mark(glyph: Array[String], color: Color, head_top: Vector2) -> void:
	var pop: float = 0.0
	if _state_time < POP_TIME:
		pop = roundf(POP_HEIGHT * sin(_state_time / POP_TIME * PI))
	var w: int = glyph[0].length()
	var origin := Vector2(roundf(head_top.x - w * 0.5), head_top.y - MARK_GAP - glyph.size() - pop)
	for pass_i in 2:
		for y in glyph.size():
			for x in w:
				if glyph[y][x] != "#":
					continue
				var p := origin + Vector2(x, y)
				if pass_i == 0:
					draw_rect(Rect2(p - Vector2.ONE, Vector2(3.0, 3.0)), MARK_OUTLINE)
				else:
					draw_rect(Rect2(p, Vector2.ONE), color)
