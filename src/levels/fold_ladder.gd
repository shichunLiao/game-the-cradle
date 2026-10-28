class_name FoldLadder
extends Ladder
## 收折梯(2026-10-15 用户:新加的替代路线梯子「要有一定的解谜环节才能用」)。
##
## 平时收在上面:楼板上的洞口盖着盖板(实心,上下都过不去),梯子折成一捆挂在盖板底下,
## 一条链子拉到墙上的链条锚(`panel`)。拆锚 → 盖板打开、梯子往下放,砸到地上有声音
## (`noise_radius`,附近的守卫会过来看 —— 要挑时机,放完赶快爬或先躲)。放下来以后就是普通梯子。
## 读档时跟着面板复原(`panel_restored`)。关卡生成器 `Level.fold_ladder` 用同一条规则算路线。
##
## Usage(由 tools/level_builder 写进关卡):position / size 同 `Ladder`,另给 panel、slab_px、anchor。

## 拆这块面板(链条锚)放梯子。
@export var panel: Dismantlable
## 楼板那一截有多高,px(盖板的高度)。
@export var slab_px: float = 32.0
## 链条锚的世界坐标(画链子用)。
@export var anchor: Vector2 = Vector2.ZERO
## 梯子砸到地的声音传多远,px。
@export var noise_radius: float = 220.0
## 从收着到放到底要多久,秒。
@export var drop_time: float = 0.6
@export var hatch_color: Color = Color("24344C")
@export var chain_color: Color = Color("3D6B8A")

## 折起来的那一捆有多高,px。
const BUNDLE_PX: float = 10.0

var _open: float = 0.0          # 0 收着 → 1 放到底
var _dropping: bool = false
var _t: float = 0.0
var _hatch: CollisionShape2D


func _ready() -> void:
	super()
	var body := StaticBody2D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x, maxf(slab_px, 4.0))
	_hatch = CollisionShape2D.new()
	_hatch.shape = shape
	_hatch.position = shape.size * 0.5
	body.add_child(_hatch)
	add_child(body)
	if panel != null:
		panel.panel_dismantled.connect(func(_n: int) -> void: unfold())
		panel.panel_restored.connect(_on_restored)
	_apply(false)


## 放下来了吗(能爬了)。
func is_open() -> bool:
	return _open >= 1.0 and not _dropping


## 链条锚被拆:盖板打开、梯子往下放(验证脚本也可以直接调)。
func unfold() -> void:
	if _dropping or _open >= 1.0:
		return
	_dropping = true
	_t = 0.0
	_hatch.set_deferred(&"disabled", true)
	Audio.play(&"shutter_roll", -10.0)


func _on_restored(opened: bool) -> void:
	_dropping = false
	_open = 1.0 if opened else 0.0
	_apply(opened)


## 能不能抓、盖板挡不挡。
func _apply(opened: bool) -> void:
	collision_layer = PhysicsLayers.LADDER if opened else 0
	_hatch.set_deferred(&"disabled", opened)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _dropping:
		return
	_t += delta
	var k: float = clampf(_t / maxf(drop_time, 0.01), 0.0, 1.0)
	_open = k * k                          # 越放越快
	if k >= 1.0:
		_dropping = false
		_open = 1.0
		_apply(true)
		Audio.play(&"bridge_crash", -8.0)
		var bus := get_node_or_null(^"/root/Noise")
		if bus != null:
			bus.emit_noise(global_position + Vector2(size.x * 0.5, size.y), noise_radius)
		var cam := get_viewport().get_camera_2d()
		var shake := cam.get_node_or_null(^"CameraShake") if cam != null else null
		if shake != null and shake.has_method(&"shake"):
			shake.call(&"shake", 0.3)
	queue_redraw()


func _draw() -> void:
	if _open > 0.0:
		_draw_ladder(lerpf(slab_px + BUNDLE_PX, size.y, _open))
		return
	var dark := hatch_color.darkened(0.4)
	var lit := hatch_color.lightened(0.25)
	# 盖板:和楼板齐平的一块铁板,两颗铆钉
	draw_rect(Rect2(0.0, 0.0, size.x, slab_px), hatch_color)
	draw_rect(Rect2(0.0, 0.0, size.x, 1.0), lit)
	draw_rect(Rect2(0.0, slab_px - 1.0, size.x, 1.0), dark)
	draw_rect(Rect2(3.0, 3.0, 1.0, 1.0), lit)
	draw_rect(Rect2(size.x - 4.0, 3.0, 1.0, 1.0), lit)
	# 折起来的一捆:两根短立柱 + 叠在一起的横档
	var y0: float = slab_px
	draw_rect(Rect2(0.0, y0, RAIL_W, BUNDLE_PX), RAIL_COLOR)
	draw_rect(Rect2(size.x - RAIL_W, y0, RAIL_W, BUNDLE_PX), RAIL_COLOR)
	var y: float = y0 + 1.0
	while y < y0 + BUNDLE_PX - 1.0:
		draw_rect(Rect2(RAIL_W, y, size.x - RAIL_W * 2.0, 1.0), RAIL_COLOR.lightened(0.15))
		y += 3.0
	# 链子:从那一捆拉到墙上的链条锚,一节一节
	if anchor != Vector2.ZERO:
		var a := Vector2(size.x * 0.5, y0 + BUNDLE_PX)
		var b := to_local(anchor)
		var n: int = int(a.distance_to(b) / 3.0)
		for i in n + 1:
			var p: Vector2 = a.lerp(b, float(i) / maxf(float(n), 1.0)).floor()
			draw_rect(Rect2(p, Vector2(2.0, 2.0) if i % 2 == 0 else Vector2(1.0, 1.0)), chain_color)
