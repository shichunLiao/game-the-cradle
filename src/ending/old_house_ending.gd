class_name OldHouseEnding
extends Node2D
## 结局 · 旧屋门口: 高塔灯灭。天空安静。两人坐在门口。
##
## Then the black card: 「大陆睡着了。它累了很久。」 — 叙事脚本.md, verbatim.
##
## Pure presentation. No input, no fail state, nothing to lose. The only warm
## light in the game lives here and on the photo/pendant (美术规格.md §2).
##
## ## 高塔灯灭(2026-10-12)
## 门口看出去是塔外的夜景(`SkylineBackdrop`,和屋顶关、塔里的窗同一片)。一路上一直看得见的那道
## 坑口紫光柱先慢慢熄掉 —— Ryn 切断了方舟;然后中央高塔、军事塔、登记塔、精炼塔、出生地塔的灯
## 一座一座暗下去;灯全灭,星星亮起来(没了光害),风也慢下来。停一会儿,再黑场出字。
##
## 等待都挂在自己下面的 Timer 上,离开场景树时「敲响」它们 —— 演出途中关游戏不留协程(同 `EndingSequence`)。

## 叙事脚本.md 结局, verbatim.
const CARD_LINE: String = "大陆睡着了。它累了很久。"
## 熄灯顺序:中央高塔(方舟)先灭,最后是出生地 —— Ryn 走过来的反方向。
const LIGHTS_OUT_ORDER: Array[int] = [4, 3, 2, 1, 0]

@export var config: EndingConfig
@export var font: TowerSubtitleConfig
@export var skyline: SkylineBackdrop
@export var ambient: AmbientBed
## 结局配乐(姐姐动机的大调版)。黑场出字后慢慢淡掉。
@export var music: MusicPlayer
## 开场先停多久,秒。
@export var hold_scene: float = 1.5
## 坑口紫光熄掉用多久,秒。
@export var crater_fade: float = 3.0
## 每座塔熄灯的间隔、每盏灯暗下去用多久,秒。
@export var tower_gap: float = 0.8
@export var tower_fade: float = 1.0
## 灯全灭之后再看多久,秒(星星亮起来)。
@export var after_lights: float = 3.0
@export var fade_time: float = 2.5
@export var card_fade_in: float = 2.0

var _veil: ColorRect
var _card: Label
var _dying: bool = false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Color(Color("0B1220"), 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_veil)
	_card = Label.new()
	_card.text = CARD_LINE
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	if font != null:
		var face := SystemFont.new()
		face.font_names = font.font_names
		_card.add_theme_font_override(&"font", face)
		_card.add_theme_font_size_override(&"font_size", 32)
	_card.add_theme_color_override(&"font_color", Color("C8D4E0"))
	_card.modulate.a = 0.0
	layer.add_child(_card)
	_run.call_deferred()


func _exit_tree() -> void:
	_dying = true
	for c in get_children():
		var t := c as Timer
		if t != null and not t.is_stopped():
			t.stop()
			t.timeout.emit()


func _run() -> void:
	await _wait(hold_scene)
	if _dying:
		return
	# 方舟停了:坑口的紫光先熄
	if skyline != null:
		create_tween().tween_property(skyline, ^"crater_level", 0.0, crater_fade)
	await _wait(crater_fade)
	if _dying:
		return
	# 塔灯一座一座暗下去
	for t in LIGHTS_OUT_ORDER:
		if skyline != null:
			var tower: int = t
			create_tween().tween_method(func(v: float) -> void: skyline.set_tower_light(tower, v), 1.0, 0.0, tower_fade)
		await _wait(tower_gap)
		if _dying:
			return
	await _wait(tower_fade)
	if _dying:
		return
	if ambient != null:
		ambient.fall_asleep()
	await _wait(after_lights)
	if _dying:
		return
	create_tween().tween_property(_veil, ^"color:a", 1.0, fade_time)
	await _wait(fade_time)
	if _dying:
		return
	create_tween().tween_property(_card, ^"modulate:a", 1.0, card_fade_in)
	if music != null:
		await _wait(card_fade_in + 4.0)
		if _dying:
			return
		music.fade_out(6.0)


func _wait(seconds: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(seconds, 0.05)
	add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()
