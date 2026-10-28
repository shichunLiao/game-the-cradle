class_name VistaZone
extends Area2D
## 远景点:Ryn 站进来,镜头慢慢拉远看全景;第一次进来时 Ryn 说一句。走出去镜头拉回来。
##
## 2026-10-12 用户:「塔外的部分让玩家感受游戏中的美景」—— Celeste、Ori 的做法:走到一个能看风景的
## 地方,镜头退开,让玩家停一下。放在安全的地方(塔顶出口前、坑口风台、屋顶的高处),
## 不放在有守卫的潜行段(拉远能看到守卫,就成了作弊)。
##
## 节点原点是 **左上角**,与 `ShadowZone` / `StoryTrigger` 一致。
##
## Usage (in a scene): 设 `position`、`size`、`zoom_level`、`offset`,`camera` 指向关卡的 `FollowCamera`。
## 关卡由 `tools/level_builder` 生成时用 `lv.vista(...)` 放。

## 区域大小,px。
@export var size: Vector2 = Vector2(96.0, 48.0)
## 拉远到多少(场景里平时是 2;1 = 看到四倍的面积,1:1 像素最清楚)。
@export var zoom_level: float = 1.0
## 镜头中心往哪儿偏,世界像素(一般往上,多看天)。
@export var offset: Vector2 = Vector2(0.0, -120.0)
## 第一次进来时说的话(可以空)。
@export_multiline var text: String = ""
## 进来多久再说话,秒(先让镜头拉开)。
@export var text_delay: float = 1.2
@export var camera: FollowCamera
@export var subtitle: TowerSubtitle

var _said: bool = false
var _pending: bool = false
var _inside: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = size * 0.5
	add_child(col)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


## Ryn 在里面吗(给验证脚本用)。
func is_inside() -> bool:
	return _inside


func _on_enter(body: Node2D) -> void:
	if body is not Ryn:
		return
	_inside = true
	if camera != null:
		camera.set_vista(zoom_level, offset)
	if not _said and not _pending and not text.is_empty():
		_pending = true
		await get_tree().create_timer(text_delay).timeout
		_pending = false
		# 站够了才说(一路跑过去的不说,下次站下来再说)
		if is_inside_tree() and _inside:
			_said = true
			StoryTrigger.say(subtitle, text)


func _on_exit(body: Node2D) -> void:
	if body is not Ryn:
		return
	_inside = false
	if camera != null:
		camera.clear_vista()
