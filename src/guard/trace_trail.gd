class_name TraceTrail
extends Node2D
## Ryn 走过留下的蚀痕(2026-10-13,「追」的守卫用,`design/ideas-backlog.md` G3)。
##
## 剧情:只有缓蚀者会留下这种痕迹 —— Ryn 自己不知道(设定:Ryn 是缓蚀者,自不知)。不说破,
## 防毒面具兵的侦测器读得到,玩家看得到地上一串淡紫的脚印,自己去想。
##
## 规则(都画在画面上,Mark of the Ninja 的「规则透明」):
##   - Ryn 站在地上走动(走、跑、蹲着走都算)时,每走 `step_px` 落一个点;爬梯子、跳在空中、躲着不落;
##   - 每个点 `life` 秒后散掉,越旧越淡;
##   - 正在冒的蒸汽、有蚀的地方不落点;蒸汽冒起来时把罩住的点洗掉;
##   - 相邻两点隔太远(钻通风管、爬梯子、掉下一层)就断开 —— 守卫顺着追到断口就跟丢了。
##
## 一关一个,由第一个「追」的守卫(`GuardSenses`)放到关卡根下,名字 `TraceTrail`。关卡里没有「追」的守卫,
## 就没有这个节点,也看不到脚印(塔1、塔2 不提前露出这条线索)。
##
## Usage:
##     var trail := TraceTrail.ensure(level_root, ryn)
##     var id := trail.nearest(guard.global_position, 18.0)    # 点的编号,一直不变(散掉、洗掉也不会让别的点改号)
##     var nxt := trail.next_from(id)

const NAME: StringName = &"TraceTrail"
## 和 `SteamValve.GROUP`、`CorrosionZone.GROUP` 一样。这里**不引用那两个类**:它们一路引用到用了 `Audio` 的
## 脚本,守卫又引用到这里 —— `-s` 检查脚本里写 `Guard` 类型就会连带编不过(2026-10-13 实测)。
const STEAM_GROUP: StringName = &"steam_valves"
const CORROSION_GROUP: StringName = &"corrosion_zone"
const COLOR: Color = Color("8C6CB8")

## 每走多远落一个点,px。
@export var step_px: float = 10.0
## 一个点多久散掉,秒。
@export var life: float = 8.0
## 相邻两点最远隔多远还算连着,px(水平)。
@export var link_px: float = 28.0
## 相邻两点最多差多高还算同一层,px。
@export var link_dy: float = 6.0

var ryn: Ryn
var _pts: PackedVector2Array = PackedVector2Array()
var _times: PackedFloat32Array = PackedFloat32Array()
var _side: PackedByteArray = PackedByteArray()
## 每个点的编号(递增,不重复)。外面拿编号,不拿数组下标 —— 散掉、洗掉以后下标会变。
var _ids: PackedInt64Array = PackedInt64Array()
var _next_id: int = 0
var _clock: float = 0.0
var _last: Vector2 = Vector2.INF


## 关卡里的那一个;没有就放一个。
static func ensure(level: Node, who: Ryn) -> TraceTrail:
	var t := level.get_node_or_null(NodePath(String(NAME))) as TraceTrail
	if t == null:
		t = TraceTrail.new()
		t.name = NAME
		t.ryn = who
		level.add_child.call_deferred(t)
	return t


func _ready() -> void:
	z_index = -30          # 画在地板道具之上、角色和实心块之下
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group(CheckpointManager.RESETTABLE_GROUP)


## 回存档点:痕迹全清(`CheckpointManager` 的可重置接口)。
func capture_state() -> Dictionary:
	return {}


func restore_state(_state: Dictionary) -> void:
	clear()


func _physics_process(delta: float) -> void:
	_clock += delta
	_expire()
	_wash_steam()
	if ryn == null or not is_instance_valid(ryn):
		return
	if ryn.state != Ryn.State.NORMAL or not ryn.is_on_floor() or not ryn.is_detectable():
		return
	var p: Vector2 = ryn.global_position.round()
	if _last != Vector2.INF and p.distance_to(_last) < step_px:
		return
	_last = p
	if _washed(p):
		return
	_pts.append(p)
	_times.append(_clock)
	_side.append(_next_id % 2)
	_ids.append(_next_id)
	_next_id += 1
	queue_redraw()


## 点数。
func size() -> int:
	return _pts.size()


## 编号为 `id` 的点还在吗。
func has(id: int) -> bool:
	return _index(id) >= 0


