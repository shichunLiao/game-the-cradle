extends SceneTree
## DEV ONLY:藏身点(柜子/通风管)行为检查 + 截图。用真实按键(Input.action_press)。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/hiding_check.gd
##
## 每项打印 PASS/FAIL,有失败时退出码 1。截图存到 user://hide_shots/。
## 2026-10-11 关卡改由 tools/level_builder 生成,节点名跟着生成器走:
## 塔1 `Locker00`(2026-10-12 起在三楼)+ `GuardA`(挪过去)、塔4 `Locker00` + `Sweep00`、塔3 `Vent00A` / `Vent00B`。
## 覆盖:进柜子、守卫正对柜子看不见、跳出来、出来被发现、探照灯扫过柜子不抓人、
## 躲着时被重置能正常回存档点、通风管从另一头出来、守卫听到关柜门会来查(远了听不见、
## 空柜子不误抓)。

var level: Node
var ryn: Ryn
var fails := 0
var shot := 0


func _check(ok: bool, what: String) -> void:
	print("[hide] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)
	await physics_frame


## 按物理帧(固定 60/秒)等,不按渲染帧 —— 120Hz 屏幕上渲染帧是两倍快。
func _wait(sec: float) -> void:
	for _i in int(sec * 60.0):
		await physics_frame


func _snap(name: String) -> void:
	var dir := OS.get_user_data_dir() + "/hide_shots"
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
	await _wait(3.2)


## 新关卡里柜子附近还有别的守卫:除了被测的那个,全部看不见,免得别人触发失败流程。
## 只设 `darkness_veto` 不够:`ShadowRegistry` 开场后会把它改回暗区判定(2026-10-12 塔1 改垂直后,
## 被测柜子旁边就有别的守卫在巡逻,于是真被看见了)。别的守卫整个停掉、挪到地图外 ——
## 停用的节点照样收得到「听见声音」的信号,挪远了才听不见。
func _blind_all_except(keep: Guard) -> void:
	for c in level.get_children():
		if c is Guard and c != keep:
			var g := c as Guard
			g.process_mode = Node.PROCESS_MODE_DISABLED
			g.global_position = Vector2(-5000.0, -5000.0)


func _initialize() -> void:
	# ---- 塔1 柜子:守卫看不见躲着的人;出来站在亮处被发现
	await _load("res://src/levels/tower_1_birthplace.tscn")
	var locker := level.get_node("Locker00") as HidingSpot
	var guard := level.get_node("GuardA") as Guard
	_blind_all_except(guard)                              # 只让被测的守卫看得见
	guard.process_mode = Node.PROCESS_MODE_DISABLED       # 先定住,摆好再放开
	# 停用的节点照样收得到「听见声音」的信号 —— 先挪到 200px 外,别让他听见关柜门
	guard.global_position = locker.anchor() + Vector2(200.0, 0.0)
	ryn.global_position = locker.anchor()
	await _wait(0.3)
	_snap("t1-prompt")
	await _tap(&"interact")
	_check(ryn.state == Ryn.State.HIDING and not ryn.is_detectable(), "按 E 躲进柜子")
	await _wait(0.4)
	_snap("t1-inside-eyes")
	# 守卫站到柜子右边 60px,面朝柜子
	guard.global_position = Vector2(locker.anchor().x + 60.0, locker.anchor().y)
	guard.facing = -1
	guard.process_mode = Node.PROCESS_MODE_INHERIT
	guard.patrol_offset = 0.0
	await _wait(1.5)
	_check(guard.state == Guard.State.PATROL, "躲着时守卫正对柜子也看不见 (state=%d)" % guard.state)
	_snap("t1-guard-facing-locker")
	await _tap(&"jump")
	_check(ryn.state == Ryn.State.NORMAL and ryn.is_detectable(), "跳一下出来")
	await _wait(0.6)
	_check(guard.state == Guard.State.SPOTTED or (level.get_node("DetectionReset") as DetectionReset).is_failing(),
			"出来站在亮处被发现")
	await _wait(3.5)

	# ---- 塔4 柜子:探照灯扫过柜子不触发;躲着时被重置,出来后正常
	await _load("res://src/levels/tower_4_military.tscn")
	var locker4 := level.get_node("Locker00") as HidingSpot
	var dr := level.get_node("DetectionReset") as DetectionReset
	for g in level.get_children():
		if g is Guard:
			g.process_mode = Node.PROCESS_MODE_DISABLED
	ryn.global_position = locker4.anchor()
	await _wait(0.2)
	await _tap(&"interact")
	_check(ryn.state == Ryn.State.HIDING, "塔4 躲进柜子")
	var swept := false
	var sweep := level.get_node("Sweep00") as SweepLight
	for _i in int(ceilf(sweep.period * 60.0)) + 60:       # 比一个扫动周期多 1 秒
		await physics_frame
		var x: float = sweep.global_position.x + float(sweep.get("_x"))
		if absf(x - ryn.global_position.x) < 20.0:
			if not swept:
				_snap("t4-sweep-over-locker")
			swept = true
	_check(swept, "探照灯确实扫过柜子")
	_check(not dr.is_failing(), "躲着时探照灯不抓人")
	dr.trigger(ryn)                                        # 强行触发一次失败流程
	await _wait(3.0)
	_check(ryn.state == Ryn.State.NORMAL and ryn.get_node("Visual").visible and ryn.hiding_spot == null,
			"重置后人回到存档点、看得见、不再算躲着")

	# ---- 塔3 通风管:西口进,东口蹲着出来
	await _load("res://src/levels/tower_3_registry.tscn")
	for g in level.get_children():
		if g is Guard or g is GateLight:
			g.process_mode = Node.PROCESS_MODE_DISABLED
	var vw := level.get_node("Vent00A") as HidingSpot
	var ve := level.get_node("Vent00B") as HidingSpot
	ryn.global_position = vw.anchor()
	await _wait(0.3)
	_snap("t3-vent-prompt")
	await _tap(&"interact")
	_check(ryn.state == Ryn.State.HIDING, "钻进西口")
	await _wait(1.2)
	_check(ryn.state == Ryn.State.NORMAL and ryn.global_position.distance_to(ve.anchor()) < 8.0,
			"从东口出来 (%s vs %s)" % [ryn.global_position, ve.anchor()])
	_snap("t3-vent-out")

	# ---- 守卫查柜子(塔1):在守卫身边关柜门会被听见、被拉开;离远了听不见;空柜子查完没事
	await _load("res://src/levels/tower_1_birthplace.tscn")
	var lk := level.get_node("Locker00") as HidingSpot
	var gd := level.get_node("GuardA") as Guard
	var drs := level.get_node("DetectionReset") as DetectionReset
	_blind_all_except(gd)
	# 远:守卫在 120px 外背对柜子 —— 听不见(柜门噪音半径 40)
	gd.patrol_offset = 0.0
	gd.global_position = Vector2(lk.anchor().x + 120.0, lk.anchor().y)
	gd.facing = 1
	gd.darkness_veto = func(_p: Vector2) -> bool: return true
	ryn.global_position = lk.anchor()
	await _wait(0.3)
	await _tap(&"interact")
	await _wait(3.0)
	_check(ryn.state == Ryn.State.HIDING and not drs.is_failing() and gd.state == Guard.State.PATROL,
			"守卫在 120px 外:听不见关柜门,不来查")
	await _tap(&"jump")
	await _wait(0.3)
	# 近:守卫在 30px 外背对柜子 —— 听见、走过来、拉开、抓到
	gd.global_position = Vector2(lk.anchor().x + 30.0, lk.anchor().y)
	gd.facing = 1
	ryn.global_position = lk.anchor()
	await _wait(0.3)
	await _tap(&"interact")
	_check(ryn.state == Ryn.State.HIDING, "近处关柜门:进去了")
	await _wait(0.5)
	_snap("s6-guard-checking-locker")
	var found := false
	for _i in 180:
		await physics_frame
		if drs.is_failing():
			found = true
			break
	_snap("s6-guard-opened-locker")
	_check(found and ryn.state == Ryn.State.NORMAL, "守卫听见、拉开柜门、抓到人")
	await _wait(3.5)
	# 空柜子:守卫被引到柜子旁,打开是空的 —— 不失败,柜门敞开一下
	gd.global_position = Vector2(lk.anchor().x + 30.0, lk.anchor().y)
	gd.facing = 1
	ryn.global_position = Vector2(lk.anchor().x - 300.0, lk.anchor().y)   # 远离柜子,同一层
	await _wait(0.3)
	get_root().get_node("Noise").emit_noise(lk.anchor(), 60.0)
	await _wait(3.0)
	_check(not drs.is_failing() and ryn.state == Ryn.State.NORMAL, "空柜子查完,没有误抓")

	print("[hide] 失败 %d 项" % fails)
	quit(1 if fails > 0 else 0)
