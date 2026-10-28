extends SceneTree
## DEV ONLY:失败画面那一句(2026-10-17 用户:第一次被「听」的守卫抓到要显示「原来他是靠听觉行动的」)。
##
##     godot --path . --headless -s res://src/dev/fail_line_check.gd
##
## 覆盖:被「看」的守卫抓到 → spotted_line;第一次被「听」的守卫抓到 → first_hearing_caught_line;
## 第二次再被「听」的抓到 → 又是 spotted_line。有失败时退出码 1。

const SENSE_SIGHT := 0
const SENSE_HEARING := 1

var fails := 0


func _check(ok: bool, what: String) -> void:
	print("[fail-line] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _initialize() -> void:
	var level: Node = (load("res://src/levels/tower_1_birthplace.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await _frames(20)
	var seeing: Node2D = null
	var hearing: Node2D = null
	for c in level.get_children():
		if c.get(&"sense") is int:
			c.process_mode = Node.PROCESS_MODE_DISABLED
			if int(c.get(&"sense")) == SENSE_HEARING and hearing == null:
				hearing = c
			elif int(c.get(&"sense")) == SENSE_SIGHT and seeing == null:
				seeing = c
	var dr: Node = level.get_node("DetectionReset")
	var overlay: Node = dr.get(&"overlay")
	var cfg: Resource = dr.get(&"config")
	var ryn: Node2D = level.get_node("Ryn")
	_check(seeing != null and hearing != null, "塔1 有看的守卫、也有听的守卫")

	var lines: Array[String] = []
	for g: Node2D in [seeing, hearing, hearing]:
		dr.call(&"trigger", ryn, g)
		await _frames(2)
		lines.append(String(overlay.call(&"line")))
		await _frames(int(6.0 * 60.0))           # 等这次失败流程走完、重生
	_check(lines[0] == cfg.get(&"spotted_line"), "被看的守卫抓到:%s" % lines[0])
	_check(lines[1] == cfg.get(&"first_hearing_caught_line"), "第一次被听的守卫抓到:%s" % lines[1])
	_check(lines[2] == cfg.get(&"spotted_line"), "第二次被听的守卫抓到:又是 %s" % lines[2])
	print("[fail-line] done, %d fail(s)" % fails)
	quit(1 if fails > 0 else 0)
