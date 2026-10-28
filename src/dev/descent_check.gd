extends SceneTree
## DEV ONLY:坑口·下行关检查 + 截图(蚀减速、跑不起来、深蚀恍惚 + 那句话、出蚀恢复、梯子顶)。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/descent_check.gd
##
## 每项打印 PASS/FAIL,有失败时退出码 1。截图存到 user://descent_shots/。
## 用真实按键(Input.action_press)。蚀区、恍惚节点不写类型(`-s` 模式下写了类名会在 autoload
## 之前编译,`Audio` 找不到),用 get()/call() 取。
## 节点名跟着 tools/level_builder 走:吊板 2 的浅蚀是 `Corrosion00`、吊板 4 的深蚀是 `Corrosion01`。

const SCENE := "res://src/levels/pit_descent.tscn"
const TILE := 16.0

var level: Node
var ryn: Ryn
var fails := 0
var shot := 0


func _check(ok: bool, what: String) -> void:
	print("[descent] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


## 按物理帧(固定 60/秒)等,不按渲染帧 —— 120Hz 屏幕上渲染帧是两倍快。
func _wait(sec: float) -> void:
	for _i in int(sec * 60.0):
		await physics_frame


func _snap(name: String) -> void:
	var dir := OS.get_user_data_dir() + "/descent_shots"
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png("%s/%02d-%s.png" % [dir, shot, name])
	shot += 1


func _release_all() -> void:
	for a in [&"move_left", &"move_right", &"move_down", &"move_up", &"sprint"]:
		Input.action_release(a)


## 站在 (x 格, floor 行) 上。
func _place(x_tile: float, floor_row: int) -> void:
	_release_all()
	ryn.velocity = Vector2.ZERO
	ryn.global_position = Vector2(x_tile * TILE + 8.0, floor_row * TILE)
	await _wait(0.3)


## 按着右走 `warm` 秒热身,再量 `sec` 秒走了多少 px/秒。
func _speed_right(sprint: bool, warm: float = 0.3, sec: float = 0.5) -> float:
	Input.action_press(&"move_right")
	if sprint:
		Input.action_press(&"sprint")
	await _wait(warm)
	var x0 := ryn.global_position.x
	await _wait(sec)
	var v := (ryn.global_position.x - x0) / sec
	_release_all()
	return v


## 按住 E 直到这块面板拆掉(最多 3 秒)。
func _hold_until(panel: Dismantlable) -> void:
	Input.action_press(&"interact")
	var t := 0.0
	while not panel.is_dismantled and t < 3.0:
		await physics_frame
		t += 1.0 / 60.0
	Input.action_release(&"interact")
	await _wait(0.2)


func _subtitle_text() -> String:
	var sub := level.get_node("TowerSubtitle") as TowerSubtitle
	return (sub.get("_label") as Label).text


## 守卫和灯都不抓人。只设 `darkness_veto` 不够:`ShadowRegistry` 开场后会把它改回暗区判定。
## 守卫整个停掉;探照灯、门禁跟路线机器人一样把 `ryn` 置空。
func _disarm(node: Node) -> void:
	for c in node.get_children():
		if c is Guard:
			(c as Guard).process_mode = Node.PROCESS_MODE_DISABLED
		elif c.get(&"ryn") != null and c.get(&"detection_reset") != null:
			c.set(&"ryn", null)
		_disarm(c)


func _initialize() -> void:
	create_timer(150.0).timeout.connect(func() -> void:
		print("[descent] TIMEOUT (a step errored or hung)")
		quit(2))
	level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	ryn = level.get_node("Ryn") as Ryn
	_disarm(level)
	await _wait(1.5)
	_snap("start-rim")

	var shallow: Area2D = level.get_node("Corrosion00")
	var deep: Area2D = level.get_node("Corrosion01")
	var haze: CanvasLayer = level.get_node("CorrosionHaze")
	_check(is_equal_approx(float(deep.get("haze_strength")), 1.0), "Corrosion01 是深蚀")

	# ---- 吊板 2(第 34 行):蚀外 / 蚀里走路速度
	await _place(44.0, 34)
	var v_clean := await _speed_right(false)
	await _place(57.0, 34)
	var v_corr := await _speed_right(false)
	var drag: float = shallow.get("drag")
	_check(absf(v_corr / v_clean - drag) < 0.08,
			"浅蚀里走路变慢:%.0f → %.0f px/s(比 %.2f,设定 %.2f)" % [v_clean, v_corr, v_corr / v_clean, drag])
	await _place(57.0, 34)
	Input.action_press(&"move_right")
	Input.action_press(&"sprint")
	await _wait(0.4)
	_check(not ryn.is_sprinting, "蚀里按跑步也跑不起来(没有跑步噪音)")
	_snap("shallow-corrosion")
	await _wait(1.5)
	_release_all()
	await _place(74.0, 34)
	_check(is_equal_approx(ryn.ground_drag, 1.0), "走出蚀:速度恢复")
	_check(not bool(haze.call("deep_done")), "浅蚀不触发深的恍惚")

	# ---- 梯子顶:蹲着走过去不会被吸下去;站上去按下能爬下去
	await _place(81.0, 22)
	Input.action_press(&"move_down")
	Input.action_press(&"move_right")
	await _wait(2.6)   # 蹲行 44px/s
	_check(ryn.state == Ryn.State.NORMAL and ryn.global_position.x > 85.0 * TILE,
			"蹲着走过梯子口:没被吸到梯子上(x=%.0f)" % ryn.global_position.x)
	_release_all()
	await _place(84.0, 22)
	Input.action_press(&"move_down")
	await _wait(0.4)
	_check(ryn.state == Ryn.State.CLIMBING, "站在梯子顶按下:爬下去")
	await _wait(12.0 * TILE / ryn.config.climb_speed + 0.8)   # 12 格梯子,按设定的爬速算(2026-10-15 爬速 56 → 40)
	_check(ryn.state == Ryn.State.NORMAL and absf(ryn.global_position.y - 34.0 * TILE) < 2.0,
			"爬到梯子脚自动下梯(y=%.0f)" % ryn.global_position.y)
	_release_all()

	# ---- 吊板 4(第 58 行):深蚀 → 恍惚 + 那句话
	await _place(44.0, 58)
	Input.action_press(&"move_left")
	await _wait(1.3)
	_check(bool(haze.call("deep_done")), "走进深蚀:恍惚")
	_check(float(haze.call("strength")) > 0.5, "恍惚强度 %.2f" % float(haze.call("strength")))
	_snap("deep-haze")
	await _wait(0.6)
	_check(_subtitle_text() == "「头好沉……身体快撑不住了。不过我身上好像还有什么东西。」", "恍惚后出字:「头好沉。……」")
	_snap("deep-haze-line")
	await _wait(2.5)
	_release_all()
	_check(float(haze.call("strength")) == 0.0, "恍惚退掉")
	_snap("after-haze")

	# ---- 吊板 5「蚀池放流」(2026-10-12):满池走得很慢 → 拆盖板钻进泵房 → 拆阀门 → 排干 → 正常速度
	var pool: Area2D = level.get_node("Corrosion02")
	var drain: Node2D = level.get_node("Drain00")
	var gp := level.get_node("GuardP5") as Guard
	gp.process_mode = Node.PROCESS_MODE_INHERIT
	gp.darkness_veto = func(_p: Vector2) -> bool: return true
	await _place(30.0, 72)
	_snap("pool-full")
	var v_pool := await _speed_right(false)
	_check(v_pool < 40.0, "满池蚀里走得很慢:%.0f px/s(平时 105)" % v_pool)
	var cover: Dismantlable = null
	var valve: Dismantlable = null
	for n in level.get_children():
		var d := n as Dismantlable
		if d != null and d.kind == Dismantlable.Kind.PANEL:
			if d.look == Dismantlable.Look.VENT_COVER:
				cover = d
			elif d.look == Dismantlable.Look.VALVE:
				valve = d
	_check(cover != null and valve != null, "有通风口盖板和排放阀")
	await _place(10.0, 72)
	await _hold_until(cover)
	for i in 3:
		Input.action_press(&"interact")
		await physics_frame
		await physics_frame
		Input.action_release(&"interact")
		await _wait(0.4)
		if ryn.state == Ryn.State.HIDING:
			break
	await _wait(1.2)
	_check(absf(ryn.global_position.y - 81.0 * TILE) < 4.0, "拆盖板钻下去,到了泵房(y %.0f 格)" % (ryn.global_position.y / TILE))
	await _place(4.0, 81)
	_snap("pump-room")
	await _hold_until(valve)
	_check(valve.is_dismantled, "拆掉排放阀")
	await _wait(1.5)
	_snap("pool-draining")
	await _wait(3.0)
	_check(bool(drain.call("is_drained")) and float(pool.call("level")) <= 0.02, "4 秒排干")
	var pursuit := gp.get_node("Pursuit") as GuardPursuit
	_check(pursuit.mode() == GuardPursuit.Mode.SEARCHING or gp.global_position.x < 66.0 * TILE,
			"排放的声音把东头的守卫引过来(x %.0f 格)" % (gp.global_position.x / TILE))
	gp.process_mode = Node.PROCESS_MODE_DISABLED
	await _place(30.0, 72)
	_snap("pool-drained")
	var v_dry := await _speed_right(false)
	_check(v_dry > 90.0, "排干之后走路正常:%.0f px/s" % v_dry)

	# ---- 坑底
	await _place(56.0, 136)
	await _wait(1.2)
	_snap("bottom-fog")

	print("[descent] done, %d fail(s). shots: %s/descent_shots" % [fails, OS.get_user_data_dir()])
	quit(1 if fails > 0 else 0)
