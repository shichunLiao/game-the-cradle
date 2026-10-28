class_name Ryn
extends CharacterBody2D
## Ryn, the player character: walk, jump, crouch and climb.
##
## Origin is at Ryn's FEET. All tuning comes from `config` (a
## RynMovementConfig resource). Movement is driven by `intent` (RynIntent),
## which is filled from the Input Map each physics tick while `input_enabled`.
##
## Thread safety: main thread only (it is a scene node).
##
## Movement rules:
##  - Walk: velocity eases toward the target speed (acceleration / deceleration).
##  - Jump: launch velocity is derived from `config.jump_height`; releasing the
##    key while rising adds gravity (variable height). Everything runs on the
##    fixed physics tick, so the same hold time gives the same height.
##  - Air jump (二段跳): in the air, a fresh jump press spends one of
##    `config.air_jumps` for a lower hop (`config.air_jump_height`). Refilled on
##    the floor and when hopping off a ladder. A buffered press that lands first
##    stays a ground jump — only a press made in the air is an air jump.
##  - Crouch: hold down on the floor. Collider and drawn silhouette shrink
##    together. Releasing under a low ceiling keeps Ryn crouched until there is
##    room to stand (checked with a shape sweep), so Ryn can never clip into it.
##  - Climb: press up (or down at a ladder top) overlapping a Ladder. Gravity is
##    off while climbing; jump to hop off; reaching the top or floor exits.
##  - Hide: a `HidingSpot` (locker / vent) calls `enter_hiding()`. Ryn stops,
##    is not drawn and `is_detectable()` turns false, so guards, sweep lights,
##    gate lights and Vera's sweep all ignore her. Jump, or a direction pressed
##    AFTER entering, steps back out (`exit_hiding()`); the spot handles E.
##
## Usage:
##     var ryn: Ryn = preload("res://src/player/ryn.tscn").instantiate()
##     ryn.config = load("res://assets/data/ryn_movement.tres")  # scene already sets one
##     add_child(ryn)
##     # Drive without real input (tests, cutscenes):
##     ryn.input_enabled = false
##     ryn.intent.move_x = 1.0

enum State {
	## Walking, standing, crouching, jumping or falling.
	NORMAL,
	## Holding a ladder.
	CLIMBING,
	## Inside a hiding spot (locker, vent). Not drawn, not detectable, not moving.
	HIDING,
}

## Emitted when Ryn goes into or comes out of a hiding spot.
signal hiding_changed(hidden: bool, spot: Node2D)
## 空中又跳了一下(二段跳)。画面(重新起跳的那一帧)、声音、脚下一小团气流都接这个。
signal air_jumped

## Movement tuning. Required.
@export var config: RynMovementConfig

## Current intent. Written by Ryn from the Input Map when `input_enabled`.
var intent: RynIntent = RynIntent.new()
## When false, Ryn does not read the Input Map; set `intent` externally.
var input_enabled: bool = true
## Facing direction, -1 (left) or 1 (right). Read by the camera for look-ahead.
var facing: int = 1
## Current high-level state.
var state: State = State.NORMAL

## 站在梯子顶往下爬:离梯子中线多近才抓,px。
## 梯子感应区比脚底多伸 4px(`ryn.tscn` 的 LadderSensor:高 28、中心 -10),站在梯子顶上才碰得到
## 梯子 —— 以前感应区底边正好贴着脚底、和梯子顶边只是相切,站在梯子顶按下永远爬不下去(2026-10-11
## 坑底下行关第一次需要往下爬时发现)。
const LADDER_TOP_GRAB_PX: float = 6.0
## 判「站在边缘」时碰撞体往前挪多少,px。宽 10 的碰撞体挪 4 之后脚下没地面 =
## 只剩不到 4px 还踩在边上。
const EDGE_PROBE_PX: float = 4.0
## True while crouched (collider and silhouette are the short ones).
var is_crouching: bool = false
## True while actually sprinting (Shift held, on floor, not crouched).
## 读它来决定残影与跑步噪音。
var is_sprinting: bool = false
## 脚下的拖累:乘在**地面**最大速度上,1 = 正常。由外部写(坑底的蚀 `CorrosionZone`:粘鞋底)。
## 只管地面水平速度,不碰跳跃 —— 关卡生成器的路线检查按不变的跳跃能力算。
## 小于 1 时跑不起来(按跑步也只是走:`is_sprinting` 为 false,没有跑步噪音和残影)。
var ground_drag: float = 1.0
## 瞄准丢扣件中(`RynThrow` 写):站住不走,左右键交给瞄准去调落点,不拿来走路和转身。
var aiming: bool = false

