class_name HidingSpot
extends Area2D
## 藏身点:柜子 / 通风管(Mark of the Ninja 的藏身处)。
##
## 暗处只挡守卫的眼睛,挡不住探照灯;柜子两样都挡。这给了「不在暗处也能躲」的选项,
## 也是塔4 对付探照灯的办法。
##
##   | 种类 | 进去 | 里面 | 出来 |
##   |---|---|---|---|
##   | 柜子 LOCKER | 站在柜子前按 E | 不画人,柜门缝里露出一双眼睛;守卫、探照灯、门禁灯都抓不到 | 按 E、跳、或进去后重新按方向 |
##   | 通风管 VENT | 站在管口按 E | 在管子里爬 `travel_time` 秒 | 从 `link` 那一头蹲着爬出来 |
##
## 进柜子会「咚」一声(`enter_noise`,很小),附近的守卫会过来看 —— 躲是有代价的。
## 抓人的一方都先问 `Ryn.is_detectable()`,所以这里不用知道有哪些守卫、哪些灯。
##
## 节点原点是 **左上角**,与 `GrayBlock` / `Dismantlable` / `ShadowZone` 一致;
## 底边应当贴在地面上(Ryn 躲进去时站在底边中点)。
##
## Usage (in a scene): instance `hiding_spot.tscn`,设 `position`、`kind`;通风管两头互相设 `link`。

enum Kind {
	## 柜子:原地躲着。
	LOCKER,
	## 通风管口:钻进去,从另一头出来。
	VENT,
}

## 每个藏身点都加入这个组,demo 和关卡脚本可以找到它们。
const GROUP: StringName = &"hiding_spot"
const INTERACT_ACTION: StringName = &"interact"
## 刚进去的这段时间里不响应 E —— 进去那一下的 E 不能紧接着把人又弹出来。
const REENTRY_GUARD: float = 0.2
## 进出时柜门晃动的时长,秒。
const SHAKE_TIME: float = 0.16
## 门缝里的眼睛多久眨一次,秒。
const BLINK_PERIOD: float = 3.2

@export var kind: Kind = Kind.LOCKER
## 大小,px。柜子默认 24x48(比 Ryn 的 44 高);通风管口建议 20x14。
@export var size: Vector2 = Vector2(24.0, 48.0):
	set(value):
		size = value
		_sync_shape()
		queue_redraw()
## 通风管的另一头。柜子不用设。
@export var link: HidingSpot
## 盖在这个管口上的螺栓盖板(2026-10-12 谜题房)。盖着就钻不进去,先长按 E 拆掉;为空 = 没盖。
## 只挡「从这头进去」,从另一头钻过来照样出得来(盖板是从外面拧上的)。
@export var cover: Dismantlable
## 在通风管里爬多久才从另一头出来,秒。
@export var travel_time: float = 0.8
## 进出时发出的噪音半径,px。柜门很轻,管子更响。
@export var enter_noise: float = 40.0
## 提示文字;为空则按种类给默认值。
@export var prompt_text: String = ""

@export_group("Look")
@export var body_color: Color = Color("16233A")
@export var door_color: Color = Color("1E3050")
@export var rim_color: Color = Color("3D6B8A")
@export var slit_color: Color = Color("0B1220")
@export var eye_color: Color = Color("E3DDE0")
@export var prompt_color: Color = Color("C8D4E0")
@export var prompt_outline: Color = Color("0B1220")
@export var prompt_font_size: int = 18

var _shape: RectangleShape2D
var _collider: CollisionShape2D
var _label: Label
var _ryn: Ryn
var _inside_for: float = 0.0
var _travel_left: float = 0.0
var _shake_left: float = 0.0
var _clock: float = 0.0
var _open_left: float = 0.0
## 柜门被守卫拉开后敞着多久,秒。
const OPEN_TIME: float = 0.7


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	monitorable = false
	_shape = RectangleShape2D.new()
	_collider = CollisionShape2D.new()
	_collider.shape = _shape
	add_child(_collider)
	_sync_shape()
	add_to_group(GROUP)
	_label = _build_label()
	add_child(_label)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## 躲进去时 Ryn 站的点(世界坐标):底边中点。
func anchor() -> Vector2:
	return global_position + Vector2(size.x * 0.5, size.y)


