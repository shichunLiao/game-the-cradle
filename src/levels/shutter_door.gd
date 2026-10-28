class_name ShutterDoor
extends Node2D
## 拆不动的铁卷门(2026-10-12 谜题房,塔3「控制室」)。门本身拆不了 —— 要找到控制它的面板
## (`panel`,一块 `Dismantlable` PANEL)拆掉,门才哗啦啦卷上去。
##
## 门旁的小灯:红 = 锁着(是别处控制的,别在门前白费力气),绿 = 开了。卷上去的声音很大
## (`noise_radius`),附近的守卫会过来看。回存档点时跟着面板一起回到原样。
##
## 节点原点是 **左上角**(和 `GrayBlock` 一样),碰撞体 = `size`。
##
## Usage (in a scene): 设 `position`、`size`、`panel`。关卡由 `tools/level_builder` 用 `lv.shutter(...)` 放。

@export var size: Vector2 = Vector2(16.0, 208.0):
	set(value):
		size = value
		_sync_shape()
		queue_redraw()
## 控制这扇门的面板。
@export var panel: Dismantlable
## 卷上去要多久,秒。
@export var open_time: float = 1.1
## 卷门的声音传多远,px。
@export var noise_radius: float = 220.0
@export var slat_color: Color = Color("24344C")
@export var rail_color: Color = Color("141F31")
@export var lamp_closed: Color = Color("8B3A2F")
@export var lamp_open: Color = Color("3D6B8A")

## 0 = 关着,1 = 全开。
var _open: float = 0.0
var _opening: bool = false
var _body: StaticBody2D
var _shape: RectangleShape2D
var _col: CollisionShape2D


func _ready() -> void:
	z_index = 1
	_body = StaticBody2D.new()
	_body.collision_layer = PhysicsLayers.WORLD
	_body.collision_mask = 0
	_shape = RectangleShape2D.new()
	_col = CollisionShape2D.new()
	_col.shape = _shape
	_body.add_child(_col)
	add_child(_body)
	_sync_shape()
	if panel != null:
		panel.panel_dismantled.connect(func(_n: int) -> void: open())
		panel.panel_restored.connect(_on_restored)


## 开了吗(全部卷上去)。
func is_open() -> bool:
	return _open >= 1.0


## 卷上去(面板拆掉时调;验证脚本也可以直接调)。
func open() -> void:
	if _open >= 1.0 or _opening:
		return
	_opening = true
	Audio.play(&"shutter_roll", -6.0)
	var bus := get_node_or_null(^"/root/Noise")
	if bus != null:
		bus.emit_noise(global_position + size * 0.5, noise_radius)


func _on_restored(opened: bool) -> void:
	_opening = false
	_open = 1.0 if opened else 0.0
	_apply()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _opening:
		return
	_open = minf(_open + delta / maxf(open_time, 0.01), 1.0)
	if _open >= 1.0:
		_opening = false
		_apply()
	queue_redraw()


func _apply() -> void:
	if _col != null:
		_col.set_deferred(&"disabled", _open >= 1.0)


func _sync_shape() -> void:
	if _shape == null or _col == null:
		return
	_shape.size = size
	_col.position = size * 0.5


func _draw() -> void:
	# 两边的导轨(一直在)
	draw_rect(Rect2(-2.0, 0.0, 2.0, size.y), rail_color)
	draw_rect(Rect2(size.x, 0.0, 2.0, size.y), rail_color)
	# 门帘:一条条横的铁片,从上往下放;开的时候往上收
	var shown: float = size.y * (1.0 - _open)
	var y: float = 0.0
	while y < shown - 1.0:
		draw_rect(Rect2(0.0, y, size.x, 3.0), slat_color)
		draw_rect(Rect2(0.0, y + 3.0, size.x, 1.0), slat_color.darkened(0.45))
		y += 4.0
	if shown > 4.0:
		draw_rect(Rect2(0.0, shown - 3.0, size.x, 3.0), slat_color.lightened(0.15))   # 底边
	# 顶上的卷轴箱 + 状态灯
	draw_rect(Rect2(-3.0, -6.0, size.x + 6.0, 7.0), rail_color)
	draw_rect(Rect2(-3.0, -6.0, size.x + 6.0, 1.0), rail_color.lightened(0.2))
	var lamp: Color = lamp_open if _open >= 1.0 else lamp_closed
	draw_rect(Rect2(size.x * 0.5 - 1.5, -4.5, 3.0, 3.0), lamp)
	draw_rect(Rect2(size.x * 0.5 - 3.5, -6.5, 7.0, 7.0), Color(lamp, 0.15))