var _shape: RectangleShape2D
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
## 这次在空中还能跳几下(落地 / 下梯子时补满 `config.air_jumps`)。
var _air_jumps_left: int = 0
var _ladders: Array[Ladder] = []
var _climb_ladder: Ladder
var _climb_distance: float = 0.0
## 一格一格爬:这一步往哪走(-1 上 / 1 下 / 0 停在横档上)、从哪到哪、歇了多久、一共爬完几格。
var _step_dir: int = 0
var _step_from: float = 0.0
var _step_target: float = 0.0
var _step_rest: float = 0.0
var _climb_steps: int = 0
## The spot Ryn is inside while `state == HIDING`; null otherwise.
var hiding_spot: Node2D
var _hide_time: float = 0.0
## A direction only gets Ryn out once it was released inside — otherwise the key
## still held from walking up to the locker would pop her straight back out.
var _hide_move_armed: bool = false

@onready var _collider: CollisionShape2D = $CollisionShape2D
# 立绘视觉与占位视觉同签名,这里不写死类型,W7 换素材时可直接替换节点脚本。
@onready var _visual: Node2D = $Visual
@onready var _ladder_sensor: Area2D = $LadderSensor


func _ready() -> void:
	assert(config != null, "Ryn.config must be set")
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.LADDER_TOP
	_shape = RectangleShape2D.new()
	_collider.shape = _shape
	_apply_height(config.stand_height)
	_ladder_sensor.collision_layer = 0
	_ladder_sensor.collision_mask = PhysicsLayers.LADDER
	_ladder_sensor.area_entered.connect(_on_sensor_area_entered)
	_ladder_sensor.area_exited.connect(_on_sensor_area_exited)
	_sync_visual()


func _physics_process(delta: float) -> void:
	if config == null:
		return
	if input_enabled:
		_poll_input()
	match state:
		State.NORMAL:
			_tick_normal(delta)
		State.CLIMBING:
			_tick_climbing(delta)
		State.HIDING:
			_tick_hiding(delta)
	_sync_visual(delta)


## Current collider height in px (equals the drawn silhouette height).
func get_body_height() -> float:
	return _shape.size.y


## False while Ryn is inside a hiding spot. Everything that can catch Ryn
## (guards, sweep lights, gate lights, Vera's sweep) asks this first.
##
## Usage: `if not ryn.is_detectable(): return`
func is_detectable() -> bool:
	return state != State.HIDING


## True when Ryn can step into a hiding spot right now: on the floor, walking or
## crouching, not climbing, not already hidden.
func can_hide() -> bool:
	return state == State.NORMAL and is_on_floor()


## Steps into `spot`. `anchor` is where Ryn stands while hidden (the spot's
## floor centre). Returns false when hiding is not possible right now.
##
## Usage: `ryn.enter_hiding(self, Vector2(x, floor_y))`
func enter_hiding(spot: Node2D, anchor: Vector2) -> bool:
	if not can_hide():
		return false
	state = State.HIDING
	hiding_spot = spot
	_hide_time = 0.0
	_hide_move_armed = absf(intent.move_x) < 0.3
	velocity = Vector2.ZERO
	is_sprinting = false
	global_position = anchor
	_visual.visible = false            # 当帧就藏起来,不等下一个物理帧
	hiding_changed.emit(true, spot)
	return true


## Steps out of the current spot. With `at`, Ryn comes out there instead (the
## far end of a vent) — crouched, so she never pops up inside a low ceiling;
## the normal crouch rule stands her up next tick if there is room.
##
## Usage: `ryn.exit_hiding()` / `ryn.exit_hiding(other_vent_anchor)`
func exit_hiding(at: Variant = null) -> void:
	if state != State.HIDING:
		return
	var spot: Node2D = hiding_spot
	state = State.NORMAL
	hiding_spot = null
	velocity = Vector2.ZERO
	if at is Vector2:
		global_position = at
		_set_crouching(true)
	_visual.visible = true             # 当帧就出现(守卫拉开柜门的那一刻要看得见她)
	hiding_changed.emit(false, spot)


