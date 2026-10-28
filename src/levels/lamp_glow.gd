class_name LampGlow
extends Node2D
## 一盏灯的光晕(2026-10-13 精装修,`docs/polish-research.md` §3.3 / §4.1)。
##
## 叠加混合(`CanvasItemMaterial.BLEND_MODE_ADD`)的同心椭圆,按 `steps` 级量化成硬边 —— 像素画的光,
## 不是平滑渐变(和旧屋原来烤进贴图的烛光同一种画法,只是现在会闪)。
##
## **只管画面,不进玩法**:它不是 `ShadowZone`,守卫看不看得见与它无关。Mark of the Ninja 的规矩是
## 「画面上的光 = 玩法上的光」,所以塔里的灯由关卡生成器保证光圈不碰暗区;旧屋没有守卫,随便亮。
##
## 闪法(`flicker`):
##   - STEADY      不闪
##   - CANDLE      烛火:快、小幅、偶尔一缩
##   - EMBER       炉火 / 油灯:慢慢呼吸
##   - FLUORESCENT 灯管:平时稳,隔几秒「咔」地断一下(塔3「灯管嗡鸣」)
##   - EMERGENCY   应急灯:慢脉冲
## 闪动只用确定的伪随机(按节点位置播种),同一位置每次跑都一样 —— 截图和检查可以复现。
##
## Usage (in code):
##     var glow := LampGlow.new()
##     glow.color = Color("C4A574"); glow.radius = 40.0; glow.flicker = LampGlow.Flicker.CANDLE
##     glow.position = Vector2(365, 299)
##     add_child(glow)

enum Flicker { STEADY, CANDLE, EMBER, FLUORESCENT, EMERGENCY }

## 光的颜色。旧屋用 accent-warm,塔里只用冷色(美术规格 §2)。
@export var color: Color = Color("C4A574")
## 最外一圈的半径,px。
@export var radius: float = 40.0
## 最里一圈的强度(叠加的量),外圈依次减弱。
@export_range(0.0, 1.0) var energy: float = 0.16
## 量化成几圈。
@export_range(1, 12) var steps: int = 6
## 衰减曲线的指数:越大,光越集中在中心、外圈越淡(2 ≈ 平方衰减)。
@export var falloff: float = 2.2
## 竖直方向的比例:< 1 压扁(落在地上的一片光),> 1 拉长。
@export var squash: float = 1.0
@export var flicker: Flicker = Flicker.STEADY
## 有没有电 / 点没点着。灭了什么都不画。`FuseBox` 断电时调 `set_powered(false)`。
@export var powered: bool = true

var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _k: float = 1.0
var _dip_left: float = 0.0
var _next_dip: float = 0.0


## 点亮 / 熄灭。
func set_powered(on: bool) -> void:
	powered = on
	queue_redraw()


## 现在的亮度倍数(0 = 灭)。检查脚本用。
func level() -> float:
	return _k if powered else 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = int(global_position.x) * 7919 + int(global_position.y) * 104729 + int(flicker)
	_next_dip = _rng.randf_range(2.0, 9.0)
	_t = _rng.randf_range(0.0, 10.0)


func _process(delta: float) -> void:
	_t += delta
	var k: float = 1.0
	match flicker:
		Flicker.CANDLE:
			k = 0.92 + 0.05 * sin(_t * 9.1) * sin(_t * 3.7) + 0.03 * sin(_t * 23.0)
			_next_dip -= delta
			if _next_dip <= 0.0:
				_dip_left = 0.12
				_next_dip = _rng.randf_range(1.5, 5.0)
		Flicker.EMBER:
			k = 0.86 + 0.10 * sin(_t * 1.3) + 0.04 * sin(_t * 4.1)
		Flicker.FLUORESCENT:
			_next_dip -= delta
			if _next_dip <= 0.0:
				_dip_left = _rng.randf_range(0.05, 0.22)
				_next_dip = _rng.randf_range(4.0, 12.0)
		Flicker.EMERGENCY:
			k = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * TAU * 0.6))
	if _dip_left > 0.0:
		_dip_left -= delta
		k *= 0.75 if flicker == Flicker.CANDLE else 0.0
	if not is_equal_approx(k, _k):
		_k = k
		queue_redraw()


func _draw() -> void:
	if not powered or _k <= 0.0:
		return
	var n: int = maxi(steps, 1)
	for i in n:
		# 外圈先画、每圈叠一次:叠过 k 圈的地方亮度 = energy × (k / n)^falloff。
		# 第一版每圈一样亮,外圈和里圈差一大截,看起来是一圈圈的靶心(2026-10-13 截图)。
		var r: float = roundf(radius * float(n - i) / float(n))
		var a: float = energy * (pow(float(i + 1) / float(n), falloff) - pow(float(i) / float(n), falloff)) * _k
		_draw_ellipse(r, Color(color, a))


func _draw_ellipse(r: float, c: Color) -> void:
	if is_equal_approx(squash, 1.0):
		draw_circle(Vector2.ZERO, r, c)
		return
	var pts := PackedVector2Array()
	var segs: int = maxi(16, int(r))
	for s in segs:
		var ang: float = TAU * float(s) / float(segs)
		pts.append(Vector2(roundf(cos(ang) * r), roundf(sin(ang) * r * squash)))
	draw_colored_polygon(pts, c)
