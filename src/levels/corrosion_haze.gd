class_name CorrosionHaze
extends CanvasLayer
## 蚀的恍惚:踩进蚀里时,屏幕重影、边上发暗,过一会儿退掉。第一次踩进深的那滩时最重,还出一句话。
##
## 叙事脚本.md 终局 A·下行:「Ryn 短暂恍惚,但未失忆。」——「头好沉……身体快撑不住了。不过我身上好像还有什么东西。」
## 恍惚**不夺走操作**,也不挡视线太久(最重的一次约 2.4 秒);浅的那几滩只轻轻闪一下。
## 画在氛围层(80)之上、字幕和小地图(90)之下 —— 字是清楚的,人是晕的。
##
## Usage (in a scene): 放在关卡根节点下,`subtitle` 指向 `TowerSubtitle`,设 `deep_line`;
## `CorrosionZone.haze` 指向它。关卡由 `tools/level_builder` 生成时自动放(有蚀区就有它)。

const HAZE_LAYER: int = 85
const SHADER := preload("res://src/levels/canvas_post_corrosion_haze.gdshader")

## 第一次踩进深蚀时的那一句。
@export_multiline var deep_line: String = ""
@export var subtitle: TowerSubtitle
## 「深」的门槛:`touch(strength)` 的 strength 不低于它就算深蚀。
@export_range(0.0, 1.0) var deep_threshold: float = 0.8
## 第一次深蚀的恍惚:涨上去 / 停住 / 退掉,秒。
@export var deep_rise: float = 0.5
@export var deep_hold: float = 0.9
@export var deep_fall: float = 1.0
## 之后每次踩进去:轻轻一闪,秒。
@export var light_time: float = 0.7
## 轻闪的强度乘数(乘在那滩的 strength 上)。
@export_range(0.0, 1.0) var light_scale: float = 0.45
## 两次轻闪至少隔多久,秒(连着几滩不要一直闪)。
@export var light_cooldown: float = 2.5
## 第一次深蚀之后,字幕晚多久出来(先晕,再说话)。
@export var line_delay: float = 0.7

var _rect: ColorRect
var _mat: ShaderMaterial
var _t: float = 0.0
var _peak: float = 0.0
var _rise: float = 0.0
var _hold: float = 0.0
var _fall: float = 0.0
var _active: bool = false
var _deep_done: bool = false
var _cooldown: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	layer = HAZE_LAYER
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


## 第一次深蚀已经演过了吗。
func deep_done() -> bool:
	return _deep_done


## 现在的强度(0..1)。
func strength() -> float:
	return _strength_at(_t) if _active else 0.0


## 踩进一滩蚀。`strength` 是那滩的恍惚强度(0..1)。
func touch(strength_in: float) -> void:
	if strength_in <= 0.0:
		return
	if strength_in >= deep_threshold and not _deep_done:
		_deep_done = true
		_start(1.0, deep_rise, deep_hold, deep_fall)
		_say_later()
		return
	if _cooldown > 0.0 or _active:
		return
	_start(clampf(strength_in * light_scale, 0.0, 1.0), light_time * 0.3, 0.0, light_time * 0.7)


func _start(peak: float, rise: float, hold: float, fall: float) -> void:
	_peak = peak
	_rise = maxf(rise, 0.01)
	_hold = maxf(hold, 0.0)
	_fall = maxf(fall, 0.01)
	_t = 0.0
	_active = true
	_cooldown = light_cooldown
	_rect.visible = true


func _say_later() -> void:
	if deep_line.is_empty():
		return
	await get_tree().create_timer(line_delay).timeout
	if is_inside_tree():
		StoryTrigger.say(subtitle, deep_line)


func _process(delta: float) -> void:
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not _active:
		return
	_t += delta
	var s: float = _strength_at(_t)
	_mat.set_shader_parameter(&"strength", s)
	_mat.set_shader_parameter(&"time_s", _time)
	if _t >= _rise + _hold + _fall:
		_active = false
		_rect.visible = false


func _strength_at(t: float) -> float:
	if t < _rise:
		return _peak * smoothstep(0.0, 1.0, t / _rise)
	if t < _rise + _hold:
		return _peak
	var k: float = clampf((t - _rise - _hold) / _fall, 0.0, 1.0)
	return _peak * (1.0 - smoothstep(0.0, 1.0, k))
