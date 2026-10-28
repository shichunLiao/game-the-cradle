class_name GuardSenses
extends Node
## 「听」和「追」两种守卫的发现方式(2026-10-13,`design/ideas-backlog.md` G2 / G3)。`Guard._ready` 在
## `sense` 不是 SIGHT 时自动挂上,`guard.gd` 只管「听」的看不见、「追」的近视。
##
## ## 听(HEARING,面罩头盔兵)
## 看不见。声音照常由 `GuardPursuit` 听(噪音环碰到他 = 他听到,环的大小就是规则,不另外加成),
## 听到就快步走到声源。发现只有两种:
##   - 搜查途中(走去声源、在声源张望)Ryn 离他 `listen_catch_px` 以内;
##   - 平时 Ryn 离他 `touch_px` 以内(撞上了)。
## 暗处挡不住他。破法:蹲着走(没有声音)、出了声就赶快安静地走开、丢扣件把他引走、躲柜子。
##
## ## 追(TRACKING,防毒面具兵)
## 视野锥短(近视,暗处看不见)。蚀侦测器读得到 Ryn 走过的痕迹(`TraceTrail`):脚下踩到新鲜的痕迹,
## 就「?」顺着痕迹一点一点追过去(`GuardPursuit.follow`);追到痕迹的头 —— 旁边有柜子就拉开,
## Ryn 离他 `track_catch_px` 以内(侦测器直接读到她)就算发现,暗处也一样。痕迹断了(通风管、梯子、
## 掉下一层、蚀池、蒸汽)或散了,就在断口张望一会儿,回去巡逻。破法:别走回头路、用通风管 / 梯子 / 蚀甩掉他。
##
## 两种都用 `Guard.spot()` 判发现 —— 和被看见走同一条重置路径。

## 「听」:撞上算发现的距离(水平),px。
@export var touch_px: float = 14.0
## 「听」:搜查途中离多近算发现(水平),px。
@export var listen_catch_px: float = 28.0
## 「追」:脚下多近的痕迹算踩到,px。
@export var sniff_px: float = 16.0
## 「追」:离多近侦测器直接读到人,px。
@export var track_catch_px: float = 22.0
## 「追」:跟丢之后多久才会再去闻新的痕迹,秒(免得在断口原地反复起疑)。
@export var track_cooldown: float = 2.5
## 和 Ryn 算「同一层」的高度差,px。
@export var same_floor_dy: float = 24.0

## 走到一个痕迹点算「到了」的距离,px。要比 `GuardPursuit` 停步的 8px 大。
const ARRIVE_PX: float = 10.0

var _guard: Guard
var _pursuit: GuardPursuit
var _ryn: Ryn
var _trail: TraceTrail
## 正在追的那个痕迹点的编号(`TraceTrail` 的编号,不是下标);-1 = 没在追。
var _follow_i: int = -1
var _cooldown: float = 0.0


func _ready() -> void:
	_guard = get_parent() as Guard
	if _guard == null:
		set_physics_process(false)
		return
	var level: Node = _guard.owner if _guard.owner != null else _guard.get_parent()
	if level != null:
		_ryn = level.get_node_or_null(^"Ryn") as Ryn
	for c in _guard.get_children():
		if c is GuardPursuit:
			_pursuit = c
	if _guard.sense == Guard.Sense.TRACKING and level != null and _ryn != null:
		_trail = TraceTrail.ensure(level, _ryn)


## 「追」:正在跟着痕迹吗(检查脚本 / 画面用)。
func is_tracking() -> bool:
	return _follow_i >= 0


func _physics_process(delta: float) -> void:
	if _ryn == null or _guard.state == Guard.State.SPOTTED:
		_follow_i = -1
		return
	match _guard.sense:
		Guard.Sense.HEARING:
			_tick_hearing()
		Guard.Sense.TRACKING:
			_tick_tracking(delta)


## Ryn 在不在同一层、水平离守卫多远(不同层或躲着返回 INF)。
func _ryn_dx() -> float:
	if not _ryn.is_detectable():
		return INF
	var d: Vector2 = _ryn.global_position - _guard.global_position
	if absf(d.y) > same_floor_dy:
		return INF
	return absf(d.x)


func _tick_hearing() -> void:
	var dx: float = _ryn_dx()
	var searching: bool = _pursuit != null and _pursuit.is_searching()
	if dx <= touch_px or (searching and dx <= listen_catch_px):
		_guard.spot(_ryn)


func _tick_tracking(delta: float) -> void:
	if _trail == null or not is_instance_valid(_trail):
		return
	if _ryn_dx() <= track_catch_px and (_follow_i >= 0 or _ryn_dx() <= touch_px):
		_guard.spot(_ryn)
		_follow_i = -1
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	var feet: Vector2 = _guard.global_position
	if _follow_i < 0:
		if _cooldown > 0.0:
			return
		var i: int = _trail.nearest(feet, sniff_px)
		if i < 0:
			return
		_follow_i = i
		_step()
		return
	# 跟着走:点散了 / 被洗掉了就跟丢;到了当前点就走下一个
	if not _trail.has(_follow_i):
		_lose()
		return
	# 到了 = 和 `GuardPursuit` 停步的距离(8px)一样宽松再多一点;第一版用 6px,守卫停在 8px 外永远「没到」
	if absf(_trail.point(_follow_i).x - feet.x) <= ARRIVE_PX:
		var nxt: int = _trail.next_from(_follow_i)
		if nxt < 0:
			_lose()
			return
		_follow_i = nxt
		_step()
	elif _pursuit != null and not _pursuit.is_searching():
		_lose()


## 往当前点走;它后面断了,就是痕迹的头(到了查看、有柜子就拉开)。
func _step() -> void:
	if _pursuit == null:
		return
	var last: bool = _trail.next_from(_follow_i) < 0
	_pursuit.follow(_trail.point(_follow_i), last)


## 跟丢了:让 `GuardPursuit` 在原地张望完自己收尾,冷却一会儿再闻。
func _lose() -> void:
	_follow_i = -1
	_cooldown = track_cooldown
