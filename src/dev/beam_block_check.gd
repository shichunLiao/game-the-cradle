extends SceneTree
## DEV ONLY:探照灯被地板 / 平台挡住,灯头是无人机(2026-10-15 用户试玩)。
##
##     godot --path . -s res://src/dev/beam_block_check.gd          # 开窗口跑才有截图
##
## 覆盖:灯正下方站着 → 抓到;灯和人中间塞一块平台 → 抓不到;光柱每条都落在实心上(不停在半空)。
## 截图(脚手架、塔4 各一张,镜头拉远看全一盏灯)存 production/qa/evidence/beam-block/。有失败时退出码 1。

const OUT := "res://production/qa/evidence/beam-block"

var fails := 0
var level: Node


func _check(ok: bool, what: String) -> void:
	print("[beam] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _load(path: String) -> void:
	if level != null:
		level.queue_free()
		await process_frame
	level = (load(path) as PackedScene).instantiate()
	root.add_child(level)
	await _frames(20)
	for c in level.get_children():
		if c is Guard:
			(c as Guard).process_mode = Node.PROCESS_MODE_DISABLED


func _first_sweep() -> SweepLight:
	for c in level.get_children():
		if c is SweepLight:
			return c
	return null


## 镜头拉远,框住整盏灯(灯头到落点),截一张。
func _snap(name: String, sw: SweepLight) -> void:
	sw.ryn = null                                   # 截图时不抓人
	var cam := Camera2D.new()
	level.add_child(cam)
	var old := root.get_viewport().get_camera_2d()
	cam.zoom = (old.zoom if old != null else Vector2.ONE) / 2.5
	cam.global_position = sw.global_position + Vector2(sw.sweep_span * 0.5, sw.beam_length * 0.5)
	cam.make_current()
	await _frames(90)
	var img := root.get_texture().get_image()
	if img != null:                                 # headless 拿不到画面
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, name]))
	cam.queue_free()


func _initialize() -> void:
	# ---- 塔4 第一盏:灯定住不扫,人站正下方
	await _load("res://src/levels/tower_4_military.tscn")
	var sw := _first_sweep()
	var ryn := level.get_node("Ryn") as Ryn
	var dr := level.get_node("DetectionReset") as DetectionReset
	ryn.input_enabled = false
	sw.period = 1.0e9                               # 偏移 ≈ 0:光柱停在灯的原点
	await _frames(2)
	var floor_y: float = sw.global_position.y + sw.call(&"_reach_at", 0.0)
	_check(floor_y > sw.global_position.y + 16.0, "灯往下照到实心(落点在灯下 %.0f px)" % (floor_y - sw.global_position.y))

	# 中间塞一块平台:抓不到
	var plat := StaticBody2D.new()
	plat.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(96.0, 16.0)
	shape.shape = rect
	plat.add_child(shape)
	plat.position = Vector2(sw.global_position.x, floor_y - 72.0)   # 关卡根在原点,先摆好再加
	level.add_child(plat)
	await _frames(3)                                # 等物理世界登记到这块平台
	ryn.global_position = Vector2(sw.global_position.x, floor_y)
	ryn.velocity = Vector2.ZERO
	await _frames(30)
	_check(not dr.is_failing(), "灯和人中间有平台:照不到")

	# 拿掉平台:抓到
	plat.queue_free()
	await _frames(10)
	_check(dr.is_failing(), "拿掉平台:照到、被发现")
	await _frames(240)

	# ---- 光柱每条都落在实心上(塔4 每盏灯、脚手架第一盏)
	var stuck := 0
	var lights := 0
	for c in level.get_children():
		if c is SweepLight:
			lights += 1
			for l in (c.get("_len") as PackedFloat32Array):
				if l >= SweepLight.REACH:
					stuck += 1
	_check(lights > 0 and stuck == 0, "塔4 %d 盏灯,每条光都照到东西(没照到的 %d 条)" % [lights, stuck])
	await _snap("01-tower4-blocked-by-platform", _first_sweep())

	await _load("res://src/levels/scaffold_descent.tscn")
	sw = _first_sweep()
	await _frames(5)
	var hit_floor := true
	for l in (sw.get("_len") as PackedFloat32Array):
		hit_floor = hit_floor and l < SweepLight.REACH
	_check(hit_floor, "脚手架的灯打到地上(以前停在离地 1 格)")
	await _snap("00-scaffold-drone-beam", sw)

	print("[beam] done, %d fail(s)" % fails)
	quit(1 if fails > 0 else 0)
