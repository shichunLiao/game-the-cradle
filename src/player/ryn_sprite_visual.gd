class_name RynSpriteVisual
extends Node2D
## 按精灵表逐帧绘制 Ryn。所有状态都从同一张表取帧。
##
## ## 素材
##
## `assets/art/ryn_sprites.png`,由 `assets/art/src/build_ryn_sheet.py` 从用户立绘
## `assets/art/src/ryn_source.png`(只读)生成:立绘收成 24x44 后切成部件,每帧只做整像素
## 平移,不重画、不缩放 —— 每一帧都是同一个人。表的布局(必须与构建脚本一致):
##
##   每格 40x56,脚底中心在格内 (20, 55)。上半 12 行是动作,下半 12 行是同位置的眼睛高光。
##    0 待机呼吸 8 | 1 小动作(抬头张望)8 | 2 走 8 | 3 跑 8
##    4 起跑 0-1 / 急停 2-4 / 转身 5-6 | 5 蹲下 0-1 过渡 / 2-7 蹲姿呼吸 | 6 蹲着走 8
##    7 跳:起跳 上升快 上升 顶点 下落 下落快 轻落地 重落地 | 8 爬梯 0-3(背面) / 翻上梯顶 4-5
##    9 顶墙 0-3 / 边缘晃 4-7 | 10 拆东西 0-5 | 11 被发现 0-3 / 举照片 4-7
##   12 带水平速度的跳:上升 顶点 下落 下落快(Celeste 的 jumpFast)
##   跑是 6 帧(第 3 行 0-5),其余循环 8 帧。
##
## ## 选哪一格
##
## 照 Celeste 开源 Player.cs 的 `UpdateSprite()`:按优先级一条条往下判,先命中先用
## (研究记录见 `docs/ryn-animation-research.md`)。潜行另加三条:
##   - **藏身不是另一个姿势**:蹲在暗处和蹲在亮处是同一个蹲姿,只是整个人压暗、眼睛留着
##     高光(Mark of the Ninja 的做法)。上一版藏身单独一行,用户反馈「和蹲下不一样很奇怪」。
##   - 拆东西、被发现、举照片是「动作」,由外部用 `set_action()` 指定,优先级最高。
##
## ## 节奏
##
## 走、跑、蹲着走按**走过的距离**推进(跑得快动作就快,停下就停),共用一个相位,
## 所以走↔跑切换时腿是连续的。其余按时间推进。这些数只影响画面,不进移动公式。
##
## **每帧停留不等长**(`*_WEIGHTS`):触地、腾空、吸满这类关键帧停久一点,过渡帧快一点。
## 「像素动画的生死在节奏,不在帧数」—— 4 帧靠节奏能看起来像 12 帧。每张表前后两半的
## 权重和相等,所以相位 0 和 0.5 永远是两侧的触地帧,走↔跑切换不会错脚。
##
## 原点在 **脚底中心**,与碰撞体一致。1 个表像素 = 1 个世界像素。

## 脚踩实地的那一帧(走 / 跑 / 蹲着走的触地帧)。脚步声、扬尘、噪音都跟着它,
## 而不是按走过的距离另算 —— 声音和画面对上,才「踩得实」。`kind`:&"walk" / &"run" / &"sneak"。
signal foot_planted(kind: StringName)
## 落地。`hard` = 掉落超过 `hard_land_fall_px`(画面上用的是重落地那一帧)。
signal landed(hard: bool)
## 起跳离地(往上跳,不含从边缘走下去)。
signal took_off
## 开始急停。
signal skid_started

## 外部指定的动作(`set_action()`)。空 = 没有,按移动状态选帧。
const ACTION_NONE: StringName = &""
## 蹲着拆东西(拧三下、再撬),循环。
const ACTION_WORK: StringName = &"work"
## 被发现时一惊、然后僵住。播一次,停在最后一帧。
const ACTION_CAUGHT: StringName = &"caught"
## 举起照片。播一次,停在最后一帧。
const ACTION_PHOTO: StringName = &"photo"
## 瞄准丢扣件:停在蓄力那一格(手举到耳边捏着扣件)。`RynThrow` 指定。
const ACTION_AIM: StringName = &"aim"
## 丢出去:出手 → 随势 → 收,播一次停在最后一帧。`RynThrow` 在 `THROW_TIME` 后取消。
const ACTION_THROW: StringName = &"throw"

