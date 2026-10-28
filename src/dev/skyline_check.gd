extends SceneTree
## DEV ONLY:塔外的景检查 + 截图 —— 每关的远景点拉得远、拉得回;塔里的窗看得到外面。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/skyline_check.gd
##
## 截图存 user://skyline_check/。守卫都停掉(只看景)。远景点挑不碰出口的那一格站(碰到出口会换关)。

const CASES: Array = [
	# [场景, 远景点里站哪(格), 中间一扇窗前站哪(格)]
	["res://src/levels/slum_rooftops.tscn", Vector2(58, 41), Vector2(10, 50)],
	["res://src/levels/tower_1_birthplace.tscn", Vector2(109, 25), Vector2(56, 110)],
	["res://src/levels/tower_2_refinery.tscn", Vector2(57, 8), Vector2(97, 146)],
	["res://src/levels/tower_3_registry.tscn", Vector2(107, 13), Vector2(97, 146)],
	["res://src/levels/tower_4_military.tscn", Vector2(107, 13), Vector2(41, 146)],
	["res://src/levels/pit_descent.tscn", Vector2(14, 12), Vector2(30, 12)],
	["res://src/levels/pipeline_bridge.tscn", Vector2(165, 27), Vector2(40, 30)],
	["res://src/levels/sky_bridge.tscn", Vector2(60, 20), Vector2(30, 20)],
	["res://src/levels/scaffold_descent.tscn", Vector2(30, 10), Vector2(50, 30)],
]

var fails := 0
var shot := 0


func _check(ok: bool, what: String) -> void:
	print("[skyline] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _wait(sec: float) -> void:
	for _i in int(sec * 60.0):
		await physics_frame


func _snap(name: String) -> void:
	var dir := OS.get_user_data_dir() + "/skyline_check"
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png("%s/%02d-%s.png" % [dir, shot, name])
	shot += 1


func _initialize() -> void:
	create_timer(200.0).timeout.connect(func() -> void:
		print("[skyline] TIMEOUT")
		quit(2))
	var dir := OS.get_user_data_dir() + "/skyline_check"
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + "/" + f)
	for c in CASES:
		await _run(c[0], c[1], c[2])
	print("[skyline] done, %d fail(s)" % fails)
	root.get_node("Audio").call("quit_game")


func _run(path: String, vista_at: Vector2, window_at: Vector2) -> void:
	var level: Node = (load(path) as PackedScene).instantiate()
	root.add_child(level)
	var name := path.get_file().get_basename()
	var ryn := level.get_node("Ryn") as Ryn
	var cam := level.get_node("FollowCamera") as FollowCamera
	await _wait(0.5)
	for c in level.get_children():
		if c is Guard:
			(c as Guard).process_mode = Node.PROCESS_MODE_DISABLED
	var windows := 0
	for c in level.get_children():
		if c is SkylineWindow:
			windows += 1
	_check(windows > 0 or level.get_node("Backdrop") is SkylineBackdrop, "%s:有塔外的景(窗 %d 个)" % [name, windows])
	# 中间的窗(屋顶关:旧屋的暖窗)
	ryn.global_position = Vector2(window_at.x * 16.0 + 8.0, window_at.y * 16.0)
	cam.snap_to_target()
	await _wait(1.2)
	_snap(name + "-window")
	# 远景点
	ryn.global_position = Vector2(vista_at.x * 16.0 + 8.0, vista_at.y * 16.0)
	cam.snap_to_target()
	await _wait(3.0)
	_check(cam.zoom.x < 1.1, "%s:远景点镜头拉远(zoom %.2f)" % [name, cam.zoom.x])
	_snap(name + "-vista")
	ryn.global_position = Vector2(window_at.x * 16.0 + 8.0, window_at.y * 16.0)
	await _wait(3.0)
	_check(cam.zoom.x > 1.9, "%s:走出远景点镜头拉回(zoom %.2f)" % [name, cam.zoom.x])
	level.queue_free()
	await process_frame
