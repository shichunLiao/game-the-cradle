extends SceneTree
## DEV ONLY:探照灯「真的过得去」—— 真物理、灯开着,像人一样看着灯走(2026-10-14)。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/sweep_check.gd
##
## 起因:真人试玩卡在高空栈桥后半截 —— 灯照得穿暗处,光柱扫满整段桥面,中间没有柜子,怎么走都会被照到。
## 路线机器人(`--demo=route`)会把探照灯静音(它测的是地形),体检因此一直没发现。生成器现在有
## `level_dsl.sweep_timing_issues`(格子上的时序模型);这里用真实按键在游戏里走一遍,证明模型说「过得去」
## 的地方真的过得去,也证明原来的布局真的过不去。
##
## 机器人的走法:站在灯照不到的地方或柜子里,用灯自己的扫动公式(`SweepLight._offset_at`)往后推算 ——
## 「现在出发、按走路速度走到下一个柜子 / 出口,这一路灯柱会不会碰到我(两边多留 MARGIN)」,不会才走。
## 到了柜子按 E 躲进去;到了出口梯子往下爬,躯干低于灯柱才算过;终点是平地就站满一个扫动周期。
## 中途被抓(`DetectionReset.fail_started`)= 失败;一直等不到能走的时机 = 过不去。
## 只测灯:守卫全部停掉挪走(守卫有自己的检查)。从那一段的存档点出发(摆位,不是可达性主张)。
##
## 每项打印 PASS/FAIL,有失败时退出码 1。截图存到 `production/qa/evidence/sweep-timing/`。

const TILE := 16.0
const WALK := 105.0            # Ryn 走路速度(assets/data/ryn_movement.tres)
const MARGIN := 12.0           # 推算时灯柱两边多留的 px —— 人不是逐帧操作
const TORSO := 21.0            # 灯采样躯干中点:站着 42px 的一半
const WAIT_LIMIT := 30.0       # 一个落脚点最多等 30 秒
const EVIDENCE := "res://production/qa/evidence/sweep-timing"

var level: Node
var ryn: Ryn
var fails := 0
var caught := false
var shot := 0


