extends SceneTree
## DEV ONLY:任意场景截一张图(Ryn 站在指定位置,镜头跟过去)。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/scene_shot.gd -- \
##         --scene=res://src/levels/prologue_slum.tscn --at=80,320 --out=res://production/qa/evidence/prologue-room/04-x.png
##
## `--wait=` 等几秒再截(默认 1.5,让入场字幕、淡入走完一部分)。守卫停掉,不会触发失败。


func _initialize() -> void:
	var scene := ""
	var at := Vector2.INF
	var out := ""
	var wait := 1.5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene = a.substr(8)
		elif a.begins_with("--at="):
			var xy := a.substr(5).split(",")
			at = Vector2(float(xy[0]), float(xy[1]))
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--wait="):
			wait = float(a.substr(7))
	if scene.is_empty() or out.is_empty():
		push_error("scene_shot: 要 --scene= 和 --out=")
		quit(1)
		return
	var level := (load(scene) as PackedScene).instantiate()
	root.add_child(level)
	await process_frame
	for c in level.get_children():
		if c.scene_file_path.ends_with("guard.tscn"):
			c.process_mode = Node.PROCESS_MODE_DISABLED
	var dr := level.get_node_or_null("DetectionReset")
	if dr != null:
		dr.process_mode = Node.PROCESS_MODE_DISABLED
	var ryn := level.get_node_or_null("Ryn") as Node2D
	if ryn != null:
		ryn.set("input_enabled", false)
		if at.is_finite():
			ryn.global_position = at
	for i in int(wait * 60.0):
		await physics_frame
	var cam := level.get_node_or_null("FollowCamera")
	if cam != null and cam.has_method("snap_to_target"):
		cam.call("snap_to_target")
	for i in 6:
		await process_frame
	var path := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_texture().get_image().save_png(path)
	print("scene_shot: ", path)
	quit()
