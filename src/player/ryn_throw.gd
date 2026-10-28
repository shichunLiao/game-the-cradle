class_name RynThrow
extends Node2D
## 丢扣件:按住丢扣件键瞄准,左右键调落点,松开丢出去;落地的声音把守卫引过去。
##
## 2026-10-11 加。玩家之前遇到难缠的守卫只能躲和等(用户两次反馈「过不去」),
## 这是一个**主动**的办法 —— Mark of the Ninja 的丢东西。守卫本来就会循声查看
## (`GuardPursuit`),这里只负责「在哪儿出声」。
##
## ## 读得懂
## 瞄准时画出:抛物线(和真的飞行同一个算法,`ThrownBolt.predict`)、落点、
## 落地声音能传多远的圈,以及**圈里的守卫头上一个小箭头** —— 丢之前就知道会引来谁。
##
## ## 规则
##  - 只能站在地上瞄准(不能在空中、梯子上、柜子里)。瞄准时不走路;跳 = 取消。
##  - 身上最多 `config.max_count` 个;到存档点、被发现重来都补满。左上角显示还剩几个。
##  - 序章和塔1 一开始**还不会**(关卡根节点 `throw_unlocked = false`):身上没有、左上角不显示、
##    存档点也不补;塔1 四楼捡到第一颗扣件(`BoltPickup`)才学会,之后照常补满。
##  - 丢出去本身不出声,落地才出声。
##
## ## 动作
## 瞄准时 Ryn 停在「蓄力」那一格(手举到耳边捏着扣件),松开播「出手 → 随势 → 收」
## (`RynSpriteVisual.ACTION_AIM` / `ACTION_THROW`,只用原立绘部件平移拼的,2026-10-11 用户定稿)。
## 蹲着瞄准时保持蹲姿 —— 站姿的图对不上蹲下的身体。
##
## Usage (in a scene): 作为 `Ryn` 的子节点(`ryn.tscn` 已带),`config` 指向 `throw_default.tres`。
## 关卡里的存档点、名叫 `CheckpointManager` 的节点会被自动接上(补满)。

## 丢出去一个(给音效、测试用)。
signal thrown(bolt: ThrownBolt)
## 剩余数量变了。
signal count_changed(count: int)

const HUD_LAYER: int = 88

@export var config: ThrowConfig

var _ryn: Ryn
var _count: int = 0
var _aiming: bool = false
var _aim: float = 0.0
var _was_held: bool = false
var _preview: Dictionary = {}
var _empty_flash: float = 0.0
var _hud: Control
var _hud_layer: CanvasLayer
var _time: float = 0.0
var _unlocked: bool = true


func _ready() -> void:
	_ryn = get_parent() as Ryn
	if _ryn == null or config == null:
		set_physics_process(false)
		return
	top_level = true          # 画在世界坐标里,不跟着 Ryn 的变换
	global_position = Vector2.ZERO
	z_index = 6
	_count = config.max_count
	_build_hud()
	_connect_checkpoints.call_deferred()
	_read_level_unlock.call_deferred()


## 还剩几个。
func count() -> int:
	return _count


## 正在瞄准吗。
func is_aiming() -> bool:
	return _aiming


## 学会丢扣件了吗(序章、塔1 捡到第一颗之前是 false)。
func is_unlocked() -> bool:
	return _unlocked


## 身上满了吗。还没学会时永远不满(第一颗总能捡)。
func is_full() -> bool:
	return _unlocked and _count >= config.max_count


## 捡到 `n` 个(地上的扣件 `BoltPickup`)。不超过上限;返回实际加了几个。
## 还没学会时,捡到就学会了。
func add_bolts(n: int) -> int:
	if not _unlocked:
		_unlocked = true
		_hud.visible = true
	var before: int = _count
	_count = mini(_count + maxi(n, 0), config.max_count)
	if _count != before:
		count_changed.emit(_count)
		_hud.queue_redraw()
	return _count - before


## 补满(到存档点、重来)。还没学会时什么都不做。
func refill() -> void:
	if _unlocked and _count != config.max_count:
		_count = config.max_count
		count_changed.emit(_count)
		_hud.queue_redraw()


## 预览算出来的落点;没在瞄准或不会落地时返回 null(给验证脚本用)。
func predicted_landing() -> Variant:
	if not _aiming or _preview.is_empty() or not bool(_preview["landed"]):
		return null
	return _preview["at"]