## 精灵表(ryn_sprites.png)。为空则什么都不画。
@export var texture: Texture2D
@export_group("Cycles")
## 走一整轮(8 帧)对应的地面距离,px。52 在 walk_speed=105 下约 16 帧/秒。
@export var walk_cycle_px: float = 52.0
## 跑一整轮(8 帧)对应的地面距离,px。68 在冲刺 170 px/s 下约 20 帧/秒。
@export var run_cycle_px: float = 68.0
## 蹲着走一整轮(8 帧)对应的地面距离,px。32 在 crouch_speed=44 下约 11 帧/秒。
@export var crouch_cycle_px: float = 32.0
## 待机呼吸的帧率。8 帧 / 5 = 1.6 秒一次呼吸。
@export var idle_fps: float = 5.0
## 蹲姿呼吸的帧率(第 5 行第 2-7 帧)。
@export var crouch_fps: float = 4.0
## 藏住时的呼吸帧率。同一个蹲姿,呼吸更慢 —— 屏住气。
@export var hidden_fps: float = 2.5
## 顶墙时两脚交替的帧率。
@export var push_fps: float = 5.0
## 站在边缘晃的帧率。
@export var edge_fps: float = 6.0
## 拆东西的帧率。
@export var work_fps: float = 8.0
@export_group("Transitions")
## 下蹲过渡每帧持续的时间,秒。下蹲要快 —— 重力往下拉。
@export var crouch_transition_frame: float = 0.04
## 起身过渡每帧持续的时间,秒。起身比下蹲慢,才有重量感(SLYNYRD:下 50ms / 上 100ms)。
@export var stand_transition_frame: float = 0.07
## 原地起跑(按着跑步键)的预备动作,每帧秒数,共 2 帧。
@export var start_frame_time: float = 0.05
## 急停每帧秒数,共 3 帧。
@export var skid_frame_time: float = 0.06
## 松开方向键或反向时,水平速度高于它才播急停(低于它是转身)。走路 105 不会触发,跑步 170 会。
@export var skid_min_speed: float = 120.0
## 转身每帧秒数,共 2 帧。
@export var turn_frame_time: float = 0.05
## 滞空时水平速度高于它,换成两腿跨开的跳(第 12 行)。
@export var air_move_speed: float = 60.0
## 起跳那一帧(身体拉长)持续的时间,秒。
@export var takeoff_time: float = 0.06
## 轻落地压扁持续的时间,秒。
@export var land_soft_time: float = 0.1
## 重落地(蹲一下缓冲)持续的时间,秒。
@export var land_hard_time: float = 0.2
## 下落超过这个距离算重落地,px。比一次满跳(56)高 —— 从平台或拆开的盖板掉下来。
@export var hard_land_fall_px: float = 80.0
## 翻上梯顶每帧秒数,共 2 帧。
@export var climb_over_frame: float = 0.07
## 站着不动多久后播一次小动作,秒(Celeste 用 3 秒)。
@export var fidget_after: float = 4.0
## 小动作的帧率。8 帧约 1.3 秒。
@export var fidget_fps: float = 6.0
## 被发现、举照片这类「播一次」的动作的帧率。
@export var oneshot_fps: float = 12.0
@export_group("Thresholds")
## 水平速度高于它算「跑」。介于 walk_speed(105) 与冲刺速度(170) 之间。
@export var run_speed: float = 135.0
## 低于这个速度视为站定。
@export var still_speed: float = 8.0
## 站定后多久回到待机,秒。留一点余量是为了转身那一帧不闪回。
@export var settle_time: float = 0.06

const CELL_W: int = 40
const CELL_H: int = 56
## 格子里的脚底中心。
const CELL_FOOT := Vector2i(20, 55)

const ROW_IDLE: int = 0
const ROW_FIDGET: int = 1
const ROW_WALK: int = 2
const ROW_RUN: int = 3
const ROW_MOVES: int = 4
const ROW_CROUCH: int = 5
const ROW_CROUCH_WALK: int = 6
const ROW_JUMP: int = 7
const ROW_CLIMB: int = 8
const ROW_PUSH_EDGE: int = 9
const ROW_WORK: int = 10
const ROW_CAUGHT_PHOTO: int = 11
const ROW_AIR_MOVE: int = 12
## 动作行数。眼睛高光在 `行号 + ACTION_ROWS`。
const ACTION_ROWS: int = 13

