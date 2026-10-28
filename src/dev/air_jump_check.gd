extends SceneTree
## DEV ONLY:二段跳(2026-10-14 用户要的)。真物理,不靠按键(`input_enabled = false`,直接填 `intent`)。
##
##     godot --path . --headless --fixed-fps 60 -s res://src/dev/air_jump_check.gd
##
## 覆盖:一段跳顶点 ≈ `jump_height`;到顶点再按一下,再往上 ≈ `air_jump_height`;空中只能再跳一次;
## 落地补满;提前按、先落地的那一下还是普通跳(满高),不吃掉二段跳;从梯子上跳开也能再跳一下。
## 每项打印 PASS/FAIL,有失败时退出码 1。

var level: Node
var ryn: Ryn
var fails := 0


func _check(ok: bool, what: String) -> void:
	print("[air] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


## 按一下跳(这一帧算「按下」,之后一直按住,直到 `release_jump()`)。
func _press_jump() -> void:
	ryn.intent.jump_pressed = true
	ryn.intent.jump_held = true
	await physics_frame
	ryn.intent.jump_pressed = false


func _release_jump() -> void:
	ryn.intent.jump_held = false


## 一直等到落地,记下最高点(脚底 y 最小)。
func _air_until_land(max_frames: int = 240) -> float:
	var top: float = ryn.global_position.y
	for _i in max_frames:
		await physics_frame
		top = minf(top, ryn.global_position.y)
		if ryn.is_on_floor() and ryn.velocity.y >= 0.0:
			break
	return top


## 等到上升停下来(顶点)。
func _until_apex(max_frames: int = 120) -> void:
	for _i in max_frames:
		await physics_frame
		if ryn.velocity.y >= 0.0:
			return


func _initialize() -> void:
	# 塔2 一楼:一大片平地(和扣件检查同一处),守卫停掉
	level = (load("res://src/levels/tower_2_refinery.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await _frames(30)
	for c in level.get_children():
		if c is Guard:
			(c as Guard).process_mode = Node.PROCESS_MODE_DISABLED
	ryn = level.get_node("Ryn") as Ryn
	ryn.input_enabled = false
	var cfg: RynMovementConfig = ryn.config
	ryn.global_position = Vector2(12.0 * 16.0 + 8.0, 198.0 * 16.0)
	ryn.velocity = Vector2.ZERO
	await _frames(20)
	var floor_y: float = ryn.global_position.y
	_check(ryn.is_on_floor(), "站在地上(y=%.0f)" % floor_y)

	# ---- 一段跳:按住到顶
	await _press_jump()
	var top1: float = await _air_until_land()
	_release_jump()
	var h1: float = floor_y - top1
	_check(absf(h1 - cfg.jump_height) < 6.0, "一段跳顶点 %.0f px(设定 %.0f)" % [h1, cfg.jump_height])
	await _frames(10)

	# ---- 二段跳:到顶点再按
	await _press_jump()
	await _until_apex()
	var apex1: float = ryn.global_position.y
	await _press_jump()
	_check(ryn.velocity.y < -100.0, "空中再按一下:又往上(速度 %.0f)" % ryn.velocity.y)
	var top2: float = await _air_until_land()
	_release_jump()
	var extra: float = apex1 - top2
	_check(absf(extra - cfg.air_jump_height) < 6.0,
			"二段跳又上去 %.0f px(设定 %.0f),一共 %.0f px" % [extra, cfg.air_jump_height, floor_y - top2])
	await _frames(10)

	# ---- 空中只能再跳一次
	await _press_jump()
	await _until_apex()
	await _press_jump()
	await _until_apex()
	var y_before: float = ryn.global_position.y
	await _press_jump()
	await _frames(6)
	_check(ryn.velocity.y > 0.0 and ryn.global_position.y >= y_before - 1.0,
			"第三下没反应(还在往下掉,速度 %.0f)" % ryn.velocity.y)
	_release_jump()
	await _air_until_land()
	await _frames(5)

	# ---- 落地补满:再跳一次,二段跳又能用
	await _press_jump()
	await _until_apex()
	await _press_jump()
	_check(ryn.velocity.y < -100.0, "落地以后补满:又能二段跳")
	_release_jump()
	await _air_until_land()
	await _frames(5)

	# ---- 提前按、先落了地:那一下是普通跳(满高),不是二段跳
	await _press_jump()
	_release_jump()
	# 等到快落地(离地 < 6px、往下掉)再按
	for _i in 120:
		await physics_frame
		if ryn.velocity.y > 0.0 and floor_y - ryn.global_position.y < 6.0:
			break
	var landed_jump_floor: float = floor_y
	ryn.intent.jump_pressed = true
	ryn.intent.jump_held = true
	await physics_frame
	ryn.intent.jump_pressed = false
	var air_left_after_press: int = int(ryn.get("_air_jumps_left"))
	# 落地那一帧之后才起跳(缓冲):先等它真的跳起来
	for _i in 12:
		if ryn.velocity.y < -100.0:
			break
		await physics_frame
	var top3: float = await _air_until_land()
	_release_jump()
	_check(landed_jump_floor - top3 > cfg.jump_height - 8.0 and air_left_after_press == cfg.air_jumps,
			"快落地时按的那一下:没用掉二段跳,落地后起跳是普通跳(高 %.0f px)" % (landed_jump_floor - top3))
	await _frames(10)

	print("[air] done, %d fail(s)" % fails)
	quit(1 if fails > 0 else 0)
