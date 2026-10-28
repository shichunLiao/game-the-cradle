class_name VeraTraces
extends Node2D
## 坑底 Vera 身上的两样东西(2026-10-12,线索链 C6):接住一路埋下的伏笔。
##
##   - 核心束具上挂着一块号牌「V-17」—— 塔2 广播、工装布条、塔3 档案里的那个工号;
##   - 她手腕上绑着一条布,和塔2 那件叠好的工装同一个颜色 —— 工装是她自己撕下来留下的。
##
## 只是画面,不出字、不碰玩法。号牌是冷青的暗字(和登记塔终端同一种绿),布是工装的旧蓝。
## 节点原点放在 Vera 的左上角(和场景里的 `Vera` 方块同一点;Vera 14×46,比 Ryn 高一点)。
##
## Usage (in a scene): 放在 `Vera` 旁边,`position` = Vera 的 `position`。

## 号牌上的字。
@export var tag_text: String = "V-17"
## 字体(与字幕同一套系统字体)。
@export var font_config: TowerSubtitleConfig
@export var font_size: int = 12
@export var tag_color: Color = Color("16233A")
@export var text_color: Color = Color(0.42, 0.88, 0.66, 0.85)
## 布的颜色:和塔2 的工装(`StoryPickup.cloth_color`)一样。
@export var cloth_color: Color = Color("5B7FA3")

var _font: Font
var _time: float = 0.0


func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var face := SystemFont.new()
	if font_config != null:
		face.font_names = font_config.font_names
	_font = face


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# 号牌:从上面的束具垂一根细线下来,挂在她左边胸口高度
	var sway: float = sin(_time * 0.9) * 0.6
	var plate := Rect2(Vector2(-22.0 + sway, 12.0), Vector2(18.0, 8.0))
	draw_line(Vector2(-13.0, -8.0), plate.position + Vector2(9.0, 0.0), Color("2A3446"), 1.0)
	draw_rect(plate, tag_color)
	draw_rect(Rect2(plate.position, Vector2(plate.size.x, 1.0)), tag_color.lightened(0.25))
	if _font != null:
		var half: float = 0.5
		var w: float = _font.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * half
		draw_set_transform(plate.position + Vector2((plate.size.x - w) * 0.5, 6.0), 0.0, Vector2(half, half))
		draw_string(_font, Vector2.ZERO, tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 手腕上的布:绕一圈,垂下来一小截,跟着轻轻晃
	draw_rect(Rect2(11.0, 26.0, 4.0, 3.0), cloth_color)
	draw_rect(Rect2(11.0, 26.0, 4.0, 1.0), cloth_color.lightened(0.15))
	var tail: float = 15.0 + sin(_time * 1.3) * 0.8
	draw_line(Vector2(14.0, 29.0), Vector2(tail, 34.0), cloth_color.darkened(0.15), 1.0)