const CYCLE_FRAMES: int = 8
const RUN_FRAMES: int = 6
## 每帧相对停留时间。待机:呼尽(0)、吸满(4)停久一点。
const IDLE_WEIGHTS: Array[float] = [1.4, 0.8, 0.8, 1.0, 1.4, 0.8, 0.8, 1.0]
## 走:触地略长、下沉略短。
const WALK_WEIGHTS: Array[float] = [1.15, 0.85, 1.0, 1.0, 1.15, 0.85, 1.0, 1.0]
## 跑:腾空最长 —— 那是「快」的那一下。
const RUN_WEIGHTS: Array[float] = [1.0, 0.8, 1.2, 1.0, 0.8, 1.2]
## 蹲着走(潜行):落脚那帧停最久(小心放下),迈脚快。
const SNEAK_WEIGHTS: Array[float] = [1.3, 0.9, 0.8, 1.0, 1.3, 0.9, 0.8, 1.0]
## 各行的触地帧(脚踩实的那一帧),发 `foot_planted`。
const WALK_CONTACTS: Array[int] = [0, 4]
const RUN_CONTACTS: Array[int] = [0, 3]
const SNEAK_CONTACTS: Array[int] = [0, 4]
## 起跳时竖直速度低于它才算「跳」(从边缘走下去不算)。
const TAKEOFF_SPEED: float = -100.0
const FIDGET_LOOK_UP: int = 2
const MOVE_START: int = 0
const MOVE_SKID: int = 2
const MOVE_SKID_FRAMES: int = 3
const MOVE_TURN: int = 5
## 第 5 行:第 0-1 帧是下蹲过渡,第 2-7 帧是蹲姿呼吸。
const CROUCH_LOOP_START: int = 2
const CROUCH_LOOP_FRAMES: int = 6
const JUMP_TAKEOFF: int = 0
const JUMP_RISE_FAST: int = 1
const JUMP_RISE: int = 2
const JUMP_APEX: int = 3
const JUMP_FALL: int = 4
const JUMP_FALL_FAST: int = 5
const JUMP_LAND_SOFT: int = 6
const JUMP_LAND_HARD: int = 7
const CLIMB_FRAMES: int = 4
const CLIMB_OVER: int = 4
const PUSH_START: int = 0
const EDGE_START: int = 4
const LOOP4: int = 4
const WORK_FRAMES: int = 6
const CAUGHT_START: int = 0
const PHOTO_START: int = 4
const ONESHOT_FRAMES: int = 4
## 丢扣件在 ROW_AIR_MOVE 的后半:4 蓄力,5 出手,6 随势,7 收。
const AIM_FRAME: int = 4
const THROW_START: int = 5
## 出手 / 随势 / 收 各停多久,秒。出手要快(那一下的劲),收要慢。
const THROW_FRAME_TIMES: Array[float] = [0.08, 0.12, 0.22]
## 整个丢出动作的时长,秒(= THROW_FRAME_TIMES 之和)。
const THROW_TIME: float = 0.42
## 起步时的相位:单脚抬起的换步帧,而不是双脚大开的触地帧 —— 从站立直接跳成
## 大跨步,起步那一下会顿。
const START_PHASE: float = 2.0 / 8.0

const LAND_MIN_SPEED: float = 150.0
const CONCEAL_RATE: float = 3.2
## 隐蔽色调。仍可辨 —— 玩家必须看得见自己。
const CONCEAL_TINT: Color = Color(0.42, 0.52, 0.66, 1.0)

