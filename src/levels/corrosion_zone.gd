class_name CorrosionZone
extends Area2D
## 一滩蚀:地上黑紫色的稠东西,粘鞋底。Ryn 踩在里面走得慢、跑不起来;踩进深的那滩会恍惚一下。
##
## 叙事脚本.md 终局 A·下行:「蚀开始粘鞋底。Ryn 短暂恍惚,但未失忆。」
##  - **粘**:Ryn 在区域里时 `Ryn.ground_drag = drag`(地面速度乘上它;跳跃不变)。
##    0.5 时走路 105 → 52px/s;踩着蚀跑不起来(按跑步也只是走),也就没有跑步噪音。
##  - **恍惚**:进区域时叫 `CorrosionHaze.touch(haze_strength)`;第一次碰到 `haze_strength`
##    ≥ `CorrosionHaze.deep_threshold` 的那滩,屏幕重影 + 字幕「头好沉……」(只一次)。
##  - 只是减速和画面,不算被发现、不扣命;不影响守卫(守卫走在蚀里也不慢 —— 他们穿着靴子)。
##
## 节点原点是 **左上角**(与 `ShadowZone` 一致);区域底边 = 地面顶面,蚀画在底边上。
##
## Usage (in a scene): 设 `position`、`size`、`drag`、`haze_strength`,`haze` 指向关卡的 `CorrosionHaze`。
## 关卡由 `tools/level_builder` 生成时用 `lv.corrosion(...)` 放。

## 区域大小,px(高度盖住 Ryn 站着的身体即可)。
@export var size: Vector2 = Vector2(96.0, 48.0)
## 地面速度乘数(粘鞋底)。
@export_range(0.1, 1.0) var drag: float = 0.5
## 进来时恍惚多重(0 = 不恍惚)。
@export_range(0.0, 1.0) var haze_strength: float = 0.4
@export var haze: CorrosionHaze
@export var sludge_color: Color = Color("2A1538")
@export var sheen_color: Color = Color("7A58A0")
## 冒泡的间隔(每个泡),秒。
@export var bubble_period: float = 1.7
## 蚀池的深度,px(2026-10-12「蚀池放流」)。0 = 普通的一滩(糊在地上 2~4px);> 0 画成一整层这么厚的液面,
## 排放时液面往下降。
@export var pool_depth: float = 0.0

## 所有蚀区都在这个组里(两滩挨着时,出一滩要看还踩没踩着另一滩)。
const GROUP: StringName = &"corrosion_zone"

var _time: float = 0.0
var _ryn: Ryn
## 还剩多少(2026-10-12 下行关「蚀池放流」):1 = 满,0 = 排干。拖累和恍惚跟着按比例变轻。
var _level: float = 1.0
var _base_drag: float = 0.5
var _base_haze: float = 0.4


func _enter_tree() -> void:
	add_to_group(GROUP)


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
	body_exited.connect(_on_body_exited)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2   # 画在地板块(z 1)前面:蚀是糊在地面上的
	_base_drag = drag
	_base_haze = haze_strength


## 还剩多少(0..1)。
func level() -> float:
	return _level


## 排放(`CorrosionDrain` 调):k = 1 满,0 干。拖累 `drag` 从原来的值往 1 退、恍惚往 0 退;
## 干了就不再算蚀(不粘鞋、不画)。Ryn 正踩在里面时马上换成新的拖累。
func set_level(k: float) -> void:
	_level = clampf(k, 0.0, 1.0)
	drag = lerpf(1.0, _base_drag, _level)
	haze_strength = _base_haze * _level
	var dry: bool = _level <= 0.02
	visible = not dry
	set_deferred(&"monitoring", not dry)
	if _ryn != null:
		if dry:
			_on_body_exited(_ryn)
		else:
			_ryn.ground_drag = drag
	queue_redraw()