## 守卫拉开柜门。里面有人就把人请出来并返回她(由守卫去「发现」),没人返回 null。
## 柜门敞开一会儿,玩家看得见「他查过了」。
##
## Usage: `var found := locker.open_by_guard()`
func open_by_guard() -> Node2D:
	_open_left = OPEN_TIME
	_shake_left = SHAKE_TIME
	var audio := get_node_or_null(^"/root/Audio")
	if audio != null:
		audio.play(&"land", -9.0, 0.6)
	if is_occupied():
		var found: Ryn = _ryn
		found.exit_hiding()
		return found
	return null


## Ryn 站在口前吗(能进,或者管口还盖着、等着拆)。小地图用:这时画出通风管通到哪 ——
## 盖着的管口也画,玩家拆之前就知道它通到哪(谜题房要靠这个选)。
func is_prompting() -> bool:
	return _ryn != null and is_instance_valid(_ryn) and _ryn.input_enabled and not is_occupied() \
			and (_label.visible or is_covered())


## 管口还盖着吗。
func is_covered() -> bool:
	return cover != null and is_instance_valid(cover) and not cover.is_dismantled


## 在通风管里爬了多少:0 刚钻进去 → 1 快出来;不在这个管口里返回 -1。小地图用。
func travel_progress() -> float:
	if kind != Kind.VENT or not is_occupied():
		return -1.0
	return clampf(1.0 - _travel_left / maxf(travel_time, 0.01), 0.0, 1.0)


## Ryn 现在是不是在这个点里。
func is_occupied() -> bool:
	return _ryn != null and is_instance_valid(_ryn) and _ryn.hiding_spot == self


func _physics_process(delta: float) -> void:
	_clock += delta
	_shake_left = maxf(_shake_left - delta, 0.0)
	_open_left = maxf(_open_left - delta, 0.0)
	var occupied: bool = is_occupied()
	if occupied:
		_inside_for += delta
		if kind == Kind.VENT:
			_travel_left -= delta
			if _travel_left <= 0.0:
				_come_out_at_far_end()
		elif _inside_for > REENTRY_GUARD and Input.is_action_just_pressed(INTERACT_ACTION):
			_ryn.exit_hiding()
			_bump(enter_noise)
	elif _ryn != null and is_instance_valid(_ryn) and _ryn.can_hide() and not is_covered() \
			and Input.is_action_just_pressed(INTERACT_ACTION):
		if _ryn.enter_hiding(self, anchor()):
			_inside_for = 0.0
			_travel_left = travel_time
			_bump(enter_noise)
	_sync_label(occupied)
	queue_redraw()


## 通风管:从另一头蹲着爬出来。
func _come_out_at_far_end() -> void:
	var far: HidingSpot = link if link != null and is_instance_valid(link) else self
	_ryn.exit_hiding(far.anchor())
	far._bump(far.enter_noise)


## 进出的一下:晃门、出声、发噪音、管口掉点灰。autoload 走 /root 路径,
## 静态分析时 autoload 名会被当成类名(gameplay_audio.gd 同理)。
func _bump(noise_radius: float) -> void:
	_shake_left = SHAKE_TIME
	var audio := get_node_or_null(^"/root/Audio")
	if kind == Kind.LOCKER:
		if audio != null:
			audio.play(&"land", -11.0, 0.7)
	else:
		if audio != null:
			audio.play(&"dismantle_1", -12.0, 0.8)
		var particles := get_parent().get_node_or_null(^"ParticleBurst") if get_parent() != null else null
		if particles != null and particles.has_method(&"emit_dust"):
			particles.emit_dust(anchor(), 5, 0, 0.8)
	var bus := get_node_or_null(^"/root/Noise")
	if bus != null:
		bus.emit_noise(anchor(), noise_radius)


func _sync_shape() -> void:
	if _shape == null or _collider == null:
		return
	# 感应区比本体左右各宽 6px:站在柜子前面就算到了
	_shape.size = size + Vector2(12.0, 0.0)
	_collider.position = size * 0.5


func _build_label() -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Heiti SC",
			"Noto Sans CJK SC", "Microsoft YaHei", "sans-serif"])
	l.add_theme_font_override(&"font", f)
	l.add_theme_font_size_override(&"font_size", prompt_font_size)
	l.add_theme_color_override(&"font_color", prompt_color)
	l.add_theme_constant_override(&"outline_size", 2)
	l.add_theme_color_override(&"font_outline_color", prompt_outline)
	l.size = Vector2(140.0, float(prompt_font_size) + 4.0)
	l.position = Vector2(size.x * 0.5 - 70.0, -l.size.y - 4.0)
	l.visible = false
	return l


