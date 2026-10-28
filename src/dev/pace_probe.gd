extends Node
## DEV ONLY:全流程体检的记录器(2026-10-12)。路线机器人带 `--pace` 跑关时挂在 `DemoState` 底下,
## 每个物理帧记三样:
##
##   - 存档点什么时候踩到(两个存档点之间 = 死一次要重来的那一段);
##   - Ryn 站的地方是不是「被盯着」:某个守卫巡逻范围里任一位置、它会有的朝向看得到这里
##     (不在暗处、没被墙挡),或者在探照灯扫射范围 / 门禁灯框里。连续被盯着的一段 = 一个
##     「要看时机才过得去的关口」;
##   - 走了多远。
##
## 谜题房(蒸汽阀、配电箱、蚀池放流)里的关口另外标出来:设计上要先解机关(放汽、断电、排干)才过得去,
## 机器人只拆挡路的机关,不会去解这些 —— 那里「被盯着」是意料之中。
##
## 量的是 **地形和危险物摆在哪**,不是「机器人会不会被抓」:守卫和灯都被关掉了,机器人也不等时机,
## 所以结果和守卫当时走到哪、面朝哪无关。跑完 `report()` 打一行 `[pace] {json}`,
## `tools/pacing/run_pacing.py` 收集成报告。
##
## Usage(`DemoState` 里):
##     var probe: Node = preload("res://src/dev/pace_probe.gd").new()
##     add_child(probe)
##     probe.call("setup", level_root, ryn, route)
##     ...
##     probe.call("report", verdict)

## 两段「被盯着」之间不到这么多帧,算同一个关口(0.75 秒)。
const MERGE_TICKS: int = 45
## 「听」的守卫撞上算发现的距离(和 `GuardSenses.touch_px` 一样),px。
const TOUCH_PX: float = 14.0
## 守卫巡逻范围的取样间距,px。
const PATROL_SAMPLE_PX: float = 24.0

var _ryn: Ryn
var _route: DevRoute
var _level: Node
var _registry: ShadowRegistry
var _guards: Array[Guard] = []
var _facings: Dictionary = {}          # Guard → Array[int]
var _lights: Array[Node2D] = []
var _sources: Dictionary = {}          # 名字 → {kind, cycle}
var _puzzles: Array = []               # {name, rect, lights}
var _tick: int = 0
var _dist: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _checkpoints: Array = []
var _beats: Array = []
var _open: Dictionary = {}
var _last_cover: int = -100000
var _covered_ticks: int = 0
var _shade_ticks: int = 0
var _active: bool = false
## 刚踩到、还没判断「站的地方有没有被盯着」的存档点(在 `_checkpoints` 里的序号;-1 = 没有)。
## 踩到的信号在物理刷新里发,那时不能打射线,留到下一帧判断。
var _cp_pending: int = -1


## 开始记。`level_root` 是关卡根,`route` 是机器人走的那条 `DevRoute`。
func setup(level_root: Node, ryn: Ryn, route: DevRoute) -> void:
	_level = level_root
	_ryn = ryn
	_route = route
	_last_pos = ryn.global_position
	_collect(level_root)
	for g in _guards:
		_facings[g] = _guard_facings(g)
		_sources[String(g.name)] = {"kind": _guard_kind(g), "cycle": _guard_cycle(g),
				"sense": ["sight", "hearing", "tracking"][int(g.sense)]}
	for l in _lights:
		var sweep := l as SweepLight
		if sweep != null:
			_sources[String(l.name)] = {"kind": "sweep", "cycle": sweep.period}
		else:
			var gate := l as GateLight
			_sources[String(l.name)] = {"kind": "gate", "cycle": gate.red_time + gate.green_time}
	var cm: CheckpointManager = _find_checkpoints(level_root)
	if cm != null:
		cm.checkpoint_activated.connect(_on_checkpoint)
	_active = true


