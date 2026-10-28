extends SceneTree
## DEV ONLY:守卫巡逻检查 —— 每关每个守卫跑 70 秒,看他有没有走完巡逻线、有没有半路来回抖、
## 停最久多久、哨兵多久转一次身。
##
##     godot --path . --headless --fixed-fps 60 -s res://src/dev/patrol_check.gd
##
## `--fixed-fps` 让物理按固定步长尽快跑,不用真的等 70 秒。Ryn 移到地图外并停掉,不发出声音、
## 不被看见 —— 这里只测常态巡逻。
## 2026-10-11 用户:「有几个地方巡逻会站在原地左右摆动,完全过不去」→ `guard_behaviour.gd` 的修正。

const LEVELS: Array[String] = [
	"res://src/levels/slum_rooftops.tscn",
	"res://src/levels/tower_1_birthplace.tscn",
	"res://src/levels/tower_2_refinery.tscn",
	"res://src/levels/tower_3_registry.tscn",
	"res://src/levels/tower_4_military.tscn",
	"res://src/levels/pit_descent.tscn",
	"res://src/levels/pipeline_bridge.tscn",
	"res://src/levels/sky_bridge.tscn",
	"res://src/levels/scaffold_descent.tscn",
]
const SECONDS: float = 70.0
## 离端点多远以内的掉头不算「半路抖」,px。
const END_SLACK: float = 6.0
## 有巡逻范围的守卫,最长可以停多久,秒(扫视 4×0.7 + 端点 1.2、驻足 2.1、哨兵 3.5 都在内)。
const MAX_STILL: float = 6.0

var fails := 0


func _check(ok: bool, what: String) -> void:
	print("[patrol] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _initialize() -> void:
	for path in LEVELS:
		await _run_level(path)
	print("[patrol] done, %d fail(s)" % fails)
	quit(1 if fails > 0 else 0)


func _run_level(path: String) -> void:
	var level: Node = (load(path) as PackedScene).instantiate()
	root.add_child(level)
	var ryn := level.get_node("Ryn") as Node2D
	ryn.process_mode = Node.PROCESS_MODE_DISABLED
	ryn.global_position = Vector2(-5000.0, -5000.0)
	var guards: Array[Guard] = []
	for c in level.get_children():
		if c is Guard:
			guards.append(c as Guard)
	await physics_frame
	await physics_frame
	var stats: Dictionary = {}
	for g in guards:
		stats[g] = {"min": g.global_position.x, "max": g.global_position.x, "jitter": 0, "last_v": 0.0,
				"still": 0.0, "max_still": 0.0, "flips": 0, "last_facing": g.facing, "gaps": [], "since_flip": 0.0}
	var dt: float = 1.0 / 60.0
	for _i in int(SECONDS * 60.0):
		await physics_frame
		for g in guards:
			var st: Dictionary = stats[g]
			var x: float = g.global_position.x
			st["min"] = minf(st["min"], x)
			st["max"] = maxf(st["max"], x)
			var lo: float = g.get("_min_x")
			var hi: float = g.get("_max_x")
			var v: float = g.velocity.x
			if absf(v) > 0.1:
				if absf(st["last_v"]) > 0.1 and signf(v) != signf(st["last_v"]) \
						and x > lo + END_SLACK and x < hi - END_SLACK:
					st["jitter"] += 1
				st["last_v"] = v
				st["still"] = 0.0
			else:
				st["still"] += dt
				st["max_still"] = maxf(st["max_still"], st["still"])
			st["since_flip"] += dt
			if g.facing != st["last_facing"]:
				st["flips"] += 1
				(st["gaps"] as Array).append(st["since_flip"])
				st["since_flip"] = 0.0
				st["last_facing"] = g.facing
	var name := path.get_file().get_basename()
	for g in guards:
		var st: Dictionary = stats[g]
		var lo: float = g.get("_min_x")
		var hi: float = g.get("_max_x")
		var span: float = hi - lo
		var beh := g.get_node_or_null("Behaviour") as GuardBehaviour
		var style: String = GuardBehaviour.Style.keys()[beh.style] if beh != null else "?"
		if span < 1.0 and style == "STEADY":
			# 原地、不转身的盯梢(2026-10-12 谜题房「蒸汽廊」的哨兵:一直盯着来路,要靠蒸汽过):不该动、不该转
			_check(int(st["flips"]) == 0 and float(st["max"]) - float(st["min"]) < 1.0,
					"%s %s(STEADY 原地盯梢):一直朝一个方向、没动(转身 %d 次)" % [name, g.name, st["flips"]])
		elif span < 1.0:
			# 原地站岗:转身间隔要够长
			var gaps: Array = st["gaps"]
			var shortest: float = INF
			for k in range(1, gaps.size()):   # 第一次转身前的时间不算
				shortest = minf(shortest, float(gaps[k]))
			_check(gaps.size() >= 2 and shortest >= 3.0,
					"%s %s(%s 原地):转身 %d 次,最短间隔 %.1f 秒" % [name, g.name, style, gaps.size(), shortest])
		else:
			var cover: float = (float(st["max"]) - float(st["min"])) / span
			_check(cover >= 0.95 and int(st["jitter"]) == 0 and float(st["max_still"]) <= MAX_STILL,
					"%s %s(%s,%.0fpx):走完 %.0f%%,半路掉头 %d 次,最长停 %.1f 秒"
					% [name, g.name, style, span, cover * 100.0, st["jitter"], st["max_still"]])
	level.queue_free()
	await process_frame
