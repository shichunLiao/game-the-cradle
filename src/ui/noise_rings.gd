class_name NoiseRings
extends Node2D
## 把每一次噪音画成一圈往外扩散的细环 —— Mark of the Ninja 的做法:
## 「这一步会被听见多远」直接画在地上,玩家不用猜守卫能不能听到。
##
## 环的半径就是噪音半径(守卫能听到的最远距离),所以画面和规则是同一个数。
## 由噪音总线(`Noise` autoload)创建并转发 `noise_made`,所以每一关自动生效,
## 场景不用加节点。它挂在视口的画布上,跟着相机走,画的是世界坐标。
##
## Usage:
##     var rings := NoiseRings.new()
##     add_child(rings)
##     rings.add_ring(Vector2(100, 320), 150.0)

class Ring:
	var at: Vector2
	var radius: float
	var t: float

## 关掉就不画(规则不受影响,守卫照样听得见)。
@export var enabled: bool = true
## 环扩到满半径要多久,秒。快 —— 声音是一下子传出去的。
@export var grow_time: float = 0.22
## 一圈从出现到消失总共多久,秒。
@export var life_time: float = 0.6
## 环的颜色。与探照灯光同色系的冷白,在暗背景上读得出、不抢角色。
@export var color: Color = Color("C8D4E0")
## 最响(半径 >= loud_radius)时的不透明度;小声按半径比例变淡。
@export var max_alpha: float = 0.5
@export var loud_radius: float = 220.0
## 同时最多几圈。跑步时每步一圈,太多会糊成一片。
@export var max_rings: int = 12

var _rings: Array[Ring] = []


func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


## 加一圈。`radius` <= 0 不画(蹲行就是无声的)。
func add_ring(at: Vector2, radius: float) -> void:
	if not enabled or radius <= 0.0:
		return
	var r := Ring.new()
	r.at = at.round()
	r.radius = radius
	r.t = 0.0
	_rings.append(r)
	while _rings.size() > max_rings:
		_rings.pop_front()
	set_process(true)


## 清空(换场景、重来时)。
func clear() -> void:
	_rings.clear()
	queue_redraw()


func _process(delta: float) -> void:
	var alive: Array[Ring] = []
	for r in _rings:
		r.t += delta
		if r.t < life_time:
			alive.append(r)
	_rings = alive
	queue_redraw()
	if _rings.is_empty():
		set_process(false)


func _draw() -> void:
	for r in _rings:
		var grow: float = clampf(r.t / maxf(grow_time, 0.0001), 0.0, 1.0)
		# 先快后慢地扩出去,扩满后原地淡出
		var radius: float = r.radius * (1.0 - pow(1.0 - grow, 3.0))
		var fade: float = 1.0 - clampf(r.t / maxf(life_time, 0.0001), 0.0, 1.0)
		var c := color
		c.a = max_alpha * clampf(r.radius / loud_radius, 0.35, 1.0) * fade
		if radius < 1.0 or c.a <= 0.0:
			continue
		var segments: int = clampi(int(radius * 0.6), 16, 96)
		draw_arc(r.at, roundf(radius), 0.0, TAU, segments, c, 1.0, false)
