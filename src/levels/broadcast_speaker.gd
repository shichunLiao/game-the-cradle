class_name BroadcastSpeaker
extends Node2D
## 墙上的广播喇叭(2026-10-12,线索链):Ryn 走进触发区,「叮——咚」一声,喇叭一圈圈震,
## 底下出一行冷青色的广播字幕(不是 Ryn 的话,颜色不一样、没有「」)。
##
## 塔2:「〔广播〕V-11 到 V-20 号，零点到坑口转运站集合。」—— 之后捡到工装,工号 V-17 就在这个
## 范围里,玩家自己把两件事接起来:她被调去坑口了。
##
## 只播一次;不夺走操作。节点原点是喇叭挂在墙上的那一点。
##
## Usage (in a scene): 设 `position`、`text`、`trigger_rect`(相对原点,px),`subtitle` 指向关卡的
## `TowerSubtitle`。关卡由 `tools/level_builder` 生成时用 `lv.broadcast(...)` 放。

## 广播的那一句(带「〔广播〕」前缀)。
@export_multiline var text: String = ""
@export var subtitle: TowerSubtitle
## 触发区,相对节点原点,px。
@export var trigger_rect: Rect2 = Rect2(-64.0, 0.0, 128.0, 96.0)
## 提示音之后多久出字,秒(先「叮——咚」,再说话)。
@export var speak_delay: float = 0.9
## 字幕停多久,秒(长句)。
@export var hold_time: float = 4.2
@export var body_color: Color = Color("2A3446")
@export var rim_color: Color = Color("3D6B8A")
@export var wave_color: Color = Color("8FB8C8")

var _played: bool = false
var _talk: float = -1.0
var _time: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -1
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = PhysicsLayers.PLAYER
	area.monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = trigger_rect.size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = trigger_rect.position + trigger_rect.size * 0.5
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


## 播过了吗(验证脚本用)。
func is_done() -> bool:
	return _played


## 直接开播(验证脚本用;正常由触发区开播)。
func play() -> void:
	if _played:
		return
	_played = true
	_talk = 0.0
	Audio.play(&"pa_chime", -14.0)
	await get_tree().create_timer(speak_delay).timeout
	if is_inside_tree() and subtitle != null:
		subtitle.show_line(text, TowerSubtitle.Tone.BROADCAST, hold_time)


func _process(delta: float) -> void:
	_time += delta
	if _talk >= 0.0:
		_talk += delta
		if _talk > speak_delay + hold_time + 0.8:
			_talk = -1.0
	queue_redraw()


func _draw() -> void:
	# 托架 + 喇叭口(朝右下张开的梯形)
	draw_rect(Rect2(-1.0, -2.0, 3.0, 6.0), body_color.darkened(0.3))
	draw_rect(Rect2(1.0, 0.0, 4.0, 3.0), body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(4.0, -1.0), Vector2(13.0, -5.0),
			Vector2(13.0, 8.0), Vector2(4.0, 4.0)]), body_color)
	draw_line(Vector2(13.0, -5.0), Vector2(13.0, 8.0), rim_color, 1.0)
	draw_line(Vector2(4.0, -1.0), Vector2(13.0, -5.0), body_color.lightened(0.15), 1.0)
	# 线缆往上走
	draw_rect(Rect2(0.0, -14.0, 1.0, 12.0), body_color.darkened(0.2))
	# 播的时候:喇叭口前一圈圈的声波
	if _talk < 0.0:
		return
	for i in 3:
		var k: float = fposmod(_time * 1.6 + float(i) / 3.0, 1.0)
		var r: float = 6.0 + k * 14.0
		draw_arc(Vector2(13.0, 1.5), r, -0.7, 0.7, 10, Color(wave_color, 0.45 * (1.0 - k)), 1.0)


func _on_body_entered(body: Node2D) -> void:
	if body is Ryn:
		play()
