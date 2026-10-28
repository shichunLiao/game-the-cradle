extends SceneTree
## DEV ONLY:丢扣件检查 + 截图。用真实按键(Input.action_press)。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/throw_check.gd
##
## 覆盖:瞄准时站住不走、预览落点 = 真实落点、落地声把守卫引过去、守卫查声音不走下平台、
## 用掉一个少一个、存档点补满、空中不能瞄准、用完了按也丢不出去;塔1 教学:一开始不会、
## 捡到第一颗才学会、提示句、从吊桥西头把守卫引到桥下再跳下去走掉。截图存 user://throw_shots/。
## `RynThrow` / `ThrownBolt` 不写类型(用到 `Audio`,`-s` 模式下会在 autoload 之前编译)。

var level: Node
var ryn: Ryn
var thrower: Node2D
var fails := 0
var shot := 0


func _check(ok: bool, what: String) -> void:
	print("[throw] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _wait(sec: float) -> void:
	for _i in int(sec * 60.0):
		await physics_frame


func _snap(name: String) -> void:
	var dir := OS.get_user_data_dir() + "/throw_shots"
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png("%s/%02d-%s.png" % [dir, shot, name])
	shot += 1


func _release_all() -> void:
	for a in [&"move_left", &"move_right", &"move_down", &"jump", &"throw", &"sprint"]:
		Input.action_release(a)


func _load(path: String) -> void:
	if level != null:
		level.queue_free()
		await process_frame
	level = (load(path) as PackedScene).instantiate()
	root.add_child(level)
	ryn = level.get_node("Ryn") as Ryn
	thrower = ryn.get_node("Throw") as Node2D
	await _wait(1.0)


## 只留 `keep` 这个守卫在动,而且看不见人(ShadowRegistry 开场接线之后再设,不会被改回去)。
func _only_guard(keep: Guard) -> void:
	for c in level.get_children():
		if c is Guard and c != keep:
			(c as Guard).process_mode = Node.PROCESS_MODE_DISABLED
	keep.darkness_veto = func(_p: Vector2) -> bool: return true


func _subtitle_text() -> String:
	var sub := level.get_node("TowerSubtitle") as TowerSubtitle
	return (sub.get("_label") as Label).text


func _place(x: float, y: float) -> void:
	_release_all()
	ryn.velocity = Vector2.ZERO
	ryn.global_position = Vector2(x, y)
	await _wait(0.4)


func _initialize() -> void:
	create_timer(150.0).timeout.connect(func() -> void:
		print("[throw] TIMEOUT")
		quit(2))
	# 先清掉上一次的截图:截图按顺序编号,改了检查顺序后旧编号会留下来混在一起
	var dir := OS.get_user_data_dir() + "/throw_shots"
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(dir + "/" + f)

	# ---- 塔2 一楼:守卫 A(巡逻 20..54 格),Ryn 站在他西边。塔2 起一开始就会丢扣件
	await _load("res://src/levels/tower_2_refinery.tscn")
	var guard := level.get_node("GuardA") as Guard
	_only_guard(guard)
	guard.process_mode = Node.PROCESS_MODE_DISABLED       # 先摆好再放开
	guard.global_position = Vector2(30.0 * 16.0 + 8.0, 198.0 * 16.0)
	await _place(12.0 * 16.0 + 8.0, 198.0 * 16.0)
	_check(int(thrower.call("count")) == 3, "开场身上 3 个扣件")
	_snap("hud-full")

	Input.action_press(&"throw")
	await _wait(0.2)
	_check(bool(thrower.call("is_aiming")) and ryn.aiming, "按住 F:开始瞄准")
	var x0 := ryn.global_position.x
	Input.action_press(&"move_right")
	await _wait(0.6)
	Input.action_release(&"move_right")
	await _wait(0.1)
	_check(absf(ryn.global_position.x - x0) < 1.0, "瞄准时按右:Ryn 站住不走(移动 %.1f px)" % (ryn.global_position.x - x0))
	var predicted: Variant = thrower.call("predicted_landing")
	_check(predicted != null, "预览算出落点")
	var visual: Node = ryn.get_node("Visual")
	_check(visual.call("current_action") == &"aim", "瞄准时:蓄力姿势(手举到耳边)")
	_snap("aim-preview")
	var landed_at: Array = [null]
	var guard_x_at_land: Array = [0.0]
	thrower.connect(&"thrown", func(b: Node2D) -> void:
		b.connect(&"landed", func(at: Vector2) -> void:
			landed_at[0] = at
			guard_x_at_land[0] = guard.global_position.x))
	guard.process_mode = Node.PROCESS_MODE_INHERIT
	Input.action_release(&"throw")
	await _wait(0.05)
	_check(visual.call("current_action") == &"throw", "松开:出手姿势")
	_snap("throw-release")
	await _wait(0.15)
	_check(int(thrower.call("count")) == 2 and not ryn.aiming, "松开:丢出去,剩 2 个")
	await _wait(0.4)
	_check(visual.call("current_action") == &"", "丢完 0.5 秒:回到一般动作")
	await _wait(1.6)
	_check(landed_at[0] != null and predicted != null and (landed_at[0] as Vector2).distance_to(predicted) < 3.0,
			"真实落点 = 预览落点(差 %.1f px)" % ((landed_at[0] as Vector2).distance_to(predicted) if landed_at[0] != null and predicted != null else -1.0))
	var pursuit := guard.get_node("Pursuit") as GuardPursuit
	_check(pursuit.mode() == GuardPursuit.Mode.SEARCHING, "落地声:守卫 A 去查看")
	_snap("guard-lured")
	# 等他走到扣件前蹲下(最多 3 秒);从蹲下那一刻开始计时
	for _i in 180:
		if pursuit.inspect_phase() == GuardPursuit.Inspect.CROUCH:
			break
		await physics_frame
	var crouch_t0 := Engine.get_physics_frames()
	var gx0: float = guard_x_at_land[0]
	var target_x: float = (landed_at[0] as Vector2).x if landed_at[0] != null else gx0
	# 2026-10-14 起停在扣件前 12px 低头看(`GuardPursuit.bolt_stand_off`)
	_check(absf(guard.global_position.x - target_x) < minf(absf(gx0 - target_x) - 10.0, 24.0),
			"守卫走到落点(落地时离 %.0f px → 现在 %.0f px)" % [absf(gx0 - target_x), absf(guard.global_position.x - target_x)])
	_snap("guard-at-bolt")

	# ---- 2026-10-14 用户:「螺母要牵制警卫更久、警卫低头查看」—— 蹲下低头看 → 捡起来 → 起身张望
	_check(pursuit.inspect_phase() == GuardPursuit.Inspect.CROUCH and guard.gaze_down
			and is_equal_approx(guard.current_range(), guard.config.gaze_down_range),
			"到了扣件前:蹲下低头看,视野缩到 %.0f px" % guard.current_range())
	_check(get_nodes_in_group(GuardPursuit.BOLT_GROUP).size() == 1, "低头看的时候扣件还在地上")
	_snap("guard-crouch-inspect")
	# 他朝着 Ryn 那边低头看:平常 140px 的锥看得到 70px 外的人,低头时看不到。Ryn 走过去站在他前面 ~70px
	var caught_inspect := [false]
	(level.get_node("DetectionReset") as DetectionReset).fail_started.connect(
			func(_p: Node2D, _g: Node2D) -> void: caught_inspect[0] = true)
	guard.darkness_veto = Callable()                     # 这一段要他真的看得见
	var toward: StringName = &"move_right" if guard.global_position.x > ryn.global_position.x else &"move_left"
	var away: StringName = &"move_left" if toward == &"move_right" else &"move_right"
	var stop_at: float = guard.global_position.x - signf(guard.global_position.x - ryn.global_position.x) * 70.0
	Input.action_press(toward)
	for _i in 180:
		if absf(ryn.global_position.x - stop_at) < 4.0:
			break
		await physics_frame
	Input.action_release(toward)
	await _wait(0.5)
	_snap("ryn-in-front-of-crouching-guard")
	_check(not bool(caught_inspect[0]) and absf(ryn.global_position.x - guard.global_position.x) < 90.0,
			"他低头的时候,Ryn 走到他面前 %.0f px(平常的视野里)也没被发现(走路声也没把他叫起来)"
			% absf(ryn.global_position.x - guard.global_position.x))
	Input.action_press(away)                             # 他快起身了:退回去
	await _wait(1.3)
	Input.action_release(away)
	guard.darkness_veto = func(_p: Vector2) -> bool: return true
	for _i in 300:
		if pursuit.inspect_phase() == GuardPursuit.Inspect.LOOK:
			break
		await physics_frame
	_check(pursuit.inspect_phase() == GuardPursuit.Inspect.LOOK and not guard.gaze_down
			and get_nodes_in_group(GuardPursuit.BOLT_GROUP).is_empty(),
			"低头看了 %.1f 秒,捡起来:扣件没了,站起来张望" % ((Engine.get_physics_frames() - crouch_t0) / 60.0))
	_snap("guard-holds-bolt")
	var look_t0 := Engine.get_physics_frames()
	for _i in 300:
		if pursuit.inspect_phase() == GuardPursuit.Inspect.NONE:
			break
		await physics_frame
	var stay: float = (Engine.get_physics_frames() - crouch_t0) / 60.0
	var look: float = (Engine.get_physics_frames() - look_t0) / 60.0
	_check(stay >= pursuit.bolt_inspect_time + pursuit.bolt_look_time - 0.2 and look >= pursuit.bolt_look_time - 0.2
			and not caught_inspect[0],
			"在扣件那里待了 %.1f 秒(低头 %.0f + 张望 %.1f),之后照常冷静 2.5 秒、走回去" % [stay, pursuit.bolt_inspect_time, look])

	# ---- 存档点补满
	# 出生点就是存档点 00,开场就激活了:离开、再碰一次也要补满
	var cp := level.get_node("Checkpoint00") as Checkpoint
	await _place(cp.global_position.x + 80.0, cp.global_position.y)
	_check(int(thrower.call("count")) == 2, "离开存档点:还是 2 个")
	await _place(cp.global_position.x, cp.global_position.y)
	_check(int(thrower.call("count")) == 3, "回到(已激活的)存档点:补满 3 个")

	# ---- 空中不能瞄准
	await _place(12.0 * 16.0 + 8.0, 198.0 * 16.0)
	Input.action_press(&"jump")
	await _wait(0.12)
	Input.action_press(&"throw")
	await _wait(0.1)
	_check(not bool(thrower.call("is_aiming")), "空中按 F:不瞄准")
	_release_all()
	await _wait(1.0)

	# ---- 用完了:丢三个,第四次按不出去
	for _k in 3:
		Input.action_press(&"throw")
		await _wait(0.15)
		Input.action_release(&"throw")
		await _wait(0.3)
	_check(int(thrower.call("count")) == 0, "连丢三个,剩 0")
	Input.action_press(&"throw")
	await _wait(0.2)
	_check(not bool(thrower.call("is_aiming")), "没有了:按 F 不瞄准(左上角闪红)")
	_snap("hud-empty")
	_release_all()

	# ---- 塔1 教学:一开始不会;四楼吊桥上捡到第一颗才学会
	await _load("res://src/levels/tower_1_birthplace.tscn")
	var gt := level.get_node("GuardT") as Guard
	_only_guard(gt)
	_check(not bool(thrower.call("is_unlocked")) and int(thrower.call("count")) == 0,
			"塔1 开场:还不会丢扣件,身上 0 个")
	_check(not (thrower.get("_hud") as Control).visible, "塔1 开场:左上角不显示扣件")
	Input.action_press(&"throw")
	await _wait(0.2)
	_check(not bool(thrower.call("is_aiming")), "还不会时按 F:没反应")
	_release_all()
	var cp1 := level.get_node("Checkpoint01") as Checkpoint
	await _place(cp1.global_position.x, cp1.global_position.y)
	_check(int(thrower.call("count")) == 0, "还不会时碰存档点:不补")
	var bolt := level.get_node("Bolt00") as Node2D
	gt.process_mode = Node.PROCESS_MODE_DISABLED
	gt.global_position = Vector2(20.0 * 16.0 + 8.0, 90.0 * 16.0)   # 守卫先定在梯子这头
	await _place(bolt.global_position.x + 40.0, bolt.global_position.y)
	await _place(bolt.global_position.x, bolt.global_position.y)
	await _wait(0.8)
	_check(bool(thrower.call("is_unlocked")) and int(thrower.call("count")) == 1, "捡到第一颗:学会了,身上 1 个")
	_check((thrower.get("_hud") as Control).visible, "左上角出现扣件")
	_check(_subtitle_text() == "「我有一些螺母，扔出应该能吸引他们的注意吧」", "提示句:「我有一些螺母，扔出应该能吸引他们的注意吧」")
	_snap("t1-first-bolt")
	# 站到吊桥西头,把扣件丢到身后(东边)的桥面上:守卫 T 走到桥下查看
	await _place(31.0 * 16.0 + 8.0, 84.0 * 16.0)
	ryn.facing = 1
	gt.global_position = Vector2(30.0 * 16.0 + 8.0, 90.0 * 16.0)
	gt.process_mode = Node.PROCESS_MODE_INHERIT
	Input.action_press(&"throw")
	await _wait(0.2)
	_check(bool(thrower.call("is_aiming")), "学会之后能瞄准")
	_snap("t1-aim-behind")
	Input.action_release(&"throw")
	await _wait(1.6)
	var p2 := gt.get_node("Pursuit") as GuardPursuit
	_check(p2.mode() == GuardPursuit.Mode.SEARCHING and gt.global_position.x > 34.0 * 16.0,
			"守卫 T 走到桥下查看(x %.0f 格)" % (gt.global_position.x / 16.0))
	# 跳下吊桥西头,往梯子走:他在桥下背对着,看不见
	var caught := [false]
	(level.get_node("DetectionReset") as DetectionReset).fail_started.connect(func(_p: Node2D, _g: Node2D) -> void: caught[0] = true)
	gt.darkness_veto = Callable()                        # 这一段要他真的看得见
	Input.action_press(&"move_left")
	await _wait(3.6)
	_release_all()
	_snap("t1-slipped-past")
	_check(not bool(caught[0]) and ryn.global_position.x < 14.0 * 16.0,
			"从吊桥西头跳下、走到梯子脚的暗角,没被发现(x %.0f 格)" % (ryn.global_position.x / 16.0))

	# ---- 守卫查声音不走下平台:塔4 吊桥上的守卫 C,声音在吊桥西头外面的下一层
	await _load("res://src/levels/tower_4_military.tscn")
	var gc := level.get_node("GuardC") as Guard
	_only_guard(gc)
	await _place(100.0 * 16.0, 183.0 * 16.0)              # Ryn 远远放在一楼
	var y0 := gc.global_position.y
	var bus: Node = root.get_node("Noise")
	bus.call(&"emit_noise", Vector2(6.0 * 16.0, 118.0 * 16.0), 800.0)
	await _wait(5.0)
	_check(absf(gc.global_position.y - y0) < 2.0,
			"守卫查下一层的声音:停在吊桥边上,没掉下去(y %.0f → %.0f,x %.0f)" % [y0, gc.global_position.y, gc.global_position.x])
	_snap("guard-at-ledge")

	print("[throw] done, %d fail(s). shots: %s/throw_shots" % [fails, OS.get_user_data_dir()])
	quit(1 if fails > 0 else 0)
