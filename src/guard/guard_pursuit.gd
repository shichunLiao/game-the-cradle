class_name GuardPursuit
extends Node
## 守卫的 **搜查** 与 **追击**。挂在 Guard 下,`guard.gd` 一行不改 ——
## 它通过接管 `velocity` 和 `facing` 实现,与 `GuardBehaviour` 同一套路。
##
## ## 追击默认关闭 —— 它与原设定互斥
##
## `设定摘要.md` 锁定的是「被发现:『不行,这样会被发现。』**关卡重置**」—— 看见即结束。
## 追击要成立就必须让"看见"不再立刻重置,两者无法共存。2026-10-04 试开过一轮,
## 实际玩起来变成"走进视野锥没反应、必须撞到守卫才重开",与设定不符,遂改回。
##
##     chase_enabled = false (默认) : 看见 → 立即重置        ← 原设定
##     chase_enabled = true         : 看见 → 追 → 追上才重置
##
## **听觉搜查不受这个开关影响**:`_on_noise` 不检查 `chase_enabled`,所以守卫听到
## 声音照样走过去查看。听觉的价值本来就在"把守卫引过来",不在"追着你跑"。
##
## ## 搜查必须与 SUSPICIOUS 状态同步
##
## `Guard` 自己会在 `suspicion_duration`(2.5s) 后把状态拨回 PATROL,而本节点的
## `search_timeout` 是 7s。中间那几秒里 `_tick_patrol`(走向巡逻点)、
## `GuardBehaviour`(扫视/驻足) 和 `_tick_search`(走向声源) 会同时写 `velocity`,
## 守卫就乱了(2026-10-04 发现)。
##
## 解法是两头收紧:
##   1. 搜查进行中 **持续刷新** `report_disturbance()`,让 SUSPICIOUS 不超时
##   2. 一旦 `state` 真的回到 PATROL,立刻退出搜查交还控制权
## 搜查结束后停止刷新,守卫自然冷却回 PATROL,`_tick_patrol` 会把它带回巡逻区间
## (它朝区间外时 `to_goal` 反号,会自己走回来)。
##
## ## 为什么这里要自己调 move_and_slide()
##
## `Guard._physics_process` 在 SUSPICIOUS 时执行 `_tick_suspicious()`,第一行就是
## `velocity.x = 0.0`,然后 **同一帧** 调用 `move_and_slide()`。本节点是 Guard 的
## 子节点,在那之后才跑 —— 设的速度要等下一帧,而下一帧又被清零。结果是搜查
## 一步都走不出去(2026-10-04 发现)。
##
## 所以设完速度后自己再 `move_and_slide()` 一次:Guard 那次是以 0 速度走的,
## 等于没动,这一次才是真正的位移。不改 `guard.gd` 的前提下这是最干净的接管点。
##
## ## 听觉
##
## 连 `Noise.noise_made`。听到范围内的声音就走过去查看 —— **听觉只会让守卫
## 移动和提高警觉,永远不会直接判定发现**。看见仍然只能靠视野锥。
## 这条界线是刻意的:声音把守卫引过来,眼睛才抓人。

## ## 扣件:走过去、低头看、捡起来(2026-10-14)
##
## 用户试玩:守卫走到落点原地左右转两下(2.2 秒、每 1.1 秒转一次身)就走,「没有安全感,
## 螺母用处不大」。改成《杀手》系列丢硬币那样:听到扣件落地 → 快步走到扣件前 → 蹲下低头看
## `bolt_inspect_time` 秒(视线压低、锥缩到只看得见脚前,`Guard.gaze_down`)→ 捡起来(扣件没了)→
## 站起来慢慢张望 `bolt_look_time` 秒、只转一次身 → 回去巡逻。低头的时候走路的小声音听不见,
## 跑步、落地、拆东西还是会把他叫起来。扣件被认领后不会自己消失(`ThrownBolt.claim`)。
## 别的声音(落地、拆东西)照旧:走到声源,站着看一会儿,中途只转一次身 —— 不再原地打转。

signal player_caught(player: Node2D, guard: Guard)

enum Mode { IDLE, SEARCHING, CHASING }
## 查看扣件的阶段:没在看 / 蹲着低头看 / 起身张望。
enum Inspect { NONE, CROUCH, LOOK }
## 地上躺着的扣件所在的组(= `ThrownBolt.GROUP`)。
const BOLT_GROUP: StringName = &"thrown_bolt"