var _height: float = 28.0
var _stand_height: float = 0.0
var _facing: int = 1
var _climbing: bool = false
var _climb_distance: float = 0.0
## 一格一格爬:爬完了几格、现在是不是正在拉(`Ryn` 每帧给)。
var _climb_steps: int = 0
var _climb_moving: bool = false
var _climb_dir: float = 0.0
var _concealment: float = 0.0
var _shown_conceal: float = 0.0
var _phase: float = START_PHASE
var _airborne: bool = false
var _vel_x: float = 0.0
var _vel_y: float = 0.0
var _clock: float = 0.0
var _still_for: float = 0.0
var _crouched_for: float = 0.0
var _stood_for: float = 1.0
var _air_time: float = 0.0
var _fall_px: float = 0.0
var _land_left: float = 0.0
var _land_hard: bool = false
var _move_x: float = 0.0
var _look_up: bool = false
var _sprint: bool = false
var _pushing: bool = false
var _at_edge: bool = false
var _driving: bool = false
var _just_started: bool = false
var _start_left: float = 0.0
var _skid_left: float = 0.0
var _skid_facing: int = 1
var _turn_left: float = 0.0
var _climb_over_left: float = 0.0
var _idle_for: float = 0.0
var _fidget_t: float = -1.0
var _action: StringName = ACTION_NONE
var _action_t: float = 0.0
var _last_cell: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	# 项目默认过滤是线性(default_texture_filter=1 在 Godot 4 里是 Linear)。
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 二段跳:空中再起跳那一下,重新放一次起跳帧(收腿、蹬)
	var body := get_parent()
	if body != null and body.has_signal(&"air_jumped"):
		body.connect(&"air_jumped", func() -> void: _air_time = 0.0)


func _process(delta: float) -> void:
	var parent := get_parent() as Node2D
	if parent != null:
		position = parent.global_position.round() - parent.global_position
	_clock += delta
	_action_t += delta
	_land_left = maxf(_land_left - delta, 0.0)
	_start_left = maxf(_start_left - delta, 0.0)
	_skid_left = maxf(_skid_left - delta, 0.0)
	_turn_left = maxf(_turn_left - delta, 0.0)
	_climb_over_left = maxf(_climb_over_left - delta, 0.0)
	if _is_crouched():
		_crouched_for += delta
		_stood_for = 0.0
	else:
		_stood_for += delta
		_crouched_for = 0.0
	_tick_fidget(delta)
	_emit_footfall()
	if not is_equal_approx(_shown_conceal, _concealment):
		_shown_conceal = move_toward(_shown_conceal, _concealment, CONCEAL_RATE * delta)
	queue_redraw()


## 一格一格爬(2026-10-15):`steps` 爬完了几格,`moving` 正在往下一格拉。`Ryn` 每帧在 `update_pose()` 之后调。
func set_climb_step(steps: int, moving: bool) -> void:
	_climb_steps = steps
	_climb_moving = moving


## 与 `RynPlaceholderVisual` 同签名,便于互换。`Ryn` 每帧先调 `set_motion()` 再调它。
func update_pose(height: float, width: float, facing: int, climbing: bool, climb_distance: float) -> void:
	_height = height
	_stand_height = maxf(_stand_height, height)
	if climbing:
		if not is_equal_approx(climb_distance, _climb_distance):
			_climb_dir = signf(climb_distance - _climb_distance)
	elif _climbing:
		# 刚离开梯子。往上爬到顶(速度清零)才播翻上去;往下爬到地面、从梯子上跳开都不播。
		if _climb_dir < 0.0 and _vel_y > -1.0:
			_climb_over_left = climb_over_frame * 2.0
		_climb_dir = 0.0
	_climbing = climbing
	_climb_distance = climb_distance
	if facing != _facing and not climbing and not _airborne and not _is_crouched() \
			and absf(_vel_x) > still_speed and _skid_left <= 0.0:
		_turn_left = turn_frame_time * 2.0
	_facing = facing


func set_concealment(value: float) -> void:
	_concealment = clampf(value, 0.0, 1.0)


func set_motion(walked_px: float, airborne: bool, vel_y: float, vel_x: float = 0.0, delta: float = 0.0) -> void:
	if airborne:
		if not _airborne:
			_air_time = 0.0
			_fall_px = 0.0
			if vel_y < TAKEOFF_SPEED:
				took_off.emit()
		_air_time += delta
		if vel_y > 0.0:
			_fall_px += vel_y * delta
	elif _airborne and _vel_y > LAND_MIN_SPEED:
		_land_hard = _fall_px > hard_land_fall_px
		_land_left = land_hard_time if _land_hard else land_soft_time
		landed.emit(_land_hard)
	var was_still: bool = _still_for >= settle_time
	if absf(vel_x) < still_speed and not airborne:
		_still_for += delta
		if _still_for >= settle_time:
			_phase = START_PHASE
	else:
		_still_for = 0.0
		# 起跑要等 set_intent() 知道有没有按跑步键再决定(同一帧里它在后面调)
		_just_started = was_still and not airborne and not _is_crouched()
		var cycle: float = walk_cycle_px
		if _is_crouched():
			cycle = crouch_cycle_px
		elif absf(vel_x) > run_speed:
			cycle = run_cycle_px
		_phase += walked_px / maxf(cycle, 0.0001)
	_airborne = airborne
	_vel_y = vel_y
	_vel_x = vel_x


