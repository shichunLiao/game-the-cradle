class_name SweepLight
extends Node2D
## 探照灯。叙事脚本.md 塔4 入塔:「**探照灯扫过**。窄道、高台。」
##
## 这是塔4 的核心玩法,之前只做了守卫,这一条一直缺着 —— `里程碑排期.md` W3 把它
## 标为「留给后塔」,塔4 就是那个后塔。
##
## ## 它故意不被暗处豁免
##
## 守卫看不见暗处的你(Story 004),但 **探照灯照亮暗处**。否则塔4 只要全程蹲在暗区
## 就通关了,加压无从谈起。灯扫是对"躲暗处"这一招的针对性破解 —— 遇到灯扫必须靠
## 走位和时机,这正是塔4 要加的那层压力。
##
## 命中后走 `DetectionReset.trigger()`,与被守卫看见同一条失败路径、同一句台词。
##
## 2026-10-15(用户试玩):光被地板、平台挡住 —— 以前是一个纯矩形,会穿过平台照到下层的人,
## 也会停在半空碰不到地。现在光柱分 `STRIPS` 条,每条往下打射线到第一块实心(`PhysicsLayers.WORLD`)为止;
## 判定是「灯口到躯干中点之间没有实心」。关卡生成器 `level_dsl.Sweep.stop` 用同一条规则算。
## 灯头是一架无人机(用户:「探照灯光是无人机打出来的」),跟着扫动来回飞。

## 灯柱宽度,px。
@export var beam_width: float = 56.0
## 灯柱向下照的长度,px。
@export var beam_length: float = 160.0
## 扫动行程(相对本节点的 x 偏移)。正负皆可。
@export var sweep_span: float = 260.0
## 一个来回用时,秒。
@export var period: float = 5.0
## 在端点的停留比例(0..0.4)。停顿让玩家有窗口。
@export_range(0.0, 0.4) var dwell: float = 0.18
## 相位偏移 0..1 —— 多盏灯错开,不要同步扫。
@export_range(0.0, 1.0) var phase_offset: float = 0.0
@export var detection_reset: DetectionReset
@export var ryn: Ryn

@export_group("Colours")
@export var beam_color: Color = Color("C8D4E0")
@export var beam_alpha: float = 0.17
@export var housing_color: Color = Color("1A2A44")

var _t: float = 0.0
## 有没有电(2026-10-12 谜题房:配电箱拆了就断电 —— 灯灭、不抓人)。
var powered: bool = true


## 通电 / 断电(`FuseBox` 调)。断电时灯灭、停在原处、不抓人。
func set_powered(on: bool) -> void:
	powered = on
	queue_redraw()
var _x: float = 0.0
## 光柱分几条各自找落点。
const STRIPS: int = 8
## 往下照不到东西时,光柱画到这么长(px)。
const REACH: float = 1600.0
var _len := PackedFloat32Array()
var _q: PhysicsRayQueryParameters2D
var _anim: float = 0.0


func _ready() -> void:
	z_index = -5
	_t = phase_offset * period
	_q = PhysicsRayQueryParameters2D.create(Vector2.ZERO, Vector2.ZERO, PhysicsLayers.WORLD)
	_len.resize(STRIPS)
	_len.fill(beam_length)


## 从灯口所在高度、本地 x 处往下,到第一块实心的距离(px)。
func _reach_at(local_x: float) -> float:
	var from: Vector2 = to_global(Vector2(local_x, 1.0))   # 往下挪 1px,灯口贴着楼板时别算撞到
	_q.from = from
	_q.to = from + Vector2(0.0, REACH)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(_q)
	return REACH if hit.is_empty() else (hit.position as Vector2).y - from.y + 1.0


func _physics_process(delta: float) -> void:
	_anim += delta
	queue_redraw()                       # 断电时无人机也还在飞(旋翼转)
	if not powered:
		return   # 断电:灯灭、停在原处,不抓人
	_t = fmod(_t + delta, maxf(period, 0.0001))
	_x = _offset_at(_t)
	var sw: float = beam_width / STRIPS
	for i in STRIPS:
		_len[i] = _reach_at(_x - beam_width * 0.5 + sw * (i + 0.5))
	if ryn == null or detection_reset == null:
		return
	# 躲在柜子里的人照不到 —— 柜子正是对付探照灯的办法(暗处挡不住灯,柜子挡得住)
	if not ryn.is_detectable():
		return
	# 采样躯干中点,与守卫判定同一个点
	var p: Vector2 = ryn.global_position - Vector2(0.0, ryn.get_body_height() * 0.5)
	var local: Vector2 = p - global_position
	if absf(local.x - _x) <= beam_width * 0.5 and local.y >= 0.0 and _reach_at(local.x) >= local.y:
		detection_reset.trigger(ryn, self)