func _read_level_unlock() -> void:
	var level: Node = _ryn.get_parent()
	if level == null or level.get(&"throw_unlocked") == null:
		return
	if not bool(level.get(&"throw_unlocked")):
		_unlocked = false
		_count = 0
		_hud.visible = false


func _connect_checkpoints() -> void:
	var level: Node = _ryn.get_parent()
	if level == null:
		return
	# 每次碰到存档点都补满 —— 包括回到已经激活过的那个(`checkpoint_activated` 只在第一次激活时发)
	for node in get_tree().get_nodes_in_group(Checkpoint.GROUP):
		var cp := node as Checkpoint
		if cp != null and level.is_ancestor_of(cp):
			cp.checkpoint_touched.connect(func(_c: Checkpoint) -> void: refill())
	var cpm := level.get_node_or_null(^"CheckpointManager") as CheckpointManager
	if cpm != null:
		cpm.state_restored.connect(refill)   # 被发现、回存档点重来


func _physics_process(delta: float) -> void:
	_time += delta
	_empty_flash = maxf(_empty_flash - delta, 0.0)
	var held: bool = _ryn.input_enabled and _ryn.intent.throw_held
	if _aiming:
		if not _can_aim() or _ryn.intent.jump_pressed:
			_stop_aim()
		elif not held:
			_throw()
		else:
			_move_aim(_ryn.intent.move_x * config.aim_speed * delta)
			_update_preview()
	elif held and not _was_held and _unlocked:
		if _count > 0 and _can_aim():
			_start_aim()
		else:
			_empty_flash = 0.5
			_hud.queue_redraw()
	_was_held = held
	queue_redraw()
	if _empty_flash > 0.0:
		_hud.queue_redraw()


func _can_aim() -> bool:
	return _ryn.state == Ryn.State.NORMAL and _ryn.is_on_floor() and _ryn.input_enabled


func _start_aim() -> void:
	_aiming = true
	_ryn.aiming = true
	_aim = float(_ryn.facing) * config.start_distance
	_update_preview()
	if not _ryn.is_crouching:
		_set_pose(&"aim")


func _stop_aim() -> void:
	_aiming = false
	_ryn.aiming = false
	_preview = {}
	if _pose() == &"aim":
		_set_pose(&"")


## Ryn 的视觉节点(占位视觉没有 `set_action` 时什么都不做)。
func _set_pose(action: StringName) -> void:
	var visual: Node = _ryn.get_node_or_null(^"Visual")
	if visual != null and visual.has_method(&"set_action"):
		visual.call(&"set_action", action)


func _pose() -> StringName:
	var visual: Node = _ryn.get_node_or_null(^"Visual")
	if visual != null and visual.has_method(&"current_action"):
		return visual.call(&"current_action")
	return &""


## 落点左右移动;穿过 Ryn 脚下时直接跳到另一边的最近距离(中间那段丢不了)。
func _move_aim(dx: float) -> void:
	if is_zero_approx(dx):
		return
	var next: float = _aim + dx
	if signf(next) != signf(_aim) or absf(next) < config.min_distance:
		if signf(dx) != signf(_aim):
			next = signf(dx) * config.min_distance
		else:
			next = signf(_aim) * config.min_distance
	_aim = clampf(next, -config.max_distance, config.max_distance)
	_ryn.facing = 1 if _aim > 0.0 else -1


func _hand() -> Vector2:
	var h: float = config.hand_height_crouch if _ryn.is_crouching else config.hand_height_stand
	# 站着时 = 蓄力那一格里手的位置(手举到耳边,脚底往上约 30px、往前 6px)
	return _ryn.global_position + Vector2(float(_ryn.facing) * 6.0, -h)


func _update_preview() -> void:
	_preview = ThrownBolt.predict(get_world_2d().direct_space_state, _hand(),
			ThrownBolt.launch_velocity(config, _aim), config)


