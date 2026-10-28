class_name HomeAmbience
extends Node2D
## 旧屋里会动的小东西(2026-10-13 精装修,`docs/polish-research.md` §3.1):
##
##   - 炉子上水壶嘴冒的汽,往上飘、往左散;
##   - 炉膛格栅里几颗火星,一明一暗;
##   - 窗外那道冷光里飘的灰尘;
##   - 烛芯上那一点火苗在跳。
##
## 「温馨」报告(Project Horseshoe 2017)说柔软 = 温和、有来源的刺激:这些都很小、很慢,而且一眼看得出从哪来。
## 只是画面,不碰玩法。节点原点放在 (0, 0),坐标都是世界坐标。确定的伪随机(固定种子),截图可复现。
##
## Usage (in code):
##     var amb := HomeAmbience.new()
##     amb.window = $Window
##     add_child(amb)

const STEAM: Color = Color(0.78, 0.82, 0.86)
const EMBER: Color = Color("E2C08A")
const DUST: Color = Color("C8D4E0")
const FLAME_TIP: Color = Color("E8CFA0")

## 水壶嘴(汽从这里出来)。
@export var kettle_spout: Vector2 = Vector2(430.0, 283.0)
## 炉膛格栅(火星在这里面)。
@export var grate: Rect2 = Rect2(434.0, 305.0, 14.0, 6.0)
## 烛芯顶上(火苗尖)。
@export var flame_tip: Vector2 = Vector2(364.0, 296.0)
## 窗:读它的几何算出光柱,灰尘只飘在光柱里。
@export var window: WindowLight
@export var dust_count: int = 12
@export var steam_count: int = 7

var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _dust: Array[Vector3] = []     # (沿光柱宽 0..1, 沿光柱长 0..1, 相位)
var _steam: Array[float] = []      # 每缕汽的出生时间偏移


func _ready() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 20261013
	for i in dust_count:
		_dust.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf() * TAU))
	for i in steam_count:
		_steam.append(float(i) / float(maxi(steam_count, 1)))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	_draw_steam()
	_draw_embers()
	_draw_flame()
	_draw_dust()


## 一缕汽 1.8 秒:从壶嘴出来,往上 14px、往左飘 6px,越来越淡、越来越宽。
func _draw_steam() -> void:
	for off in _steam:
		var k: float = fposmod(_t / 1.8 + off, 1.0)
		var p: Vector2 = kettle_spout + Vector2(-k * 6.0 + sin((_t + off * 9.0) * 2.0) * 1.0, -k * 14.0)
		var w: float = 1.0 + floorf(k * 2.0)
		draw_rect(Rect2(p.round(), Vector2(w, 1.0)), Color(STEAM, 0.35 * (1.0 - k)))


## 格栅里四颗火星,各自按不同的慢节奏一明一暗。
func _draw_embers() -> void:
	var spots: Array[Vector2] = [Vector2(2, 3), Vector2(6, 2), Vector2(9, 4), Vector2(12, 3)]
	for i in spots.size():
		var b: float = 0.5 + 0.5 * sin(_t * (1.1 + i * 0.37) + i * 1.7)
		draw_rect(Rect2(grate.position + spots[i], Vector2.ONE), Color(EMBER, 0.35 + 0.55 * b))


## 火苗尖:1px,偶尔往上跳一格。
func _draw_flame() -> void:
	var up: float = 1.0 if sin(_t * 7.3) * sin(_t * 2.9) > 0.35 else 0.0
	draw_rect(Rect2(flame_tip + Vector2(0.0, -up), Vector2.ONE), Color(FLAME_TIP, 0.9))


## 窗光里的灰尘:在光柱的平行四边形里慢慢往下飘、左右晃。
func _draw_dust() -> void:
	if window == null:
		return
	var top_l: Vector2 = window.position + Vector2(0.0, -window.size.y)
	var w: float = window.size.x
	var skew: float = window.beam_skew
	var length: float = window.beam_length
	for d in _dust:
		var v: float = fposmod(d.y + _t * 0.025, 1.0)
		var u: float = clampf(d.x + sin(_t * 0.4 + d.z) * 0.05, 0.0, 1.0)
		var p: Vector2 = top_l + Vector2(u * w + skew * v, length * v)
		var a: float = 0.28 * sin(v * PI)
		draw_rect(Rect2(p.round(), Vector2.ONE), Color(DUST, a))