## 当前扫动偏移。两端带停留的三角波。
func _offset_at(t: float) -> float:
	var u: float = t / maxf(period, 0.0001)
	var d: float = clampf(dwell, 0.0, 0.4)
	var half: float = 0.5
	var move: float = maxf(half - d, 0.0001)
	var f: float = 0.0
	if u < d:
		f = 0.0
	elif u < half:
		f = (u - d) / move
	elif u < half + d:
		f = 1.0
	else:
		f = 1.0 - clampf((u - half - d) / move, 0.0, 1.0)
	return lerpf(0.0, sweep_span, smoothstep(0.0, 1.0, f))


func _draw() -> void:
	_draw_drone()
	if not powered:
		return
	# 光柱:上窄下宽,到 beam_length 宽到 beam_width 为止;每条在自己的落点停下
	var top_w: float = beam_width * 0.35
	var lref: float = maxf(beam_length, 1.0)
	var c := beam_color
	c.a = beam_alpha
	var spot := beam_color
	spot.a = beam_alpha * 1.6          # 落点上的光斑:「这里危险」
	var sw: float = beam_width / STRIPS
	for i in STRIPS:
		var l: float = _len[i]
		var d1: float = minf(l, lref)
		var w1: float = lerpf(top_w, beam_width, d1 / lref)
		var cone := PackedVector2Array([
			Vector2(_x - top_w * 0.5, 0.0), Vector2(_x + top_w * 0.5, 0.0),
			Vector2(_x + w1 * 0.5, d1), Vector2(_x + w1 * 0.5, l),
			Vector2(_x - w1 * 0.5, l), Vector2(_x - w1 * 0.5, d1)])
		var xa: float = _x - beam_width * 0.5 + sw * i
		var col := PackedVector2Array([Vector2(xa, 0.0), Vector2(xa + sw, 0.0), Vector2(xa + sw, l), Vector2(xa, l)])
		for poly in Geometry2D.intersect_polygons(cone, col):
			draw_colored_polygon(poly, c)
		var lo: float = maxf(xa, _x - w1 * 0.5)
		var hi: float = minf(xa + sw, _x + w1 * 0.5)
		if hi > lo and l < REACH:
			draw_rect(Rect2(lo, l - 3.0, hi - lo, 3.0), spot, true)


## 灯头:一架小无人机(约 24x10px),灯口在它肚子下面、正好是光柱顶点。
func _draw_drone() -> void:
	var x: float = roundf(_x)
	var body := housing_color
	var hi := housing_color.lightened(0.3)
	draw_rect(Rect2(x - 6.0, -8.0, 12.0, 5.0), body, true)            # 机身
	draw_rect(Rect2(x - 6.0, -8.0, 12.0, 1.0), hi, true)
	draw_rect(Rect2(x - 11.0, -7.0, 5.0, 1.0), body, true)            # 机臂
	draw_rect(Rect2(x + 6.0, -7.0, 5.0, 1.0), body, true)
	draw_rect(Rect2(x - 12.0, -9.0, 2.0, 3.0), body, true)            # 电机
	draw_rect(Rect2(x + 10.0, -9.0, 2.0, 3.0), body, true)
	var rw: float = 9.0 if int(_anim * 30.0) % 2 == 0 else 5.0        # 旋翼转起来的虚影,长短交替
	var rc := hi
	rc.a = 0.7
	draw_rect(Rect2(x - 11.0 - rw * 0.5, -10.0, rw, 1.0), rc, true)
	draw_rect(Rect2(x + 11.0 - rw * 0.5, -10.0, rw, 1.0), rc, true)
	draw_rect(Rect2(x - 3.0, -3.0, 6.0, 3.0), body.darkened(0.3), true)   # 灯口
	draw_rect(Rect2(x - 2.0, -1.0, 4.0, 1.0), beam_color if powered else body.darkened(0.5), true)
	if powered and fmod(_anim, 1.0) < 0.15:                             # 红色指示灯一闪
		draw_rect(Rect2(x + 4.0, -7.0, 1.0, 1.0), Color("E04050"), true)
