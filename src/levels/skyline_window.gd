class_name SkylineWindow
extends Node2D
## 塔里墙上的一扇窗 / 一个破口:透过它看到塔外的夜景(`SkylineBackdrop` 裁成这一块)。
##
## 2026-10-12 用户要「在塔内开窗」。每扇窗看出去是同一片连续的景(按关卡的 `level_rect` 算视差),
## 走过一排窗,远处的塔会跟着慢慢移;越往上爬,窗里的地平线越低、天越多。
##
## 两种样子:
##  - `WINDOW`:石框窗,中间一两根铁栏,窗台下一小片冷光;
##  - `BREACH`:墙塌了一块,边缘参差(塔顶、坑口用,开得大,配远景镜头)。
##
## 画在塔内背景(z -100)之上、实心块和角色之下(z -60):它是「后墙上的洞」。
## 用 `clip_children` 把整片夜景裁成窗的形状,所以夜景不会画到窗外去。
##
## 节点原点是 **左上角**。
##
## Usage (in a scene): 设 `position`、`size`、`level_rect`(同关卡)、`kind`。
## 关卡由 `tools/level_builder` 生成时用 `lv.window(...)` 放。

enum Kind { WINDOW, BREACH }

@export var size: Vector2 = Vector2(48.0, 64.0)
@export var kind: Kind = Kind.WINDOW
## 整关的世界矩形(和关卡里别的窗、背景一致,景才连得上)。
@export var level_rect: Rect2 = Rect2(0, 0, 1920, 2400)
## 要去的那座塔(0..4),窗里它的灯更亮;-1 = 不强调。
@export_range(-1, 4) var focus_tower: int = -1
## 全景转多少(同 `SkylineBackdrop.pan`;同一关要一样)。
@export var pan: float = 0.0
## 地平线在画面多高(同 `SkylineBackdrop.horizon`;塔里 0.5 = Ryn 眼睛的高度,窗里看得到远处的塔)。
@export_range(0.0, 1.0) var horizon: float = 0.5
@export var seed_value: int = 7
## 石框 / 破口边缘的颜色。
@export var frame_color: Color = Color("1A2A44")
## 窗台下那片冷光。
@export var spill_color: Color = Color(0.239, 0.42, 0.541, 0.07)

var _mask: Node2D
var _frame: Node2D
var _sky: SkylineBackdrop
var _edge: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	z_index = -60
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if kind == Kind.BREACH:
		_edge = _ragged_outline()
	_mask = Node2D.new()
	_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_mask.draw.connect(_draw_mask)
	add_child(_mask)
	_sky = SkylineBackdrop.new()
	_sky.as_background = false
	_sky.level_rect = level_rect
	_sky.focus_tower = focus_tower
	_sky.pan = pan
	_sky.horizon = horizon
	_sky.seed_value = seed_value
	_sky.show_near = false
	_mask.add_child(_sky)
	_frame = Node2D.new()
	_frame.draw.connect(_draw_frame)
	add_child(_frame)


## 窗的形状:窗是矩形,破口是参差的多边形。
func _draw_mask() -> void:
	if kind == Kind.BREACH:
		_mask.draw_colored_polygon(_edge, Color.WHITE)
	else:
		_mask.draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


func _draw_frame() -> void:
	if kind == Kind.BREACH:
		# 破口边缘:一圈 2px 的断砖
		for i in _edge.size():
			var a: Vector2 = _edge[i]
			var b: Vector2 = _edge[(i + 1) % _edge.size()]
			_frame.draw_line(a, b, frame_color, 2.0)
		return
	# 石框:四边 3px,窗台再厚一点、往外伸
	var f := frame_color
	_frame.draw_rect(Rect2(-3.0, -3.0, size.x + 6.0, 3.0), f)
	_frame.draw_rect(Rect2(-3.0, 0.0, 3.0, size.y), f)
	_frame.draw_rect(Rect2(size.x, 0.0, 3.0, size.y), f)
	_frame.draw_rect(Rect2(-5.0, size.y, size.x + 10.0, 4.0), f)
	_frame.draw_rect(Rect2(-5.0, size.y, size.x + 10.0, 1.0), f.lightened(0.25))
	# 铁栏:一根竖的,宽窗两根
	var bars: int = 1 if size.x < 64.0 else 2
	for i in bars:
		var bx: float = size.x * float(i + 1) / float(bars + 1)
		_frame.draw_rect(Rect2(bx - 1.0, 0.0, 2.0, size.y), f.darkened(0.2))
	_frame.draw_rect(Rect2(0.0, size.y * 0.5 - 1.0, size.x, 2.0), f.darkened(0.2))
	# 窗台下一小片冷光(月光透进来)
	var spill := PackedVector2Array([Vector2(0.0, size.y + 4.0), Vector2(size.x, size.y + 4.0),
			Vector2(size.x + 14.0, size.y + 40.0), Vector2(-14.0, size.y + 40.0)])
	_frame.draw_colored_polygon(spill, spill_color)


## 破口:沿矩形四边顺时针走,边上的点随机往里缩 0..6px(按位置取种子,每次一样)。
## 四个角固定内缩 3px、角两边 8px 以内不放随机点 —— 否则角上前后两条边的点会交叉,
## 多边形三角化失败,遮罩画不出来,整个破口就看不见了(2026-10-12 截图时发现)。
func _ragged_outline() -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x) * 92821 ^ int(position.y) * 68917
	var w: float = size.x
	var h: float = size.y
	var c: float = 3.0
	var margin: float = 8.0
	var step: float = 6.0
	var pts := PackedVector2Array([Vector2(c, c)])
	var x: float = margin
	while x < w - margin:
		pts.append(Vector2(x, rng.randf_range(0.0, 6.0)))
		x += step
	pts.append(Vector2(w - c, c))
	var y: float = margin
	while y < h - margin:
		pts.append(Vector2(w - rng.randf_range(0.0, 6.0), y))
		y += step
	pts.append(Vector2(w - c, h - c))
	x = w - margin
	while x > margin:
		pts.append(Vector2(x, h - rng.randf_range(0.0, 4.0)))
		x -= step
	pts.append(Vector2(c, h - c))
	y = h - margin
	while y > margin:
		pts.append(Vector2(rng.randf_range(0.0, 6.0), y))
		y -= step
	if Geometry2D.triangulate_polygon(pts).is_empty():
		push_warning("SkylineWindow: 破口轮廓三角化失败,退回矩形")
		return PackedVector2Array([Vector2.ZERO, Vector2(w, 0.0), Vector2(w, h), Vector2(0.0, h)])
	return pts
