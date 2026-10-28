class_name GuardBehaviour
extends Node
## 巡逻样式。之前所有守卫都是同一种:匀速直线来回,玩家看一眼就学会了,
## 整座塔的守卫毫无区别。
##
## 这个适配器给守卫叠加行为层:端点停顿时左右扫视、随机驻足观察、哨兵原地转身、
## 按类型调整速度与视野。它只用 `Guard` 的公开接口:`hold_patrol()` 让巡逻停下、
## `patrol_turned` 告诉它走到端点了、`facing` 转头。
##
## ## 2026-10-11 修过的三个 bug(用户:「巡逻站在原地左右摆动,完全过不去」)
##  - 扫视型把**自己的转头**当成「刚到端点」,每转一次就重新开始扫视 —— 永远停在端点左右摆。
##    现在只听 `patrol_turned`(真的走到端点才发)。
##  - 驻足、扫视原来靠「把 velocity 清零」来停,可本节点在守卫**之后**才跑,清零被下一帧的
##    `_tick_patrol` 覆盖 —— 驻足从没生效。现在用 `hold_patrol()`。
##  - 哨兵不管有没有巡逻范围都每 1.75 秒转身:有范围的边走边转、转了就往回走,在原地来回抖;
##    没范围的转得太快,来不及从背后溜过去。现在:没范围的每个方向站 `sentry_hold` 秒;
##    有范围的照常走,到端点多站 `sentry_hold` 秒。
##
## ## 职责边界
##
## 这里只管 **常态巡逻怎么走、怎么看**。听觉与追击在 `guard_pursuit.gd`,
## 两者互不干涉:守卫一旦离开 PATROL,本脚本就交还控制权。
##
## Usage (in a scene):
##     [node name="Behaviour" type="Node" parent="Guard"]
##     style = 1   # SCANNER

## 巡逻样式。
enum Style {
	## 原样:匀速来回。适合教学段,让玩家先学会基本规律。
	STEADY,
	## 扫视型:到端点会原地左右转头数次再折返。等背身的窗口更短。
	SCANNER,
	## 驻足型:路上会随机停下观察一会儿,节奏不可预测。
	LOITERER,
	## 哨兵:几乎不移动,原地缓慢转向。守死路口用。
	SENTRY,
}

@export var style: Style = Style.STEADY
## 速度倍率,叠在 `GuardConfig.patrol_speed` 上。
@export var speed_scale: float = 1.0
## 视野锥距离倍率。塔4 的警戒兵可以调大。
@export var range_scale: float = 1.0
## SCANNER:端点转头次数。
@export var scan_turns: int = 2
## SCANNER:每次转头的停留,秒。
@export var scan_hold: float = 0.7
## LOITERER:平均多少秒驻足一次。
@export var loiter_interval: float = 4.5
## LOITERER:每次驻足多久,秒。
@export var loiter_hold: float = 1.6
## SENTRY:每个方向站多久,秒。要够玩家从他背后走出视野(170px,走路约 1.7 秒)再留余量。
@export var sentry_hold: float = 3.5

var _guard: Guard
var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _hold_left: float = 0.0
var _scans_left: int = 0
var _base_speed: float = 0.0
var _base_range: float = 0.0
var _visual: GuardPlaceholderVisual
var _suspend_left: float = 0.0


func _ready() -> void:
	_guard = get_parent() as Guard
	if _guard == null:
		push_warning("GuardBehaviour must be a child of a Guard")
		set_physics_process(false)
		return
	_rng.seed = int(_guard.global_position.x) * 7919 + int(style)
	await get_tree().process_frame
	if _guard.config == null:
		return
	_base_speed = _guard.config.patrol_speed
	_base_range = _guard.config.cone_range
	# 每个守卫一份独立配置,否则改一个会改到所有共享同一 .tres 的守卫。
	var cfg: GuardConfig = _guard.config.duplicate()
	cfg.patrol_speed = _base_speed * speed_scale
	cfg.cone_range = _base_range * range_scale
	_guard.config = cfg
	_guard.patrol_turned.connect(_on_patrol_turned)
	_timer = _rng.randf_range(0.0, loiter_interval) if style == Style.LOITERER else sentry_hold


func _physics_process(delta: float) -> void:
	if _guard == null or _guard.config == null:
		return
	# 驱动走路动画 —— 之前守卫是静止色块在滑,和 Ryn 不对等,很突兀。
	# 相位按走过的距离推进,所以停下腿就停。
	if _visual == null:
		_visual = _guard.get_node_or_null(^"Visual") as GuardPlaceholderVisual
	if _visual != null:
		_visual.set_walk(absf(_guard.velocity.x) * delta)
	# 被发现/起疑时交还控制权 —— 行为层只管常态巡逻。
	if _guard.state != Guard.State.PATROL:
		_scans_left = 0
		return
	# 别人接管着(`GuardChat` 让两个守卫停下来聊天):不转头、不驻足
	if _suspend_left > 0.0:
		_suspend_left -= delta
		return
	match style:
		Style.SCANNER:
			_tick_scan(delta)
		Style.LOITERER:
			_tick_loiterer(delta)
		Style.SENTRY:
			if _is_post():
				_tick_sentry(delta)


## 让行为层歇 `seconds` 秒(不转头、不驻足、不扫视),外面的人接管朝向。`seconds` ≤ 0 = 马上恢复。
## `GuardChat` 用:两个守卫面对面聊天时不能自己转身。
##
## Usage: `behaviour.suspend(30.0)` … `behaviour.suspend(0.0)`
func suspend(seconds: float) -> void:
	_suspend_left = maxf(seconds, 0.0)
	_scans_left = 0


## 走到端点掉头了:扫视型原地左右看几次再走;有巡逻范围的哨兵多站一会儿。
func _on_patrol_turned(_new_facing: int) -> void:
	if _guard.state != Guard.State.PATROL or _suspend_left > 0.0:
		return
	match style:
		Style.SCANNER:
			# 转偶数次,最后还是朝掉头后的方向,停完接着往回走
			_scans_left = scan_turns * 2
			_hold_left = scan_hold
			_guard.hold_patrol(_scans_left * scan_hold + 0.05)
		Style.SENTRY:
			_guard.hold_patrol(sentry_hold)


## 扫视:停着的这段时间里每 `scan_hold` 秒转一次头。
func _tick_scan(delta: float) -> void:
	if _scans_left <= 0:
		return
	_hold_left -= delta
	if _hold_left <= 0.0:
		_guard.facing = -_guard.facing
		_scans_left -= 1
		_hold_left = scan_hold


## 路上随机驻足,让节奏不可预测 —— 玩家不能只靠数拍子。
func _tick_loiterer(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		var hold: float = loiter_hold * _rng.randf_range(0.7, 1.3)
		_guard.hold_patrol(hold)
		_timer = hold + loiter_interval * _rng.randf_range(0.7, 1.3)


## 原地站岗的哨兵(没有巡逻范围):每个方向站 `sentry_hold` 秒再转身。
func _tick_sentry(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_guard.facing = -_guard.facing
		_timer = sentry_hold


## 没有巡逻范围 = 原地站岗。
func _is_post() -> bool:
	return is_zero_approx(_guard.patrol_offset)
