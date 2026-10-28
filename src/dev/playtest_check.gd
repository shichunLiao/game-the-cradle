extends SceneTree
## DEV ONLY:试玩记录器(`PlaytestLog`)的检查。
##
##     godot --path . --headless --fixed-fps 60 -s res://src/dev/playtest_check.gd
##
## 开塔1:踩存档点、守卫起疑、躲进柜子再出来、丢扣件、被「看」和「听」的守卫各抓一次(等重生);
## 换到塔4:被探照灯抓一次。然后读回记录文件,一项项对。每项打印 PASS/FAIL,有失败时退出码 1。
## 记录文件留在 user://playtest_check.jsonl,可以拿去喂 `tools/playtest/report.py`。
##
## 守卫都停掉(`_disarm`),「被发现」直接走 `DetectionReset.trigger()` —— 和真的被看见是同一条路。
## 不写 `PlaytestLog` 的类型,按 autoload 节点 `call()`(见 playtest_log.gd 开头)。

const OUT := "user://playtest_check.jsonl"

var level: Node
var ryn: Ryn
var log_node: Node
var fails := 0


func _check(ok: bool, what: String) -> void:
	print("[playtest] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _wait(sec: float) -> void:
	for _i in int(sec * 60.0):
		await physics_frame


func _disarm(node: Node) -> void:
	for c in node.get_children():
		if c is Guard:
			(c as Guard).process_mode = Node.PROCESS_MODE_DISABLED
		elif c.get(&"ryn") != null and c.get(&"detection_reset") != null:
			c.set(&"ryn", null)
		_disarm(c)


func _load(path: String) -> void:
	if level != null:
		level.queue_free()
		await process_frame
	level = (load(path) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	ryn = level.get_node("Ryn") as Ryn
	_disarm(level)
	await _wait(0.6)


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		print("[playtest] TIMEOUT (a step errored or hung)")
		quit(2))
	log_node = root.get_node("PlaytestLog")
	_check(not log_node.call("is_recording"), "-s 检查脚本里默认不记")
	log_node.call("start", OUT)
	_check(log_node.call("is_recording"), "强制开始后在记")

	# ---- 塔1
	await _load("res://src/levels/tower_1_birthplace.tscn")
	var cps := level.get_node("CheckpointManager") as CheckpointManager
	var cp1 := level.get_node("Checkpoint01") as Checkpoint
	cps.activate(cp1)
	ryn.global_position = cp1.global_position
	await _wait(1.0)
	var ga := level.get_node("GuardA") as Guard
	ga.report_disturbance()
	await _wait(0.2)
	var locker := level.get_node("Locker00") as Node2D
	var anchor: Vector2 = locker.call("anchor")
	ryn.global_position = anchor
	await _wait(0.3)
	_check(ryn.enter_hiding(locker, anchor), "站在柜子前、躲得进去")
	await _wait(0.5)
	ryn.exit_hiding()
	await _wait(0.2)
	ryn.get_node("Throw").emit_signal("thrown", null)
	await _wait(0.2)
	var reset := level.get_node("DetectionReset") as DetectionReset
	reset.trigger(ryn, ga)
	await _wait(4.5)
	_check(not reset.is_failing(), "塔1 第一次失败演完、重生")
	await _wait(1.0)
	reset.trigger(ryn, level.get_node("GuardG"))
	await _wait(4.5)

	# ---- 塔4
	await _load("res://src/levels/tower_4_military.tscn")
	await _wait(1.0)
	(level.get_node("DetectionReset") as DetectionReset).trigger(ryn, level.get_node("Sweep00"))
	await _wait(4.5)
	log_node.call("stop")
	_check(not log_node.call("is_recording"), "停下后不再记")

	_verify()
	print("[playtest] done, %d fail(s). log: %s" % [fails, ProjectSettings.globalize_path(OUT)])
	quit(1 if fails > 0 else 0)


func _verify() -> void:
	var f := FileAccess.open(OUT, FileAccess.READ)
	_check(f != null, "记录文件写出来了")
	if f == null:
		return
	var ev: Array[Dictionary] = []
	while not f.eof_reached():
		var line := f.get_line()
		if line.is_empty():
			continue
		var d: Variant = JSON.parse_string(line)
		if d is Dictionary:
			ev.append(d)
		else:
			_check(false, "每行都是 JSON:" + line.left(60))
	var kinds := ev.map(func(e: Dictionary) -> String: return e.get("ev", ""))
	_check(kinds.size() > 0 and kinds[0] == "session", "第一行是 session")
	_check(kinds.size() > 0 and kinds[-1] == "end", "最后一行是 end")
	var enters := ev.filter(func(e: Dictionary) -> bool: return e.ev == "enter")
	_check(enters.size() == 2 and str(enters[0].scene).ends_with("tower_1_birthplace.tscn")
			and str(enters[1].scene).ends_with("tower_4_military.tscn"), "进了塔1、塔4 两关")
	var leaves := ev.filter(func(e: Dictionary) -> bool: return e.ev == "leave")
	_check(leaves.size() == 2 and int(leaves[0].fails) == 2 and int(leaves[1].fails) == 1,
			"离开时记了这关失败几次(塔1 2、塔4 1)")
	# 出生就站在 Checkpoint00 上,一开场就算踩到
	var cp := ev.filter(func(e: Dictionary) -> bool: return e.ev == "cp")
	_check(cp.size() == 3 and cp[0].name == "Checkpoint00" and cp[1].name == "Checkpoint01"
			and cp[2].name == "Checkpoint00", "存档点:塔1 00 → 01,塔4 00")
	var alerts := ev.filter(func(e: Dictionary) -> bool: return e.ev == "alert")
	_check(alerts.size() == 1 and alerts[0].src == "GuardA" and alerts[0].sense == "sight", "守卫 A 起疑(看)")
	var hide := ev.filter(func(e: Dictionary) -> bool: return e.ev == "hide")
	var unhide := ev.filter(func(e: Dictionary) -> bool: return e.ev == "unhide")
	_check(hide.size() == 1 and hide[0].spot == "Locker00" and unhide.size() == 1, "进出柜子 Locker00")
	_check(ev.filter(func(e: Dictionary) -> bool: return e.ev == "throw").size() == 1, "丢了一个扣件")
	var fl := ev.filter(func(e: Dictionary) -> bool: return e.ev == "fail")
	_check(fl.size() == 3, "三次被发现(实际 %d)" % fl.size())
	if fl.size() == 3:
		_check(fl[0].by == "guard_sight" and fl[0].src == "GuardA" and fl[0].cp == "Checkpoint01"
				and float(fl[0].since_respawn) < 0.0, "第 1 次:看的守卫 A,存档点 01,之前没重生过")
		_check(fl[0].do == "stand" and fl[0].has("shade") and fl[0].has("x"), "第 1 次:记了 Ryn 的动作 / 暗处 / 位置")
		_check(fl[1].by == "guard_hearing" and fl[1].src == "GuardG", "第 2 次:听的守卫 G")
		# 离上次重生多久 = 这次被抓的时间 − 第一次重生(交还控制)的时间;顿帧让失败演出比 2.35 秒长,不写死
		var r1: Array = ev.filter(func(e: Dictionary) -> bool: return e.ev == "respawn")
		var want := float(fl[1].t) - float(r1[0].t) if r1.size() > 0 else -1.0
		_check(want > 0.5 and absf(float(fl[1].since_respawn) - want) < 0.03,
				"第 2 次:离上次重生 %.2f 秒(时间轴上 %.2f)" % [float(fl[1].since_respawn), want])
		_check(fl[2].by == "sweep" and fl[2].src == "Sweep00" and fl[2].cp == "Checkpoint00", "第 3 次:塔4 探照灯,出生的存档点")
	var resp := ev.filter(func(e: Dictionary) -> bool: return e.ev == "respawn")
	_check(resp.size() == 3, "三次重生(实际 %d)" % resp.size())
	var pos := ev.filter(func(e: Dictionary) -> bool: return e.ev == "pos")
	var t_end := float(ev[-1].t)
	_check(absf(pos.size() - t_end / 0.25) < 6.0, "每 0.25 秒一个位置(%d 个 / %.1f 秒)" % [pos.size(), t_end])
	var mono := true
	for i in range(1, ev.size()):
		if float(ev[i].t) < float(ev[i - 1].t):
			mono = false
	_check(mono, "时间一直往前")