## True when there is room above to stand up from a crouch. Always true when
## already standing.
func can_stand() -> bool:
	if not is_crouching:
		return true
	var grow: float = config.stand_height - config.crouch_height
	return not test_move(global_transform, Vector2(0.0, -grow))


## 拿来走路的左右输入:瞄准时为 0(左右键在调落点)。
func _walk_x() -> float:
	return 0.0 if aiming else intent.move_x


func _poll_input() -> void:
	intent.move_x = Input.get_axis(&"move_left", &"move_right")
	intent.move_y = Input.get_axis(&"move_up", &"move_down")
	intent.jump_pressed = Input.is_action_just_pressed(&"jump")
	intent.jump_held = Input.is_action_pressed(&"jump")
	intent.sprint = Input.is_action_pressed(&"sprint")
	intent.throw_held = Input.is_action_pressed(&"throw")


func _tick_normal(delta: float) -> void:
	var on_floor: bool = is_on_floor()

	# Coyote time and jump buffer
	if on_floor:
		_coyote_left = config.coyote_time
		_air_jumps_left = config.air_jumps
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)
	if intent.jump_pressed:
		_jump_buffer_left = config.jump_buffer_time
	else:
		_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)

	if absf(_walk_x()) > 0.01:
		facing = 1 if _walk_x() > 0.0 else -1

	if _try_grab_ladder():
		return

	# Jump (a crouch with a low ceiling above cannot jump)
	var jumped: bool = false
	if _jump_buffer_left > 0.0 and _coyote_left > 0.0 and can_stand():
		velocity.y = -config.jump_velocity()
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		jumped = true
	elif intent.jump_pressed and not on_floor and _air_jumps_left > 0 and can_stand() \
			and not _lands_within(config.jump_buffer_time):
		# 二段跳:只认在空中按下的那一次;快落地时按的(跳跃缓冲时间内就会踩到地)留给落地后的普通跳
		velocity.y = -config.air_jump_velocity()
		_air_jumps_left -= 1
		_jump_buffer_left = 0.0
		air_jumped.emit()

	_update_crouch(on_floor and not jumped)

	# Horizontal: ease toward target speed
	# 跑步是叠加档:蹲行不能跑(姿态使然),松开 Shift 立刻回到 walk_speed。
	# 脚下被拖着(蚀粘鞋底)时跑不起来
	var sprinting: bool = intent.sprint and not is_crouching and on_floor and ground_drag >= 1.0
	is_sprinting = sprinting and absf(velocity.x) > config.walk_speed * 0.9
	var max_speed: float = config.crouch_speed if is_crouching else config.walk_speed
	if sprinting:
		max_speed *= config.sprint_multiplier
	if on_floor:
		max_speed *= ground_drag
	var target: float = _walk_x() * max_speed
	var speeding_up: bool = absf(target) > 0.01 \
			and (velocity.x == 0.0 or signf(velocity.x) == signf(target)) \
			and absf(velocity.x) <= absf(target)
	var rate: float = config.acceleration if speeding_up else config.deceleration
	if sprinting and speeding_up:
		rate *= config.sprint_accel_multiplier
	if not on_floor:
		rate *= config.air_control
	velocity.x = move_toward(velocity.x, target, rate * delta)

	# Vertical: gravity with fall boost and jump cut
	var g: float = config.gravity
	if velocity.y > 0.0:
		g *= config.fall_gravity_multiplier
	elif velocity.y < 0.0 and not intent.jump_held:
		g *= config.jump_release_gravity_multiplier
	velocity.y = minf(velocity.y + g * delta, config.max_fall_speed)

	move_and_slide()


## 照现在往下掉的速度,`seconds` 秒内会不会踩到地(往上走时一定是 false)。
func _lands_within(seconds: float) -> bool:
	if velocity.y <= 0.0:
		return false
	return test_move(global_transform, Vector2(velocity.x * seconds, velocity.y * seconds + 2.0))


