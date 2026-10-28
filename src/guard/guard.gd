class_name Guard
extends CharacterBody2D
## A patrolling guard with a three-state vision cone.
##
## Implements `production/epics/the-cradle/story-002-guard-vision-cone.md`.
## Origin is at the FEET, matching Ryn. All tuning comes from `config`
## (a GuardConfig resource); the patrol route is scene layout, so it lives on
## the node (`patrol_offset`, `initial_facing`) rather than in the config.
##
## Thread safety: main thread only (it is a scene node).
##
## State machine — these are the ONLY transitions that exist:
##
##     from        | event                                | to
##     ------------|--------------------------------------|------------
##     PATROL      | a target passes can_see()            | SPOTTED
##     PATROL      | report_disturbance()                 | SUSPICIOUS
##     SUSPICIOUS  | a target passes can_see()            | SPOTTED
##     SUSPICIOUS  | elapsed >= config.suspicion_duration | PATROL
##     SPOTTED     | nothing visible this tick            | SUSPICIOUS
##
## SUSPICIOUS always decays on a timer, so the guard can never stick in it.
## The three states are the same behaviour with a different cone — not three
## AIs. There is no chasing and no combat: entering SPOTTED emits
## `player_spotted` and stops, and Story 003 owns everything after that.
##
## Line of sight is confirmed with ONE raycast per overlapping body, run inside
## `_physics_process` because the 2D space state is locked outside it
## (`docs/engine-reference/godot/modules/physics-2d.md`).
##
## Usage:
##     var guard: Guard = preload("res://src/guard/guard.tscn").instantiate()
##     guard.config = load("res://assets/data/guard_default.tres")
##     guard.patrol_offset = 260.0          # patrols spawn_x .. spawn_x + 260
##     guard.player_spotted.connect(_on_spotted)
##     add_child(guard)
##     # Story 004 hook: veto sightings while the target stands in darkness.
##     guard.darkness_veto = func(p: Vector2) -> bool: return shadows.covers(p)

## 怎么发现人(2026-10-13 三种守卫,`design/ideas-backlog.md` G1–G3):
##   - SIGHT     「看」:视野锥,暗处看不见(原来的守卫,军帽制服兵)
##   - HEARING   「听」:头盔封住眼睛,**没有视野锥**;听到声音走过去,到了声源 Ryn 还在旁边、或者撞到 Ryn 才算发现
##               (面罩头盔兵)。暗处挡不住他 —— 要蹲着、安静地走开
##   - TRACKING  「追」:视野锥短(近视);蚀侦测器读得到 Ryn 走过留下的痕迹,踩到就顺着追(防毒面具兵)
## 「听」和「追」的那部分在 `GuardSenses`(本节点 `_ready` 时自动挂上),这里只管「听」的看不见、「追」的近视。
enum Sense { SIGHT, HEARING, TRACKING }

enum State {
	## Walking the route, scanning with the wide cold-cyan cone.
	PATROL,
	## Alerted but with nothing in sight: cone narrows and turns warm. Decays.
	SUSPICIOUS,
	## A target is visible: cone turns red and flashes rust-red.
	SPOTTED,
}

## Emitted once each time the guard goes from not-seeing to seeing a target.
## Story 003 consumes this; nothing else reacts here by design.
signal player_spotted(player: Node2D, guard: Guard)
## 巡逻走到端点、刚掉过头。`new_facing` 是掉头后的朝向。`GuardBehaviour` 听它开始扫视。
signal patrol_turned(new_facing: int)

## Tuning. Required.
@export var config: GuardConfig
## Signed horizontal distance from the spawn point to the far end of the patrol
## route, px. 0 makes the guard a stationary watcher.
@export var patrol_offset: float = 0.0
## Facing at spawn: -1 (left) or 1 (right).
@export var initial_facing: int = 1
## 怎么发现人,见 `Sense`。
@export var sense: Sense = Sense.SIGHT

