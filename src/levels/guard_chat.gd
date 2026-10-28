class_name GuardChat
extends Node2D
## 两个守卫停下来聊天,Ryn 躲在附近才听得到(2026-10-12,线索链;用户定稿 A 段)。
##
## 塔4 军械库:吊桥上守卫 C(西半截)和 D(东半截)。Ryn 一进这一段(`approach_rect`),两人各自
## 走到巡逻线挨着的那一头(`meet_a_x` / `meet_b_x`)停下、面对面;Ryn 摸到 `hear_radius` 以内(比如
## 从吊桥下面货箱夹出来的暗缝爬过去),他们开口 —— 每句画在说话那人的头顶上,不走底部字幕:
##
##     守卫甲:「上个月押下去那个女修理工,一路上都在说,会有人来找她。」
##     守卫乙:「谁会下坑找人啊。」
##     守卫甲:「也对。」
##
## 只说一遍。站好了、Ryn 还没靠近时,头顶冒一个淡淡的「……」(在聊,但听不清 —— 走近点)。
## 等太久(`max_wait`)Ryn 没来,两人各走各的,过一会儿再碰头。任何一个守卫起疑 / 发现、或者
## 失败流程开始,马上散开,下次重新来(没说完的不算说过)。
##
## 停着的守卫照样看得见人(视锥不变,只是朝向对方);行为层(`GuardBehaviour`)在这段时间里歇着,
## 不自己转身。节点原点放在 (0, 0):画的位置都按守卫的世界坐标算。
##
## Usage (in a scene): 关卡由 `tools/level_builder` 生成时用 `lv.guard_chat(...)` 放,排在守卫后面
## (同一帧里守卫先走、这里再改朝向)。

enum Phase { IDLE, GATHER, WAIT_EAR, TALK, DONE }

@export var guard_a: Guard
@export var guard_b: Guard
## A / B 在哪里停下(世界 x)。一般是两人巡逻线挨着的那两头 —— 走到头自然会停在那里。
@export var meet_a_x: float = 0.0
@export var meet_b_x: float = 0.0
## Ryn 进这块(世界坐标),两人开始往碰头的地方走。
@export var approach_rect: Rect2 = Rect2()
## 那几句:「0|……」是 A 说、「1|……」是 B 说;「\n」换行。
@export var lines: PackedStringArray = PackedStringArray()
## Ryn 离两人中点多近才听得到,px。
@export var hear_radius: float = 240.0
## 两人停好之后最多等 Ryn 多久,秒。
@export var max_wait: float = 20.0
## 散开之后多久才再碰头,秒。
@export var regroup_delay: float = 6.0
@export var ryn: Ryn
@export var detection_reset: DetectionReset
@export var font_config: TowerSubtitleConfig
## 字号(按这个栅格化再缩一半,镜头放大 2 倍后一比一)。
@export var font_size: int = 16
@export var text_color: Color = Color("C8D4E0")
@export var outline_color: Color = Color("0B1220")

const ARRIVE_PX: float = 4.0
const HOLD_FOREVER: float = 1.0e6

var _phase: Phase = Phase.IDLE
var _parked: Array[bool] = [false, false]
var _wait: float = 0.0
var _cooldown: float = 0.0
var _line: int = 0
var _line_t: float = 0.0
var _time: float = 0.0
var _font: Font


func _ready() -> void:
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var face := SystemFont.new()
	if font_config != null:
		face.font_names = font_config.font_names
	_font = face
	if detection_reset != null:
		detection_reset.phase_changed.connect(_on_fail_phase)


## 现在到哪一步了(验证脚本用)。
func phase() -> Phase:
	return _phase


## 正在说第几句(0 起);没在说返回 -1。
func current_line() -> int:
	return _line if _phase == Phase.TALK else -1


func _physics_process(delta: float) -> void:
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	if ryn == null or guard_a == null or guard_b == null:
		return
	var busy: bool = _phase == Phase.GATHER or _phase == Phase.WAIT_EAR or _phase == Phase.TALK
	if busy and (guard_a.state != Guard.State.PATROL or guard_b.state != Guard.State.PATROL):
		_scatter()
		return
	match _phase:
		Phase.IDLE:
			if _cooldown <= 0.0 and approach_rect.has_point(ryn.global_position):
				_phase = Phase.GATHER
				_parked = [false, false]
		Phase.GATHER:
			_try_park(0)
			_try_park(1)
			if _parked[0] and _parked[1]:
				_phase = Phase.WAIT_EAR
				_wait = 0.0
		Phase.WAIT_EAR:
			_face_each_other()
			if _can_hear():
				_phase = Phase.TALK
				_line = 0
				_line_t = 0.0
				Audio.play(&"subtitle", -22.0, 0.7)
			else:
				_wait += delta
				if _wait > max_wait:
					_scatter()
		Phase.TALK:
			_face_each_other()
			_line_t += delta
			if _line_t >= _line_time(_line):
				_line += 1
				_line_t = 0.0
				if _line >= lines.size():
					_release()
					_phase = Phase.DONE
				else:
					Audio.play(&"subtitle", -22.0, 0.7)
	queue_redraw()


