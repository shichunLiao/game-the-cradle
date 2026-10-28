extends SceneTree
## DEV ONLY:三种守卫(看・听・追)检查 + 截图(2026-10-13,`design/ideas-backlog.md` G1–G3)。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/senses_check.gd
##
## 听(输油管桥 GuardA):没有视野锥、站在他面前不被发现;撞上就发现;出声把他引过来,人还在 → 发现;
##     出声后安静走开 → 他在声源张望完、没抓到。
## 追(下行关 GuardB,吊板 3):关卡里有蚀痕、塔1 没有;走路落痕迹;断开(瞬移 = 通风管)的痕迹不连;
##     8 秒散掉;踩到痕迹顺着追过来抓到人;痕迹断了就跟丢。
## 截图存到 production/qa/evidence/guard-senses/。

const OUT := "res://production/qa/evidence/guard-senses"
const T := 16.0

var level: Node
var ryn: Ryn
var fails := 0
var shot := 0
var caught := false


func _check(ok: bool, what: String) -> void:
	print("[senses] %s  %s" % ["PASS" if ok else "FAIL", what])
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
	dr.fail_started.connect(func(_p: Node2D, by: Node2D) -> void:
		caught = true
		print("[senses]   (被 %s 发现,Ryn %s)" % [by.name if by != null else "?", str(ryn.global_position.round())]))
	await _wait(3.4)


## 守卫都停掉;灯不抓人。要用的守卫在各段里再放开。
func _disarm(node: Node) -> void:
	for c in node.get_children():
		if c is Guard:
			(c as Guard).process_mode = Node.PROCESS_MODE_DISABLED
		elif c.get(&"ryn") != null and c.get(&"detection_reset") != null:
			c.set(&"ryn", null)
		_disarm(c)


func _arm(g: Guard) -> void:
	g.process_mode = Node.PROCESS_MODE_INHERIT


func _wait_control() -> void:
	await _wait(0.5)
	var t := 0.0
	while (not ryn.input_enabled) and t < 10.0:
		await _wait(0.25)
		t += 0.25
	await _wait(0.5)


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
		cam.call("snap_to_target")
	await _wait(0.2)


func _walk(dir: int, sec: float) -> void:
	var a: StringName = &"move_right" if dir > 0 else &"move_left"
	Input.action_press(a)
	await _wait(sec)
	Input.action_release(a)
	await _wait(0.1)


func _noise(at: Vector2, radius: float) -> void:
	root.get_node("Noise").call("emit_noise", at, radius)


## 把守卫放回 `x`、面朝 `facing`、停住巡逻(不影响搜查 / 追)。巡逻样式(扫视型会自己转头)也停掉 ——
## 测的是听 / 追,不能让他转过头用眼睛看到。
func _stage(g: Guard, x: float, facing: int) -> void:
	var beh := g.get_node_or_null("Behaviour")
	if beh != null:
		beh.process_mode = Node.PROCESS_MODE_DISABLED
	g.global_position.x = x
	g.velocity = Vector2.ZERO
	g.facing = facing
	g.hold_patrol(60.0)
	await _wait(0.2)


func _initialize() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
		print("[senses] TIMEOUT")
		quit(2))
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _hearing()
	await _tracking()
	await _tower_1_no_trail()
	print("[senses] done, %d fail(s)" % fails)
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ 听
func _hearing() -> void:
	await _load("res://src/levels/pipeline_bridge.tscn")
	var g := level.get_node("GuardA") as Guard
	_check(g.sense == Guard.Sense.HEARING, "输油管桥 GuardA 是「听」")
	_arm(g)
	var gx: float = g.global_position.x
	var gy: float = g.global_position.y
	await _stage(g, gx, 1)
	_check(not (g.get_node("VisionCone") as Node2D).visible, "听:没有视野锥")
	# 站在他面前 60px、亮处、不出声
	await _place(Vector2(gx + 60.0, gy))
	await _wait(1.5)
	_check(not caught, "听:站在面前 60px 不出声 → 没发现(他看不见)")
	_snap("hearing-blind")
	# 撞上
	await _place(Vector2(gx + 8.0, gy))
	await _wait(0.4)
	_check(caught, "听:撞上 → 发现")
	await _wait_control()
	# 出声,人不走 → 他走过来抓到
	caught = false
	await _stage(g, gx, 1)
	await _place(Vector2(gx + 70.0, gy))
	_noise(ryn.global_position, 100.0)
	await _wait(0.6)
	_snap("hearing-comes")
	var t := 0.0
	while not caught and t < 4.0:
		await _wait(0.1)
		t += 0.1
	_check(caught, "听:出声后站着不走 → 他走到声源发现人(%.1f 秒)" % t)
	await _wait_control()
	# 出声后安静走开(瞬移 = 蹲着溜走,不出声)→ 没抓到
	caught = false
	await _stage(g, gx, 1)
	await _place(Vector2(gx + 70.0, gy))
	_noise(ryn.global_position, 100.0)
	await _wait(0.2)
	ryn.global_position.x = gx + 170.0
	await _wait(4.5)
	_check(not caught, "听:出声后安静走开 → 他在声源张望,没抓到")


