extends Node
## DEV ONLY:真人试玩记录器(2026-10-14,`design/ideas-backlog.md` K7)。autoload `PlaytestLog`。
##
## 试玩的人只管玩,这里自动记下:
##   - 每关进 / 出的时间;存档点什么时候踩到;
##   - 每次被发现:在哪、被谁(哪种守卫 / 探照灯 / 门禁灯 / Vera)、Ryn 当时在干嘛(站 / 走 / 跑 / 蹲 / 蹲着走 /
##     爬梯 / 空中)、在不在暗处、离上次重生多久;
##   - 守卫起疑(头上冒「?」)—— 差点被抓的地方;丢扣件、进出柜子 / 通风管;
##   - Ryn 每 0.25 秒的位置(画热点图)。
##
## 写到 `user://playtest/<开始时间>.jsonl`,一行一个事件,每行写完就 flush(闪退也不丢)。
## `tools/playtest/report.py` 读这些文件,出 `production/qa/playtest-<日期>.md` 和每关的热点图。
##
## 什么时候开:编辑器里跑(debug 版)默认开;`-s` 检查脚本、`--demo=` 机器人不开(会把数据搅乱)。
## 强制开 / 关:`-- --playtest-log` / `-- --no-playtest-log`。
##
## 只记、不评,也不改任何规则。`DetectionReset` 刻意不记失败次数 —— 那是给玩家的「失败没有代价」;
## 这里是给开发者看的,玩家看不到。
##
## **不写游戏里的类名**(`Guard`、`Ryn`……):autoload 和 `-s` 检查脚本都会编译到它,写了类名会一路
## 连到用 `Audio` 的脚本(`trace_trail.gd` 踩过的坑)。一律按节点名、属性、`call()` 鸭子类型。
##
## Usage:
##     PlaytestLog.start("user://x.jsonl")   # 检查脚本里强制开、指定文件
##     PlaytestLog.follow(level_root)        # 关卡不是 current_scene 时(检查脚本)手动接上
##     PlaytestLog.stop()

## 文件放哪。
const DIR: String = "user://playtest"
## 位置多久记一次,秒。
const SAMPLE_SEC: float = 0.25
## Ryn 水平速度低于这个算站着,px/s。
const STILL_SPEED: float = 5.0
const FORCE_ON: String = "--playtest-log"
const FORCE_OFF: String = "--no-playtest-log"
## Guard.State:PATROL 0 · SUSPICIOUS 1 · SPOTTED 2;Guard.Sense:SIGHT 0 · HEARING 1 · TRACKING 2
const GUARD_PATROL: int = 0
const GUARD_SUSPICIOUS: int = 1
const SENSE_NAMES: PackedStringArray = ["sight", "hearing", "tracking"]
## Ryn.State:NORMAL 0 · CLIMBING 1 · HIDING 2
const RYN_CLIMBING: int = 1
const RYN_HIDING: int = 2

var _file: FileAccess
var _path: String = ""
## 试玩时间(暂停不算),秒。按物理帧数算真实秒数 —— 被发现时的顿帧(`Hitstop`)会调慢 `time_scale`,
## 用 `delta` 会少算。
var _t: float = 0.0
var _level_t: float = 0.0
var _scene: Node
var _scene_path: String = ""
var _ryn: Node2D
var _shadows: Node
var _guards: Array[Node2D] = []
var _guard_state: Dictionary = {}      # Node2D → int
var _cp_name: String = ""
var _respawn_t: float = -1.0
var _sample_left: float = 0.0
var _fails_here: int = 0


func _ready() -> void:
	# `-s` 检查脚本的 `_initialize()` 比 autoload 的 `_ready` 先跑,可能已经 `start()` 过了
	set_physics_process(_file != null)
	if _file == null and _wanted():
		start()


## 现在在记吗。
func is_recording() -> bool:
	return _file != null


## 正在写的文件(`user://…`);没在记时是空字符串。
func current_path() -> String:
	return _path


