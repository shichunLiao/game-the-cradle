class_name GateLight
extends Node2D
## 门禁灯号。叙事脚本.md 塔3 入塔:「灯管嗡鸣。**登记窗口按时开关**；守卫换班有空档。」
## 美术规格 §4 塔3:「门禁灯绿/红极简」。
##
## 塔3 是纯时机塔(无拆解),但之前只有守卫巡逻构成窗口 —— 叙事承诺的「窗口按时开关」
## 一直没兑现。这补上:一个按固定节奏红绿循环的门禁区,红灯时进入即判发现。
##
## 与守卫不同,它 **完全可预测**。里程碑排期 W2 要的「明确『等』的节奏:可视巡逻环
## 或灯号」就是这个 —— 玩家能数拍子,这是设计意图,不是缺陷。

## 红灯(危险)持续,秒。
@export var red_time: float = 3.2
## 绿灯(可通行)持续,秒。
@export var green_time: float = 2.4
## 转红前的预警,秒。黄灯闪烁。
@export var warn_time: float = 0.9
## 相位偏移 0..1 —— 多道门错开。
@export_range(0.0, 1.0) var phase_offset: float = 0.0
@export var size: Vector2 = Vector2(64.0, 72.0)
@export var detection_reset: DetectionReset
@export var ryn: Ryn

@export_group("Colours")
@export var red_color: Color = Color("8B3A2F")
@export var warn_color: Color = Color("D6B53C")
@export var green_color: Color = Color("3D6B8A")

var _t: float = 0.0
## 有没有电(2026-10-12 谜题房:配电箱拆了就断电 —— 灯灭、不抓人)。
var powered: bool = true


## 通电 / 断电(`FuseBox` 调)。断电时灯灭、停在原处、不抓人。
func set_powered(on: bool) -> void:
	powered = on
	queue_redraw()


func _ready() -> void:
	z_index = -4
	_t = phase_offset * _cycle()


func _cycle() -> float:
	return maxf(red_time + green_time, 0.0001)


## 0 = 绿(安全), 1 = 黄(预警), 2 = 红(危险)
func phase() -> int:
	var u: float = fmod(_t, _cycle())
	if u < green_time - warn_time:
		return 0
	if u < green_time:
		return 1
	return 2


func _physics_process(delta: float) -> void:
	if not powered:
		return   # 断电:门禁灯灭,随便过
	_t += delta
	queue_redraw()
	if phase() != 2 or ryn == null or detection_reset == null:
		return
	if not ryn.is_detectable():
		return
	var p: Vector2 = ryn.global_position - Vector2(0.0, ryn.get_body_height() * 0.5)
	var local: Vector2 = p - global_position
	if local.x >= 0.0 and local.x <= size.x and local.y >= -size.y and local.y <= 0.0:
		detection_reset.trigger(ryn, self)


func _draw() -> void:
	if not powered:
		draw_rect(Rect2(0.0, -size.y, size.x, size.y), Color(green_color, 0.25), false, 1.0)
		draw_rect(Rect2(size.x * 0.5 - 3.0, -size.y - 5.0, 6.0, 4.0), Color(green_color, 0.3), true)
		return
	var ph: int = phase()
	var c: Color = [green_color, warn_color, red_color][ph]
	# 黄灯闪烁 —— 预警要抢眼
	var a: float = 0.16
	if ph == 1:
		a = 0.16 + 0.14 * (1.0 if fmod(_t * 6.0, 1.0) < 0.5 else 0.0)
	elif ph == 2:
		a = 0.26
	var fill := c
	fill.a = a
	draw_rect(Rect2(0.0, -size.y, size.x, size.y), fill, true)
	# 门框 + 顶上的灯
	draw_rect(Rect2(0.0, -size.y, size.x, size.y), Color(c, 0.7), false, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 3.0, -size.y - 5.0, 6.0, 4.0), c, true)