## Facing direction, -1 (left) or 1 (right). The cone turns with it.
var facing: int = 1
## Current state. Change it through `report_disturbance()`, not by assignment.
var state: State = State.PATROL
## Optional veto, `func(target_global: Vector2) -> bool`. Story 004 sets this to
## "the target is standing in darkness"; unset means nothing is hidden.
var darkness_veto: Callable = Callable()
## 低头看地上的东西(`GuardPursuit` 查看扣件时设):视线往下压 `config.gaze_down_deg`、
## 锥缩成 `config.gaze_down_range` —— 只看得到脚前。发现状态下不算(抓到人时一定是抬头的)。
var gaze_down: bool = false

## 「追」的守卫视野锥只有普通的这么长。
const TRACKING_SIGHT_SCALE: float = 0.6

var _shape: RectangleShape2D
var _min_x: float = 0.0
var _max_x: float = 0.0
var _wait_left: float = 0.0
var _state_time: float = 0.0
var _visible_target: Node2D
# Both allocated once: a per-frame raycast must not allocate.
var _ray_query: PhysicsRayQueryParameters2D
var _occlusion: Callable

@onready var _cone: VisionCone = $VisionCone
@onready var _collider: CollisionShape2D = $CollisionShape2D
@onready var _visual: GuardPlaceholderVisual = $Visual


func _ready() -> void:
	assert(config != null, "Guard.config must be set")
	facing = -1 if initial_facing < 0 else 1
	# Layer 0: nothing detects the guard body yet (no combat, and Ryn must not
	# bump into it). Mask WORLD: the guard still stands on floors.
	collision_layer = 0
	collision_mask = PhysicsLayers.WORLD
	_shape = RectangleShape2D.new()
	_shape.size = Vector2(config.body_width, config.body_height)
	_collider.shape = _shape
	_collider.position = Vector2(0.0, -config.body_height * 0.5)
	_min_x = minf(global_position.x, global_position.x + patrol_offset)
	_max_x = maxf(global_position.x, global_position.x + patrol_offset)
	_ray_query = PhysicsRayQueryParameters2D.create(global_position, global_position)
	_ray_query.collision_mask = PhysicsLayers.WORLD
	_ray_query.collide_with_bodies = true
	_ray_query.collide_with_areas = false
	# `exclude` is Array[RID], NOT Array[Object] — the official 4.6 example
	# prints `[self]` and is wrong. See modules/physics-2d.md ("CORRECTION").
	_ray_query.exclude = [get_rid()]
	_occlusion = _is_occluded
	_cone.position = Vector2(0.0, -config.eye_height)
	_cone.set_segments(config.cone_segments)
	if sense == Sense.TRACKING:
		# 近视:锥短一截。每个守卫一份配置,别改到共用的 .tres(`GuardBehaviour` 之后会在这个基础上再乘 range_scale)
		config = config.duplicate()
		config.cone_range *= TRACKING_SIGHT_SCALE
		config.suspicious_cone_range *= TRACKING_SIGHT_SCALE
	if sense != Sense.SIGHT:
		var senses := GuardSenses.new()
		senses.name = "Senses"
		add_child(senses)
	_sync_visuals()


func _physics_process(delta: float) -> void:
	if config == null:
		return
	_state_time += delta
	_update_detection()
	match state:
		State.PATROL:
			_tick_patrol(delta)
		State.SUSPICIOUS:
			_tick_suspicious()
		State.SPOTTED:
			_tick_spotted()
	velocity.y = minf(velocity.y + config.gravity * delta, config.max_fall_speed)
	move_and_slide()
	_sync_visuals()


## 巡逻原地停 `seconds` 秒(朝向不变;已经在停就取较长的)。停着的时候 `_tick_patrol`
## 不碰 `facing`,所以行为层可以在这段时间里自己转头。
##
## 2026-10-11:行为层原来靠「把 velocity 清零」来停,但它在守卫之后才跑,清零被下一帧的
## `_tick_patrol` 覆盖,驻足从没生效;扫视型把自己的转头当成「刚到端点」,永远停在端点左右摆。
##
## Usage: `guard.hold_patrol(1.6)`
func hold_patrol(seconds: float) -> void:
	_wait_left = maxf(_wait_left, seconds)


