extends SceneTree
## DEV ONLY:坑底结局走一遍 —— 举照片 → 照片 → 三句 → 切断节点 → 「方舟停」→ 淡出 → 换到旧屋结局。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/ending_check.gd
##
## 2026-10-12 结局的等待改成挂在自己下面的 Timer(关游戏时不再泄漏协程),淡出改成补间;
## 这个检查确认演出本身还完整。举照片、关照片、切断都直接触发(不靠按键),所以只测演出的流程。

var fails := 0


func _check(ok: bool, what: String) -> void:
	print("[ending] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _wait(sec: float) -> void:
	for _i in int(sec * 60.0):
		await physics_frame


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		print("[ending] TIMEOUT")
		quit(2))
	var level: Node = (load("res://src/levels/pit_bottom.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	var seq: Node = level.get_node("EndingSequence")
	var photo: Node = level.get_node("PhotoTrigger")
	var display: Node = level.get_node("PhotoDisplay")
	var cut := level.get_node("CutNode") as Dismantlable
	var got := {"ark": false, "finished": false}
	seq.connect(&"ark_stopped", func() -> void: got["ark"] = true)
	seq.connect(&"ending_finished", func() -> void: got["finished"] = true)

	await _wait(6.0)                                         # B:两句 Vera / Ryn,之后照片才能举
	_check(not cut.visible, "切断节点在举照片之前藏着")
	photo.emit_signal(&"photo_raised")                       # C:举照片
	await _wait(2.2)                                         # 静帧 freeze_time 1.6
	_check(bool(display.call("is_open")), "静帧之后照片打开")
	display.call("hide_photo")                               # 玩家看完照片
	await _wait(6.0)                                         # 三句 line_gap 2.6:别来找我 / 我找到了 / 我知道你会来
	var sub := level.get_node("TowerSubtitle") as TowerSubtitle
	var said: String = (sub.get("_label") as Label).text
	_check(said == "「就知道你会来。」", "「我找到了」之后 Vera:%s" % said)
	_check(level.get_node_or_null("VeraTraces") != null, "Vera 身上有 V-17 号牌和工装布条")
	var dir := ProjectSettings.globalize_path("res://production/qa/evidence/clue-chain")
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir + "/10-pit-bottom-vera-knew.png")
	await _wait(3.4)                                         # 第三句 2.6 + 照片收起的淡出
	_check(cut.visible and cut.process_mode != Node.PROCESS_MODE_DISABLED, "照片之后:切断节点出现")
	cut.force_dismantle()                                    # D:切断
	await _wait(0.5)
	_check(bool(got["ark"]), "切断:方舟停(ark_stopped)")
	await _wait(6.5)                                         # 淡出 4.5 + 1.2
	_check(bool(got["finished"]), "淡出完:ending_finished")
	await _wait(0.5)
	var now: String = current_scene.scene_file_path if current_scene != null else ""
	_check(now.ends_with("old_house_ending.tscn"), "换到旧屋结局(%s)" % now)
	print("[ending] done, %d fail(s)" % fails)
	root.get_node("Audio").call("quit_game")
