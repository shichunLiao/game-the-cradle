class_name SteamValve
extends Node2D
## 蒸汽阀门(2026-10-12 谜题房,塔2「蒸汽廊」):长按 E 拧开阀门,白汽喷出来罩住一片(`cloud_rect`)
## `duration` 秒 —— 这段时间里那一片算暗处,守卫看不见里面的人。时间到汽散了,阀门自己关上,可以再拧一次。
##
## 汽散之前 0.8 秒就开始变淡,而且「看得见汽」一定比「算暗处」先结束 —— 不能让玩家以为自己还躲着。
## 回存档点时马上关掉、阀门复原。
##
## 节点原点放在 (0, 0):汽团按世界坐标画。
##
## Usage (in a scene): 设 `panel`(阀门)、`cloud_rect`。关卡由 `tools/level_builder` 用 `lv.steam_valve(...)` 放。

@export var panel: Dismantlable
## 汽罩住的范围,世界坐标。
@export var cloud_rect: Rect2 = Rect2(0, 0, 160, 96)
## 喷多久,秒。
@export var duration: float = 6.0
@export var steam_color: Color = Color(0.82, 0.86, 0.9, 1.0)

const FADE_IN: float = 0.25
const FADE_OUT: float = 0.8
const PUFFS: int = 46

var _left: float = 0.0
var _time: float = 0.0
var _shade: TempShade
var _puffs: Array[Vector4] = []   # x, y(相对汽团), 半径, 相位


## 组名:蚀痕(`TraceTrail`)要知道哪里在冒汽 —— 冒汽的地方落不下痕迹,冒起来时把痕迹洗掉。
const GROUP: StringName = &"steam_valves"


func _ready() -> void:
	z_index = 3   # 罩在人前面:躲在里面的人只看得见一个影子
	add_to_group(GROUP)
	_shade = TempShade.new(self, cloud_rect, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cloud_rect.position.x) * 31 + int(cloud_rect.position.y)
	for i in PUFFS:
		_puffs.append(Vector4(rng.randf() * cloud_rect.size.x, rng.randf() * cloud_rect.size.y,
				rng.randf_range(7.0, 15.0), rng.randf() * TAU))
	if panel != null:
		panel.panel_dismantled.connect(func(_n: int) -> void: vent())
		panel.panel_restored.connect(func(_opened: bool) -> void: _stop())


## 正在喷吗(那一片现在算暗处)。
func is_venting() -> bool:
	return _left > 0.0


## 喷(阀门被拧开时调;验证脚本也可以直接调)。
func vent() -> void:
	_left = duration
	_shade.set_active(true)
	Audio.play(&"steam_hiss", -8.0)


func _stop() -> void:
	_left = 0.0
	_shade.set_active(false)
	if panel != null and panel.is_dismantled:
		panel.rearm()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_time += delta
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		_stop()
		return
	queue_redraw()


func _alpha() -> float:
	if _left <= 0.0:
		return 0.0
	var since: float = duration - _left
	return clampf(since / FADE_IN, 0.0, 1.0) * clampf(_left / FADE_OUT, 0.0, 1.0)


func _draw() -> void:
	var a: float = _alpha()
	if a <= 0.0:
		return
	var r := cloud_rect
	# 底下一层匀的雾,上面一团团往上飘的汽
	draw_rect(r, Color(steam_color, 0.22 * a))
	for p in _puffs:
		var drift: float = fmod(_time * 10.0 + p.w * 8.0, r.size.y)
		var y: float = r.position.y + fposmod(p.y - drift, r.size.y)
		var x: float = r.position.x + p.x + sin(_time * 1.3 + p.w) * 3.0
		var rad: float = p.z * (0.85 + 0.15 * sin(_time * 2.0 + p.w))
		draw_circle(Vector2(x, y), rad, Color(steam_color, 0.16 * a))
		draw_circle(Vector2(x, y), rad * 0.55, Color(steam_color, 0.14 * a))
	# 阀门口喷出来的那一股
	if panel != null:
		var mouth: Vector2 = panel.global_position + panel.size * 0.5
		var to := Vector2(clampf(mouth.x, r.position.x, r.end.x), r.get_center().y)
		for i in 6:
			var k: float = fposmod(_time * 3.0 + float(i) / 6.0, 1.0)
			draw_circle(mouth.lerp(to, k), 3.0 + k * 6.0, Color(steam_color, 0.3 * a * (1.0 - k)))
