extends SceneTree
## DEV ONLY:爬梯用背面 4 帧(2026-10-15 用户定稿 v4,带披风)。
##
##     godot --path . -s res://src/dev/climb_back_check.gd          # 要截图就开窗口跑
##
## 覆盖:爬梯时画的是爬梯行 0-3 格,往上爬 4 格都轮到;截图存
## production/qa/evidence/climb-back/。有失败时退出码 1。

const OUT := "res://production/qa/evidence/climb-back"
const ROW_CLIMB := 8

var fails := 0


func _check(ok: bool, what: String) -> void:
	print("[climb] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _snap(name: String, at: Vector2) -> void:
	var img := root.get_texture().get_image()
	if img == null:                                        # headless 拿不到画面,只跑判定
		return
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, name]))
	# 人物附近放大 4 倍,看得清背面
	var r := Rect2i(Vector2i(at) - Vector2i(80, 110), Vector2i(160, 140)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(r)
	crop.resize(r.size.x * 4, r.size.y * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path("%s/%s-x4.png" % [OUT, name]))


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var level: Node = (load("res://src/levels/tower_1_birthplace.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await _frames(30)
	for c in level.get_children():
		if c is Guard:
			(c as Guard).process_mode = Node.PROCESS_MODE_DISABLED
	var ryn := level.get_node("Ryn") as Ryn
	var ladder := level.get_node("Ladder00_10") as Node2D
	ryn.input_enabled = false
	ryn.global_position = Vector2(ladder.call(&"center_x"), ladder.call(&"bottom_y") - 1.0)
	ryn.velocity = Vector2.ZERO
	await _frames(2)
	var cam := root.get_viewport().get_camera_2d()
	if cam != null:
		cam.reset_smoothing()                                # 瞬移过去,镜头别慢慢追
	await _frames(40)
	ryn.intent.move_y = -1.0
	var seen := {}
	var shots := 0
	for i in 150:
		await physics_frame
		if ryn.state != Ryn.State.CLIMBING:
			continue
		var snap: Dictionary = (ryn.get_node("Visual") as Node).call(&"snapshot")
		if int(snap[&"row"]) == ROW_CLIMB and int(snap[&"frame"]) < 4:
			if not seen.has(int(snap[&"frame"])) and shots < 4:
				await process_frame
				_snap("%02d-back-climb-f%d" % [shots, int(snap[&"frame"])], ryn.get_global_transform_with_canvas().origin)
				shots += 1
			seen[int(snap[&"frame"])] = true
	ryn.intent.move_y = 0.0
	_check(seen.size() == 4, "往上爬:背面 4 格都轮到 %s" % [seen.keys()])
	print("[climb] done, %d fail(s)" % fails)
	quit(1 if fails > 0 else 0)