## 开始记。`path` 为空时按开始时间起名,放在 `DIR` 下。已经在记就什么也不做。
func start(path: String = "") -> void:
	if _file != null:
		return
	if path.is_empty():
		DirAccess.make_dir_recursive_absolute(DIR)
		var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
		path = "%s/%s.jsonl" % [DIR, stamp]
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("PlaytestLog: 打不开 %s(%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	_path = path
	_t = 0.0
	_write({"ev": "session", "started": Time.get_datetime_string_from_system(false, true),
			"godot": Engine.get_version_info().get("string", "")})
	set_physics_process(true)


## 停下、关文件(先把当前这关记一笔「离开」)。
func stop() -> void:
	if _file == null:
		return
	_leave("stop")
	_write({"ev": "end"})
	_file.close()
	_file = null
	_scene = null
	set_physics_process(false)


## 换到 `scene` 这一关来记。平时自动跟着 `current_scene` 走;检查脚本把关卡直接挂在 root 下时手动调。
func follow(scene: Node) -> void:
	if scene == _scene:
		return
	_leave("switch")
	_scene = scene
	_scene_path = "" if scene == null else scene.scene_file_path
	_level_t = 0.0
	_fails_here = 0
	_cp_name = ""
	_respawn_t = -1.0
	_sample_left = 0.0
	_ryn = null
	_shadows = null
	_guards.clear()
	_guard_state.clear()
	if scene == null or _file == null:
		return
	_write({"ev": "enter", "scene": _scene_path})
	_ryn = scene.get_node_or_null("Ryn") as Node2D
	_shadows = scene.get_node_or_null("ShadowRegistry")
	var reset := scene.get_node_or_null("DetectionReset")
	_hook(reset, "fail_started", _on_fail)
	_hook(reset, "control_restored", _on_respawn)
	_hook(scene.get_node_or_null("CheckpointManager"), "checkpoint_activated", _on_checkpoint)
	if _ryn != null:
		_hook(_ryn, "hiding_changed", _on_hiding)
		_hook(_ryn.get_node_or_null("Throw"), "thrown", _on_thrown)
	for n in scene.get_children():
		if _global_name(n) == &"Guard":
			_guards.append(n as Node2D)
			_guard_state[n] = int(n.get("state"))


func _wanted() -> bool:
	var user := OS.get_cmdline_user_args()
	if user.has(FORCE_OFF):
		return false
	if user.has(FORCE_ON):
		return true
	if not OS.is_debug_build():
		return false
	# `-s` 检查脚本:主循环是带脚本的 SceneTree
	if get_tree().get_script() != null:
		return false
	for a in user:
		if a.begins_with("--demo="):
			return false
	return true


func _physics_process(_delta: float) -> void:
	var step := 1.0 / Engine.physics_ticks_per_second
	var cur := get_tree().current_scene
	if cur != null and cur != _scene:
		follow(cur)
	elif _scene != null and not is_instance_valid(_scene):
		follow(null)
	_t += step
	_level_t += step
	if _ryn == null or not is_instance_valid(_ryn):
		return
	_poll_guards()
	_sample_left -= step
	if _sample_left <= 0.0:
		_sample_left += SAMPLE_SEC
		var e := _ryn_fields()
		e["ev"] = "pos"
		_write(e)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		stop()


func _leave(reason: String) -> void:
	if _scene_path.is_empty() or _file == null:
		return
	_write({"ev": "leave", "scene": _scene_path, "reason": reason, "fails": _fails_here})
	_scene_path = ""


# ------------------------------------------------------------------ 事件

func _on_fail(_player: Node2D, source: Node2D) -> void:
	_fails_here += 1
	var e := _ryn_fields() if _ryn != null and is_instance_valid(_ryn) else {}
	e["ev"] = "fail"
	e["cp"] = _cp_name
	e["since_respawn"] = snappedf(_t - _respawn_t, 0.01) if _respawn_t >= 0.0 else -1.0
	e["by"] = _source_kind(source)
	if source != null:
		e["src"] = String(source.name)
		e["sx"] = roundi(source.global_position.x)
		e["sy"] = roundi(source.global_position.y)
	_write(e)


func _on_respawn() -> void:
	_respawn_t = _t
	var e := _ryn_fields() if _ryn != null and is_instance_valid(_ryn) else {}
	e["ev"] = "respawn"
	e["cp"] = _cp_name
	_write(e)


func _on_checkpoint(cp: Node2D) -> void:
	_cp_name = String(cp.name)
	_write({"ev": "cp", "name": _cp_name, "x": roundi(cp.global_position.x), "y": roundi(cp.global_position.y)})


func _on_hiding(hidden: bool, spot: Node2D) -> void:
	var e := _ryn_fields()
	e["ev"] = "hide" if hidden else "unhide"
	e["spot"] = "" if spot == null else String(spot.name)
	_write(e)


func _on_thrown(_bolt: Node) -> void:
	var e := _ryn_fields()
	e["ev"] = "throw"
	_write(e)


## 守卫从巡逻变成起疑(头上冒「?」)。从「发现」退回来、存档点重置都不算。
func _poll_guards() -> void:
	for g in _guards:
		if not is_instance_valid(g):
			continue
		var s := int(g.get("state"))
		var was: int = _guard_state.get(g, GUARD_PATROL)
		if s == was:
			continue
		_guard_state[g] = s
		if was == GUARD_PATROL and s == GUARD_SUSPICIOUS:
			var e := _ryn_fields()
			e["ev"] = "alert"
			e["src"] = String(g.name)
			e["sense"] = _sense_name(g)
			e["sx"] = roundi(g.global_position.x)
			e["sy"] = roundi(g.global_position.y)
			_write(e)


# ------------------------------------------------------------------ 小工具

## 接上 `obj` 的 `sig`(没有这个节点 / 信号、或已经接过就跳过 —— 同一关先离开再回来不会接两次)。
func _hook(obj: Object, sig: StringName, cb: Callable) -> void:
	if obj != null and obj.has_signal(sig) and not obj.is_connected(sig, cb):
		obj.connect(sig, cb)


func _ryn_fields() -> Dictionary:
	var p := _ryn.global_position
	return {"x": roundi(p.x), "y": roundi(p.y), "do": _doing(), "shade": _in_shade()}


## Ryn 在干嘛:stand / walk / run / crouch / sneak / climb / hide / air / aim。
func _doing() -> String:
	var st := int(_ryn.get("state"))
	if st == RYN_CLIMBING:
		return "climb"
	if st == RYN_HIDING:
		return "hide"
	if _ryn.has_method("is_on_floor") and not _ryn.call("is_on_floor"):
		return "air"
	if _ryn.get("aiming"):
		return "aim"
	var moving: bool = absf((_ryn.get("velocity") as Vector2).x) > STILL_SPEED
	if _ryn.get("is_crouching"):
		return "sneak" if moving else "crouch"
	if _ryn.get("is_sprinting"):
		return "run"
	return "walk" if moving else "stand"


## 和 `RynStealthVisual`、`Guard.sight_point()` 同一个采样点:躯干中点。
func _in_shade() -> bool:
	if _shadows == null or not is_instance_valid(_shadows) or not _ryn.has_method("get_body_height"):
		return false
	var h: float = _ryn.call("get_body_height")
	return bool(_shadows.call("covers", _ryn.global_position - Vector2(0.0, h * 0.5)))


func _source_kind(source: Node) -> String:
	if source == null:
		return "other"
	match _global_name(source):
		&"Guard":
			return "guard_" + _sense_name(source)
		&"SweepLight":
			return "sweep"
		&"GateLight":
			return "gate"
		&"VeraSweep":
			return "vera"
	return "other"


func _sense_name(guard: Node) -> String:
	var s := int(guard.get("sense"))
	return SENSE_NAMES[s] if s >= 0 and s < SENSE_NAMES.size() else "sight"


func _global_name(n: Node) -> StringName:
	var s := n.get_script() as Script
	return &"" if s == null else s.get_global_name()


func _write(e: Dictionary) -> void:
	if _file == null:
		return
	e["t"] = snappedf(_t, 0.01)
	if not _scene_path.is_empty():
		e["lt"] = snappedf(_level_t, 0.01)
	_file.store_line(JSON.stringify(e))
	_file.flush()