## 默认 false —— 看见即重置(原设定)。开启则改为追上才重置,二者互斥。
@export var chase_enabled: bool = false
## 追击移动速度倍率(相对巡逻速度)。
@export var chase_speed_scale: float = 1.75
## 搜查(走向声源)速度倍率。听到动静是 **快步赶过去**,不是散步 ——
## 低于 1.5 时玩家根本察觉不到守卫在反应。
@export var search_speed_scale: float = 1.9
## 判定「追上」的水平距离,px。
@export var catch_distance: float = 14.0
## 脱离视野后还要追多久才放弃,秒。
@export var lose_sight_grace: float = 1.8
## 到达声源后原地搜查多久,秒。
@export var search_hold: float = 2.2
## 搜查状态持续上限,秒。超时回巡逻。
@export var search_timeout: float = 7.0
## 听力倍率。哨兵可调高。
@export var hearing_scale: float = 1.0
@export_group("Lockers")
## 声源离柜子多近,守卫就会去查那个柜子,px(柜子中线到声源的水平距离)。
@export var locker_check_radius: float = 20.0
## 站在柜子前多久才拉开柜门,秒。给玩家一个「他要开了」的时间。
@export var locker_check_time: float = 1.1
## 查柜子时站在柜门前多远,px。
@export var locker_stand_off: float = 10.0
@export_group("Bolts")
## 走到扣件前多远停下来低头看,px。
@export var bolt_stand_off: float = 12.0
## 蹲着低头看多久,秒(最后捡起来)。
@export var bolt_inspect_time: float = 4.0
## 捡起来以后站起身、慢慢张望多久,秒(中间只转一次身)。
@export var bolt_look_time: float = 2.0
## 低头看的时候,半径比这小的声音听不见(走路 70 听不见;落地 130、拆东西 220 听得见),px。
@export var bolt_focus_ignore_below: float = 100.0
## 落地声和扣件离多近算「这声音是这颗扣件」,px。
@export var bolt_match_radius: float = 6.0
@export_group("Edges")
## 搜查时往前看多远有没有地面,px。前面没地就停在边上张望,不走下去。
## 2026-10-11 加:丢扣件以后,声音常常在下一层或坑对面,守卫不能为了查声音掉下楼。
@export var edge_probe_ahead: float = 9.0

var _guard: Guard
var _mode: int = Mode.IDLE
var _target: Node2D
var _goal_x: float = 0.0
var _lost_for: float = 0.0
var _mode_time: float = 0.0
var _hold_left: float = 0.0
## 这次搜查要查的柜子(声源就在柜子旁边时);null = 普通搜查。
var _locker: HidingSpot
## `go_check` 给的停留时间;< 0 = 用 `search_hold`。
var _hold_override: float = -1.0
## `go_check` 给的搜查时限(要走很远时比 `search_timeout` 长);< 0 = 用 `search_timeout`。
var _timeout_override: float = -1.0
var _checking_left: float = 0.0
## 这次搜查要去看的扣件(`ThrownBolt`,声音就是它落地的那一声);null = 普通搜查。
## 按组名找、用 call() 调,不写 `ThrownBolt` 类型:它用到 `Audio`,`-s` 检查脚本里一路编译过去会失败
## (和 TraceTrail 同一个坑)。
var _bolt: Node2D
var _inspect: int = Inspect.NONE
var _inspect_left: float = 0.0
var _look_turned: bool = false
## 普通搜查这一轮站多久(只在一半的时候转一次身)。
var _hold_total: float = 0.0


func _ready() -> void:
	_guard = get_parent() as Guard
	if _guard == null:
		push_warning("GuardPursuit must be a child of a Guard")
		set_physics_process(false)
		return
	_guard.player_spotted.connect(_on_spotted)
	# 走 /root 路径:autoload 名在静态分析时被当成类名,直接 `Noise.connect(...)`
	# 会被判成"在类上调用非静态方法"。节点路径是动态的,不受此限。
	var bus := get_node_or_null(^"/root/Noise")
	if bus != null:
		bus.connect(&"noise_made", _on_noise)


## 当前模式,给调试与音效用。
func mode() -> int:
	return _mode