func _sync_label(occupied: bool) -> void:
	if _label == null:
		return
	# 玩家不能操作时(被发现、过场)不出提示
	var near: bool = _ryn != null and is_instance_valid(_ryn) and _ryn.input_enabled
	if occupied and kind == Kind.LOCKER and near:
		_label.text = KeyBindings.with_key("E 出来")
		_label.visible = true
	elif near and not occupied and _ryn.can_hide() and not is_covered():
		_label.text = KeyBindings.with_key(prompt_text if not prompt_text.is_empty() else (
				"E 躲进柜子" if kind == Kind.LOCKER else "E 钻进去"))
		_label.visible = true
	else:
		_label.visible = false


func _on_body_entered(body: Node2D) -> void:
	if body is Ryn:
		_ryn = body


func _on_body_exited(body: Node2D) -> void:
	# 躲在里面时人被放在锚点上,仍在感应区内;只有真的走开才清掉
	if body == _ryn and not is_occupied():
		_ryn = null


func _draw() -> void:
	var shake: float = 0.0
	if _shake_left > 0.0:
		shake = 1.0 if fposmod(_shake_left * 40.0, 2.0) < 1.0 else -1.0
	if kind == Kind.LOCKER:
		_draw_locker(shake)
	else:
		_draw_vent(shake)


func _draw_locker(shake: float) -> void:
	var w: float = size.x
	var h: float = size.y
	var o := Vector2(shake, 0.0)
	draw_rect(Rect2(o, Vector2(w, h - 2.0)), body_color)                       # 柜身
	if _open_left > 0.0:
		# 柜门被拉开:里面是黑的,门板只剩铰链那一侧的一条
		draw_rect(Rect2(o + Vector2(2.0, 2.0), Vector2(w - 4.0, h - 6.0)), slit_color)
		draw_rect(Rect2(o + Vector2(0.0, 2.0), Vector2(3.0, h - 6.0)), door_color)
		draw_rect(Rect2(o, Vector2(w, 1.0)), rim_color)
		return
	draw_rect(Rect2(o + Vector2(2.0, 2.0), Vector2(w - 4.0, h - 6.0)), door_color)  # 柜门
	draw_rect(Rect2(o, Vector2(w, 1.0)), rim_color)                            # 顶面受光
	for y in [6.0, 9.0, 12.0]:                                                 # 门上的百叶缝
		draw_rect(Rect2(o + Vector2(5.0, y), Vector2(w - 10.0, 1.0)), slit_color)
	draw_rect(Rect2(o + Vector2(w - 6.0, h * 0.5 - 2.0), Vector2(2.0, 5.0)), rim_color)  # 把手
	draw_rect(Rect2(o + Vector2(2.0, h - 2.0), Vector2(3.0, 2.0)), body_color)  # 柜脚
	draw_rect(Rect2(o + Vector2(w - 5.0, h - 2.0), Vector2(3.0, 2.0)), body_color)
	if is_occupied() and fposmod(_clock, BLINK_PERIOD) > 0.14:
		# 门缝里的眼睛:朝向跟着 Ryn
		var cx: float = w * 0.5 + float(_ryn.facing) * 1.0
		draw_rect(Rect2(o + Vector2(roundf(cx - 3.0), 9.0), Vector2(1.0, 1.0)), eye_color)
		draw_rect(Rect2(o + Vector2(roundf(cx + 2.0), 9.0), Vector2(1.0, 1.0)), eye_color)


func _draw_vent(shake: float) -> void:
	var w: float = size.x
	var h: float = size.y
	var o := Vector2(shake, 0.0)
	draw_rect(Rect2(o, Vector2(w, h)), slit_color)                             # 管口里是黑的
	draw_rect(Rect2(o, Vector2(w, 1.0)), rim_color)                            # 框
	draw_rect(Rect2(o, Vector2(1.0, h)), rim_color)
	draw_rect(Rect2(o + Vector2(w - 1.0, 0.0), Vector2(1.0, h)), rim_color)
	var x: float = 4.0
	while x < w - 3.0:                                                         # 栅条
		draw_rect(Rect2(o + Vector2(x, 2.0), Vector2(1.0, h - 2.0)), door_color)
		x += 4.0
