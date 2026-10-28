extends SceneTree
## DEV ONLY:谜题房检查 + 截图(2026-10-12)。四座塔各一间,全部用真实按键(长按 E 拆、点 E 钻管子)。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/puzzle_check.gd
##
## 塔1 断桥:拆链条锚 → 吊桥倒下、站得上去;砸下来的声音把西平台的守卫引过来。
## 塔2 蒸汽廊:不放汽站在哨兵面前 → 被发现;拧阀门 → 那一片算暗处、站在哨兵面前不被发现;汽散、阀门复原、能再拧。
## 塔3 控制室:盖着的管口钻不进;拆盖板 → 钻得进;控制室里拆面板 → 铁卷门开;被发现回存档点 → 门关回去、面板复原。
## 塔4 配电室:拆盖板钻进配电室;拆配电箱 → 探照灯断电、院子变暗;技工走去电闸修好 → 来电、配电箱复原。
##
## 截图存到 production/qa/evidence/puzzle-rooms/(先清空)。机关节点(ShutterDoor / DropBridge / SteamValve /
## FuseBox)脚本里用了 `Audio`,`-s` 模式下不能写类型 —— 用 `call()`。

const OUT := "res://production/qa/evidence/puzzle-rooms"
const T := 16.0
## 谜题房的楼层(格):下层地面 S4 = 62,上层平台 U = 49。
const P_ROW := 62.0
const U_ROW := 49.0

var level: Node
var ryn: Ryn
var fails := 0
var shot := 0
var caught := false


