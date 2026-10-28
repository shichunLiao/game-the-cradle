class_name Minimap
extends CanvasLayer
## 右上角常驻小地图。显示整关轮廓、Ryn 位置、已探索区域。
##
## ## 为什么它需要存在
##
## 四座塔纵向扩展之后一屏再也装不下整关（相机可视约 640x360，关卡约 1760x1400）。
## 玩家必须随时知道「我在第几层、哪边是上」,否则爬塔会变成迷路。
##
## ## 零接线
##
## 丢进关卡根下面就能用:`_collect()` 自己走一遍场景树分类几何体,世界范围取
## `Camera2D` 的 limit_*(关卡的权威边界)。只有 `ryn` 建议显式指,找不到时才回退
## 到按类型搜索。
##
## ## 三种原点约定
##
## 这个代码库里 position 的含义**按类型不同**,小地图必须按类型分派:
##   - `GrayBlock` / `Ladder` / `ShadowZone` → 左上角,向右下延展
##   - `TowerExit` / `VeraSweep`            → 左下角(`Rect2(Vector2(0,-size.y), size)`)
##   - `Checkpoint`                         → 下方居中(`Rect2(-size.x/2, -size.y, ...)`)
## 统一按左上角处理会让出口和检查点画错位置 —— 这是实现时第一个踩到的坑。
##
## ## 守卫为什么默认只在警觉时显示
##
## 这是潜行游戏。常驻显示所有守卫位置等于把潜行变成看图,玩家不再需要听脚步、
## 不再需要试探视锥。只在守卫 **离开 PATROL** 时显示,给的是玩家已经知道的信息
## （视锥已经变黄/变红）,帮他判断往哪边躲,而不是替他做侦察。
## 而且只在**已探索**的格子里画 —— 否则一个警觉守卫会顺便泄露没走过的地形。
##
## ## 存档点(2026-10-11)
##
## 关卡放大三倍后,玩家要知道「我存到哪儿了、重来会回到哪」。**到过的**存档点画成亮色
## 菱形、画在迷雾**之上**(去过的地方本来就知道);**现在会在这里重来**的那个大一号、慢慢闪。
## 看过但没到的还是暗点,没探索的被迷雾盖住 —— 不泄露没走过的路。
##
## ## 通风管(2026-10-12,点子 S7)
##
## 看过的管口画一个小方块。站在管口前(「E 钻进去」亮着)时,一条虚线连到另一头、那一头画一个空心框 ——
## 进去之前就知道会从哪里出来;在管子里爬的时候,Ryn 的点顺着虚线移过去。钻过一次的管子,两头和
## 一条淡虚线一直留着(走过的路)。另一头只画一个框,不揭开那边的迷雾。
##
## Usage (in a scene):
##     [node name="Minimap" type="CanvasLayer" parent="." node_paths=PackedStringArray("ryn", "camera")]
##     script = res://src/ui/minimap.gd
##     ryn = NodePath("../Ryn")
##     camera = NodePath("../FollowCamera")

## 面板底色。与字幕描边同色,所以小地图读起来像同一套 UI。
const BG_COLOR: Color = Color("0B1220")
## 边框。与 `GrayBlock.TOP_EDGE_COLOR` 同色。
const BORDER_COLOR: Color = Color("3D6B8A")
## 实体结构。比关卡里的填充亮一档,否则在底色上看不见。
const SOLID_COLOR: Color = Color("2A3E5C")
## 结构顶面 —— 和关卡里一样,顶面高光是「这能站」的信号。
const SOLID_TOP_COLOR: Color = Color("3D6B8A")
## 梯子。偏亮的蓝,与 `SprintAfterimage.tint` 同色。
const LADDER_COLOR: Color = Color("4C7BA8")
## 暗区。比底色更暗 —— 安全的地方在地图上是「洞」。
const SHADOW_COLOR: Color = Color("05080F")
## 未拆的可拆物件。
const PANEL_COLOR: Color = Color("8FA8C0")
## 已拆开的可拆物件(留一个暗痕,表示这里通了)。
const PANEL_OPEN_COLOR: Color = Color("3A4A60")
## 检查点(看过、还没到)。
const CHECKPOINT_COLOR: Color = Color("46607F")
## 到过的存档点。
const CHECKPOINT_REACHED_COLOR: Color = Color("6FA8C8")
## 现在的重生点。
const CHECKPOINT_ACTIVE_COLOR: Color = Color("B8E4F4")
## 出口。全局唯一的暖色,和举照片的提示同色。
const EXIT_COLOR: Color = Color("C4A574")
## Ryn。与 `RynPlaceholderVisual.BODY_COLOR` 同色。
const RYN_COLOR: Color = Color("C8D4E0")
## 警觉守卫。与视锥的 SPOTTED 红同色。
const ALERT_COLOR: Color = Color("C4453A")
## 通风管口和它通到哪的虚线。偏绿的冷青,和梯子、存档点的蓝分得开。
const VENT_COLOR: Color = Color("8FB8A8")