func _on_spotted(player: Node2D, _by: Guard) -> void:
	if not chase_enabled:
		return
	_target = player
	_set_mode(Mode.CHASING)


## 听到声音 —— 只引导移动,不判定发现。
func _on_noise(at: Vector2, radius: float) -> void:
	if _guard == null or _mode == Mode.CHASING:
		return
	if _guard.state == Guard.State.SPOTTED:
		return
	if _guard.global_position.distance_to(at) > radius * hearing_scale:
		return
	# 正蹲着看扣件:走路那种小声音听不见
	if _inspect == Inspect.CROUCH and radius < bolt_focus_ignore_below:
		return
	_goal_x = at.x
	_set_mode(Mode.SEARCHING)
	# 声音就在柜子旁边(关柜门那一声、或者脚步停在柜子前):去查那个柜子
	_locker = _locker_near(at)
	if _locker != null:
		var side: float = signf(_guard.global_position.x - _locker.anchor().x)
		if side == 0.0:
			side = 1.0
		_goal_x = _locker.anchor().x + side * (_locker.size.x * 0.5 + locker_stand_off)
		_checking_left = locker_check_time
	else:
		# 扣件落地的那一声:走到它前面停下,等会儿低头看、捡起来。认领了它就不会先消失。
		var bolt: Node2D = _bolt_at(at)
		if bolt != null and bool(bolt.call(&"claim", _guard)):
			_bolt = bolt
			var dir: float = signf(at.x - _guard.global_position.x)
			if dir == 0.0:
				dir = float(_guard.facing)
			_goal_x = at.x - dir * bolt_stand_off
			var speed: float = maxf(_guard.config.patrol_speed * search_speed_scale, 1.0)
			_timeout_override = absf(_goal_x - _guard.global_position.x) / speed \
					+ bolt_inspect_time + bolt_look_time + 3.0
	_guard.report_disturbance()


## 叫这个守卫走到 `at` 那里停 `hold` 秒(比如配电箱断电,技工去电闸那里修)。和听到声音一样走过去,
## 只是不看听不听得到,停得久一点;走不到(前面没地)就在边上停。
##
## Usage: `pursuit.go_check(breaker_pos, 3.5)`
func go_check(at: Vector2, hold: float) -> void:
	if _guard == null or _guard.state == Guard.State.SPOTTED or _mode == Mode.CHASING:
		return
	_set_mode(Mode.SEARCHING)
	_goal_x = at.x
	_locker = null
	_hold_override = hold
	var speed: float = maxf(_guard.config.patrol_speed * search_speed_scale, 1.0)
	_timeout_override = absf(at.x - _guard.global_position.x) / speed + hold + 3.0
	_guard.report_disturbance()


## 跟着蚀痕走(「追」的守卫,`GuardSenses` 每到一个痕迹点就给下一个)。不超时:痕迹还在就一直追。
## `last` = 痕迹到头了:走到那里停下来查看,旁边有柜子就拉开。
##
## Usage: `pursuit.follow(next_point, false)`
func follow(at: Vector2, last: bool) -> void:
	if _guard == null or _guard.state == Guard.State.SPOTTED or _mode == Mode.CHASING:
		return
	if _inspect == Inspect.CROUCH:
		return   # 正低头看扣件:痕迹等他起来再说
	if _mode != Mode.SEARCHING:
		_set_mode(Mode.SEARCHING)
	_mode_time = 0.0
	_goal_x = at.x
	_hold_left = 0.0
	_hold_override = -1.0
	_locker = _locker_near(at) if last else null
	if _locker != null:
		var side: float = signf(_guard.global_position.x - _locker.anchor().x)
		if side == 0.0:
			side = 1.0
		_goal_x = _locker.anchor().x + side * (_locker.size.x * 0.5 + locker_stand_off)
		_checking_left = locker_check_time
	_guard.report_disturbance()


## 还在搜查 / 跟痕迹吗(到了地方、看完一圈就是 false)。
func is_searching() -> bool:
	return _mode == Mode.SEARCHING


## 查看扣件到哪一步了(`Inspect`)。验证脚本、动画用。
func inspect_phase() -> int:
	return _inspect


func _set_mode(m: int) -> void:
	_mode = m
	_mode_time = 0.0
	_lost_for = 0.0
	_hold_left = 0.0
	_hold_override = -1.0
	_timeout_override = -1.0
	_hold_total = 0.0
	_end_inspect()
	if m != Mode.SEARCHING:
		_locker = null


