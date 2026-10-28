class_name TowerExit
extends Area2D
## The way out of a tower. Ryn touching it ends the level.
##
## Fires once: re-entering after the exit line has started changes nothing.
##
## Usage (in a scene): instance, set `size`, point `level` at the tower root.

@export var size: Vector2 = Vector2(32.0, 48.0):
	set(value):
		size = value
		_apply_shape()
		queue_redraw()
@export var level: TowerLevel
@export var marker_color: Color = Color("3D6B8A")

var _shape: RectangleShape2D
var _collider: CollisionShape2D
var _used: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	_collider = CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	_collider.shape = _shape
	add_child(_collider)
	_apply_shape()
	body_entered.connect(_on_body_entered)


func _apply_shape() -> void:
	if _shape == null or _collider == null:
		return
	_shape.size = size
	# Origin is the bottom-left (feet height), matching GrayBlock/Checkpoint.
	_collider.position = Vector2(size.x * 0.5, -size.y * 0.5)


func _draw() -> void:
	var rect := Rect2(Vector2(0.0, -size.y), size)
	draw_rect(rect, marker_color, false, 1.0)
	draw_line(Vector2(0.0, -size.y * 0.5), Vector2(size.x, -size.y * 0.5), marker_color, 1.0)


func _on_body_entered(body: Node2D) -> void:
	if _used or body is not Ryn or level == null:
		return
	_used = true
	level.leave()
