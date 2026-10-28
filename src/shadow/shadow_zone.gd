class_name ShadowZone
extends Area2D
## A DESIGN-MARKED dark region. While the point a guard looks at sits inside
## one, that guard cannot see it — 暗处优先.
##
## Implements `production/epics/the-cradle/story-004-darkness-detection.md`
## (AC: 场景可标记暗区 + 暗区边界有可读的视觉提示). Story 006 owns WHERE zones go.
##
## Darkness here is AUTHORED, not sampled. `美术规格.md`'s 暗处 is a gameplay
## space a level designer places, not a brightness read back out of the
## renderer: inferring it from rendered pixels would hand authorship to the
## lighting and make the rule unpredictable. So a zone is a rectangle someone
## drew on purpose.
##
## Node origin is the TOP-LEFT corner, matching `GrayBlock`, so positions and
## sizes line up on the 16 px grid. No rotation and no scale: `global_rect()`
## assumes both, because the rule has to equal the drawing.
##
## Zones do not know about guards. They add themselves to `GROUP` and
## `ShadowRegistry` pulls the group, so a level can place them freely and
## nothing needs wiring by hand.
##
## Usage (in a scene): instance `shadow_zone.tscn`, set `position` and `size`.
## Usage (in code):
##     var z := ShadowZone.new()
##     z.config = load("res://assets/data/shadow_default.tres")
##     z.size = Vector2(80, 32)
##     z.position = Vector2(1210, 288)
##     add_child(z)

## Group every shadow zone joins so the registry can find it.
const GROUP: StringName = &"shadow_zone"

## Zone size in px. Grows right and down from the origin.
@export var size: Vector2 = Vector2(64.0, 32.0):
	set(value):
		size = value
		_sync_shape()
		queue_redraw()

## Drawing and margin tuning. Required to draw; an unset config draws nothing
## but still hides (the rule is geometry, not paint).
@export var config: ShadowConfig:
	set(value):
		config = value
		queue_redraw()

var _shape: RectangleShape2D
var _collider: CollisionShape2D


func _ready() -> void:
	# Present in the physics world but inert: nothing queries it today. The
	# darkness test is pure Rect2 maths (ShadowQuery), which keeps it allocation
	# free on the guard's per-tick path and usable outside a physics callback.
	# `monitorable` stays on so a later "you are hidden" cue can sense a zone.
	collision_layer = PhysicsLayers.SHADOW
	collision_mask = 0
	monitoring = false
	monitorable = true
	_shape = RectangleShape2D.new()
	_collider = CollisionShape2D.new()
	_collider.shape = _shape
	add_child(_collider)
	_sync_shape()
	add_to_group(GROUP)


## The zone in world space. Exactly the rectangle `_draw` paints, which is what
## makes the visible boundary the real boundary.
##
## Usage: `rects.append(zone.global_rect())`
func global_rect() -> Rect2:
	return Rect2(global_position, size)


func _sync_shape() -> void:
	if _shape == null or _collider == null:
		return
	_shape.size = size
	_collider.position = size * 0.5


## 2026-10-13 细致化:用 `canvas_shadow_zone.gdshader` 画(边缘抖点渐暗、墙砖透得出来、脚下地板也暗),
## 不再画虚线框和四角括号。和别的暗区相邻的那一边不软(开场等一帧,所有暗区都进了树再看邻居)。
const SHADER: Shader = preload("res://src/shadow/canvas_shadow_zone.gdshader")

var _mat: ShaderMaterial
var _floor: Node2D
## 下面贴着别的暗区:不画地板那一条。
var _floor_skip: bool = false


func _enter_tree() -> void:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		material = _mat
		_floor = Node2D.new()
		_floor.name = "FloorShade"
		_floor.z_as_relative = false
		_floor.z_index = 2          # 压在实心块(z 1)上面:暗处脚下那条地板顶
		_floor.material = ShaderMaterial.new()
		(_floor.material as ShaderMaterial).shader = SHADER
		_floor.draw.connect(_draw_floor)
		add_child(_floor)
		_neighbours.call_deferred()
	_apply_uniforms(Vector4(1.0, 1.0, 1.0, 0.0))


## 看四边有没有贴着别的暗区:贴着的那一边不软。
func _neighbours() -> void:
	if not is_inside_tree():
		return
	var r := global_rect()
	var soft := Vector4(1.0, 1.0, 1.0, 0.0)
	for n in get_tree().get_nodes_in_group(GROUP):
		var z := n as ShadowZone
		if z == null or z == self or not z.is_visible_in_tree():
			continue
		var o := z.global_rect()
		var v_overlap: bool = o.position.y < r.end.y - 0.5 and o.end.y > r.position.y + 0.5
		var h_overlap: bool = o.position.x < r.end.x - 0.5 and o.end.x > r.position.x + 0.5
		if v_overlap and absf(o.end.x - r.position.x) < 1.0:
			soft.x = 0.0
		if v_overlap and absf(o.position.x - r.end.x) < 1.0:
			soft.y = 0.0
		if h_overlap and absf(o.end.y - r.position.y) < 1.0:
			soft.z = 0.0
		if h_overlap and absf(o.position.y - r.end.y) < 1.0:
			soft.w = 1.0           # 下面还是暗区:不画地板那一条(那不是地板)
	_apply_uniforms(soft)


func _apply_uniforms(soft: Vector4) -> void:
	if _mat == null or config == null:
		return
	var fmat := _floor.material as ShaderMaterial
	for m in [_mat, fmat]:
		m.set_shader_parameter(&"size", size)
		m.set_shader_parameter(&"tint", config.fill_color)
		m.set_shader_parameter(&"core_alpha", config.fill_alpha)
		m.set_shader_parameter(&"bottom_extra", config.bottom_extra)
		m.set_shader_parameter(&"edge_px", config.soft_edge_px)
		m.set_shader_parameter(&"soft", soft)
		m.set_shader_parameter(&"floor_px", config.floor_px)
		m.set_shader_parameter(&"floor_alpha", config.floor_alpha)
	_mat.set_shader_parameter(&"floor_mode", 0)
	fmat.set_shader_parameter(&"floor_mode", 1)
	_floor_skip = soft.w > 0.5
	_floor.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if config == null or size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


## 地板顶上那一条:暗区底边往下 `floor_px`。
func _draw_floor() -> void:
	if config == null or _floor_skip or size.x <= 0.0:
		return
	_floor.position = Vector2(0.0, size.y)
	_floor.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, config.floor_px)), Color.WHITE)