func _update_crouch(on_floor: bool) -> void:
	var want: bool = intent.move_y > 0.5 and on_floor
	var next: bool = want
	# Keep crouching while there is no room to stand.
	if not want and is_crouching and not can_stand():
		next = true
	if next != is_crouching:
		_set_crouching(next)


func _set_crouching(value: bool) -> void:
	is_crouching = value
	_apply_height(config.crouch_height if value else config.stand_height)


## Resizes the collider, keeping the feet on the origin.
func _apply_height(height: float) -> void:
	_shape.size = Vector2(config.body_width, height)
	_collider.position = Vector2(0.0, -height * 0.5)


func _try_grab_ladder() -> bool:
	if _ladders.is_empty():
		return false
	var up: bool = intent.move_y < -0.5
	var down: bool = intent.move_y > 0.5
	if not (up or down):
		return false
	if not can_stand():
		return false
	var ladder: Ladder = _nearest_ladder()
	var feet_y: float = global_position.y
	# Up needs ladder above the feet; down needs ladder below them. This keeps
	# down = crouch at the ladder foot and up = no-op at the ladder top.
	var can_up: bool = up and feet_y > ladder.top_y() + 2.0
	var can_down: bool = down and feet_y < ladder.bottom_y() - 2.0
	# 从梯子顶往下:要站在梯子上、没按左右 —— 蹲着走过地板上的梯子口不会被吸下去
	if can_down and feet_y <= ladder.top_y() + 2.0 \
			and (absf(intent.move_x) > 0.3 or absf(global_position.x - ladder.center_x()) > LADDER_TOP_GRAB_PX):
		can_down = false
	if not (can_up or can_down):
		return false
	if is_crouching:
		_set_crouching(false)
	state = State.CLIMBING
	_climb_ladder = ladder
	velocity = Vector2.ZERO
	global_position.x = ladder.center_x()
	collision_mask = PhysicsLayers.WORLD
	return true


func _nearest_ladder() -> Ladder:
	var best: Ladder = _ladders[0]
	var best_dist: float = absf(best.center_x() - global_position.x)
	for i in range(1, _ladders.size()):
		var d: float = absf(_ladders[i].center_x() - global_position.x)
		if d < best_dist:
			best = _ladders[i]
			best_dist = d
	return best


func _tick_climbing(delta: float) -> void:
	if _climb_ladder == null or not _ladders.has(_climb_ladder):
		_exit_climb()
		return
	if intent.jump_pressed:
		velocity = Vector2(intent.move_x * config.walk_speed, -config.jump_velocity() * config.ladder_jump_scale)
		if absf(intent.move_x) > 0.01:
			facing = 1 if intent.move_x > 0.0 else -1
		_exit_climb()
		_jump_buffer_left = 0.0
		_air_jumps_left = config.air_jumps   # 从梯子上跳开:空中还能再跳一下
		return
	# 一格一格爬(2026-10-15):停在横档上时,按住上 / 下就开始下一步,走到下一档横档为止;
	# 走到一半松手也会走完这一格。格子对齐梯顶(梯子上下端都在格子线上,横档每 8px 一档)。
	if _step_dir == 0:
		_step_rest -= delta
		var want: int = -1 if intent.move_y < -0.3 else (1 if intent.move_y > 0.3 else 0)
		if want != 0 and _step_rest <= 0.0:
			var g: float = config.climb_step_px
			var rel: float = (global_position.y - _climb_ladder.top_y()) / g
			var k: float = ceilf(rel - 0.001) - 1.0 if want < 0 else floorf(rel + 0.001) + 1.0
			_step_dir = want
			_step_from = global_position.y
			_step_target = _climb_ladder.top_y() + k * g
	velocity = Vector2.ZERO
	if _step_dir != 0:
		var v: float = config.climb_step_speed()
		velocity.y = clampf((_step_target - global_position.y) / maxf(delta, 0.0001), -v, v)
	# 方向在 move_and_slide 之前记下:踩到梯子脚的地面时 move_and_slide 会把向下的速度清零,
	# 用滑完的 velocity 判断就永远下不了梯子(2026-10-11 修)
	var going_up: bool = _step_dir < 0
	var going_down: bool = _step_dir > 0
	var before_y: float = global_position.y
	move_and_slide()
	_climb_distance += global_position.y - before_y
	if _step_dir != 0 and absf(_step_target - global_position.y) < 0.05:
		global_position.y = _step_target
		_step_dir = 0
		_step_rest = config.climb_step_pause
		_climb_steps += 1
	if going_up and global_position.y <= _climb_ladder.top_y():
		global_position.y = _climb_ladder.top_y()
		velocity = Vector2.ZERO
		_exit_climb()
	elif going_down and is_on_floor():
		velocity = Vector2.ZERO
		_exit_climb()