# ------------------------------------------------------------------ 追
func _tracking() -> void:
	await _load("res://src/levels/pit_descent.tscn")
	var g := level.get_node("GuardB") as Guard
	_check(g.sense == Guard.Sense.TRACKING, "下行关 GuardB 是「追」")
	var trail := level.get_node_or_null("TraceTrail") as TraceTrail
	_check(trail != null, "有「追」的关卡有蚀痕")
	if trail == null:
		return
	var gx: float = g.global_position.x
	var gy: float = g.global_position.y
	# 落痕迹(守卫还停着)
	await _place(Vector2(gx + 120.0, gy))
	trail.clear()
	await _walk(1, 1.0)
	var n1: int = trail.size()
	_check(n1 >= 6, "走 1 秒落下痕迹(%d 个点)" % n1)
	_snap("trail-footprints")
	# 断开:瞬移(像钻通风管)之后的点和前面的不连
	ryn.global_position.x += 260.0
	await _wait(0.2)
	await _walk(1, 0.5)
	var start: int = trail.nearest(Vector2(gx + 120.0, gy), 12.0)
	var chain: int = 0
	var id: int = start
	while id >= 0 and chain < 500:
		chain += 1
		id = trail.next_from(id)
	_check(start >= 0 and chain < trail.size() and chain >= n1 - 2,
			"钻通风管(瞬移)后痕迹断开:顺着走只有 %d / %d 个点" % [chain, trail.size()])
	# 8 秒散掉
	await _wait(8.6)
	_check(trail.size() == 0, "8 秒后痕迹散掉(剩 %d)" % trail.size())
	# 追:Ryn 从守卫身后 40px 往后走开,留下一串痕迹;再把守卫放到痕迹的起点(像他巡逻走到这里)
	_arm(g)
	await _stage(g, gx, 1)
	await _place(Vector2(gx - 40.0, gy))
	trail.clear()
	await _walk(-1, 1.2)
	var senses := g.get_node("Senses") as GuardSenses
	await _stage(g, gx - 44.0, -1)
	_snap("tracker-on-trail")
	var tracked := false
	var t := 0.0
	while not caught and t < 6.0:
		await physics_frame
		tracked = tracked or senses.is_tracking()
		t += 1.0 / 60.0
	_check(tracked, "追:踩到脚下的痕迹 → 顺着追")
	_check(caught, "追:顺着痕迹追到人 → 发现(%.1f 秒)" % t)
	await _wait_control()
	# 痕迹断了就跟丢
	caught = false
	await _stage(g, gx, 1)
	await _place(Vector2(gx - 40.0, gy))
	trail.clear()
	await _walk(-1, 0.6)
	ryn.global_position.x -= 300.0          # 钻进通风管 / 爬走了
	await _wait(0.2)
	await _stage(g, gx - 44.0, -1)
	var was := false
	for _i in 360:
		await physics_frame
		was = was or senses.is_tracking()
	_check(was and not caught and not senses.is_tracking(), "追:顺着追到断口 → 跟丢、没抓到(追过 %s)" % was)


func _tower_1_no_trail() -> void:
	await _load("res://src/levels/tower_1_birthplace.tscn")
	_check(level.get_node_or_null("TraceTrail") == null, "塔1 没有「追」的守卫,看不到蚀痕(线索不提前露)")
