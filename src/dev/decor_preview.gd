extends SceneTree
## DEV ONLY:塔内换装截图 —— 四座塔各取几处(一楼、中段、高处),看材质和背景道具。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/decor_preview.gd
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/decor_preview.gd -- --only=tower_3
##
## 截图存到 production/qa/evidence/tower-decor/(先清空这个文件夹)。守卫全部停掉、挪远,不会触发失败。

const OUT := "res://production/qa/evidence/tower-decor"
## [场景, 截图名前缀, [Ryn 站的位置(世界像素), ...]]
const SHOTS := [
	["res://src/levels/tower_1_birthplace.tscn", "t1", [Vector2(260, 2336), Vector2(900, 1888), Vector2(1500, 1440), Vector2(700, 992), Vector2(1200, 544)]],
	["res://src/levels/tower_2_refinery.tscn", "t2", [Vector2(260, 2336), Vector2(1500, 1888), Vector2(600, 1440), Vector2(1400, 992), Vector2(500, 544)]],
	["res://src/levels/tower_3_registry.tscn", "t3", [Vector2(400, 2336), Vector2(700, 1888), Vector2(1400, 1440), Vector2(600, 992), Vector2(1300, 544)]],
	["res://src/levels/tower_4_military.tscn", "t4", [Vector2(260, 2336), Vector2(1300, 1888), Vector2(800, 1440), Vector2(1500, 992), Vector2(700, 544)]],
]


func _initialize() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	if only.is_empty():
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".png"):
				DirAccess.remove_absolute(dir + "/" + f)
	for entry in SHOTS:
		if not only.is_empty() and not (entry[0] as String).contains(only):
			continue
		var level := (load(entry[0]) as PackedScene).instantiate()
		root.add_child(level)
		await process_frame
		for n in _guards(level):
			n.process_mode = Node.PROCESS_MODE_DISABLED
			n.position = Vector2(-4000, -4000)
		# 门禁灯、探照灯也会抓人:停掉它们和失败流程(灯照样画)
		for c in level.get_children():
			var sc: Script = c.get_script()
			if sc != null and (sc.resource_path.ends_with("gate_light.gd") or sc.resource_path.ends_with("sweep_light.gd")):
				c.process_mode = Node.PROCESS_MODE_DISABLED
		level.get_node("DetectionReset").process_mode = Node.PROCESS_MODE_DISABLED
		var ryn := level.get_node("Ryn") as Node2D
		var cam := level.get_node("FollowCamera")
		ryn.set("input_enabled", false)
		var k: int = 0
		for p in entry[2]:
			ryn.global_position = p
			ryn.set("velocity", Vector2.ZERO)
			for i in 6:
				await physics_frame
			cam.call("snap_to_target")
			for i in 12:
				await process_frame
			root.get_texture().get_image().save_png("%s/%s-%d.png" % [dir, entry[1], k])
			k += 1
		level.queue_free()
		await process_frame
	print("decor_preview: done → ", dir)
	quit()


func _guards(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in node.get_children():
		if c.scene_file_path.ends_with("guard.tscn"):
			out.append(c)
	return out