## Ryn 现在在不在这滩蚀里。
func has_ryn() -> bool:
	return _ryn != null


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var floor_y: float = size.y
	var w: float = size.x
	if pool_depth > 0.0:
		_draw_pool(floor_y, w)
		return
	# 糊在地面上的一层,边缘不齐(每 4px 一段,高 2..4px)
	var x: float = 0.0
	var i: int = 0
	while x < w:
		var seg: float = minf(4.0, w - x)
		var h: float = 2.0 + float((i * 5 + 3) % 3)
		if x < 4.0 or x > w - 8.0:
			h = 1.0 + float(i % 2)
		h = maxf(h * _level, 1.0)
		draw_rect(Rect2(x, floor_y - h, seg, h + 2.0), sludge_color)
		draw_rect(Rect2(x, floor_y - h, seg, 1.0), Color(sheen_color, 0.35))   # 表面一层油光
		x += 4.0
		i += 1
	# 一道慢慢移动的反光
	var sheen_x: float = fposmod(_time * 9.0, w + 24.0) - 12.0
	var s0: float = clampf(sheen_x, 0.0, w)
	var s1: float = clampf(sheen_x + 6.0, 0.0, w)
	if s1 > s0:
		draw_rect(Rect2(s0, floor_y - 2.0, s1 - s0, 1.0), Color(sheen_color, 0.7))
	# 冒泡:几个固定位置,鼓起 → 破掉(快排干时不冒了)
	if _level < 0.5:
		return
	var n: int = maxi(int(w / 24.0), 1)
	for b in n:
		var bx: float = 6.0 + fposmod(float(b) * 0.618034, 1.0) * maxf(w - 12.0, 1.0)
		var t: float = fposmod(_time / maxf(bubble_period, 0.1) + float(b) * 0.37, 1.0)
		if t < 0.7:
			var r: float = 1.0 + t * 2.5
			draw_rect(Rect2(bx - r, floor_y - 3.0 - r * 1.4, r * 2.0, r * 1.4), sludge_color)
			draw_rect(Rect2(bx - r * 0.4, floor_y - 3.0 - r * 1.4, 1.0, 1.0), Color(sheen_color, 0.9))
		elif t < 0.8:
			var k: float = (t - 0.7) / 0.1
			draw_rect(Rect2(bx - 3.0 - k * 2.0, floor_y - 6.0 - k * 3.0, 1.0, 1.0), Color(sheen_color, 1.0 - k))
			draw_rect(Rect2(bx + 2.0 + k * 2.0, floor_y - 6.0 - k * 3.0, 1.0, 1.0), Color(sheen_color, 1.0 - k))


## 蚀池:一整层液面(高 `pool_depth` × 剩多少),表面一道油光、几圈慢慢扩开的涟漪,偶尔冒泡。
func _draw_pool(floor_y: float, w: float) -> void:
	var h: float = maxf(pool_depth * _level, 1.0)
	var top: float = floor_y - h
	draw_rect(Rect2(0.0, top, w, h + 2.0), sludge_color)
	draw_rect(Rect2(0.0, top, w, 1.0), Color(sheen_color, 0.55))
	# 涟漪
	for i in maxi(int(w / 48.0), 1):
		var cx: float = 12.0 + fposmod(float(i) * 0.618034, 1.0) * maxf(w - 24.0, 1.0)
		var k: float = fposmod(_time * 0.35 + float(i) * 0.29, 1.0)
		var half: float = 2.0 + k * 10.0
		draw_rect(Rect2(cx - half, top, half * 2.0, 1.0), Color(sheen_color, 0.5 * (1.0 - k)))
	# 慢慢移动的反光
	var sheen_x: float = fposmod(_time * 12.0, w + 40.0) - 20.0
	var s0: float = clampf(sheen_x, 0.0, w)
	var s1: float = clampf(sheen_x + 10.0, 0.0, w)
	if s1 > s0:
		draw_rect(Rect2(s0, top + 1.0, s1 - s0, 1.0), Color(sheen_color, 0.7))
	if _level < 0.5:
		return
	for b in maxi(int(w / 32.0), 1):
		var bx: float = 6.0 + fposmod(float(b) * 0.414, 1.0) * maxf(w - 12.0, 1.0)
		var t: float = fposmod(_time / maxf(bubble_period, 0.1) + float(b) * 0.37, 1.0)
		if t < 0.6:
			var r: float = 1.0 + t * 2.5
			draw_rect(Rect2(bx - r, top - r * 1.2, r * 2.0, r * 1.2), sludge_color)
			draw_rect(Rect2(bx - r * 0.4, top - r * 1.2, 1.0, 1.0), Color(sheen_color, 0.9))


func _on_body_entered(body: Node2D) -> void:
	if body is not Ryn:
		return
	_ryn = body as Ryn
	_ryn.ground_drag = minf(_ryn.ground_drag, drag)
	if haze != null and haze_strength > 0.0:
		haze.touch(haze_strength)


func _on_body_exited(body: Node2D) -> void:
	if body != _ryn:
		return
	_ryn = null
	var r := body as Ryn
	# 还踩着别的蚀(两滩挨着)就用那滩的拖累
	var still: float = 1.0
	for z in get_tree().get_nodes_in_group(GROUP):
		var other := z as CorrosionZone
		if other != null and other != self and other.has_ryn():
			still = minf(still, other.drag)
	r.ground_drag = still