func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is Guard:
			_guards.append(child)
		elif child is SweepLight or child is GateLight:
			_lights.append(child)
		elif child is ShadowRegistry and _registry == null:
			_registry = child
		elif child is SteamValve:
			_puzzles.append({"name": "蒸汽阀 " + String(child.name), "rect": (child as SteamValve).cloud_rect.grow(8.0),
					"lights": PackedStringArray()})
		elif child is FuseBox:
			var fb := child as FuseBox
			_puzzles.append({"name": "配电箱 " + String(child.name), "rect": fb.blackout_rect, "lights": fb.light_names})
		elif child is CorrosionDrain:
			var dr := child as CorrosionDrain
			for zn in dr.zone_names:
				var z := node.get_node_or_null(NodePath(zn)) as CorrosionZone
				if z == null and _level != null:
					z = _level.get_node_or_null(NodePath(zn)) as CorrosionZone
				if z != null:
					_puzzles.append({"name": "蚀池放流 " + String(child.name),
							"rect": Rect2(z.global_position, z.size).grow_individual(48.0, 160.0, 48.0, 8.0),
							"lights": PackedStringArray()})
		_collect(child)


func _find_checkpoints(node: Node) -> CheckpointManager:
	for child in node.get_children():
		if child is CheckpointManager:
			return child
		var found: CheckpointManager = _find_checkpoints(child)
		if found != null:
			return found
	return null


func _behaviour(g: Guard) -> GuardBehaviour:
	for child in g.get_children():
		if child is GuardBehaviour:
			return child
	return null


## 守卫会有的朝向:有巡逻范围的两边都会看;原地不动的哨兵(SENTRY)会转身;原地不动的
## 其它样式(「原地盯梢」)只看出生时那一边。
func _guard_facings(g: Guard) -> Array[int]:
	var b: GuardBehaviour = _behaviour(g)
	if not is_zero_approx(g.patrol_offset) or (b != null and b.style == GuardBehaviour.Style.SENTRY):
		return [-1, 1]
	return [g.initial_facing if g.initial_facing != 0 else 1]


func _guard_kind(g: Guard) -> String:
	var b: GuardBehaviour = _behaviour(g)
	if is_zero_approx(g.patrol_offset):
		return "sentry" if b != null and b.style == GuardBehaviour.Style.SENTRY else "watcher"
	return "patrol"


## 一个来回大约多少秒(玩家平均要等半个来回)。原地盯梢的守卫等不走:-1。
func _guard_cycle(g: Guard) -> float:
	var b: GuardBehaviour = _behaviour(g)
	var speed_scale: float = b.speed_scale if b != null else 1.0
	if is_zero_approx(g.patrol_offset):
		if b != null and b.style == GuardBehaviour.Style.SENTRY:
			return 2.0 * b.sentry_hold
		return -1.0
	var speed: float = maxf(g.config.patrol_speed * speed_scale, 1.0)
	return 2.0 * absf(g.patrol_offset) / speed + 2.0 * g.config.patrol_wait_time


func _on_checkpoint(cp: Checkpoint) -> void:
	_checkpoints.append({"t": _tick, "name": String(cp.name),
			"x": roundf(_ryn.global_position.x), "y": roundf(_ryn.global_position.y), "watched": []})
	_cp_pending = _checkpoints.size() - 1


func _physics_process(_delta: float) -> void:
	if not _active or _ryn == null:
		return
	_tick += 1
	var pos: Vector2 = _ryn.global_position
	var step: float = pos.distance_to(_last_pos)
	if step < 64.0:   # 通风管出口、回存档点是瞬移,不算走的路
		_dist += step
	_last_pos = pos
	var cover: Array[String] = _covering()
	if _cp_pending >= 0:
		_checkpoints[_cp_pending]["watched"] = cover   # 在存档点重生时,站的地方被谁盯得到
		_cp_pending = -1
	if not cover.is_empty():
		_covered_ticks += 1
		if _open.is_empty() or _tick - _last_cover > MERGE_TICKS:
			_close_beat()
			_open = {"t0": _tick, "t1": _tick, "x": roundf(pos.x), "y": roundf(pos.y),
					"src": {}, "seg": _checkpoints.size(), "puzzle": {}}
		for s in cover:
			_open["src"][s] = true
		for pz in _puzzles:
			if (pz["rect"] as Rect2).has_point(pos + Vector2(0.0, -8.0)):
				_open["puzzle"][pz["name"]] = true
			else:
				for s in cover:
					if (pz["lights"] as PackedStringArray).has(s):
						_open["puzzle"][pz["name"]] = true
		_open["t1"] = _tick
		_last_cover = _tick
	elif not _open.is_empty() and _tick - _last_cover > MERGE_TICKS:
		_close_beat()


