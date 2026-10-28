extends SceneTree
## DEV ONLY:天际线远景预览截图(屋顶上 / 爬高之后 / 镜头拉远)。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/skyline_preview.gd
##
## 截图存 user://skyline_shots/。前景放一块屋顶和 Ryn 当比例尺。

func _initialize() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var sky := SkylineBackdrop.new()
	sky.level_rect = Rect2(0, 0, 3200, 2400)
	sky.focus_tower = 0
	world.add_child(sky)
	var roof := (load("res://src/levels/gray_block.tscn") as PackedScene).instantiate() as Node2D
	roof.set("size", Vector2(3200, 64))
	roof.position = Vector2(0, 2336)
	world.add_child(roof)
	var ryn := (load("res://src/player/ryn.tscn") as PackedScene).instantiate() as Node2D
	ryn.position = Vector2(400, 2336)
	ryn.set("input_enabled", false)
	world.add_child(ryn)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	world.add_child(cam)
	cam.make_current()
	var dir := OS.get_user_data_dir() + "/skyline_shots"
	DirAccess.make_dir_recursive_absolute(dir)
	var shots := [["1-rooftop", Vector2(400, 2290), 2.0], ["2-rooftop-east", Vector2(1700, 2290), 2.0],
		["3-high-up", Vector2(1200, 600), 2.0], ["4-vista-zoom1", Vector2(900, 2150), 1.0]]
	for s in shots:
		ryn.position = Vector2((s[1] as Vector2).x, 2336)
		cam.global_position = s[1]
		cam.zoom = Vector2(s[2], s[2])
		for i in 20:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [dir, s[0]])
	quit()
