extends SceneTree
## DEV ONLY:跑步残影的几组参数并排对比(点子 F3)。每组:跑起来 → 跑满速 → 录 1 秒(30 帧)→ 松手停下再录 0.4 秒。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/afterimage_compare.gd
##
## 帧存 user://afterimage_compare/<组名>/NN.png(Ryn 周围 600x200),由 scratchpad 里的脚本拼成 GIF。

const PRESETS := {
	"A": {"spacing_px": 11.0, "life_time": 0.26, "max_ghosts": 7, "start_alpha": 0.38},   # 旧值
	"B": {"spacing_px": 18.0, "life_time": 0.22, "max_ghosts": 4, "start_alpha": 0.34},   # 少而清楚(2026-10-12 用户选定,现在的默认值)
	"C": {"spacing_px": 9.0, "life_time": 0.34, "max_ghosts": 9, "start_alpha": 0.42},    # 拖得更长
}


func _initialize() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var bd := TowerBackdrop.new()
	bd.area = Rect2(0, -200, 6000, 600)
	bd.ground_y = 320.0
	world.add_child(bd)
	var floor_block := (load("res://src/levels/gray_block.tscn") as PackedScene).instantiate() as Node2D
	floor_block.set("size", Vector2(6000, 64))
	floor_block.position = Vector2(0, 320)
	world.add_child(floor_block)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	world.add_child(cam)
	await process_frame
	cam.make_current()
	var base := OS.get_user_data_dir() + "/afterimage_compare"
	for key in PRESETS:
		var ryn := (load("res://src/player/ryn.tscn") as PackedScene).instantiate() as Node2D
		ryn.position = Vector2(200, 320)
		world.add_child(ryn)
		var ghost := ryn.get_node("Afterimage")
		for k in PRESETS[key]:
			ghost.set(k, PRESETS[key][k])
		var dir := "%s/%s" % [base, key]
		DirAccess.make_dir_recursive_absolute(dir)
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + "/" + f)
		for i in 10:
			await physics_frame
		Input.action_press(&"move_right")
		Input.action_press(&"sprint")
		var frame := 0
		for t in 120:
			await physics_frame
			cam.global_position = Vector2(ryn.global_position.x, 300.0)
			if t == 89:
				Input.action_release(&"move_right")
				Input.action_release(&"sprint")
			if t >= 60 and t % 2 == 0:
				await process_frame
				var img := root.get_texture().get_image()
				img.get_region(Rect2i(340, 260, 600, 200)).save_png("%s/%02d.png" % [dir, frame])
				frame += 1
		Input.action_release(&"move_right")
		Input.action_release(&"sprint")
		ryn.queue_free()
		await process_frame
	print("afterimage_compare: done → ", base)
	quit()