func _tick_hiding(delta: float) -> void:
	velocity = Vector2.ZERO
	_hide_time += delta
	if hiding_spot == null or not is_instance_valid(hiding_spot):
		exit_hiding()
		return
	if absf(intent.move_x) < 0.3:
		_hide_move_armed = true
	if absf(intent.move_x) > 0.5:
		facing = 1 if intent.move_x > 0.0 else -1
	# 跳出来,或者进去之后重新按方向(Mark of the Ninja:动一下就出来)
	if intent.jump_pressed or (_hide_move_armed and absf(intent.move_x) > 0.5):
		_jump_buffer_left = 0.0
		exit_hiding()


func _exit_climb() -> void:
	state = State.NORMAL
	_climb_ladder = null
	_step_dir = 0
	_step_rest = 0.0
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.LADDER_TOP


## 每个物理帧把移动状态交给视觉。之前由关卡里的 `RynStealthVisual` 代传,序章和
## 结局没放那个节点,结果 Ryn 在那两个场景里一直定在同一帧 —— 现在 Ryn 自己传。
func _sync_visual(delta: float = 0.0) -> void:
	# 躲在柜子/通风管里时不画人(柜门缝里的眼睛由 HidingSpot 画)。
	# 每帧按状态设,所以存档点回滚把 state 改回 NORMAL 时人会自己出现。
	_visual.visible = state != State.HIDING
	var climbing: bool = state == State.CLIMBING
	var on_floor: bool = is_on_floor()
	_visual.set_motion(absf(velocity.x) * delta, not on_floor and not climbing,
			velocity.y, velocity.x, delta)
	_visual.update_pose(_shape.size.y, config.body_width, facing, climbing, _climb_distance)
	if _visual.has_method(&"set_climb_step"):
		_visual.call(&"set_climb_step", _climb_steps, _step_dir != 0)
	_visual.set_intent(_walk_x(), _is_looking_up(on_floor), intent.sprint,
			_is_pushing_wall(on_floor), _is_at_edge(on_floor))


## 正往墙里走(Celeste 的 push):在地上、按着方向、贴着那一侧的墙。只给动画用。
func _is_pushing_wall(on_floor: bool) -> bool:
	if not on_floor or state != State.NORMAL or absf(_walk_x()) < 0.5 or not is_on_wall():
		return false
	return get_wall_normal().x * _walk_x() < -0.5


## 脚下一半已经悬空(Celeste 的 edge):碰撞体往朝向挪 `EDGE_PROBE_PX` 后脚下没有地面。
## 只在站定时测,只给动画用。
func _is_at_edge(on_floor: bool) -> bool:
	if not on_floor or state != State.NORMAL or is_crouching or absf(velocity.x) > 1.0:
		return false
	var ahead := global_transform.translated(Vector2(float(facing) * EDGE_PROBE_PX, 0.0))
	return not test_move(ahead, Vector2(0.0, 2.0))


## 按着上、身边没有梯子:抬头看(Celeste 的 lookUp)。只给动画用。
func _is_looking_up(on_floor: bool) -> bool:
	return on_floor and state == State.NORMAL and not is_crouching \
			and intent.move_y < -0.5 and _ladders.is_empty()


func _on_sensor_area_entered(area: Area2D) -> void:
	var ladder := area as Ladder
	if ladder != null and not _ladders.has(ladder):
		_ladders.append(ladder)


func _on_sensor_area_exited(area: Area2D) -> void:
	var ladder := area as Ladder
	if ladder != null:
		_ladders.erase(ladder)
