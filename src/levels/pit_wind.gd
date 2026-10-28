class_name PitWind
extends Node2D
## 地上一道格栅,底下的风往上灌,带着黑雾。
##
## 叙事脚本.md 塔 4 出塔·靠近坑口:「风从下方上来,带黑雾感。」—— 塔顶出口前的格栅,
## 雾一缕缕往上飘、被风扯长。只是氛围,不挡路、不算暗区、不影响守卫。
## 坑底「下行」关里也用它做裂缝里冒出来的蚀雾。
##
## 节点原点是 **格栅左端、地面顶面**(像素 y = 行 × 16)。雾往上飘 `rise` px。
## 雾是程序画的(每缕按时间算位置),没有粒子节点,不随机 —— 每次打开都一样。
##
## Usage (in a scene): 设 `position`、`width`、`rise`。
## 关卡由 `tools/level_builder` 生成时用 `lv.pit_wind(...)` 放。

## 格栅宽度,px。
@export var width: float = 64.0
## 雾往上飘多高,px。
@export var rise: float = 80.0
## 同时有几缕雾。
@export var wisps: int = 30
## 雾往上飘的速度,px/秒。
@export var speed: float = 22.0
## 雾心的颜色 —— 黑雾。
@export var core_color: Color = Color(0.04, 0.03, 0.06, 0.35)
## 雾边的颜色 —— 比背景亮一点的灰紫;纯黑在暗背景上看不见,要靠亮边把黑心勾出来。
@export var rim_color: Color = Color(0.34, 0.31, 0.42, 0.20)
## 格栅上方一柱淡淡的雾气(底下浓、往上淡)。
@export var haze_color: Color = Color(0.30, 0.28, 0.38, 0.22)
## 被风扯出来的细线(更快)。
@export var streak_color: Color = Color(0.70, 0.68, 0.80, 0.30)
@export var grate_color: Color = Color("1B222C")
@export var slat_color: Color = Color("3A4656")
## 不画格栅(坑底的裂缝自己有形状)。
@export var draw_grate: bool = true

var _time: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2   # 在地板块(z 1)前面,格栅才画得在地面上


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if draw_grate:
		draw_rect(Rect2(0.0, 0.0, width, 4.0), grate_color)
		var x: float = 2.0
		while x < width - 1.0:
			draw_rect(Rect2(x, 0.0, 1.0, 4.0), slat_color)
			x += 4.0
	# 雾柱:几层横条,底下浓、往上淡,两侧随时间轻轻摆
	var bands: int = 8
	for k in bands:
		var f: float = float(k) / float(bands)
		var wob: float = sin(_time * 0.9 + f * 4.0) * 4.0 * f
		var grow: float = 6.0 + f * 18.0
		draw_rect(Rect2(-grow * 0.5 + wob, -rise * (f + 1.0 / bands), width + grow, rise / bands + 1.0),
				Color(haze_color, haze_color.a * (1.0 - f)))
	# 雾:先画全部亮边,再画全部黑心 —— 一缕一缕分开画,每缕自带一圈亮边,读成「洞」不是「雾」
	var n: int = maxi(wisps, 1)
	for pass_i in 2:
		for i in n:
			var w := _wisp(i)
			var c: Vector2 = w[0]
			var r: float = w[1]
			var fade: float = w[2]
			if pass_i == 0:
				# 亮边:大、淡,被风扯长(竖的比横的长)
				# 再外一圈更淡的,边缘就不是一道硬框
				draw_rect(Rect2(c.x - r * 1.4, c.y - r * 1.5, r * 2.8, r * 3.0), Color(rim_color, rim_color.a * fade * 0.4))
				var rim := Color(rim_color, rim_color.a * fade)
				draw_rect(Rect2(c.x - r, c.y - r * 1.1, r * 2.0, r * 2.2), rim)
				draw_rect(Rect2(c.x - r * 0.6, c.y - r * 1.7, r * 1.2, r * 3.0), rim)
			else:
				var core := Color(core_color, core_color.a * fade)
				draw_rect(Rect2(c.x - r * 0.65, c.y - r * 0.8, r * 1.3, r * 1.6), core)
				draw_rect(Rect2(c.x - r * 0.35, c.y - r * 1.3, r * 0.7, r * 2.2), core)
	# 风:几道细线飞快往上,斜一点
	for j in 7:
		var life2: float = fposmod(_time * speed * 3.2 / maxf(rise, 1.0) + float(j) * 0.21, 1.0)
		var sx: float = 6.0 + fposmod(float(j) * 0.43, 1.0) * (width - 12.0)
		var sy: float = -life2 * rise * 1.2
		var a2: float = sin(life2 * PI) * streak_color.a
		draw_line(Vector2(sx + life2 * 6.0, sy), Vector2(sx + life2 * 6.0 + 2.0, sy - 9.0),
				Color(streak_color, a2), 1.0)


## 第 i 缕雾此刻的 [中心, 半径, 浓度]。固定的横向位置和相位,往上飘,到顶淡掉再从格栅里出来。
func _wisp(i: int) -> Array:
	var seed_x: float = fposmod(float(i) * 0.618034, 1.0)
	var seed_p: float = fposmod(float(i) * 0.377, 1.0)
	var life: float = fposmod(_time * speed / maxf(rise, 1.0) + seed_p, 1.0)
	var sway: float = sin(_time * 1.3 + float(i) * 2.1) * (3.0 + life * 9.0)
	var center := Vector2(3.0 + seed_x * (width - 6.0) + sway, -life * rise)
	return [center, 3.0 + life * 8.0, sin(life * PI)]