## 提前结束 `hold_patrol` 的停顿,马上接着巡逻(`GuardChat` 聊完放人用)。
##
## Usage: `guard.release_hold()`
func release_hold() -> void:
	_wait_left = 0.0


## World position every sight ray starts from (the eye, above the feet).
##
## Usage: `var eye := guard.eye_position()`
func eye_position() -> Vector2:
	if config == null:
		return global_position
	return global_position + Vector2(0.0, -_eye_height())


## 眼睛离脚底多高:站着 `config.eye_height`,蹲下低头看东西时低 `config.gaze_down_eye_drop`。
func _eye_height() -> float:
	return config.eye_height - (config.gaze_down_eye_drop if _gaze_pitch() > 0.0 else 0.0)


## The single point on `body` that sight rays are aimed at: its mid-body.
## Bodies exposing `get_body_height()` (Ryn does) are measured; anything else is
## aimed at its origin.
##
## Usage: `guard.can_see(guard.sight_point(ryn))`
func sight_point(body: Node2D) -> Vector2:
	if body == null:
		return Vector2.ZERO
	if body.has_method(&"get_body_height"):
		var height: float = float(body.call(&"get_body_height"))
		return body.global_position + Vector2(0.0, -height * 0.5)
	return body.global_position


## True when `target_global` is visible right now: inside the current cone, not
## occluded by WORLD geometry, and not vetoed by `darkness_veto`.
##
## MUST be called from a physics callback — it queries the 2D space state, which
## is locked outside `_physics_process`.
##
## Usage: `if guard.can_see(guard.sight_point(ryn)): ...`
func can_see(target_global: Vector2) -> bool:
	if config == null:
		return false
	return GuardVision.can_see(eye_position(), target_global,
			gaze_direction(), current_half_angle(), current_range(),
			_occlusion, darkness_veto)


## 视线方向(单位向量):平视是 (facing, 0);低头时往下压 `config.gaze_down_deg`。
func gaze_direction() -> Vector2:
	var pitch: float = _gaze_pitch()
	return Vector2(float(facing) * cos(pitch), sin(pitch))


func _gaze_pitch() -> float:
	if config == null or not gaze_down or state == State.SPOTTED:
		return 0.0
	return deg_to_rad(config.gaze_down_deg)


## Cone half-angle in radians for the current state.
func current_half_angle() -> float:
	if config == null:
		return 0.0
	if _gaze_pitch() > 0.0:
		return deg_to_rad(config.gaze_down_half_angle_deg)
	if state == State.SUSPICIOUS:
		return config.suspicious_cone_half_angle_rad()
	return config.cone_half_angle_rad()


## Cone reach in px for the current state.
func current_range() -> float:
	if config == null:
		return 0.0
	if _gaze_pitch() > 0.0:
		return config.gaze_down_range
	if state == State.SUSPICIOUS:
		return config.suspicious_cone_range
	return config.cone_range


## Spots `target` directly, without a sight check — a guard who opens a locker
## and finds Ryn inside. Same path as a real sighting: SPOTTED, `player_spotted`,
## and the reset system takes it from there.
##
## Usage: `guard.spot(ryn)`
func spot(target: Node2D) -> void:
	if target == null or state == State.SPOTTED:
		return
	_enter_spotted(target)


