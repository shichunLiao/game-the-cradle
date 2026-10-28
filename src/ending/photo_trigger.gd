class_name PhotoTrigger
extends Area2D
## 坑底: the spot where Ryn can raise the photograph.
##
## 叙事脚本.md 刻意不写: 「照片只在序章持有 + 终局使用各一次」 — so this fires
## exactly once and then never prompts again.
##
## Usage: instance in pit_bottom, point `ending` at the EndingSequence.

signal photo_raised

@export var size: Vector2 = Vector2(72.0, 56.0):
	set(value):
		size = value
		_apply_shape()
@export var config: EndingConfig
@export var prompt_font: TowerSubtitleConfig

var _shape: RectangleShape2D
var _collider: CollisionShape2D
var _label: Label
var _in_reach: bool = false
var _used: bool = false
var _armed: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	_collider = CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	_collider.shape = _shape
	add_child(_collider)
	_apply_shape()
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if prompt_font != null:
		var face := SystemFont.new()
		face.font_names = prompt_font.font_names
		_label.add_theme_font_override(&"font", face)
		_label.add_theme_font_size_override(&"font_size", 20)
	if config != null:
		_label.text = KeyBindings.with_key(config.photo_prompt)
		_label.add_theme_color_override(&"font_color", config.warm)
	_label.size = Vector2(size.x, 24.0)
	_label.position = Vector2(0.0, -size.y - 26.0)
	_label.visible = false
	add_child(_label)


func _apply_shape() -> void:
	if _shape == null or _collider == null:
		return
	_shape.size = size
	_collider.position = Vector2(size.x * 0.5, -size.y * 0.5)


## Until armed, standing here shows nothing: the photo is only raised once Vera
## has spoken (叙事脚本 order), not the moment Ryn walks in.
func arm() -> void:
	_armed = true


func _physics_process(_delta: float) -> void:
	if _used or not _armed:
		return
	var near: bool = false
	for body in get_overlapping_bodies():
		if body is Ryn:
			near = true
			break
	if near != _in_reach:
		_in_reach = near
		_label.visible = near
	if near and Input.is_action_just_pressed(&"interact"):
		_used = true
		_label.visible = false
		photo_raised.emit()