## 这一帧玩家想做什么,以及身边的地形。由 `Ryn` 每个物理帧填。
##
## `move_x` 方向输入;`look_up` 按着上、身边没有梯子;`sprint` 按着跑步键;
## `pushing` 正往墙里走;`at_edge` 脚下一半已经悬空(Celeste 的 edge 判定)。
func set_intent(move_x: float, look_up: bool, sprint: bool, pushing: bool, at_edge: bool) -> void:
	var driving: bool = absf(move_x) > 0.01 and signf(move_x) == signf(_vel_x)
	if _driving and not driving and absf(_vel_x) > skid_min_speed and not _airborne \
			and not _climbing and not _is_crouched():
		_skid_left = skid_frame_time * MOVE_SKID_FRAMES
		_skid_facing = 1 if _vel_x > 0.0 else -1
		_turn_left = 0.0
		skid_started.emit()
	_driving = driving
	if _just_started and sprint:
		_start_left = start_frame_time * 2.0
	_just_started = false
	_move_x = move_x
	_look_up = look_up
	_sprint = sprint
	_pushing = pushing
	_at_edge = at_edge


## 指定一个外部动作(`ACTION_*`),或 `ACTION_NONE` 取消。重复指定同一个动作不会重播。
##
## Usage: `ryn.get_node("Visual").set_action(RynSpriteVisual.ACTION_PHOTO)`
func set_action(action: StringName) -> void:
	if action == _action:
		return
	_action = action
	_action_t = 0.0


## 当前的外部动作(`ACTION_*`)。
func current_action() -> StringName:
	return _action


## 当前画的是表里哪一格。残影抓拍用。
##
## Usage: `var snap: Dictionary = sprite.snapshot()`
func snapshot() -> Dictionary:
	var cell: Vector2i = _cell()
	return {&"row": cell.y, &"frame": cell.x, &"facing": _shown_facing()}


## 在 `canvas` 上把快照里那一格再画一遍。只在 `canvas._draw()` 里调用。
##
## Usage (在残影节点的 _draw 里): `sprite.draw_snapshot(self, local_pos, snap, color)`
func draw_snapshot(canvas: CanvasItem, origin: Vector2, snap: Dictionary, color: Color) -> void:
	if texture == null or snap.is_empty():
		return
	_blit(canvas, origin, Vector2i(snap[&"frame"], snap[&"row"]), snap[&"facing"], color)


func _draw() -> void:
	if texture == null:
		return
	var cell: Vector2i = _cell()
	var facing: int = _shown_facing()
	_blit(self, Vector2.ZERO, cell, facing, Color.WHITE.lerp(CONCEAL_TINT, _shown_conceal))
	# 眼睛高光:身体压暗了,眼睛还亮着 —— 「我藏住了,但我还在看」
	var glint: float = smoothstep(0.5, 1.0, _shown_conceal)
	if glint > 0.0:
		_blit(self, Vector2.ZERO, cell + Vector2i(0, ACTION_ROWS), facing, Color(1.0, 1.0, 1.0, glint))


