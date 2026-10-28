class_name DropBridge
extends Node2D
## 被链条拉起来的吊桥(2026-10-12 谜题房,塔1「断桥」、塔4)。
##
## 桥竖着立在对岸(铰链那头),一根链条从桥尖斜拉到这边墙上的锚(`panel`,一块 `Dismantlable` PANEL,
## 链条锚的样子)。长按 E 拆掉锚 → 链子一松,桥倒下来搭上缺口,砸地那一下很响(`noise_radius`)——
## 附近的守卫会过来看。一次性;回存档点时跟着锚一起回到原样。
##
## 节点原点是 **铰链**:桥放下来时桥面的左上角(`hinge_left`)或右上角。放下来之后的碰撞 = 桥面那一行
## 格子(`length` × 16px),和关卡生成器里那一行 `B` 一致。
##
## Usage (in a scene): 设 `position`、`length`、`hinge_left`、`panel`、`anchor`(锚的世界坐标)。
## 关卡由 `tools/level_builder` 用 `lv.drawbridge(...)` 放。

@export var length: float = 192.0:
	set(value):
		length = value
		_sync_shape()
		queue_redraw()
## 铰链在左端(放下来往右伸);false = 在右端(往左伸)。
@export var hinge_left: bool = true
@export var panel: Dismantlable
## 链条拉到哪里(世界坐标,一般是锚的中心)。
@export var anchor: Vector2 = Vector2.ZERO
## 倒下来要多久,秒。
@export var fall_time: float = 0.55
## 砸下来的声音传多远,px。
@export var noise_radius: float = 260.0
@export var deck_color: Color = Color("24344C")
@export var truss_color: Color = Color("16233A")
@export var chain_color: Color = Color("3D6B8A")

const TILE: float = 16.0
## 和 `GrayBlock.TOP_EDGE_COLOR` 同一个色:「这能站」。
const TOP_EDGE: Color = Color("3D6B8A")

## 1 = 竖着(拉起来),0 = 放平。
var _up: float = 1.0
var _falling: bool = false
var _fall_t: float = 0.0
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
	_col.disabled = true
	_body.add_child(_col)
	add_child(_body)
	_sync_shape()
	if panel != null:
		panel.panel_dismantled.connect(func(_n: int) -> void: drop())
		panel.panel_restored.connect(_on_restored)


## 放下来了吗(能走了)。
func is_down() -> bool:
	return _up <= 0.0 and not _falling


## 链子断了,桥倒下来(锚被拆时调;验证脚本也可以直接调)。
func drop() -> void:
	if _falling or _up <= 0.0:
		return
	_falling = true
	_fall_t = 0.0


func _on_restored(opened: bool) -> void:
	_falling = false
	_up = 0.0 if opened else 1.0
	_col.set_deferred(&"disabled", not opened)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _falling:
		return
	_fall_t += delta
	var k: float = clampf(_fall_t / maxf(fall_time, 0.01), 0.0, 1.0)
	_up = 1.0 - k * k                     # 越倒越快
	if k >= 1.0:
		_falling = false
		_up = 0.0
		_col.set_deferred(&"disabled", false)
		Audio.play(&"bridge_crash", -4.0)
		var bus := get_node_or_null(^"/root/Noise")
		if bus != null:
			bus.emit_noise(global_position + Vector2(length * 0.5 * _dir(), 0.0), noise_radius)
		var shake := get_viewport().get_camera_2d().get_node_or_null(^"CameraShake") if get_viewport().get_camera_2d() != null else null
		if shake != null and shake.has_method(&"shake"):
			shake.call(&"shake", 0.5)
	queue_redraw()


func _dir() -> float:
	return 1.0 if hinge_left else -1.0


func _sync_shape() -> void:
	if _shape == null or _col == null:
		return
	_shape.size = Vector2(length, TILE)
	_col.position = Vector2(length * 0.5 * _dir(), TILE * 0.5)


## 桥面上一点(放平时的坐标 x 沿桥、y 往下)转到现在的角度。
func _rot(p: Vector2) -> Vector2:
	var a: float = -_up * PI * 0.5 * _dir()
	return p.rotated(a)


func _draw() -> void:
	var d: float = _dir()
	# 桥面:6px 厚的板 + 下面一道桁架,每 8px 一道板缝
	var deck := PackedVector2Array([_rot(Vector2.ZERO), _rot(Vector2(length * d, 0.0)),
			_rot(Vector2(length * d, 8.0)), _rot(Vector2(0.0, 8.0))])
	draw_colored_polygon(deck, deck_color)
	var x: float = 8.0
	while x < length:
		draw_line(_rot(Vector2(x * d, 2.0)), _rot(Vector2(x * d, 8.0)), deck_color.darkened(0.4), 1.0)
		x += 8.0
	# 桥面顶上那条亮边和所有平台一样(`GrayBlock.TOP_EDGE_COLOR`)—— 放下来一眼看得出「能走了」
	draw_line(_rot(Vector2(0.0, 0.5)), _rot(Vector2(length * d, 0.5)), TOP_EDGE, 1.0)
	draw_line(_rot(Vector2(0.0, 11.0)), _rot(Vector2(length * d, 11.0)), truss_color, 2.0)
	var t: float = 0.0
	while t < length - 8.0:
		draw_line(_rot(Vector2(t * d, 8.0)), _rot(Vector2((t + 8.0) * d, 11.0)), truss_color, 1.0)
		t += 16.0
	draw_circle(Vector2.ZERO, 2.5, truss_color.lightened(0.2))     # 铰链
	# 链条:没断时从桥尖拉到锚;断了在桥尖垂下一截
	var tip: Vector2 = _rot(Vector2(length * d, 0.0))
	if _up >= 1.0 and not _falling:
		var to: Vector2 = to_local(anchor)
		var n: int = maxi(int(tip.distance_to(to) / 3.0), 1)
		for i in n:
			var p: Vector2 = tip.lerp(to, float(i) / float(n))
			draw_rect(Rect2(p - Vector2(1.0, 1.0), Vector2(2.0, 2.0)) if i % 2 == 0 else Rect2(p, Vector2(1.0, 1.0)), chain_color)
	else:
		for i in 4:
			draw_rect(Rect2(tip + Vector2(0.0, 2.0 + i * 3.0) - Vector2(1.0, 0.0), Vector2(2.0, 2.0)), chain_color)