func _throw() -> void:
	var bolt := ThrownBolt.new()
	bolt.config = config
	bolt.velocity = ThrownBolt.launch_velocity(config, _aim)
	bolt.position = _hand()
	_ryn.get_parent().add_child(bolt)
	_count -= 1
	var crouched: bool = _ryn.is_crouching
	_stop_aim()
	if not crouched:
		_set_pose(&"throw")
		get_tree().create_timer(RynSpriteVisual.THROW_TIME).timeout.connect(func() -> void:
			if is_instance_valid(_ryn) and _pose() == &"throw":
				_set_pose(&""))
	Audio.play(&"bolt_throw", -10.0, randf_range(0.95, 1.05))
	thrown.emit(bolt)
	count_changed.emit(_count)
	_hud.queue_redraw()


# ---------------------------------------------------------------- 画:世界里的瞄准预览

func _draw() -> void:
	if not _aiming or _preview.is_empty():
		return
	var pts: PackedVector2Array = _preview["points"]
	var every: int = maxi(config.arc_dot_every, 1)
	for i in range(every, pts.size(), every):
		var fade: float = 0.35 + 0.65 * float(i) / float(pts.size())
		draw_rect(Rect2(pts[i] - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(config.arc_color, config.arc_color.a * fade))
	if not bool(_preview["landed"]):
		return
	var at: Vector2 = _preview["at"]
	# 落点:一个小十字
	draw_line(at + Vector2(-4.0, -4.0), at + Vector2(4.0, 4.0), config.arc_color, 1.0)
	draw_line(at + Vector2(-4.0, 4.0), at + Vector2(4.0, -4.0), config.arc_color, 1.0)
	# 声音能传多远:虚线圈,慢慢转
	var segs: int = 48
	var r: float = config.noise_radius
	for k in segs:
		if k % 2 == 1:
			continue
		var a0: float = TAU * float(k) / segs + _time * 0.3
		var a1: float = TAU * float(k + 1) / segs + _time * 0.3
		draw_line(at + Vector2(cos(a0), sin(a0)) * r, at + Vector2(cos(a1), sin(a1)) * r, config.ring_color, 1.0)
	# 圈里的守卫:头上一个往下指的小箭头 —— 他会过来
	for g in _guards_in_range(at):
		var top: Vector2 = g.global_position + Vector2(0.0, -62.0 - 2.0 * sin(_time * 6.0))
		draw_colored_polygon(PackedVector2Array([top + Vector2(-4.0, -4.0), top + Vector2(4.0, -4.0), top + Vector2(0.0, 1.0)]),
				config.arc_color)


func _guards_in_range(at: Vector2) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for c in _ryn.get_parent().get_children():
		if c is Guard:
			var g := c as Guard
			var hear: float = 1.0
			var p := g.get_node_or_null(^"Pursuit") as GuardPursuit
			if p != null:
				hear = p.hearing_scale
			if g.global_position.distance_to(at) <= config.noise_radius * hear:
				out.append(g)
	return out


# ---------------------------------------------------------------- 画:左上角剩几个

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = HUD_LAYER
	add_child(_hud_layer)
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hud.position = Vector2(20.0, 18.0)
	_hud.size = Vector2(160.0, 32.0)
	_hud.draw.connect(_draw_hud)
	_hud_layer.add_child(_hud)


func _draw_hud() -> void:
	if config.max_count <= 0:
		return
	var font: Font = ThemeDB.fallback_font
	var key_col := Color(0.55, 0.62, 0.72, 0.8)
	_hud.draw_rect(Rect2(0.0, 2.0, 20.0, 20.0), Color(key_col, 0.25), false, 1.0)
	var key: String = KeyBindings.key_name(&"throw")   # 改过按键,左上角的键跟着变
	_hud.draw_string(font, Vector2(10.0 - font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5, 17.0),
			key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, key_col)
	var flash: bool = _empty_flash > 0.0 and fmod(_empty_flash, 0.2) > 0.1
	for i in config.max_count:
		var c := Vector2(36.0 + i * 20.0, 12.0)
		var pts := PackedVector2Array()
		for k in 6:
			var ang: float = TAU * float(k) / 6.0 + PI / 6.0
			pts.append(c + Vector2(cos(ang), sin(ang)) * 7.0)
		if i < _count:
			_hud.draw_colored_polygon(pts, config.bolt_color)
			_hud.draw_circle(c, 2.5, Color(0.06, 0.08, 0.12))
		else:
			pts.append(pts[0])
			_hud.draw_polyline(pts, Color(0.85, 0.3, 0.25) if flash else Color(config.bolt_color, 0.35), 1.0)