func _check(ok: bool, what: String) -> void:
	print("[puzzle] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _wait(sec: float) -> void:
	for _i in int(sec * 60.0):
		await physics_frame


func _snap(name: String) -> void:
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png("%s/%02d-%s.png" % [dir, shot, name])
	shot += 1


func _load(path: String) -> void:
	if level != null:
		level.queue_free()
		await process_frame
	level = (load(path) as PackedScene).instantiate()
	root.add_child(level)
	ryn = level.get_node("Ryn") as Ryn
	_disarm(level)
	caught = false
	var dr := level.get_node("DetectionReset") as DetectionReset
	dr.fail_started.connect(func(_p: Node2D, _g: Node2D) -> void: caught = true)
	await _wait(3.4)


## 守卫都停掉、挪远;灯不抓人。要用的守卫在各段里再放开。
func _disarm(node: Node) -> void:
	for c in node.get_children():
		if c is Guard:
			(c as Guard).process_mode = Node.PROCESS_MODE_DISABLED
		elif c.get(&"ryn") != null and c.get(&"detection_reset") != null:
			c.set(&"ryn", null)
		_disarm(c)


## 被发现之后:等失败流程走完、Ryn 回到能操作(最多 10 秒)。
func _wait_control() -> void:
	var t := 0.0
	await _wait(0.5)
	while (not ryn.input_enabled) and t < 10.0:
		await _wait(0.25)
		t += 0.25
	await _wait(0.5)


## Ryn 现在的样子(失败时打印)。
func _ryn_info() -> String:
	return "ryn=%s 状态=%s 能操作=%s" % [str((ryn.global_position / T).snapped(Vector2(0.1, 0.1))),
			Ryn.State.keys()[ryn.state], ryn.input_enabled]


func _release_all() -> void:
	for a in [&"move_left", &"move_right", &"move_down", &"move_up", &"sprint", &"interact"]:
		Input.action_release(a)


func _place(p: Vector2) -> void:
	_release_all()
	ryn.velocity = Vector2.ZERO
	ryn.global_position = p
	await _wait(0.1)
	var cam := level.get_node_or_null("FollowCamera")
	if cam != null:
		cam.call("snap_to_target")   # 镜头直接对过去(跟随镜头是慢慢追的,截图会拍到别处)
	await _wait(0.3)


func _hold_e(sec: float) -> void:
	Input.action_press(&"interact")
	await _wait(sec)
	Input.action_release(&"interact")
	await physics_frame


## 按住 E 直到这块面板拆掉(最多 3 秒)。比「按固定秒数」稳:窗口模式下帧不匀,1.6 秒有时差一点点。
func _dismantle(panel: Dismantlable) -> void:
	Input.action_press(&"interact")
	var t := 0.0
	while not panel.is_dismantled and t < 3.0:
		await physics_frame
		t += 1.0 / 60.0
	Input.action_release(&"interact")
	await _wait(0.2)


## 点 E 钻进管口,直到人真的进去(最多点 3 次)。
func _enter_vent() -> void:
	for i in 3:
		await _tap_e()
		await _wait(0.3)
		if ryn.state == Ryn.State.HIDING:
			return


func _tap_e() -> void:
	Input.action_press(&"interact")
	await physics_frame
	await physics_frame
	Input.action_release(&"interact")
	await physics_frame


## 某种样子的机关面板,按 x 从西到东。
func _panels(look: int) -> Array[Dismantlable]:
	var out: Array[Dismantlable] = []
	for n in level.get_children():
		var p := n as Dismantlable
		if p != null and p.kind == Dismantlable.Kind.PANEL and int(p.look) == look:
			out.append(p)
	out.sort_custom(func(a: Dismantlable, b: Dismantlable) -> bool: return a.global_position.x < b.global_position.x)
	return out


## 拆这块面板时 Ryn 站在哪(地面那一点)。
func _stand(p: Dismantlable) -> Vector2:
	if p.look == Dismantlable.Look.VENT_COVER:
		return p.global_position + Vector2(10.0, 14.0)
	return p.global_position + Vector2(8.0, 36.0)


func _vent_with_cover(cover: Dismantlable) -> HidingSpot:
	for n in level.get_children():
		var v := n as HidingSpot
		if v != null and v.cover == cover:
			return v
	return null


func _registry() -> ShadowRegistry:
	return level.get_node("ShadowRegistry") as ShadowRegistry


func _initialize() -> void:
	create_timer(400.0).timeout.connect(func() -> void:
		print("[puzzle] TIMEOUT")
		quit(2))
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(dir + "/" + f)
	await _tower_1()
	await _tower_2()
	await _tower_3()
	await _tower_4()
	print("[puzzle] done, %d fail(s). shots: %s" % [fails, dir])
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ 塔1 断桥

func _tower_1() -> void:
	await _load("res://src/levels/tower_1_birthplace.tscn")
	var bridge: Node2D = level.get_node("Bridge00")
	var chain: Dismantlable = _panels(Dismantlable.Look.CHAIN)[0]
	var gp := level.get_node("GuardP") as Guard
	gp.process_mode = Node.PROCESS_MODE_INHERIT
	gp.darkness_veto = func(_p: Vector2) -> bool: return true
	_check(not bool(bridge.call("is_down")), "塔1:吊桥一开始竖着")
	await _place(_stand(chain))
	_snap("t1-chain-before")
	var gx0: float = gp.global_position.x
	await _dismantle(chain)
	_check(chain.is_dismantled, "长按 E 拆掉链条锚")
	await _wait(0.9)
	_check(bool(bridge.call("is_down")), "吊桥倒下来了")
	_snap("t1-bridge-down")
	await _wait(2.5)
	var pursuit := gp.get_node("Pursuit") as GuardPursuit
	_check(pursuit.mode() == GuardPursuit.Mode.SEARCHING and gp.global_position.x > gx0 + 8.0,
			"砸下来的声音把西平台的守卫引过来(x %.0f → %.0f 格)" % [gx0 / T, gp.global_position.x / T])
	_snap("t1-guard-comes")
	gp.process_mode = Node.PROCESS_MODE_DISABLED
	var on_bridge: Vector2 = bridge.global_position + Vector2(6.0 * T, 0.0)
	await _place(on_bridge)
	await _wait(0.6)
	_check(ryn.is_on_floor() and absf(ryn.global_position.y - on_bridge.y) < 4.0, "站在吊桥上,掉不下去")


# ------------------------------------------------------------------ 塔2 蒸汽廊

func _tower_2() -> void:
	await _load("res://src/levels/tower_2_refinery.tscn")
	var valves: Array[Dismantlable] = _panels(Dismantlable.Look.VALVE)
	var steam: Node2D = level.get_node("Steam00")
	var s1 := level.get_node("GuardS1") as Guard
	s1.process_mode = Node.PROCESS_MODE_INHERIT       # 真的看得见(暗处判定照常)
	var front := Vector2(44.0 * T + 8.0, U_ROW * T)    # 哨兵 1(50 格)面前 6 格
	_check(valves.size() == 2, "塔2:两个阀门")
	# 不放汽:站在他面前一定被看见
	await _place(front)
	await _wait(1.0)
	_check(caught, "不放汽站在哨兵面前:被发现(这一段不解谜过不去)")
	await _wait_control()                               # 等失败流程走完、回到存档点
	caught = false
	# 拧阀门 1
	await _place(_stand(valves[0]))
	await _dismantle(valves[0])
	_check(bool(steam.call("is_venting")), "拧开阀门 1:喷汽")
	_check(_registry().covers(front - Vector2(0.0, 20.0)), "汽罩住的地方算暗处")
	await _place(front)
	_snap("t2-in-steam")
	await _wait(1.5)
	_check(not caught, "站在汽里、哨兵面前:没被发现")
	await _place(Vector2(56.0 * T + 8.0, U_ROW * T))   # 走到哨兵背后
	await _wait(4.0)
	_check(not bool(steam.call("is_venting")) and not _registry().covers(front - Vector2(0.0, 20.0)),
			"6 秒后汽散了,那一片又是亮的")
	_check(not valves[0].is_dismantled, "阀门自己关上了(能再拧)")
	await _place(_stand(valves[0]))
	await _dismantle(valves[0])
	_check(bool(steam.call("is_venting")), "再拧一次:又喷  " + _ryn_info())
	_snap("t2-valve-again")


# ------------------------------------------------------------------ 塔3 控制室

func _tower_3() -> void:
	await _load("res://src/levels/tower_3_registry.tscn")
	var covers: Array[Dismantlable] = _panels(Dismantlable.Look.VENT_COVER)
	var control: Dismantlable = _panels(Dismantlable.Look.CONTROL)[0]
	var shutter: Node2D = level.get_node("Shutter00")
	_check(covers.size() == 2 and not bool(shutter.call("is_open")), "塔3:两个封着的管口,铁卷门关着")
	var to_room: Dismantlable = covers[1]                # 100 格那个:通控制室
	var vent := _vent_with_cover(to_room)
	await _place(_stand(to_room))
	_snap("t3-covered-vent")
	await _tap_e()
	await _wait(0.3)
	_check(ryn.state != Ryn.State.HIDING, "管口封着:点 E 钻不进去")
	await _dismantle(to_room)
	_check(to_room.is_dismantled and not vent.is_covered(), "长按 E 拆掉盖板")
	await _enter_vent()
	await _wait(1.2)
	var room := Vector2(60.0 * T + 8.0, P_ROW * T)
	_check(ryn.global_position.distance_to(room) < 24.0, "钻进去,从控制室里出来  " + _ryn_info())
	# 控制室里的存档点先碰一下(回滚要回到「门还关着」)
	await _place(Vector2(58.0 * T + 8.0, P_ROW * T))
	await _place(_stand(control))
	await _dismantle(control)
	_check(control.is_dismantled, "拆掉控制面板")
	await _wait(1.5)
	_check(bool(shutter.call("is_open")), "铁卷门卷上去了")
	_snap("t3-shutter-open")
	# 被发现 → 回到控制室的存档点:门关回去、面板复原
	var dr := level.get_node("DetectionReset") as DetectionReset
	dr.trigger(ryn, level.get_node("GuardK") as Node2D)
	await _wait_control()
	_check(not bool(shutter.call("is_open")) and not control.is_dismantled, "被发现回存档点:门关回去、面板复原")
	await _place(_stand(control))
	await _dismantle(control)
	await _wait(1.5)
	await _place(Vector2(34.0 * T + 8.0, U_ROW * T))
	Input.action_press(&"move_left")
	await _wait(1.2)
	_release_all()
	_check(ryn.global_position.x < 32.0 * T, "门开了:往西走过铁卷门  " + _ryn_info()
			+ " 门开=%s" % str(shutter.call("is_open")))
	_snap("t3-through-shutter")


# ------------------------------------------------------------------ 塔4 配电室

func _tower_4() -> void:
	await _load("res://src/levels/tower_4_military.tscn")
	var fuse: Node2D = level.get_node("Fuse00")
	var cover: Dismantlable = _panels(Dismantlable.Look.VENT_COVER)[0]
	var box: Dismantlable = _panels(Dismantlable.Look.FUSE)[0]
	var tech := level.get_node("GuardT") as Guard
	tech.process_mode = Node.PROCESS_MODE_INHERIT
	tech.darkness_veto = func(_p: Vector2) -> bool: return true
	var lights: Array[Node] = []
	for n in fuse.get("light_names") as PackedStringArray:
		lights.append(level.get_node(NodePath(n)))
	var yard := Vector2(70.0 * T, P_ROW * T - 20.0)
	_check(lights.size() == 2 and bool(lights[0].get("powered")) and not _registry().covers(yard),
			"塔4:两盏探照灯亮着,院子不是暗处")
	await _place(Vector2(70.0 * T, P_ROW * T))
	_snap("t4-yard-lit")
	await _place(_stand(cover))
	await _dismantle(cover)
	await _enter_vent()
	await _wait(1.2)
	_check(ryn.global_position.distance_to(Vector2(16.0 * T, P_ROW * T)) < 24.0, "拆开盖板,钻进配电室")
	await _place(_stand(box))
	var tx0: float = tech.global_position.x
	await _dismantle(box)
	_check(bool(fuse.call("is_off")), "拆配电箱:断电")
	_check(not bool(lights[0].get("powered")) and not bool(lights[1].get("powered")), "两盏探照灯都灭了")
	_check(_registry().covers(yard), "院子变成暗处")
	await _place(Vector2(70.0 * T, P_ROW * T))
	await _wait(1.5)
	_snap("t4-blackout")
	_check(tech.global_position.x < tx0 - 16.0, "技工往西走去电闸(x %.0f → %.0f 格)" % [tx0 / T, tech.global_position.x / T])
	var waited := 0.0
	while bool(fuse.call("is_off")) and waited < 30.0:
		await _wait(0.5)
		waited += 0.5
	_check(not bool(fuse.call("is_off")) and absf(tech.global_position.x - 44.0 * T - 8.0) < 24.0,
			"技工在电闸修好:来电(断电 %.1f 秒)" % (waited + 1.5))
	_check(bool(lights[0].get("powered")) and not _registry().covers(yard), "探照灯又亮了,院子又是亮的")
	_check(not box.is_dismantled, "配电箱复原(能再拆)")
