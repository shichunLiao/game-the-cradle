class_name StoryPickup
extends Area2D
## 地上一小件东西,Ryn 走过去就捡起来,出一句话。
##
## 叙事脚本.md 塔 2 出塔:「捡到一小片工装布料或熟悉的垫片(可选道具演出)」。
## 不进背包、不计数 —— 它是一句话的道具,不是收集品。隔一会儿闪一下,让玩家注意到它。
##
## 2026-10-12(线索链,用户选「留给 Ryn」用在工装上):工装是 **叠好的**,放在 Ryn 一定会经过的地方 ——
## 不是掉在地上的,是 Vera 留给妹妹的。上面一块淡白的工号布条(V-17),捡起来那一句念出工号。
## 被发现、回存档点之后不会再出现(捡过就是捡过)。
##
## 节点原点是 **脚下那一点**(地面,物件水平中心)。画在地面上,宽约 12px。
##
## Usage (in a scene): 设 `position`、`text`,`subtitle` 指向关卡的 `TowerSubtitle`。
## 关卡由 `tools/level_builder` 生成时用 `lv.pickup(...)` 放。

## 捡起来时的那一句。
@export_multiline var text: String = ""
@export var subtitle: TowerSubtitle
## 布料的颜色(工装的旧蓝)。
@export var cloth_color: Color = Color("5B7FA3")
## 缝线 / 补丁的颜色。
@export var stitch_color: Color = Color("C9A46A")
## 工号布条的颜色(淡白)。
@export var tag_color: Color = Color("C8D4E0")
## 多久闪一下,秒。
@export var glint_period: float = 1.6
## 捡起来后飘起、淡出的时间,秒。
@export var lift_time: float = 0.6

var _taken: bool = false
var _time: float = 0.0
var _lift: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20.0, 24.0)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0.0, -12.0)
	add_child(col)
	body_entered.connect(_on_body_entered)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# z 0 + 生成器把它排在暗区之后、Ryn 之前:画在暗区的暗色上面(不被压暗),又在 Ryn 脚下
	z_index = 0


## 捡过了吗。
func is_taken() -> bool:
	return _taken


func _process(delta: float) -> void:
	_time += delta
	if _taken:
		_lift += delta
		if _lift >= lift_time:
			hide()
			set_process(false)
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_lift / maxf(lift_time, 0.001), 0.0, 1.0)
	var rise: float = -10.0 * t
	var a: float = 1.0 - t
	# 叠好的工装:三层对齐的布(下深上浅,像叠起来的厚度)、一道缝线、领口一角,上面一块工号布条
	var c := Color(cloth_color, a)
	# 暗区里也要看得见:先画一圈很淡的亮底
	if not _taken:
		var pulse: float = 0.10 + 0.08 * sin(_time * 3.0)
		draw_rect(Rect2(-9.0, -9.0, 18.0, 9.0), Color(stitch_color, pulse))
	draw_rect(Rect2(-7.0, -2.0 + rise, 14.0, 2.0), c.darkened(0.3))
	draw_rect(Rect2(-7.0, -4.0 + rise, 14.0, 2.0), c.darkened(0.12))
	draw_rect(Rect2(-7.0, -7.0 + rise, 14.0, 3.0), c)
	draw_line(Vector2(-7.0, -4.0 + rise), Vector2(7.0, -4.0 + rise), Color(c.darkened(0.45), a), 1.0)   # 折痕
	draw_rect(Rect2(3.0, -7.0 + rise, 4.0, 1.0), Color(stitch_color, a * 0.9))                       # 领口
	draw_rect(Rect2(-5.0, -6.0 + rise, 5.0, 2.0), Color(tag_color, a * 0.85))                         # 工号布条
	draw_rect(Rect2(-4.0, -5.0 + rise, 1.0, 1.0), Color(cloth_color.darkened(0.5), a))
	draw_rect(Rect2(-2.0, -5.0 + rise, 2.0, 1.0), Color(cloth_color.darkened(0.5), a))
	if _taken:
		return
	# 闪一下:十字星,周期里只亮一小段
	var phase: float = fmod(_time, maxf(glint_period, 0.1)) / maxf(glint_period, 0.1)
	if phase < 0.3:
		var k: float = sin(phase / 0.3 * PI)
		var g := Color(1.0, 0.95, 0.8, 0.9 * k)
		var p := Vector2(5.0, -8.0)
		draw_line(p + Vector2(-4.0 * k, 0.0), p + Vector2(4.0 * k, 0.0), g, 1.0)
		draw_line(p + Vector2(0.0, -4.0 * k), p + Vector2(0.0, 4.0 * k), g, 1.0)


func _on_body_entered(body: Node2D) -> void:
	if _taken or body is not Ryn:
		return
	_taken = true
	_lift = 0.0
	Audio.play(&"checkpoint", -14.0, 1.25)
	StoryTrigger.say(subtitle, text)
