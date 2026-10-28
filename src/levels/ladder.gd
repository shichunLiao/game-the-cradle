class_name Ladder
extends Area2D
## 可攀爬的铁梯 / 管道。节点原点是攀爬区的 **左上角**。
##
## ## 精细化
##
## 旧版是两条细线加几道横杠。现在做成钉在石墙上的铁梯:立柱有受光面与背光面、
## 横档是有厚度的梯级、每隔几档有一个墙面固定件。
##
## 和 `GrayBlock` 同一条原则:**可攀爬性必须一眼可读**。所以横档保持高对比、
## 间距均匀 —— 玩家是靠"一排等距横杠"认出梯子的,细节不能破坏这个节奏。
##
## The top end carries a thin one-way platform flush with `top_y()`, so Ryn can
## stand on top of the ladder and step onto a ledge at the same height.
##
## Usage (in a scene): instance ladder.tscn, set `position` and `size`.
## Ryn's ladder sensor detects it through the PhysicsLayers.LADDER layer.

const RAIL_COLOR: Color = Color("3D6B8A")
const RUNG_SPACING: float = 8.0
const TOP_PLATFORM_THICKNESS: float = 4.0
## 立柱宽度。
const RAIL_W: float = 2.0
## 横档厚度。给梯级一点实体感。
const RUNG_H: float = 2.0
## 每隔几档一个墙面固定件。
const BRACKET_EVERY: int = 4

## Climb zone size in pixels.
@export var size: Vector2 = Vector2(16, 64):
	set(value):
		size = value
		queue_redraw()


func _ready() -> void:
	collision_layer = PhysicsLayers.LADDER
	collision_mask = 0
	monitoring = false
	monitorable = true

	var zone := RectangleShape2D.new()
	zone.size = size
	var zone_collider := CollisionShape2D.new()
	zone_collider.shape = zone
	zone_collider.position = size * 0.5
	add_child(zone_collider)

	var top := StaticBody2D.new()
	top.collision_layer = PhysicsLayers.LADDER_TOP
	top.collision_mask = 0
	var top_shape := RectangleShape2D.new()
	top_shape.size = Vector2(size.x, TOP_PLATFORM_THICKNESS)
	var top_collider := CollisionShape2D.new()
	top_collider.shape = top_shape
	top_collider.one_way_collision = true
	top_collider.position = Vector2(size.x * 0.5, TOP_PLATFORM_THICKNESS * 0.5)
	top.add_child(top_collider)
	add_child(top)


## World Y of the top of the ladder (where Ryn's feet rest when standing on it).
func top_y() -> float:
	return global_position.y


## World Y of the bottom of the ladder.
func bottom_y() -> float:
	return global_position.y + size.y


## World X of the ladder's centre line, where a climbing Ryn is held.
func center_x() -> float:
	return global_position.x + size.x * 0.5


func _draw() -> void:
	_draw_ladder(size.y)


## 从顶上往下画 `length` px 长的一截梯子(`FoldLadder` 放下来的途中只画一截)。
func _draw_ladder(length: float) -> void:
	var dark := RAIL_COLOR.darkened(0.42)
	var lit := RAIL_COLOR.lightened(0.22)

	# 立柱:左柱受光在左、右柱受光在右 —— 两根柱子的高光朝外,梯子才"鼓"起来
	draw_rect(Rect2(0.0, 0.0, RAIL_W, length), RAIL_COLOR)
	draw_rect(Rect2(0.0, 0.0, 1.0, length), lit)
	draw_rect(Rect2(size.x - RAIL_W, 0.0, RAIL_W, length), RAIL_COLOR)
	draw_rect(Rect2(size.x - 1.0, 0.0, 1.0, length), dark)

	# 横档:上沿受光、下沿背光,等距 —— 玩家靠这排节奏认出梯子
	var i: int = 0
	var y: float = 4.0
	while y < length - 1.0:
		var inner_x: float = RAIL_W
		var inner_w: float = size.x - RAIL_W * 2.0
		draw_rect(Rect2(inner_x, y, inner_w, RUNG_H), RAIL_COLOR)
		draw_rect(Rect2(inner_x, y, inner_w, 1.0), lit)
		if y + RUNG_H < length:
			draw_rect(Rect2(inner_x, y + RUNG_H, inner_w, 1.0), dark)
		# 固定件:钉进石墙的卡箍,每隔几档一个
		if i % BRACKET_EVERY == 2:
			draw_rect(Rect2(-2.0, y - 1.0, 2.0, RUNG_H + 2.0), dark)
			draw_rect(Rect2(size.x, y - 1.0, 2.0, RUNG_H + 2.0), dark)
		y += RUNG_SPACING
		i += 1

	# 顶端:可以站上去的那一截,画得比梯身亮,提示"这里是落脚点"
	draw_rect(Rect2(0.0, 0.0, size.x, 1.0), lit)