## 不看扣件了(看完、被别的事打断):抬头、松开认领、动画回一般。
func _end_inspect() -> void:
	if _bolt != null and is_instance_valid(_bolt):
		_bolt.call(&"release", _guard)
	_bolt = null
	_inspect = Inspect.NONE
	_inspect_left = 0.0
	if _guard != null:
		_guard.gaze_down = false
	_set_inspect_pose(0)


## 守卫身上的动画:0 一般、1 蹲着看、2 伸手捡、3 站起来拿着看。没有这个接口的造型(方块)就不管。
func _set_inspect_pose(pose: int) -> void:
	if _guard == null:
		return
	var visual := _guard.get_node_or_null(^"Visual")
	if visual != null and visual.has_method(&"set_inspect"):
		visual.call(&"set_inspect", pose)


## 落点 `at` 上那颗刚落地的扣件。
func _bolt_at(at: Vector2) -> Node2D:
	for node in get_tree().get_nodes_in_group(BOLT_GROUP):
		var bolt := node as Node2D
		if bolt != null and bool(bolt.call(&"has_landed")) and bolt.global_position.distance_to(at) <= bolt_match_radius:
			return bolt
	return null


## 离声源 `locker_check_radius` 以内、和守卫在同一层地面上的柜子(通风管不算)。
func _locker_near(at: Vector2) -> HidingSpot:
	for node in get_tree().get_nodes_in_group(HidingSpot.GROUP):
		var spot := node as HidingSpot
		if spot == null or spot.kind != HidingSpot.Kind.LOCKER:
			continue
		var a: Vector2 = spot.anchor()
		if absf(a.x - at.x) <= locker_check_radius + spot.size.x * 0.5 \
				and absf(a.y - _guard.global_position.y) < 8.0:
			return spot
	return null


## 朝 `dir` 往前 `edge_probe_ahead` 处,脚下有没有地面。
func _floor_ahead(dir: float) -> bool:
	var space := _guard.get_world_2d().direct_space_state
	if space == null:
		return true
	var x: float = _guard.global_position.x + dir * edge_probe_ahead
	var y: float = _guard.global_position.y
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, y - 4.0), Vector2(x, y + 12.0), PhysicsLayers.WORLD)
	return not space.intersect_ray(q).is_empty()


func _physics_process(delta: float) -> void:
	if _guard == null or _guard.config == null:
		return
	_mode_time += delta
	match _mode:
		Mode.CHASING:
			_tick_chase(delta)
		Mode.SEARCHING:
			_tick_search(delta)


