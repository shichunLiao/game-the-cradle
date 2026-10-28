extends SceneTree
## DEV ONLY:环境声检查 + 导出试听文件。
##
##     godot --path . --headless -s res://src/dev/ambient_check.gd
##
## 每个地方:生成耗时、循环接缝是否平滑、点缀有没有;导出 user://ambient/<名字>.wav(循环两遍,方便试听接缝)。
## 再开一关看 `Ambient` 节点真的在播、音量跟着主音量和静音走(直接改 `Audio` 的内部值,不写设置文件)。
## `AmbientBed` 不写类型(它用到 `Audio`,`-s` 模式下写了类名会在 autoload 之前编译)。

var fails := 0


func _check(ok: bool, what: String) -> void:
	print("[ambient] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _wait(sec: float) -> void:
	for _i in int(sec * 60.0):
		await physics_frame


func _sample(s: AudioStreamWAV, i: int) -> float:
	return float(s.data.decode_s16(i * 2)) / 32767.0


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("[ambient] TIMEOUT")
		quit(2))
	var dir := OS.get_user_data_dir() + "/ambient"
	DirAccess.make_dir_recursive_absolute(dir)
	for key in AmbientBank.PROFILES.keys():
		var t0 := Time.get_ticks_usec()
		var bed := AmbientBank.bed(key)
		var acc := AmbientBank.accents(key)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var n: int = bed.data.size() / 2
		# 接缝:最后一个采样 → 第一个采样的跳变,和平时相邻采样的跳变比
		var mean_step := 0.0
		var peak := 0.0
		for i in range(1, n):
			mean_step += absf(_sample(bed, i) - _sample(bed, i - 1))
			peak = maxf(peak, absf(_sample(bed, i)))
		mean_step /= float(n - 1)
		var seam := absf(_sample(bed, 0) - _sample(bed, n - 1))
		_check(seam <= maxf(mean_step * 6.0, 0.01),
				"%s:%.1f 秒循环,接缝跳变 %.4f(平时 %.4f),峰值 %.2f,点缀 %d 种,生成 %.0f ms"
				% [key, float(n) / bed.mix_rate, seam, mean_step, peak, acc.size(), ms])
		# 导出:循环两遍
		var twice := AudioStreamWAV.new()
		twice.format = bed.format
		twice.mix_rate = bed.mix_rate
		twice.stereo = false
		twice.data = bed.data + bed.data
		twice.save_to_wav("%s/%s.wav" % [dir, key])
		for j in acc.size():
			acc[j].save_to_wav("%s/%s-accent%d.wav" % [dir, key, j])

	# ---- 关卡里:在播、跟主音量走
	var audio: Node = root.get_node("Audio")
	var saved_volume: float = audio.get("_master_volume")
	var saved_muted: bool = audio.get("_muted")
	var level: Node = (load("res://src/levels/tower_2_refinery.tscn") as PackedScene).instantiate()
	root.add_child(level)
	var amb: Node = level.get_node("Ambient")
	await _wait(4.0)
	_check(bool(amb.call("is_playing")), "塔2 的环境声在播")
	var bed_player: AudioStreamPlayer = amb.get("_bed")
	audio.set("_master_volume", 1.0)
	audio.set("_muted", false)
	await _wait(0.2)
	var full: float = bed_player.volume_db
	audio.set("_master_volume", 0.25)
	await _wait(0.2)
	var quarter: float = bed_player.volume_db
	_check(absf((full - quarter) - linear_to_db(4.0)) < 0.5,
			"主音量 100%% → 25%%:底噪 %.1f → %.1f dB" % [full, quarter])
	audio.set("_muted", true)
	await _wait(0.2)
	_check(bed_player.volume_db <= -79.0, "静音时底噪静音")
	audio.set("_muted", false)
	audio.set("_master_volume", 1.0)

	# ---- 被发现:失败流程合拢时压低,回到可操作后放回来
	var reset: Node = level.get_node("DetectionReset")
	reset.call("trigger")
	await physics_frame
	_check(Engine.time_scale < 0.1, "被发现那一下顿帧(时间流速 %.2f)" % Engine.time_scale)
	await create_timer(0.25, true, false, true).timeout   # 真实时间 0.25 秒
	_check(is_equal_approx(Engine.time_scale, 1.0), "顿帧 0.12 秒后恢复(时间流速 %.2f)" % Engine.time_scale)
	await _wait(0.6)
	var ducked: float = amb.call("duck_amount")
	_check(ducked <= -9.0, "被发现时环境声压低 %.1f dB" % ducked)
	for _i in 600:   # 等失败流程走完(最多 10 秒)
		await physics_frame
		if float(amb.call("duck_amount")) > -0.1 and int(reset.get("_sequence").get("phase")) == 0:
			break
	_check(float(amb.call("duck_amount")) > -0.1, "回到可操作后放回来")
	level.queue_free()
	await process_frame

	# ---- 坑底:方舟停 → 呼吸变慢、变低,不停
	var pit: Node = (load("res://src/levels/pit_bottom.tscn") as PackedScene).instantiate()
	root.add_child(pit)
	var pit_amb: Node = pit.get_node("Ambient")
	await _wait(3.0)
	_check(bool(pit_amb.call("is_playing")), "坑底的环境声在播")
	var pit_bed: AudioStreamPlayer = pit_amb.get("_bed")
	var awake_db: float = pit_bed.volume_db
	pit.get_node("EndingSequence").emit_signal(&"ark_stopped")
	await _wait(5.0)
	_check(absf(pit_bed.pitch_scale - float(pit_amb.get("sleep_pitch"))) < 0.02 and pit_bed.playing,
			"方舟停:呼吸变慢(音高 %.2f),还在播" % pit_bed.pitch_scale)
	_check(pit_bed.volume_db < awake_db - 6.0 and pit_bed.volume_db > -60.0,
			"变轻但不静音:%.1f → %.1f dB" % [awake_db, pit_bed.volume_db])

	pit.queue_free()
	await process_frame

	# ---- 配乐:屋顶关在播、跟主音量、被发现时压低;主菜单、结局也在播
	audio.set("_master_volume", 1.0)
	var roof: Node = (load("res://src/levels/slum_rooftops.tscn") as PackedScene).instantiate()
	root.add_child(roof)
	var music: Node = roof.get_node("Music")
	await _wait(5.0)
	_check(bool(music.call("is_playing")), "屋顶关配乐在播")
	var mp: AudioStreamPlayer = music.get("_player")
	var full_db: float = mp.volume_db
	audio.set("_master_volume", 0.5)
	await _wait(0.2)
	_check(absf((full_db - mp.volume_db) - linear_to_db(2.0)) < 0.5, "配乐跟主音量:%.1f → %.1f dB" % [full_db, mp.volume_db])
	audio.set("_master_volume", 1.0)
	roof.get_node("DetectionReset").call("trigger")
	await _wait(0.8)
	_check(mp.volume_db < full_db - 8.0, "被发现时配乐也压低(%.1f dB)" % mp.volume_db)
	roof.queue_free()
	await process_frame
	for path in ["res://src/ui/main_menu.tscn", "res://src/levels/old_house_ending.tscn"]:
		var sc: Node = (load(path) as PackedScene).instantiate()
		root.add_child(sc)
		await _wait(1.5)
		var found := false
		for c in sc.find_children("*", "Node", true, false):
			if c.has_method(&"is_playing") and c.get(&"track") != null and bool(c.call(&"is_playing")):
				found = true
		_check(found, "%s 有配乐在播" % path.get_file())
		sc.queue_free()
		await process_frame

	audio.set("_master_volume", saved_volume)
	audio.set("_muted", saved_muted)
	print("[ambient] done, %d fail(s). wav: %s" % [fails, dir])
	quit(1 if fails > 0 else 0)