## 任何一条边至少画这么宽,否则 16px 的薄墙在 0.11 倍缩放下会整条消失。
const MIN_PX: float = 1.0

@export var ryn: Ryn
## 关卡边界的来源。它的 limit_* 就是世界范围。
@export var camera: Camera2D
## 面板最大尺寸(像素)。实际尺寸按关卡长宽比缩进这个框里。
@export var max_size: Vector2 = Vector2(196.0, 168.0)
## 距屏幕右上角的边距。
@export var margin: Vector2 = Vector2(12.0, 12.0)
## Ryn 周围多大范围算「已探索」(世界像素)。
@export var reveal_radius: float = 240.0
## 迷雾格边长(世界像素)。越小越精细,代价是每帧矩形数。
@export var fog_cell: float = 48.0
## 警觉守卫是否显示。见上方说明。
@export var show_alerted_guards: bool = true
## 整体不透明度。
@export var panel_opacity: float = 0.92

var _canvas: Control
var _world: Rect2 = Rect2()
var _solids: Array[Node2D] = []
var _ladders: Array[Node2D] = []
var _shadows: Array[Node2D] = []
var _panels: Array[Dismantlable] = []
var _checkpoints: Array[Checkpoint] = []
var _checkpoint_manager: CheckpointManager
var _time: float = 0.0
var _exits: Array[Node2D] = []
var _guards: Array[Guard] = []
var _vents: Array[HidingSpot] = []
## 钻过的通风管(两头的 instance_id 组成的键 → true)。
var _vents_used: Dictionary = {}
var _seen: Dictionary = {}
var _cols: int = 0
var _rows: int = 0
var _last_mark: Vector2 = Vector2(INF, INF)
var _ready_to_draw: bool = false


func _ready() -> void:
	layer = 90
	_canvas = Control.new()
	_canvas.name = &"MinimapCanvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_canvas)
	_canvas.draw.connect(_redraw)
	# 几何体在自己的 _ready 里才设好 size,所以要等整棵树就绪。
	_collect.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	if not _ready_to_draw:
		return
	_mark_seen()
	_canvas.queue_redraw()


## 走一遍关卡树分类几何体,并确定世界范围。
func _collect() -> void:
	var root: Node = get_parent()
	if root == null:
		return
	if ryn == null:
		ryn = _find_ryn(root)
	if camera == null:
		camera = _find_camera(root)
	_classify(root)

	if camera != null and camera.limit_right > camera.limit_left \
			and camera.limit_bottom > camera.limit_top:
		_world = Rect2(float(camera.limit_left), float(camera.limit_top),
				float(camera.limit_right - camera.limit_left),
				float(camera.limit_bottom - camera.limit_top))
	else:
		_world = _geometry_bounds()
	if _world.size.x <= 0.0 or _world.size.y <= 0.0:
		push_warning("Minimap: 世界范围为空,小地图不会绘制")
		return

	_cols = int(ceil(_world.size.x / fog_cell))
	_rows = int(ceil(_world.size.y / fog_cell))
	_ready_to_draw = true


