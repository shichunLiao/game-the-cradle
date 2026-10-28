class_name WindowLight
extends Node2D
## 序章旧屋的窗。窗外是高塔的惨白光,与屋内暖光形成对比。
##
## 叙事脚本.md 序章:「旧屋内。Ryn 看合影。**窗外高塔惨白光**。」
## `美术规格.md` §2:暖色只给照片/吊坠/旧屋/结局 —— 旧屋内部用暖,窗外用
## `--tower-white`。这一冷一暖就是整个序章要讲的事:离开温暖,走向那个光。

@export var size: Vector2 = Vector2(48.0, 64.0)
## 窗外的光色。高塔惨白。
@export var light_color: Color = Color("C8D4E0")
## 投射进屋的光柱长度,px(竖直方向)。序章里正好落到地面(窗顶 y 182 → 地面 y 320)。
@export var beam_length: float = 150.0
## 光柱走到底时横着偏了多少,px:正 = 向右下,负 = 向左下。
## 序章窗里的远塔画在偏右,光从右上来,所以是负的 —— 落在窗下偏左的地铺和出生点上(2026-10-12,L2)。
@export var beam_skew: float = 70.0
@export_range(0.0, 1.0) var beam_alpha: float = 0.08
@export var frame_color: Color = Color("1A2A44")
## 极缓慢的明暗起伏 —— 远处高塔的灯在呼吸。
@export var pulse_period: float = 6.0

var _t: float = 0.0


func _ready() -> void:
	z_index = -3
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.86 + 0.14 * sin(_t / maxf(pulse_period, 0.0001) * TAU)
	# 窗洞:惨白
	var c := light_color
	c.a = 0.5 * pulse
	draw_rect(Rect2(0.0, -size.y, size.x, size.y), c, true)
	# 投进屋里的光柱(beam_skew 正向右下、负向左下)
	var beam := light_color
	beam.a = beam_alpha * pulse
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -size.y),
		Vector2(size.x, -size.y),
		Vector2(size.x + beam_skew, -size.y + beam_length),
		Vector2(beam_skew, -size.y + beam_length)]), beam)
	# 窗框与竖棂
	draw_rect(Rect2(-2.0, -size.y - 2.0, size.x + 4.0, size.y + 4.0), frame_color, false, 2.0)
	draw_rect(Rect2(size.x * 0.5 - 1.0, -size.y, 2.0, size.y), frame_color, true)
	draw_rect(Rect2(0.0, -size.y * 0.5 - 1.0, size.x, 2.0), frame_color, true)