func _tick_chase(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_set_mode(Mode.IDLE)
		return
	var dx: float = _target.global_position.x - _guard.global_position.x
	var hidden: bool = _target.has_method(&"is_detectable") and not bool(_target.call(&"is_detectable"))
	# 追上 —— 接触即抓住(躲进柜子/通风管的抓不到;追到柜子前会像跟丢了一样放弃)
	if absf(dx) <= catch_distance and not hidden:
		_guard.velocity.x = 0.0
		player_caught.emit(_target, _guard)
		_set_mode(Mode.IDLE)
		return
	# 还看得见吗
	var seen: bool = not hidden and _guard.can_see(_guard.sight_point(_target))
	if seen:
		_lost_for = 0.0
		_goal_x = _target.global_position.x
	else:
		_lost_for += delta
		if _lost_for >= lose_sight_grace:
			# 甩掉了 —— 转为搜查最后看见的位置,而不是直接回巡逻
			_set_mode(Mode.SEARCHING)
			return
	var dir: float = signf(_goal_x - _guard.global_position.x)
	_guard.velocity.x = dir * _guard.config.patrol_speed * chase_speed_scale
	if absf(dir) > 0.01:
		_guard.facing = int(dir)
	_guard.move_and_slide()


func _tick_search(delta: float) -> void:
	# 守卫已经自己冷静下来 —— 立刻交还控制权,否则会和 _tick_patrol 抢 velocity。
	if _guard.state == Guard.State.PATROL:
		_set_mode(Mode.IDLE)
		return
	if _mode_time >= (_timeout_override if _timeout_override > 0.0 else search_timeout):
		_set_mode(Mode.IDLE)
		return
	# 搜查还在进行:保持警觉,别让 SUSPICIOUS 在半路超时。
	_guard.report_disturbance()
	var dx: float = _goal_x - _guard.global_position.x
	if absf(dx) > 8.0 and _hold_left <= 0.0 and not _floor_ahead(signf(dx)):
		# 前面是边缘(楼板尽头、梯子口、坑):就在这儿张望,不走下去
		_goal_x = _guard.global_position.x
		dx = 0.0
	if absf(dx) > 8.0 and _hold_left <= 0.0:
		var dir: float = signf(dx)
		_guard.velocity.x = dir * _guard.config.patrol_speed * search_speed_scale
		_guard.facing = int(dir)
		# Guard 本帧已以 0 速度 move_and_slide 过;这一次才真正走起来。
		_guard.move_and_slide()
		return
	# 到了柜子前:面朝柜门站一会儿,然后拉开。里面有人就抓到。
	if _locker != null:
		_guard.velocity.x = 0.0
		var face: float = signf(_locker.anchor().x - _guard.global_position.x)
		if face != 0.0:
			_guard.facing = int(face)
		_checking_left -= delta
		if _checking_left <= 0.0:
			var found: Node2D = _locker.open_by_guard()
			_locker = null
			if found != null:
				_guard.spot(found)
				_set_mode(Mode.IDLE)
				return
		else:
			return
	# 到了扣件前:蹲下低头看 → 捡起来 → 站起来张望
	if _inspect != Inspect.NONE or (_bolt != null and is_instance_valid(_bolt)):
		_tick_inspect(delta)
		return
	# 到了声源:站着看一会儿,一半的时候转一次身(不再原地来回转)
	if _hold_left <= 0.0 and _hold_total <= 0.0:
		_hold_total = _hold_override if _hold_override > 0.0 else search_hold
		_hold_left = _hold_total
		_look_turned = false
	_guard.velocity.x = 0.0
	_hold_left -= delta
	if not _look_turned and _hold_left <= _hold_total * 0.5:
		_guard.facing = -_guard.facing
		_look_turned = true
	if _hold_left <= 0.0:
		# 看完一圈,什么都没有 —— 停止刷新警觉,交还控制权。
		# 守卫会在 suspicion_duration 后自然回 PATROL 并走回巡逻区间。
		_set_mode(Mode.IDLE)


func _tick_inspect(delta: float) -> void:
	_guard.velocity.x = 0.0
	match _inspect:
		Inspect.NONE:
			if _bolt == null or not is_instance_valid(_bolt) or not bool(_bolt.call(&"is_claimed_by", _guard)):
				_bolt = null   # 被别人捡走了:照普通搜查张望
				return
			# 走不到扣件跟前(在下一层、坑对面,停在边上了):够不着,照普通搜查张望
			var off: Vector2 = _bolt.global_position - _guard.global_position
			if absf(off.x) > bolt_stand_off + 12.0 or absf(off.y) > 12.0:
				_bolt.call(&"release", _guard)
				_bolt = null
				return
			var face: float = signf(_bolt.global_position.x - _guard.global_position.x)
			if face != 0.0:
				_guard.facing = int(face)
			_inspect = Inspect.CROUCH
			_inspect_left = bolt_inspect_time
			_guard.gaze_down = true
			_set_inspect_pose(1)
		Inspect.CROUCH:
			_inspect_left -= delta
			# 最后 0.6 秒伸手去捡
			_set_inspect_pose(2 if _inspect_left < 0.6 else 1)
			if _inspect_left <= 0.0:
				if _bolt != null and is_instance_valid(_bolt):
					_bolt.call(&"pick_up")
				_bolt = null
				_guard.gaze_down = false
				_inspect = Inspect.LOOK
				_inspect_left = bolt_look_time
				_look_turned = false
				_set_inspect_pose(3)
		Inspect.LOOK:
			_inspect_left -= delta
			if _inspect_left < bolt_look_time - 0.6:
				_set_inspect_pose(0)   # 拿着看一眼,收起来
			if not _look_turned and _inspect_left <= bolt_look_time * 0.4:
				_guard.facing = -_guard.facing
				_look_turned = true
			if _inspect_left <= 0.0:
				_set_mode(Mode.IDLE)