func _classify(node: Node) -> void:
	for child in node.get_children():
		if child is Dismantlable:
			_panels.append(child)
		elif child is Checkpoint:
			_checkpoints.append(child)
		elif child is CheckpointManager:
			_checkpoint_manager = child
		elif child is TowerExit:
			_exits.append(child)
		elif child is Ladder:
			_ladders.append(child)
		elif child is ShadowZone:
			_shadows.append(child)
		elif child is Guard:
			_guards.append(child)
		elif child is HidingSpot:
			if (child as HidingSpot).kind == HidingSpot.Kind.VENT:
				_vents.append(child)
		elif child is GrayBlock:
			_solids.append(child)
		_classify(child)


## 没有相机 limit 时的退路:实体几何的并集,四周留一点余量。
func _geometry_bounds() -> Rect2:
	var out := Rect2()
	var first := true
	for n in _solids:
		var r: Rect2 = _rect_of(n)
		if first:
			out = r
			first = false
		else:
			out = out.merge(r)
	return out if first else out.grow(32.0)


## 把一个节点换成世界矩形,**按类型分派原点约定**(见文件头说明)。
func _rect_of(node: Node2D) -> Rect2:
	var size: Vector2 = _size_of(node)
	var p: Vector2 = node.global_position
	if node is TowerExit or node is VeraSweep:
		return Rect2(p + Vector2(0.0, -size.y), size)
	if node is Checkpoint:
		return Rect2(p + Vector2(-size.x * 0.5, -size.y), size)
	return Rect2(p, size)


## `size` 不是所有类型都有(守卫就没有)。`get()` 对缺失属性返回 null,直接赋给
## 一个 `Vector2` 会在运行时炸,所以这里显式判类型。
func _size_of(node: Node2D) -> Vector2:
	var raw: Variant = node.get(&"size")
	return raw if raw is Vector2 else Vector2.ZERO


## `is_class()` 只认引擎类名,对 `class_name` 声明的脚本类一律返回 false ——
## 用它找 Ryn 会永远找不到而且不报错。所以这里用 `is`。
func _find_ryn(node: Node) -> Ryn:
	for child in node.get_children():
		if child is Ryn:
			return child
		var found: Ryn = _find_ryn(child)
		if found != null:
			return found
	return null


func _find_camera(node: Node) -> Camera2D:
	for child in node.get_children():
		if child is Camera2D:
			return child
		var found: Camera2D = _find_camera(child)
		if found != null:
			return found
	return null


func _cell_of(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor((world_pos.x - _world.position.x) / fog_cell)),
			int(floor((world_pos.y - _world.position.y) / fog_cell)))


func _mark_seen() -> void:
	if ryn == null or not is_instance_valid(ryn):
		return
	var p: Vector2 = ryn.global_position
	# 没走够半格就不重算 —— 每帧扫一遍揭示半径是白给的开销。
	if p.distance_squared_to(_last_mark) < fog_cell * fog_cell * 0.25:
		return
	_last_mark = p
	var span: int = int(ceil(reveal_radius / fog_cell))
	var centre: Vector2i = _cell_of(p)
	var r2: float = reveal_radius * reveal_radius
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var c := centre + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= _cols or c.y >= _rows:
				continue
			var mid := _world.position + Vector2(
					(float(c.x) + 0.5) * fog_cell, (float(c.y) + 0.5) * fog_cell)
			if mid.distance_squared_to(p) <= r2:
				_seen[c] = true


