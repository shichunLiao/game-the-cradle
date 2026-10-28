class_name CorrosionDrain
extends Node2D
## 蚀池的排放阀(2026-10-12,下行关「蚀池放流」):拆掉阀门(`panel`),一整池蚀慢慢往排水格栅
## (`grate_x`)流,`drain_time` 秒后排干 —— 地面露出来,走路不再被粘住。
##
## 排放的声音很大(`noise_radius`,从格栅那里传出去):附近的守卫会走过来查看。一次性;回存档点时
## 跟着阀门一起回到原样(蚀又满了)。
##
## 节点原点放在 (0, 0):格栅和流动的痕迹按世界坐标画。
##
## Usage (in a scene): 设 `panel`、`zone_names`(要排的 `CorrosionZone` 节点名)、`grate_x`、`floor_y`。
## 关卡由 `tools/level_builder` 用 `lv.drain(...)` 放。

@export var panel: Dismantlable
## 要排掉的几滩蚀(关卡根下的节点名)。
@export var zone_names: PackedStringArray = PackedStringArray()
## 排水格栅的世界 x(蚀往这里流,从这里漏下去)。
@export var grate_x: float = 0.0
## 蚀池所在的地面(世界 y)。
@export var floor_y: float = 0.0
## 排干要多久,秒。
@export var drain_time: float = 4.0
## 排放的声音传多远,px。
@export var noise_radius: float = 420.0
@export var sludge_color: Color = Color("2A1538")
@export var sheen_color: Color = Color("7A58A0")
@export var grate_color: Color = Color("1E2A3C")

var _zones: Array[Node] = []
## 0 = 满,1 = 排干。
var _drained: float = 0.0
var _draining: bool = false
var _time: float = 0.0


func _ready() -> void:
	z_index = 2
	var level: Node = owner if owner != null else get_parent()
	for n in zone_names:
		var z := level.get_node_or_null(NodePath(n)) if level != null else null
		if z != null:
			_zones.append(z)
	if panel != null:
		panel.panel_dismantled.connect(func(_n: int) -> void: drain())
		panel.panel_restored.connect(_on_restored)


## 排干了吗。
func is_drained() -> bool:
	return _drained >= 1.0


## 开始排(阀门被拆时调;验证脚本也可以直接调)。
func drain() -> void:
	if _draining or _drained >= 1.0:
		return
	_draining = true
	Audio.play(&"steam_hiss", -6.0, 0.55)
	var bus := get_node_or_null(^"/root/Noise")
	if bus != null:
		bus.emit_noise(Vector2(grate_x, floor_y), noise_radius)


func _on_restored(opened: bool) -> void:
	_draining = false
	_drained = 1.0 if opened else 0.0
	_apply()


func _physics_process(delta: float) -> void:
	_time += delta
	if _draining:
		_drained = minf(_drained + delta / maxf(drain_time, 0.01), 1.0)
		_apply()
		if _drained >= 1.0:
			_draining = false
	queue_redraw()


func _apply() -> void:
	for z in _zones:
		if is_instance_valid(z) and z.has_method(&"set_level"):
			z.call(&"set_level", 1.0 - _drained)


func _draw() -> void:
	# 排水格栅:地面上一块铁栅,一直在
	var g := Rect2(grate_x - 12.0, floor_y - 2.0, 24.0, 3.0)
	draw_rect(g, grate_color)
	var x: float = g.position.x + 2.0
	while x < g.end.x - 1.0:
		draw_rect(Rect2(x, g.position.y, 1.0, 3.0), Color("0B1220"))
		x += 3.0
	if not _draining:
		return
	# 排的时候:两边的蚀往格栅流(一道道往中间走的油光),格栅底下漏下去一股
	var span: float = 420.0 * (1.0 - _drained) + 40.0
	for i in 14:
		var k: float = fposmod(_time * 0.9 + float(i) / 14.0, 1.0)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var px: float = grate_x + side * span * (1.0 - k)
		draw_rect(Rect2(px, floor_y - 2.0, 4.0, 1.0), Color(sheen_color, 0.6 * (1.0 - _drained)))
	for j in 5:
		var k2: float = fposmod(_time * 2.2 + float(j) / 5.0, 1.0)
		draw_rect(Rect2(grate_x - 3.0 + float(j % 3) * 2.0, floor_y + 2.0 + k2 * 60.0, 2.0, 5.0),
				Color(sludge_color.lightened(0.15), 0.8 * (1.0 - k2)))