func _check(ok: bool, what: String) -> void:
	print("[sweep] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)
	await physics_frame


func _wait(sec: float) -> void:
	for _i in int(sec * 60.0):
		await physics_frame


func _snap(name: String) -> void:
	var dir := ProjectSettings.globalize_path(EVIDENCE)
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
	caught = false
	(level.get_node("DetectionReset") as DetectionReset).fail_started.connect(
			func(_p: Node2D, _by: Node2D) -> void: caught = true)
	# 只测灯:守卫停掉、挪到地图外(停用的节点照样收得到「听见声音」的信号,挪远了才听不见)
	for c in level.get_children():
		if c is Guard:
			(c as Guard).process_mode = Node.PROCESS_MODE_DISABLED
			(c as Guard).global_position = Vector2(-5000.0, -5000.0)
	await _wait(3.2)


func _sweeps() -> Array[SweepLight]:
	var out: Array[SweepLight] = []
	for c in level.get_children():
		if c is SweepLight:
			out.append(c as SweepLight)
	return out


## 第 t 秒之后,站在 (x, feet_y) 的人会不会在灯柱里(两边多 MARGIN)。
func _lit_at(sweeps: Array[SweepLight], x: float, feet_y: float, t: float) -> bool:
	for sw in sweeps:
		var local_y: float = feet_y - TORSO - sw.global_position.y
		if local_y < 0.0 or local_y > sw.beam_length:
			continue
		var tt: float = fmod(float(sw.get("_t")) + t, sw.period)
		var c: float = sw.global_position.x + float(sw.call("_offset_at", tt))
		if absf(x - c) <= sw.beam_width * 0.5 + MARGIN:
			return true
	return false


## 现在出发,从 Ryn 现在的位置走到 x1(起步 0.15 秒),到了以后再待 `tail` 秒(进柜子 / 往下爬),
## 这一路灯柱都碰不到。
func _clear_to(sweeps: Array[SweepLight], x1: float, tail: float) -> bool:
	var x0: float = ryn.global_position.x
	var y: float = ryn.global_position.y
	var dist: float = absf(x1 - x0)
	var dur: float = 0.15 + dist / WALK + tail
	for i in int(dur * 60.0) + 1:
		var t: float = i / 60.0
		var x: float = x0 + signf(x1 - x0) * clampf((t - 0.15) * WALK, 0.0, dist)
		if _lit_at(sweeps, x, y, t):
			return false
	return true


## 等到推算安全再出发;走到 x1。返回 false = 等不到时机 / 被抓。
func _go(sweeps: Array[SweepLight], x1: float, tail: float, label: String) -> bool:
	var waited := 0
	while not _clear_to(sweeps, x1, tail):
		await physics_frame
		waited += 1
		if caught:
			_check(false, "%s:等的时候被灯照到" % label)
			return false
		if waited > int(WAIT_LIMIT * 60.0):
			print("[sweep] %s:等了 %d 秒都找不到能走的时机" % [label, int(WAIT_LIMIT)])
			return false
	if ryn.state == Ryn.State.HIDING:
		await _tap(&"interact")                     # 从柜子出来
	var dir: StringName = &"move_right" if x1 > ryn.global_position.x else &"move_left"
	Input.action_press(dir)
	var ticks := 0
	while absf(ryn.global_position.x - x1) > 6.0 and ticks < 1200:
		await physics_frame
		ticks += 1
		if caught:
			break
	Input.action_release(dir)
	await _wait(0.1)
	if caught:
		_check(false, "%s:走的路上被灯照到(x=%.0f)" % [label, ryn.global_position.x])
		return false
	return true


## 一段:从存档点出发,经过 `lockers`(从近到远),到 `goal_x`;`ladder_down` = 终点是往下的梯子。
func _run(lockers: Array[HidingSpot], goal_x: float, ladder_down: bool, label: String) -> bool:
	var sweeps := _sweeps()
	for i in lockers.size():
		var lk := lockers[i]
		if not await _go(sweeps, lk.anchor().x, 0.25, "%s 到柜子 %s" % [label, lk.name]):
			return false
		for _try in 10:
			if ryn.state == Ryn.State.HIDING:
				break
			await _tap(&"interact")
		if ryn.state != Ryn.State.HIDING:
			_check(false, "%s:进不了柜子 %s" % [label, lk.name])
			return false
		print("[sweep] %s:躲进 %s(x=%.0f)" % [label, lk.name, ryn.global_position.x])
	if not await _go(sweeps, goal_x, 0.9 if ladder_down else 0.0, "%s 到终点" % label):
		return false
	if ladder_down:
		Input.action_press(&"move_down")
		await _wait(1.2)
		Input.action_release(&"move_down")
	else:
		await _wait(sweeps[0].period + 0.5)        # 平地终点:站满一个扫动周期
	_snap(label + "-done")
	return not caught


func _initialize() -> void:
	# ---- 高空栈桥后半截:原来的布局(没有柜子)等不到能走的时机
	await _load("res://src/levels/sky_bridge.tscn")
	var ladder_x: float = 142.0 * TILE + 8.0
	ryn.global_position = Vector2(104.0 * TILE + 8.0, 22.0 * TILE)
	for lk in [level.get_node("Locker00"), level.get_node("Locker01")]:
		(lk as Node).queue_free()
	await _wait(0.3)
	_snap("sky-bridge-no-lockers")
	var none: Array[HidingSpot] = []
	var ok_old: bool = await _run(none, ladder_x, true, "栈桥(拿掉柜子)")
	_check(not ok_old and not caught, "原来的布局:没有柜子时,等 30 秒都找不到能走到出口梯子的时机")

	# ---- 高空栈桥后半截:加了两个柜子,走得到出口梯子底下
	await _load("res://src/levels/sky_bridge.tscn")
	ryn.global_position = Vector2(104.0 * TILE + 8.0, 22.0 * TILE)
	await _wait(0.3)
	_snap("sky-bridge-start")
	var bridge: Array[HidingSpot] = [level.get_node("Locker00") as HidingSpot, level.get_node("Locker01") as HidingSpot]
	var ok_sky: bool = await _run(bridge, ladder_x, true, "栈桥")
	_check(ok_sky and ryn.global_position.y > 22.0 * TILE + 24.0,
			"栈桥:存档点 → 柜子 120 → 柜子 132 → 出口梯子往下,一次没被照到(y=%.0f)" % ryn.global_position.y)

	# ---- 塔4 营区:灯扫 42 格,三个柜子(34 / 45 / 56),用走的过得去
	await _load("res://src/levels/tower_4_military.tscn")
	await _wait(0.3)
	var camp: Array[HidingSpot] = [level.get_node("Locker00") as HidingSpot, level.get_node("Locker02") as HidingSpot,
			level.get_node("Locker01") as HidingSpot]
	var ok_camp: bool = await _run(camp, 67.0 * TILE + 8.0, false, "塔4营区")
	_check(ok_camp, "塔4 营区:出生点 → 柜子 34 → 45 → 56 → 灯扫不到的 67 列,一次没被照到")

	print("[sweep] 完成,失败 %d 项" % fails)
	quit(1 if fails > 0 else 0)