## 选格子:x = 帧,y = 行。按优先级往下判,先命中先用。
func _cell() -> Vector2i:
	var action: Vector2i = _action_cell()
	if action.x >= 0:
		return action
	if _climbing:
		# 停在横档上:一只手在上面(单数格换另一只手);正在拉:中间那帧
		return Vector2i((2 if _climb_steps % 2 == 1 else 0) + (1 if _climb_moving else 0), ROW_CLIMB)
	# 翻上梯顶排在滞空前面:离开梯子的那一帧,脚还没踩到梯顶,物理上算「不在地上」
	if _climb_over_left > 0.0:
		return Vector2i(CLIMB_OVER + _countdown_frame(_climb_over_left, climb_over_frame, 2), ROW_CLIMB)
	if _airborne:
		var jf: int = _jump_frame()
		# 带水平速度的跳换成两腿跨开的那一行(Celeste 的 jumpFast);起跳那一帧两种跳共用
		if jf != JUMP_TAKEOFF and absf(_vel_x) > air_move_speed:
			return Vector2i(maxi(jf - JUMP_RISE, 0), ROW_AIR_MOVE)   # 上升 / 顶点 / 下落 / 下落快
		return Vector2i(jf, ROW_JUMP)
	if _land_left > 0.0:
		return Vector2i(JUMP_LAND_HARD if _land_hard else JUMP_LAND_SOFT, ROW_JUMP)
	if _is_crouched():
		return _crouch_cell()
	# 起身:倒放下蹲的两帧。只在**原地**起身时播 —— 条件是起身前就已经站定
	# (静止时间比站起来的时间还长)。走着起身时腿已经在走路帧上,再插两帧下蹲
	# 过渡会显得她先走、又蹲、再站。
	if _stood_for < stand_transition_frame * 2.0 and _still_for >= settle_time \
			and _still_for >= _stood_for:
		return Vector2i(1 - int(_stood_for / stand_transition_frame), ROW_CROUCH)
	if _skid_left > 0.0:
		return Vector2i(MOVE_SKID + _countdown_frame(_skid_left, skid_frame_time, MOVE_SKID_FRAMES), ROW_MOVES)
	if _turn_left > 0.0:
		return Vector2i(MOVE_TURN + _countdown_frame(_turn_left, turn_frame_time, 2), ROW_MOVES)
	if _pushing:
		return Vector2i(PUSH_START + int(_clock * push_fps) % LOOP4, ROW_PUSH_EDGE)
	if _still_for >= settle_time:
		if _at_edge:
			return Vector2i(EDGE_START + int(_clock * edge_fps) % LOOP4, ROW_PUSH_EDGE)
		if _look_up:
			return Vector2i(FIDGET_LOOK_UP, ROW_FIDGET)
		if _fidget_t >= 0.0:
			return Vector2i(mini(int(_fidget_t * fidget_fps), CYCLE_FRAMES - 1), ROW_FIDGET)
		return Vector2i(_weighted_frame(_clock * idle_fps / float(CYCLE_FRAMES), IDLE_WEIGHTS), ROW_IDLE)
	if _start_left > 0.0:
		return Vector2i(MOVE_START + _countdown_frame(_start_left, start_frame_time, 2), ROW_MOVES)
	if absf(_vel_x) > run_speed:
		return Vector2i(_weighted_frame(_phase, RUN_WEIGHTS), ROW_RUN)
	return Vector2i(_weighted_frame(_phase, WALK_WEIGHTS), ROW_WALK)


## 外部动作的格子;没有动作时 x = -1。
func _action_cell() -> Vector2i:
	match _action:
		ACTION_CAUGHT:
			return Vector2i(CAUGHT_START + _oneshot_frame(), ROW_CAUGHT_PHOTO)
		ACTION_PHOTO:
			return Vector2i(PHOTO_START + _oneshot_frame(), ROW_CAUGHT_PHOTO)
		ACTION_WORK:
			if not _airborne and not _climbing:
				return Vector2i(int(_action_t * work_fps) % WORK_FRAMES, ROW_WORK)
		ACTION_AIM:
			if not _airborne and not _climbing:
				return Vector2i(AIM_FRAME, ROW_AIR_MOVE)
		ACTION_THROW:
			# 丢完马上走起来/跳起来,就让移动动画接手,别让脚在地上滑
			if not _airborne and not _climbing and _still_for > 0.0:
				return Vector2i(THROW_START + _throw_frame(), ROW_AIR_MOVE)
	return Vector2i(-1, -1)


func _throw_frame() -> int:
	var t: float = _action_t
	for i in THROW_FRAME_TIMES.size():
		t -= THROW_FRAME_TIMES[i]
		if t < 0.0:
			return i
	return THROW_FRAME_TIMES.size() - 1


func _crouch_cell() -> Vector2i:
	if _still_for < settle_time:
		return Vector2i(_weighted_frame(_phase, SNEAK_WEIGHTS), ROW_CROUCH_WALK)
	if _crouched_for < crouch_transition_frame * 2.0:
		return Vector2i(int(_crouched_for / crouch_transition_frame), ROW_CROUCH)
	# 藏住和没藏住是同一个蹲姿;藏住时只是呼吸更慢(颜色在 _draw 里压暗)
	var fps: float = hidden_fps if _concealment >= 0.99 else crouch_fps
	return Vector2i(CROUCH_LOOP_START + int(_clock * fps) % CROUCH_LOOP_FRAMES, ROW_CROUCH)


