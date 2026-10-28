class_name Atmosphere
extends CanvasLayer
## 氛围层:暗角 + 缓慢飘动的尘埃。
##
## ## 它一度被规格排除
##
## `美术规格.md` §1「不做」含 **视差多层风景、粒子特效堆**。作者于 2026-10-04
## 口头解除该约束(文件本身未改动)。这里仍然克制地做:
##   - 尘埃是 **极少量、极慢、极淡** 的小点,不是粒子堆
##   - 不做视差滚动层,只有一层固定的屏幕空间效果
## 理由与当初定那条规格的理由一致:潜行游戏的画面必须让玩家一眼读出"可站/不可站"
## 和"亮/暗",任何抢眼的动态元素都在跟关卡争注意力。
##
## 暗角压四角,把视线收向中心的 Ryn —— 这对 640x360 的横版尤其有效。

const ATMO_LAYER: int = 80

@export var enabled: bool = true
@export_group("Vignette")
@export var vignette_color: Color = Color("06090F")
@export var vignette_alpha: float = 0.42
## 暗角从边缘向内渗透的比例。
@export_range(0.05, 0.5) var vignette_extent: float = 0.26
@export_group("Dust")
## 尘埃粒子数。刻意很少。
@export var dust_count: int = 26
@export var dust_color: Color = Color("3D6B8A")
@export var dust_alpha: float = 0.20
## 飘动速度,px/s。
@export var dust_speed: float = 7.0
@export var seed_value: int = 1

var _rect: Control
var _dust: Array[Vector3] = []   # x, y, 相位
var _size: Vector2 = Vector2(640, 360)
var _t: float = 0.0


func _ready() -> void:
	layer = ATMO_LAYER
	_rect = Control.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.draw.connect(_draw_atmo)
	_rect.resized.connect(func() -> void:
		_size = _rect.size
		_rect.queue_redraw())
	add_child(_rect)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in dust_count:
		_dust.append(Vector3(rng.randf(), rng.randf(), rng.randf() * TAU))
	set_process(enabled)


func _process(delta: float) -> void:
	_t += delta
	_rect.queue_redraw()


func _draw_atmo() -> void:
	if not enabled:
		return
	var w: float = maxf(_size.x, 1.0)
	var h: float = maxf(_size.y, 1.0)

	# 尘埃:缓慢上浮 + 轻微横摆。数量少、速度慢、颜色淡。
	var dc := dust_color
	dc.a = dust_alpha
	for d in _dust:
		var y: float = fmod(d.y * h - _t * dust_speed, h)
		if y < 0.0:
			y += h
		var x: float = d.x * w + sin(_t * 0.35 + d.z) * 6.0
		_rect.draw_rect(Rect2(roundf(x), roundf(y), 1.0, 1.0), dc, true)

	# 暗角:四边各压一条渐变带。用分层矩形而不是着色器 —— 够用,且无平台差异。
	var steps: int = 10
	var vx: float = w * vignette_extent
	var vy: float = h * vignette_extent
	for i in steps:
		var f: float = float(i) / float(steps)
		var a: float = vignette_alpha * pow(1.0 - f, 2.0) / float(steps) * 3.0
		var c := vignette_color
		c.a = a
		var bx: float = vx * (1.0 - f)
		var by: float = vy * (1.0 - f)
		_rect.draw_rect(Rect2(0.0, 0.0, bx, h), c, true)
		_rect.draw_rect(Rect2(w - bx, 0.0, bx, h), c, true)
		_rect.draw_rect(Rect2(0.0, 0.0, w, by), c, true)
		_rect.draw_rect(Rect2(0.0, h - by, w, by), c, true)