## 编号为 `id` 的点的位置(不在了返回 INF)。
func point(id: int) -> Vector2:
	var i: int = _index(id)
	return _pts[i] if i >= 0 else Vector2.INF


## 编号为 `id` 的点落下多久了,秒(不在了返回 INF)。
func age(id: int) -> float:
	var i: int = _index(id)
	return _clock - _times[i] if i >= 0 else INF


## 离 `at` 水平 `radius` 以内、同一层的点里**最新**的那个的编号;没有返回 -1。
func nearest(at: Vector2, radius: float) -> int:
	for i in range(_pts.size() - 1, -1, -1):
		if absf(_pts[i].x - at.x) <= radius and absf(_pts[i].y - at.y) <= link_dy:
			return _ids[i]
	return -1


## 从编号 `id` 的点顺着往后(更新的)走到的下一个连着的点的编号;断了、到头、不在了返回 -1。
func next_from(id: int) -> int:
	var i: int = _index(id)
	if i < 0 or i + 1 >= _pts.size():
		return -1
	if _ids[i + 1] != id + 1:
		return -1          # 中间有点被洗掉了:断开
	var a: Vector2 = _pts[i]
	var b: Vector2 = _pts[i + 1]
	if absf(b.x - a.x) > link_px or absf(b.y - a.y) > link_dy:
		return -1
	return _ids[i + 1]


## 编号 → 数组下标(编号递增,二分);不在返回 -1。
func _index(id: int) -> int:
	var lo: int = 0
	var hi: int = _ids.size() - 1
	while lo <= hi:
		var mid: int = (lo + hi) >> 1
		if _ids[mid] == id:
			return mid
		if _ids[mid] < id:
			lo = mid + 1
		else:
			hi = mid - 1
	return -1


## 把 `rect` 里的点洗掉(蒸汽冒起来、验证脚本)。
func wash(rect: Rect2) -> void:
	var keep_p := PackedVector2Array()
	var keep_t := PackedFloat32Array()
	var keep_s := PackedByteArray()
	var keep_i := PackedInt64Array()
	for i in _pts.size():
		if not rect.has_point(_pts[i] + Vector2(0.0, -2.0)):
			keep_p.append(_pts[i])
			keep_t.append(_times[i])
			keep_s.append(_side[i])
			keep_i.append(_ids[i])
	if keep_p.size() != _pts.size():
		_pts = keep_p
		_times = keep_t
		_side = keep_s
		_ids = keep_i
		queue_redraw()


## 全部清掉(回存档点时)。
func clear() -> void:
	_pts.clear()
	_times.clear()
	_side.clear()
	_ids.clear()
	_last = Vector2.INF
	queue_redraw()


func _expire() -> void:
	var n: int = 0
	while n < _times.size() and _clock - _times[n] > life:
		n += 1
	if n > 0:
		_pts = _pts.slice(n)
		_times = _times.slice(n)
		_side = _side.slice(n)
		_ids = _ids.slice(n)
	if _pts.size() > 0 or n > 0:
		queue_redraw()


## 这一点落不落得下:正在冒的蒸汽里、有蚀的地方落不下。
## 蒸汽阀、蚀都不写类型,见 `STEAM_GROUP` 的说明。
func _washed(p: Vector2) -> bool:
	for sv in get_tree().get_nodes_in_group(STEAM_GROUP):
		if bool(sv.call(&"is_venting")) and (sv.get(&"cloud_rect") as Rect2).has_point(p + Vector2(0.0, -2.0)):
			return true
	for cz in get_tree().get_nodes_in_group(CORROSION_GROUP):
		if (cz as CanvasItem).visible and float(cz.call(&"level")) > 0.05 \
				and Rect2((cz as Node2D).global_position, cz.get(&"size") as Vector2).grow(2.0).has_point(p + Vector2(0.0, -2.0)):
			return true
	return false


func _wash_steam() -> void:
	for sv in get_tree().get_nodes_in_group(STEAM_GROUP):
		if bool(sv.call(&"is_venting")):
			wash(sv.get(&"cloud_rect") as Rect2)


func _draw() -> void:
	# 脚印:2x1 的一小横,左右脚交替错开 2px;越旧越淡
	for i in _pts.size():
		var k: float = clampf(1.0 - (_clock - _times[i]) / life, 0.0, 1.0)
		var off: float = -2.0 if _side[i] == 0 else 1.0
		draw_rect(Rect2(_pts[i] + Vector2(off, -1.0), Vector2(2.0, 1.0)), Color(COLOR, 0.65 * k))