func _guard(i: int) -> Guard:
	return guard_a if i == 0 else guard_b


func _behaviour(i: int) -> Node:
	return _guard(i).get_node_or_null(^"Behaviour")


## 走到碰头点就停下、面朝对方,行为层歇着。
func _try_park(i: int) -> void:
	if _parked[i]:
		return
	var g: Guard = _guard(i)
	var mx: float = meet_a_x if i == 0 else meet_b_x
	if absf(g.global_position.x - mx) > ARRIVE_PX or not g.is_on_floor():
		return
	_parked[i] = true
	g.hold_patrol(HOLD_FOREVER)
	var b := _behaviour(i)
	if b != null and b.has_method(&"suspend"):
		b.call(&"suspend", HOLD_FOREVER)
	_face_each_other()


func _face_each_other() -> void:
	for i in 2:
		if _parked[i]:
			var g: Guard = _guard(i)
			var other: Guard = _guard(1 - i)
			g.facing = 1 if other.global_position.x >= g.global_position.x else -1


func _can_hear() -> bool:
	var mid: Vector2 = (guard_a.global_position + guard_b.global_position) * 0.5
	return ryn.global_position.distance_to(mid) <= hear_radius


func _line_time(i: int) -> float:
	if i < 0 or i >= lines.size():
		return 0.0
	return 1.2 + 0.11 * float(_text_of(lines[i]).replace("\n", "").length())


func _speaker(entry: String) -> int:
	return 1 if entry.begins_with("1|") else 0


func _text_of(entry: String) -> String:
	var bar: int = entry.find("|")
	return entry.substr(bar + 1) if bar >= 0 and bar <= 1 else entry


## 放人:各自背对对方,接着巡逻。
func _release() -> void:
	for i in 2:
		if not _parked[i]:
			continue
		var g: Guard = _guard(i)
		var other: Guard = _guard(1 - i)
		var b := _behaviour(i)
		if b != null and b.has_method(&"suspend"):
			b.call(&"suspend", 0.0)
		if g.state == Guard.State.PATROL:
			g.facing = -1 if other.global_position.x >= g.global_position.x else 1
		g.release_hold()
	_parked = [false, false]


## 散开:没说完的不算说过,过一会儿再碰头。
func _scatter() -> void:
	_release()
	_phase = Phase.IDLE
	_cooldown = regroup_delay
	_line = 0
	_line_t = 0.0


func _on_fail_phase(p: FailSequence.Phase) -> void:
	if p != FailSequence.Phase.IDLE and _phase != Phase.DONE and _phase != Phase.IDLE:
		_scatter()


func _draw() -> void:
	if _font == null:
		return
	if _phase == Phase.WAIT_EAR:
		# 在聊,但听不清:头顶一个淡淡的「……」,一闪一闪
		var a: float = 0.25 + 0.2 * sin(_time * 3.0)
		_bubble(guard_a, "……", a)
	elif _phase == Phase.TALK and _line < lines.size():
		var entry: String = lines[_line]
		var dur: float = _line_time(_line)
		var a: float = clampf(_line_t / 0.2, 0.0, 1.0) * clampf((dur - _line_t) / 0.25, 0.0, 1.0)
		_bubble(_guard(_speaker(entry)), _text_of(entry), a)


## 一句话画在守卫头顶上(多行往上叠),下面一个小三角指着他。
## Ryn 在下面一层(货箱下的暗缝)时守卫的头在画面最上沿 —— 整段字往下挪进画面里,不被切掉。
func _bubble(g: Guard, text: String, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var half: float = 0.5
	var rows: PackedStringArray = text.split("\n")
	var line_h: float = float(font_size) * half + 2.0
	var head := g.global_position + Vector2(0.0, -54.0)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-2.0, -1.0), head + Vector2(2.0, -1.0),
			head + Vector2(0.0, 2.0)]), Color(text_color, 0.6 * alpha))
	var y: float = head.y - 4.0 - line_h * float(rows.size() - 1)
	var view := _view()
	var top: float = view.position.y + 6.0 + float(font_size) * half
	if y < top:
		y = top
	for row in rows:
		var w: float = _font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * half
		var x: float = clampf(head.x - w * 0.5, view.position.x + 4.0, view.end.x - 4.0 - w)
		draw_set_transform(Vector2(roundf(x), roundf(y)), 0.0, Vector2(half, half))
		draw_string_outline(_font, Vector2.ZERO, row, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6,
				Color(outline_color, 0.9 * alpha))
		draw_string(_font, Vector2.ZERO, row, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(text_color, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		y += line_h


## 镜头现在看得到的世界矩形。
func _view() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	var vp: Vector2 = get_viewport_rect().size
	if cam == null:
		return Rect2(Vector2.ZERO, vp)
	var size: Vector2 = vp / cam.zoom
	return Rect2(cam.get_screen_center_position() - size * 0.5, size)
