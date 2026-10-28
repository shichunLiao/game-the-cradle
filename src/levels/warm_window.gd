class_name WarmWindow
extends Node2D
## 旧屋外墙上一扇亮着暖光的窗。全游戏暖色只给照片、吊坠、旧屋、结局门口(美术规格.md)——
## 这是屋顶关开头 Ryn 脚下那栋:她刚从这里出来,回头看得见家里还亮着。
##
## 画在实心块(z 1)前面(z 2):窗是贴在外墙上的。不碰撞、不算光源(不影响守卫)。
## 节点原点是 **左上角**。
##
## Usage (in a scene): 设 `position`、`size`。关卡由 `tools/level_builder` 生成时用 `lv.warm_window(...)` 放。

## 美术规格.md --accent-warm
const ACCENT_WARM: Color = Color("C4A574")

@export var size: Vector2 = Vector2(8.0, 10.0)
@export var frame_color: Color = Color("111A2B")

var _time: float = 0.0


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# 灯光微微晃(屋里的灯),外面一圈很淡的暖晕
	var flick: float = 0.92 + 0.08 * sin(_time * 2.3) * sin(_time * 0.7)
	for i in 3:
		var g: float = 3.0 + i * 3.0
		draw_rect(Rect2(-g, -g, size.x + g * 2.0, size.y + g * 2.0), Color(ACCENT_WARM, 0.06 * flick / (i + 1)))
	draw_rect(Rect2(-1.0, -1.0, size.x + 2.0, size.y + 2.0), frame_color)
	draw_rect(Rect2(Vector2.ZERO, size), Color(ACCENT_WARM, flick))
	# 十字窗棂
	draw_rect(Rect2(size.x * 0.5 - 0.5, 0.0, 1.0, size.y), frame_color)
	draw_rect(Rect2(0.0, size.y * 0.45, size.x, 1.0), frame_color)
	# 窗台
	draw_rect(Rect2(-2.0, size.y + 1.0, size.x + 4.0, 1.0), frame_color.lightened(0.15))
