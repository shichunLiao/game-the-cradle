class_name PrologueProp
extends Area2D
## 序章里可查看的物件(合影)。靠近出提示,按 E 打开静帧。
##
## 与 `Dismantlable` 不同:这个 **不是按住**,是点一下就开。序章没有压力,
## 不该让玩家先学会"按住"这个操作 —— 那是塔2 才教的东西。
##
## 只能触发一次(叙事脚本:照片序章持有一次、终局使用一次)。

signal viewed

@export var size: Vector2 = Vector2(40.0, 48.0)
@export var display: PhotoDisplay
@export var font: TowerSubtitleConfig
@export var prompt_text: String = "E 看照片"
## 看完之后显示的目标提示。叙事脚本 序章「目标提示(UI 一行)」。
@export var subtitle: TowerSubtitle
@export_multiline var objective_line: String = ""
@export var prompt_color: Color = Color("C4A574")

var _shape: RectangleShape2D
var _label: Label
var _near: bool = false
var _used: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	var col := CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	_shape.size = size
	col.shape = _shape
	col.position = Vector2(size.x * 0.5, -size.y * 0.5)
	add_child(col)

	_label = Label.new()
	_label.text = KeyBindings.with_key(prompt_text)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		var face := SystemFont.new()
		face.font_names = font.font_names
		_label.add_theme_font_override(&"font", face)
	_label.add_theme_font_size_override(&"font_size", 10)
	_label.add_theme_color_override(&"font_color", prompt_color)
	_label.add_theme_constant_override(&"outline_size", 3)
	_label.add_theme_color_override(&"font_outline_color", Color("0B1220"))
	_label.size = Vector2(size.x + 40.0, 14.0)
	_label.position = Vector2(-20.0, -size.y - 18.0)
	_label.visible = false
	add_child(_label)

	if display != null:
		display.closed.connect(_on_closed)


func _physics_process(_delta: float) -> void:
	if _used:
		return
	var near: bool = false
	for b in get_overlapping_bodies():
		if b is Ryn:
			near = true
			break
	if near != _near:
		_near = near
		_label.visible = near
	if near and Input.is_action_just_pressed(&"interact") and display != null:
		_used = true
		_label.visible = false
		display.show_photo()


func _on_closed() -> void:
	viewed.emit()
	# 看完照片才给目标 —— 先有理由,再有任务。
	if subtitle != null and not objective_line.is_empty():
		subtitle.show_line(objective_line)