func _shown_facing() -> int:
	# 急停时身体还朝着滑行的方向(反向输入时朝向已经翻过去了)
	if _skid_left > 0.0 and _action == ACTION_NONE and not _airborne and not _climbing:
		return _skid_facing
	return _facing


## 倒计时动画的第几帧:剩余时间从 frames*frame_time 数到 0,帧号从 0 走到 frames-1。
func _countdown_frame(left: float, frame_time: float, frames: int) -> int:
	var elapsed: float = float(frames) * frame_time - left
	return clampi(int(elapsed / maxf(frame_time, 0.0001)), 0, frames - 1)


func _oneshot_frame() -> int:
	return mini(int(_action_t * oneshot_fps), ONESHOT_FRAMES - 1)


## 循环动画走到 `cycles`(只看小数部分)时是第几帧。`weights` 是每帧的相对停留时间。
func _weighted_frame(cycles: float, weights: Array[float]) -> int:
	var total: float = 0.0
	for w in weights:
		total += w
	var t: float = fposmod(cycles, 1.0) * total
	for i in weights.size():
		t -= weights[i]
		if t < 0.0:
			return i
	return weights.size() - 1


func _jump_frame() -> int:
	if _air_time < takeoff_time and _vel_y < -160.0:
		return JUMP_TAKEOFF
	if _vel_y < -160.0:
		return JUMP_RISE_FAST
	if _vel_y < -50.0:
		return JUMP_RISE
	if _vel_y < 50.0:
		return JUMP_APEX
	if _vel_y < 180.0:
		return JUMP_FALL
	return JUMP_FALL_FAST


## 换到触地帧的那一刻发 `foot_planted`。在 _process 里判:画面换帧的节奏就是这里。
func _emit_footfall() -> void:
	var cell: Vector2i = _cell()
	if cell == _last_cell:
		return
	_last_cell = cell
	match cell.y:
		ROW_WALK:
			if cell.x in WALK_CONTACTS:
				foot_planted.emit(&"walk")
		ROW_RUN:
			if cell.x in RUN_CONTACTS:
				foot_planted.emit(&"run")
		ROW_CROUCH_WALK:
			if cell.x in SNEAK_CONTACTS:
				foot_planted.emit(&"sneak")


## 站着不动够久就播一次小动作,播完重新计时。任何别的状态都会打断并清零。
func _tick_fidget(delta: float) -> void:
	var plain_idle: bool = _action == ACTION_NONE and not _climbing and not _airborne \
			and not _is_crouched() and _still_for >= settle_time and not _at_edge \
			and not _look_up and not _pushing and _land_left <= 0.0
	if not plain_idle:
		_idle_for = 0.0
		_fidget_t = -1.0
		return
	if _fidget_t >= 0.0:
		_fidget_t += delta
		if _fidget_t * fidget_fps >= float(CYCLE_FRAMES):
			_fidget_t = -1.0
			_idle_for = 0.0
		return
	_idle_for += delta
	if _idle_for >= fidget_after:
		_fidget_t = 0.0


func _is_crouched() -> bool:
	return _stand_height > 0.0 and _height < _stand_height - 0.5


## 画一格:格子里的脚底中心对到原点。朝左时绕原点水平镜像。
##
## **用画布变换镜像,不用负宽度矩形。** 实测 Godot 4.6 对负宽度目标矩形是「从给定位置
## 往右铺开再翻转」,朝左时整个人会右偏一格宽。
func _blit(canvas: CanvasItem, origin: Vector2, cell: Vector2i, facing: int, color: Color) -> void:
	var src := Rect2(cell.x * CELL_W, cell.y * CELL_H, CELL_W, CELL_H)
	var dst := Rect2(Vector2(-CELL_FOOT.x, -CELL_FOOT.y), Vector2(CELL_W, CELL_H))
	if facing < 0:
		canvas.draw_set_transform(origin, 0.0, Vector2(-1.0, 1.0))
		canvas.draw_texture_rect_region(texture, dst, src, color)
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		dst.position += origin
		canvas.draw_texture_rect_region(texture, dst, src, color)
