class_name FuseBox
extends Node2D
## 配电箱(2026-10-12 谜题房,塔4「配电室」):长按 E 拆开(`panel`),整片断电 ——
##   - `light_names` 里的探照灯 / 门禁灯熄掉,不抓人;
##   - `blackout_rect` 那一片变成暗处(画成暗区的样子,守卫看不见里面的人)。
## 代价:技工(`technician`)会走到电闸(`repair_point`)那里修,站够 `repair_time` 秒就来电;
## 没有技工、或者他走不到,`backup_time` 秒后备用电源接上。来电之后配电箱复原,可以再拆。
##
## 电闸画在 `repair_point`(墙上一个小柜子,修的时候冒火花),玩家看得见他要去哪、还要多久。
## 回存档点时马上来电、配电箱复原。
##
## 节点原点放在 (0, 0):电闸按世界坐标画。
##
## Usage (in a scene): 设 `panel`、`light_names`、`blackout_rect`、`technician`、`repair_point`。
## 关卡由 `tools/level_builder` 用 `lv.fuse_box(...)` 放。

@export var panel: Dismantlable
## 要断电的灯(关卡根下的节点名,`SweepLight` / `GateLight`)。
@export var light_names: PackedStringArray = PackedStringArray()
## 断电后变暗的一片,世界坐标。
@export var blackout_rect: Rect2 = Rect2()
## 来修的守卫。
@export var technician: Guard
## 电闸在哪(世界坐标,技工站的地面那一点)。
@export var repair_point: Vector2 = Vector2.ZERO
## 站在电闸前修多久,秒。
@export var repair_time: float = 3.0
## 没人修的话多久自己来电,秒。
@export var backup_time: float = 20.0
@export var cabinet_color: Color = Color("1E2B40")
@export var spark_color: Color = Color("C8D4E0")

const REPAIR_REACH: float = 14.0

var _off: bool = false
var _off_time: float = 0.0
var _repair: float = 0.0
var _time: float = 0.0
var _shade: TempShade


func _ready() -> void:
	z_index = 0
	if blackout_rect.size.x > 0.0:
		_shade = TempShade.new(self, blackout_rect, true)
	if panel != null:
		panel.panel_dismantled.connect(func(_n: int) -> void: cut())
		panel.panel_restored.connect(func(_opened: bool) -> void: _restore_power(false))


## 断电了吗。
func is_off() -> bool:
	return _off


## 修了多少(0..1),验证脚本和画面用。
func repair_ratio() -> float:
	return clampf(_repair / maxf(repair_time, 0.01), 0.0, 1.0)


## 断电(配电箱被拆时调;验证脚本也可以直接调)。
func cut() -> void:
	if _off:
		return
	_off = true
	_off_time = 0.0
	_repair = 0.0
	_set_lights(false)
	if _shade != null:
		_shade.set_active(true)
	Audio.play(&"power_down", -6.0)
	if technician != null and is_instance_valid(technician):
		var pursuit := technician.get_node_or_null(^"Pursuit")
		if pursuit != null and pursuit.has_method(&"go_check"):
			pursuit.call(&"go_check", repair_point, repair_time + 1.5)


func _restore_power(play_sound: bool) -> void:
	if _off and play_sound:
		Audio.play(&"power_up", -8.0)
	_off = false
	_repair = 0.0
	_set_lights(true)
	if _shade != null:
		_shade.set_active(false)
	if panel != null and panel.is_dismantled:
		panel.rearm()
	queue_redraw()


func _set_lights(on: bool) -> void:
	var level: Node = owner if owner != null else get_parent()
	for n in light_names:
		var light := level.get_node_or_null(NodePath(n)) if level != null else null
		if light != null and light.has_method(&"set_powered"):
			light.call(&"set_powered", on)


func _physics_process(delta: float) -> void:
	_time += delta
	if not _off:
		return
	_off_time += delta
	if technician != null and is_instance_valid(technician) \
			and absf(technician.global_position.x - repair_point.x) <= REPAIR_REACH \
			and absf(technician.global_position.y - repair_point.y) <= 20.0:
		_repair += delta
	if _repair >= repair_time or _off_time >= backup_time:
		_restore_power(true)
		return
	queue_redraw()


func _draw() -> void:
	if repair_point == Vector2.ZERO:
		return
	# 电闸:墙上一个小铁柜,在技工胸口高度
	var p := repair_point + Vector2(-6.0, -34.0)
	draw_rect(Rect2(p, Vector2(12.0, 14.0)), cabinet_color)
	draw_rect(Rect2(p, Vector2(12.0, 1.0)), cabinet_color.lightened(0.2))
	draw_rect(Rect2(p + Vector2(5.0, 3.0), Vector2(2.0, 6.0)), cabinet_color.darkened(0.4))   # 闸把
	if not _off:
		return
	# 断着电:柜门一闪一闪的红点;有人在修:冒火花 + 一条进度
	if fmod(_time, 0.8) < 0.4:
		draw_rect(Rect2(p + Vector2(2.0, 2.0), Vector2(2.0, 2.0)), Color("8B3A2F"))
	if _repair > 0.0:
		if fmod(_time * 9.0, 1.0) < 0.4:
			draw_rect(Rect2(p + Vector2(4.0 + sin(_time * 40.0) * 4.0, 10.0 + cos(_time * 33.0) * 3.0), Vector2(1.0, 1.0)), spark_color)
		draw_rect(Rect2(p + Vector2(-2.0, -5.0), Vector2(16.0, 2.0)), Color(0.04, 0.07, 0.12, 0.85))
		draw_rect(Rect2(p + Vector2(-2.0, -5.0), Vector2(16.0 * repair_ratio(), 2.0)), Color("3D6B8A"))
