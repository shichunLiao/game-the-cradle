class_name StoryTrigger
extends Area2D
## Ryn 走进这块区域时,底部字幕出一句话。只出一次。
##
## 叙事脚本.md:每塔「入塔一句 → **关中 0–1 句环境旁白** → 出塔一句」,入塔、出塔由
## `TowerLevel` 管,关中这一句由它管。塔放大三倍之后(2026-10-11),中段需要一句话把节奏撑住。
## 不夺走操作,只是一行字(和入塔句同一个 `TowerSubtitle`),符合「不打断潜行超过 3 秒」。
## 被发现、回存档点之后不会再出。
##
## 节点原点是 **左上角**,与 `GrayBlock` / `ShadowZone` 一致。
##
## Usage (in a scene): 设 `position`、`size`、`text`,`subtitle` 指向关卡的 `TowerSubtitle`。
## 关卡由 `tools/level_builder` 生成时用 `lv.story(...)` 放。

## 触发区大小,px。
@export var size: Vector2 = Vector2(64.0, 48.0)
## 这一句。
@export_multiline var text: String = ""
## 进入后等多久再出字,秒 —— 刚爬上来就出字会和落地声挤在一起。
@export var delay: float = 0.5
@export var subtitle: TowerSubtitle

var _done: bool = false


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
	body_entered.connect(_on_body_entered)


## 已经出过字了吗。
func is_done() -> bool:
	return _done


func _on_body_entered(body: Node2D) -> void:
	if _done or body is not Ryn or text.is_empty():
		return
	_done = true
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if is_inside_tree():
		StoryTrigger.say(subtitle, text)


## 出一句字幕,带入塔句同款的提示音。`subtitle` 为空时什么也不做。
static func say(on: TowerSubtitle, line: String) -> void:
	if on == null or line.is_empty():
		return
	on.show_line(line)
	Audio.play(&"subtitle", -16.0)