func _redraw() -> void:
	if not _ready_to_draw:
		return
	var vp: Vector2 = _canvas.get_viewport_rect().size
	var s: float = minf(max_size.x / _world.size.x, max_size.y / _world.size.y)
	var inner: Vector2 = _world.size * s
	var origin := Vector2(vp.x - margin.x - inner.x, margin.y)

	var bg := BG_COLOR
	bg.a = panel_opacity
	_canvas.draw_rect(Rect2(origin - Vector2(3.0, 3.0), inner + Vector2(6.0, 6.0)), bg, true)

	for n in _shadows:
		# 会开会关的暗区(`TempShade`:蒸汽、断电)只在开着、看得见时画
		if not is_instance_valid(n) or not n.is_visible_in_tree():
			continue
		_blit(_rect_of(n), origin, s, SHADOW_COLOR)
	for n in _solids:
		var r: Rect2 = _rect_of(n)
		_blit(r, origin, s, SOLID_COLOR)
		# 顶面高光:在地图上也要能看出哪一条是可站的面。
		_blit(Rect2(r.position, Vector2(r.size.x, 2.0)), origin, s, SOLID_TOP_COLOR)
	for n in _ladders:
		_blit(_rect_of(n), origin, s, LADDER_COLOR)
	for p in _panels:
		if not is_instance_valid(p):
			continue
		_blit(_rect_of(p), origin, s,
				PANEL_OPEN_COLOR if p.is_dismantled else PANEL_COLOR)
	for c in _checkpoints:
		if is_instance_valid(c):
			_dot(c.global_position, origin, s, CHECKPOINT_COLOR, 1.5)
	for e in _exits:
		if is_instance_valid(e):
			_blit(_rect_of(e), origin, s, EXIT_COLOR)

	_draw_fog(origin, s, bg)

	# 到过的存档点画在迷雾之上;现在的重生点大一号、慢慢闪
	var active: Checkpoint = null
	if _checkpoint_manager != null and is_instance_valid(_checkpoint_manager):
		active = _checkpoint_manager.active_checkpoint
	for c in _checkpoints:
		if not is_instance_valid(c) or not c.activated:
			continue
		if c == active:
			var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
			_diamond(c.global_position, origin, s, Color(CHECKPOINT_ACTIVE_COLOR, 0.25 * pulse), 5.5)
			_diamond(c.global_position, origin, s, CHECKPOINT_ACTIVE_COLOR, 3.5)
		else:
			_diamond(c.global_position, origin, s, CHECKPOINT_REACHED_COLOR, 2.5)

	var in_vent: Variant = _draw_vents(origin, s)

	if show_alerted_guards:
		for g in _guards:
			if not is_instance_valid(g) or g.state == Guard.State.PATROL:
				continue
			# 已探索过的格子才画,否则警觉守卫会顺带泄露没走过的地形。
			if not _seen.has(_cell_of(g.global_position)):
				continue
			_dot(g.global_position, origin, s, ALERT_COLOR, 2.0)

	if in_vent != null:
		_dot(in_vent, origin, s, RYN_COLOR, 2.0)              # 在管子里:顺着虚线爬过去
	elif ryn != null and is_instance_valid(ryn):
		_dot(ryn.global_position, origin, s, RYN_COLOR, 2.0)

	_canvas.draw_rect(Rect2(origin - Vector2(3.0, 3.0), inner + Vector2(6.0, 6.0)),
			BORDER_COLOR, false, 1.0)


## 通风管(见文件头「通风管」)。返回 Ryn 在管子里时她在小地图上该画在哪(世界坐标);不在管子里返回 null。
func _draw_vents(origin: Vector2, s: float) -> Variant:
	# 第一遍:看过的管口、钻过的管子(淡虚线)
	for v in _vents:
		if not is_instance_valid(v):
			continue
		var other: HidingSpot = v.link if v.link != null and is_instance_valid(v.link) else null
		if other != null and v.travel_progress() >= 0.0:
			_vents_used[_pair_key(v, other)] = true
		var used: bool = other != null and _vents_used.has(_pair_key(v, other))
		if used and v.get_instance_id() < other.get_instance_id():
			_dashed(v.anchor(), other.anchor(), origin, s, Color(VENT_COLOR, 0.35))
		if used or _seen.has(_cell_of(v.anchor())):
			_dot(v.anchor() - Vector2(0.0, 6.0), origin, s, VENT_COLOR, 1.5)
	# 第二遍:正要钻 / 正在钻的那一根
	var ryn_at: Variant = null
	var hint: Array = vent_hint()
	if not hint.is_empty():
		var from: Vector2 = hint[0]
		var to: Vector2 = hint[1]
		_dashed(from, to, origin, s, VENT_COLOR)
		_box(to - Vector2(0.0, 6.0), origin, s, VENT_COLOR, 3.0)
		if float(hint[2]) >= 0.0:
			ryn_at = from.lerp(to, float(hint[2]))
	return ryn_at


