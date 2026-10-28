extends SceneTree
## DEV ONLY:小地图存档点检查 + 截图。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/minimap_check.gd
##
## 塔2:Ryn 依次碰三个存档点,再站回第二个 —— 小地图上三个亮菱形,第三个(最后激活的)
## 大一号闪着。截图存 user://minimap_shots/(整屏 + 右上角放大)。
##
## 塔3(2026-10-12,S7):站到通风管口前 → 小地图画出通到哪;钻进去 → Ryn 的点顺着虚线爬;
## 出来之后这根管子记为钻过。截图另存 production/qa/evidence/minimap/。

var fails := 0


func _check(ok: bool, what: String) -> void:
	print("[minimap] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _wait(sec: float) -> void:
	for _i in int(sec * 60.0):
		await physics_frame


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("[minimap] TIMEOUT")
		quit(2))
	var level: Node = (load("res://src/levels/tower_2_refinery.tscn") as PackedScene).instantiate()
	root.add_child(level)
	var ryn := level.get_node("Ryn") as Ryn
	for c in level.get_children():
		if c is Guard:
			(c as Guard).process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(1.0)
	var cps: Array[Checkpoint] = []
	for i in 4:
		cps.append(level.get_node("Checkpoint%02d" % i) as Checkpoint)
	for i in range(1, 4):
		ryn.global_position = cps[i].global_position
		ryn.velocity = Vector2.ZERO
		await _wait(0.6)
	var cpm := level.get_node("CheckpointManager") as CheckpointManager
	var reached := 0
	for c in cps:
		if c.activated:
			reached += 1
	_check(reached == 4, "碰过的 4 个存档点(含出生点)都记为到过:%d" % reached)
	_check(cpm.active_checkpoint == cps[3], "现在的重生点是最后碰的那个")
	var mm: Node = level.get_node("Minimap")
	_check(mm.get("_checkpoint_manager") == cpm, "小地图接上了存档点管理")
	await _wait(0.5)
	var dir := OS.get_user_data_dir() + "/minimap_shots"
	DirAccess.make_dir_recursive_absolute(dir)
	var img := root.get_texture().get_image()
	img.save_png(dir + "/00-tower2-checkpoints.png")
	var crop := img.get_region(Rect2i(img.get_width() - 240, 0, 240, 200))
	crop.resize(720, 600, Image.INTERPOLATE_NEAREST)
	crop.save_png(dir + "/01-minimap-zoom.png")
	level.queue_free()
	await _wait(0.2)
	await _check_vents()
	print("[minimap] done, %d fail(s). shots: %s" % [fails, dir])
	quit(1 if fails > 0 else 0)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)
	await physics_frame


func _shot(name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://production/qa/evidence/minimap")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := root.get_texture().get_image()
	var crop := img.get_region(Rect2i(img.get_width() - 240, 0, 240, 200))
	crop.resize(720, 600, Image.INTERPOLATE_NEAREST)
	crop.save_png("%s/%s.png" % [dir, name])


func _check_vents() -> void:
	var level: Node = (load("res://src/levels/tower_3_registry.tscn") as PackedScene).instantiate()
	root.add_child(level)
	for c in level.get_children():
		if c is Guard:
			(c as Guard).process_mode = Node.PROCESS_MODE_DISABLED
			(c as Guard).position = Vector2(-4000, -4000)
	level.get_node("DetectionReset").process_mode = Node.PROCESS_MODE_DISABLED
	var ryn := level.get_node("Ryn") as Ryn
	var mm := level.get_node("Minimap")
	var a := level.get_node("Vent00A") as HidingSpot
	var b := level.get_node("Vent00B") as HidingSpot
	await _wait(1.0)
	_check(mm.call("vent_hint").is_empty(), "离通风管远的时候不画提示")
	ryn.global_position = a.anchor()
	ryn.velocity = Vector2.ZERO
	await _wait(0.5)
	var hint: Array = mm.call("vent_hint")
	_check(a.is_prompting(), "站在管口前:提示亮着")
	_check(not hint.is_empty() and (hint[1] as Vector2).distance_to(b.anchor()) < 0.5 and float(hint[2]) < 0.0,
		"小地图提示指向另一头(还没进去)")
	_shot("02-vent-hint")
	await _tap(&"interact")
	await _wait(0.3)
	hint = mm.call("vent_hint")
	_check(not hint.is_empty() and float(hint[2]) > 0.0 and float(hint[2]) < 1.0,
		"在管子里:爬了 %.2f(0~1 之间)" % (float(hint[2]) if not hint.is_empty() else -1.0))
	_shot("03-vent-travelling")
	await _wait(1.0)
	_check(ryn.global_position.distance_to(b.anchor()) < 24.0, "从另一头出来")
	_check(int(mm.call("vents_used")) == 1, "这根管子记为钻过")
	ryn.global_position = Vector2(ryn.global_position.x + 120.0, ryn.global_position.y)
	await _wait(0.4)
	_check(mm.call("vent_hint").is_empty(), "走开之后提示消失(只剩淡虚线)")
	_shot("04-vent-used")
	level.queue_free()
	await _wait(0.1)