func _close_beat() -> void:
	if _open.is_empty():
		return
	var src: Array = (_open["src"] as Dictionary).keys()
	src.sort()
	_open["src"] = src
	_open["puzzle"] = (_open["puzzle"] as Dictionary).keys()
	_beats.append(_open)
	_open = {}


## 现在盯着 Ryn 的那几样东西的名字(躲在柜子 / 通风管里的不算)。
func _covering() -> Array[String]:
	var out: Array[String] = []
	if not _ryn.is_detectable():
		return out
	var pt: Vector2 = _ryn.global_position - Vector2(0.0, _ryn.get_body_height() * 0.5)
	var shaded: bool = false
	for g in _guards:
		var r: int = _guard_covers(g, pt)
		if r == 1:
			out.append(String(g.name))
		elif r == 2:
			shaded = true
	for l in _lights:
		if _light_covers(l, pt):
			out.append(String(l.name))
	if out.is_empty() and shaded:
		_shade_ticks += 1
	return out


## 0 = 看不到,1 = 巡逻范围里某处看得到,2 = 看得到但 Ryn 在暗处。
## 「听」的守卫(2026-10-13)没有视野锥:巡逻线上会撞到的地方(巡逻范围 ± 撞上的距离,同一层)才算,暗处不挡。
## 「追」的视野锥本来就短(`Guard` 开场就把配置缩了),照常算。
func _guard_covers(g: Guard, pt: Vector2) -> int:
	if g.config == null:
		return 0
	if g.sense == Guard.Sense.HEARING:
		var lo_h: float = float(g.get(&"_min_x")) - TOUCH_PX
		var hi_h: float = float(g.get(&"_max_x")) + TOUCH_PX
		var feet_y: float = pt.y + _ryn.get_body_height() * 0.5
		return 1 if pt.x >= lo_h and pt.x <= hi_h and absf(feet_y - g.global_position.y) <= 24.0 else 0
	var reach: float = g.config.cone_range
	var eye_y: float = g.global_position.y - g.config.eye_height
	var lo: float = float(g.get(&"_min_x"))
	var hi: float = float(g.get(&"_max_x"))
	if absf(pt.y - eye_y) > reach or pt.x < lo - reach or pt.x > hi + reach:
		return 0
	var half: float = g.config.cone_half_angle_rad()
	var n: int = maxi(1, int(ceil((hi - lo) / PATROL_SAMPLE_PX)))
	var result: int = 0
	for i in n + 1:
		var x: float = lerpf(lo, hi, float(i) / float(n)) if n > 0 else lo
		var eye := Vector2(x, eye_y)
		for f in _facings[g]:
			if not GuardVision.is_in_cone(eye, pt, Vector2(float(f), 0.0), half, reach):
				continue
			if bool(g.call(&"_is_occluded", eye, pt)):
				continue
			if _registry != null and _registry.covers(pt):
				result = 2
				continue
			return 1
	return result


func _light_covers(l: Node2D, pt: Vector2) -> bool:
	if not bool(l.get(&"powered")):
		return false
	var local: Vector2 = pt - l.global_position
	var sweep := l as SweepLight
	if sweep != null:
		var lo: float = minf(0.0, sweep.sweep_span) - sweep.beam_width * 0.5
		var hi: float = maxf(0.0, sweep.sweep_span) + sweep.beam_width * 0.5
		return local.x >= lo and local.x <= hi and local.y >= 0.0 and local.y <= sweep.beam_length
	var gate := l as GateLight
	return local.x >= 0.0 and local.x <= gate.size.x and local.y >= -gate.size.y and local.y <= 0.0


## 打一行 `[pace] {json}`。
func report(verdict: String) -> void:
	_close_beat()
	var actions: Dictionary = {}
	if _route != null:
		for a in _route.actions:
			actions[a] = int(actions.get(a, 0)) + 1
	var data: Dictionary = {
		"scene": _level.scene_file_path if _level != null else "",
		"verdict": verdict.get_slice(" ", 0),
		"ticks": _tick,
		"distance": roundf(_dist),
		"route_steps": _route.points.size() if _route != null else 0,
		"actions": actions,
		"guards": _guards.size(),
		"lights": _lights.size(),
		"sources": _sources,
		"checkpoints": _checkpoints,
		"beats": _beats,
		"covered_ticks": _covered_ticks,
		"shade_ticks": _shade_ticks,
	}
	print("[pace] ", JSON.stringify(data))
