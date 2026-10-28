extends SceneTree
## DEV ONLY:收折梯(2026-10-15 用户:替代路线的梯子「要有一定的解谜环节才能用」)。
##
##     godot --path . -s res://src/dev/fold_ladder_check.gd          # 开窗口跑才有截图
##
## 覆盖(塔1 第一架收折梯):收着时站在底下按上抓不到;拆链条锚 → 梯子放到底、发出声音;
## 放下来以后爬得上去;读档(面板复原成没拆)→ 又收回去。截图存 production/qa/evidence/fold-ladder/。

const OUT := "res://production/qa/evidence/fold-ladder"

var fails := 0


func _check(ok: bool, what: String) -> void:
	print("[fold] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _snap(name: String, at: Vector2) -> void:
	var img := root.get_texture().get_image()
	if img == null:                                 # headless 拿不到画面
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var r := Rect2i(Vector2i(at) - Vector2i(110, 150), Vector2i(220, 200)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(r)
	crop.resize(r.size.x * 3, r.size.y * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, name]))


func _initialize() -> void:
	var level: Node = (load("res://src/levels/tower_1_birthplace.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await _frames(30)
	for c in level.get_children():
		if c is Guard:
			(c as Guard).process_mode = Node.PROCESS_MODE_DISABLED
	var fold := level.get_node("FoldLadder00") as FoldLadder
	var ryn := level.get_node("Ryn") as Ryn
	ryn.input_enabled = false
	var heard := [0.0]
	var bus := root.get_node_or_null(^"Noise")
	if bus != null and bus.has_signal(&"noise_made"):
		bus.connect(&"noise_made", func(_p: Vector2, r: float) -> void: heard[0] = maxf(heard[0], r))

	# ---- 收着:站在梯子底下按上,抓不到
	ryn.global_position = Vector2(fold.center_x(), fold.bottom_y())
	ryn.velocity = Vector2.ZERO
	var cam := root.get_viewport().get_camera_2d()
	await _frames(2)
	if cam != null:
		cam.reset_smoothing()
	await _frames(30)
	ryn.intent.move_y = -1.0
	await _frames(30)
	ryn.intent.move_y = 0.0
	_check(not fold.is_open() and ryn.state != Ryn.State.CLIMBING, "收着:站在底下按上抓不到")
	await process_frame
	_snap("00-folded", ryn.get_global_transform_with_canvas().origin)

	# ---- 拆链条锚 → 放下来、有声音
	fold.unfold()
	await _frames(int(fold.drop_time * 60.0) + 10)
	_check(fold.is_open(), "拆了链条锚:梯子放到底")
	_check(bus == null or not bus.has_signal(&"noise_made") or heard[0] >= fold.noise_radius - 1.0,
			"放到底有声音(%.0f px)" % heard[0])
	await process_frame
	_snap("01-unfolded", ryn.get_global_transform_with_canvas().origin)

	# ---- 放下来以后爬得上去
	ryn.intent.move_y = -1.0
	await _frames(20)
	_check(ryn.state == Ryn.State.CLIMBING, "放下来以后按上:抓住梯子")
	var y0: float = ryn.global_position.y
	await _frames(60)
	ryn.intent.move_y = 0.0
	_check(ryn.global_position.y < y0 - 16.0, "往上爬了 %.0f px" % (y0 - ryn.global_position.y))

	# ---- 读档:面板复原成没拆 → 收回去
	ryn.global_position = Vector2(fold.center_x() + 48.0, fold.bottom_y())
	ryn.state = Ryn.State.NORMAL
	await _frames(5)
	fold.call(&"_on_restored", false)
	await _frames(5)
	_check(not fold.is_open(), "读档(面板没拆):梯子又收回去")

	print("[fold] done, %d fail(s)" % fails)
	quit(1 if fails > 0 else 0)
