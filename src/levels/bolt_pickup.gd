class_name BoltPickup
extends Area2D
## 地上一颗扣件,走过去捡起来,身上多一个(不超过上限)。身上满了就不捡,留在原地。
##
## 塔1 教丢扣件的地方放一颗:隔一会儿闪一下,玩家捡起来 = 知道「扣件是能用的东西」。
## 捡过就没了(被发现重来时身上本来就会补满,不需要它再出现)。
##
## 节点原点是 **脚下那一点**(地面,扣件水平中心)。
##
## Usage (in a scene): 设 `position`。关卡由 `tools/level_builder` 生成时用 `lv.bolt(...)` 放。

## 捡起来加几个。
@export var amount: int = 1
@export var bolt_color: Color = Color("8C98A8")
@export var shine_color: Color = Color("D8E2EC")
## 多久闪一下,秒。
@export var glint_period: float = 1.4

var _taken: bool = false
var _time: float = 0.0
var _fade: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16.0, 24.0)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0.0, -12.0)
	add_child(col)
	body_entered.connect(_try_take)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## 捡过了吗。
func is_taken() -> bool:
	return _taken


func _process(delta: float) -> void:
	_time += delta
	if _taken:
		_fade += delta * 3.0
		if _fade >= 1.0:
			queue_free()
	elif monitoring:
		# 身上满了的时候站在上面不会触发 body_entered;丢掉一个之后要能再捡起来
		for b in get_overlapping_bodies():
			_try_take(b)
	queue_redraw()


func _draw() -> void:
	var a: float = 1.0 - _fade
	var lift: float = -6.0 * _fade
	var pts := PackedVector2Array()
	for i in 6:
		var ang: float = TAU * float(i) / 6.0
		pts.append(Vector2(cos(ang), sin(ang)) * 2.6 + Vector2(0.0, -2.6 + lift))
	draw_colored_polygon(pts, Color(bolt_color, a))
	draw_rect(Rect2(-0.5, -3.1 + lift, 1.0, 1.0), Color(0.05, 0.06, 0.08, a))
	if _taken:
		return
	var phase: float = fmod(_time, maxf(glint_period, 0.1)) / maxf(glint_period, 0.1)
	if phase < 0.3:
		var k: float = sin(phase / 0.3 * PI)
		var p := Vector2(2.0, -6.0)
		var g := Color(shine_color, 0.9 * k)
		draw_line(p + Vector2(-3.0 * k, 0.0), p + Vector2(3.0 * k, 0.0), g, 1.0)
		draw_line(p + Vector2(0.0, -3.0 * k), p + Vector2(0.0, 3.0 * k), g, 1.0)


func _try_take(body: Node2D) -> void:
	if _taken or body is not Ryn:
		return
	var thrower: Node = body.get_node_or_null(^"Throw")
	if thrower == null or not thrower.has_method(&"add_bolts") or bool(thrower.call(&"is_full")):
		return
	thrower.call(&"add_bolts", amount)
	_taken = true
	set_deferred(&"monitoring", false)
	Audio.play(&"bolt_tick", -8.0, 1.3)