## Puts the guard on alert without a sighting — the hook for Story 005's
## dismantling noise. Ignored while already SPOTTED. Decays back to PATROL
## `config.suspicion_duration` after the LAST report.
##
## 2026-10-12:已经在起疑时要重新计时。`GuardPursuit` 搜查途中每帧都调这里,本意是「别让 SUSPICIOUS
## 在半路超时」,但 `_set_state` 遇到同一个状态直接返回、不清计时 —— 结果每次查声音都在 2.5 秒后放弃,
## 常常走到一半就回头(谜题房里吊桥砸下来,守卫走到桥头就掉头了才发现)。
##
## Usage: `guard.report_disturbance()`
func report_disturbance() -> void:
	if state == State.SPOTTED:
		return
	if state == State.SUSPICIOUS:
		_state_time = 0.0
		return
	_set_state(State.SUSPICIOUS)


func _update_detection() -> void:
	_visible_target = null
	if sense == Sense.HEARING:
		return   # 看不见:碰到 / 在声源旁边才算发现,见 `GuardSenses`
	var targets: Array[Node2D] = _cone.overlapping_targets()
	for body in targets:
		if body == null or not is_instance_valid(body):
			continue
		# 躲在柜子/通风管里的看不见(`Ryn.is_detectable()`)
		if body.has_method(&"is_detectable") and not bool(body.call(&"is_detectable")):
			continue
		if can_see(sight_point(body)):
			_visible_target = body
			return


func _is_occluded(from: Vector2, to: Vector2) -> bool:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space_state == null:
		return false
	_ray_query.from = from
	_ray_query.to = to
	return not space_state.intersect_ray(_ray_query).is_empty()


func _tick_patrol(delta: float) -> void:
	if _visible_target != null:
		_enter_spotted(_visible_target)
		return
	velocity.x = 0.0
	if is_zero_approx(patrol_offset) or not is_on_floor():
		return
	if _wait_left > 0.0:
		_wait_left -= delta
		return
	var goal: float = _max_x if facing > 0 else _min_x
	var to_goal: float = goal - global_position.x
	if absf(to_goal) <= config.patrol_arrive_tolerance:
		global_position.x = goal
		facing = -facing
		_wait_left = config.patrol_wait_time
		patrol_turned.emit(facing)
		return
	velocity.x = signf(to_goal) * config.patrol_speed


func _tick_suspicious() -> void:
	velocity.x = 0.0
	if _visible_target != null:
		_enter_spotted(_visible_target)
		return
	if _state_time >= config.suspicion_duration:
		_set_state(State.PATROL)
		_wait_left = config.patrol_wait_time


func _tick_spotted() -> void:
	# No chase, no attack: out of scope for this story on purpose.
	velocity.x = 0.0
	if _visible_target == null:
		_set_state(State.SUSPICIOUS)


func _enter_spotted(target: Node2D) -> void:
	_set_state(State.SPOTTED)
	velocity.x = 0.0
	player_spotted.emit(target, self)


func _set_state(next: State) -> void:
	if next == state:
		return
	state = next
	_state_time = 0.0


func _sync_visuals() -> void:
	if config == null:
		return
	var fill: Color = config.patrol_cone_color
	var alpha: float = config.cone_alpha
	var flash_lit: bool = false
	match state:
		State.SUSPICIOUS:
			fill = config.suspicious_cone_color
			alpha = config.suspicious_cone_alpha
		State.SPOTTED:
			flash_lit = _flash_lit()
			fill = config.flash_color if flash_lit else config.spotted_cone_color
			alpha = config.spotted_cone_alpha
	_cone.position = Vector2(0.0, -_eye_height())
	_cone.set_facing(facing, _gaze_pitch())
	_cone.visible = sense != Sense.HEARING
	_cone.apply(current_half_angle(), current_range(),
			Color(fill.r, fill.g, fill.b, alpha))
	var body_fill: Color = config.alert_body_color if flash_lit else config.body_color
	_visual.update_pose(config.body_height, config.body_width, facing,
			body_fill, config.rim_color)
	_visual.set_alert(state, _state_time)


## True on the lit half of the spotted flash's square wave.
func _flash_lit() -> bool:
	var period: float = maxf(config.spotted_flash_period, 0.001)
	return fposmod(_state_time, period * 2.0) < period