## 现在该画的通风管提示:[入口, 出口, 爬了多少(-1 = 还没进去)](世界坐标);没有就是空数组。
## 验证脚本也用它。
func vent_hint() -> Array:
	for v in _vents:
		if not is_instance_valid(v) or v.link == null or not is_instance_valid(v.link):
			continue
		var progress: float = v.travel_progress()
		if progress >= 0.0 or v.is_prompting():
			return [v.anchor(), v.link.anchor(), progress]
	return []


## 钻过的通风管有几根(验证脚本用)。
func vents_used() -> int:
	return _vents_used.size()


func _pair_key(a: Node, b: Node) -> String:
	var ia: int = a.get_instance_id()
	var ib: int = b.get_instance_id()
	return "%d-%d" % [mini(ia, ib), maxi(ia, ib)]


## 小地图上的一条虚线(世界坐标的两点)。
func _dashed(from: Vector2, to: Vector2, origin: Vector2, s: float, color: Color) -> void:
	var a: Vector2 = origin + (from - _world.position) * s
	var b: Vector2 = origin + (to - _world.position) * s
	var length: float = a.distance_to(b)
	if length < 0.5:
		return
	var dir: Vector2 = (b - a) / length
	var t: float = 0.0
	while t < length:
		_canvas.draw_line(a + dir * t, a + dir * minf(t + 2.5, length), color, 1.0)
		t += 4.5


## 空心小方框(通风管另一头)。
func _box(world_pos: Vector2, origin: Vector2, s: float, color: Color, radius: float) -> void:
	var c: Vector2 = origin + (world_pos - _world.position) * s
	_canvas.draw_rect(Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0), color, false, 1.0)


## 未探索的格子用底色盖掉。**按行合并连续格** —— 逐格画在 1760x1400 的关卡上是
## 2400+ 次 draw_rect/帧,合并后通常只剩几十次。
func _draw_fog(origin: Vector2, s: float, bg: Color) -> void:
	var fog := bg
	fog.a = 1.0
	for ry in _rows:
		var run: int = -1
		for rx in range(_cols + 1):
			var unseen: bool = rx < _cols and not _seen.has(Vector2i(rx, ry))
			if unseen and run < 0:
				run = rx
			elif not unseen and run >= 0:
				var x0: float = _world.position.x + float(run) * fog_cell
				var y0: float = _world.position.y + float(ry) * fog_cell
				_blit(Rect2(x0, y0, float(rx - run) * fog_cell, fog_cell), origin, s, fog)
				run = -1


## 世界矩形 → 面板矩形。任何一边至少 MIN_PX,薄墙不能整条消失。
func _blit(world_rect: Rect2, origin: Vector2, s: float, color: Color) -> void:
	var pos: Vector2 = origin + (world_rect.position - _world.position) * s
	var size := Vector2(maxf(world_rect.size.x * s, MIN_PX),
			maxf(world_rect.size.y * s, MIN_PX))
	_canvas.draw_rect(Rect2(pos, size), color, true)


func _diamond(world_pos: Vector2, origin: Vector2, s: float, color: Color, radius: float) -> void:
	# 存档点的原点在脚底,菱形画在脚底往上一点(人站的位置)
	var c: Vector2 = origin + (world_pos - _world.position) * s - Vector2(0.0, radius)
	_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -radius), c + Vector2(radius, 0.0),
			c + Vector2(0.0, radius), c + Vector2(-radius, 0.0)]), color)


func _dot(world_pos: Vector2, origin: Vector2, s: float, color: Color, radius: float) -> void:
	var pos: Vector2 = origin + (world_pos - _world.position) * s
	_canvas.draw_rect(Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
			color, true)
