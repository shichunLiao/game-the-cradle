class_name KeyBindings
extends RefCounted
## 按键重新设定(2026-10-12 设定选单)。每个动作在 `project.godot` 里有两个键盘键(比如 A + ←)和手柄键;
## 这里只换 **第一个键盘键**(主键),方向键那组和手柄都不动 —— 换坏了也还有退路。
##
##   - 换成别的动作已经在用的键:两个动作互换(那个动作拿到这个动作原来的主键);
##     如果撞的是对方的第二个键(方向键那组),把它从对方身上拿掉。
##   - 存到 `user://settings.cfg` 的 [keys](physical keycode,和键盘布局无关);开游戏时 `Display` 读回来。
##   - 「恢复默认」= 回到 `project.godot` 里的样子(开游戏时先记下来)。
##
## Usage:
##     KeyBindings.capture_defaults()      # 开游戏时,读存档之前
##     KeyBindings.load_saved()
##     KeyBindings.set_key(&"jump", KEY_K)
##     var name := KeyBindings.key_name(&"jump")   # "K"

const SETTINGS_PATH: String = "user://settings.cfg"
## 能换的动作和它们的中文名(暂停 ESC 不让换:换坏了就打不开菜单)。
const ACTIONS: Array = [
	[&"move_left", "向左"], [&"move_right", "向右"], [&"move_up", "向上 / 爬梯"], [&"move_down", "向下 / 蹲"],
	[&"jump", "跳 · 空中再按二段跳"], [&"sprint", "跑"], [&"interact", "互动 / 按住拆"], [&"throw", "按住丢扣件"],
]

static var _defaults: Dictionary = {}


## 记下 `project.godot` 里每个动作的主键(恢复默认用)。只记一次。
static func capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for pair in ACTIONS:
		_defaults[pair[0]] = primary_key(pair[0])


## 记下来的默认主键(动作 → physical keycode)。验证脚本用。
static func defaults() -> Dictionary:
	return _defaults.duplicate()


## 这个动作现在的主键(physical keycode);没有键盘键返回 0。
static func primary_key(action: StringName) -> int:
	if not InputMap.has_action(action):
		return 0
	for e in InputMap.action_get_events(action):
		var k := e as InputEventKey
		if k != null:
			return int(k.physical_keycode) if k.physical_keycode != 0 else int(k.keycode)
	return 0


## 主键显示成字(按当前键盘布局),比如「A」「Space」「Shift」。
static func key_name(action: StringName) -> String:
	var code: int = primary_key(action)
	if code == 0:
		return "—"
	# 无头模式(检查脚本、路线机器人)不支持按键盘布局换算,直接用键码
	var logical: int = 0
	if DisplayServer.get_name() != "headless":
		logical = DisplayServer.keyboard_get_keycode_from_physical(code)
	var s: String = OS.get_keycode_string(logical if logical != 0 else code)
	return _pretty(s)


## 提示文字开头的「E 」换成现在的互动键(「E 拆」「E 钻进去」……改过按键,提示跟着变)。
static func with_key(text: String) -> String:
	if text.begins_with("E "):
		return key_name(&"interact") + text.substr(1)
	return text


static func _pretty(s: String) -> String:
	match s:
		"Space": return "空格"
		"Shift": return "Shift"
		"Escape": return "Esc"
		"Left": return "←"
		"Right": return "→"
		"Up": return "↑"
		"Down": return "↓"
	return s


## 把 `action` 的主键换成 `code`(physical keycode)。撞键时互换 / 拿掉,见文件头。存档。
static func set_key(action: StringName, code: int) -> void:
	var old: int = primary_key(action)
	if code == old or code == 0:
		return
	for pair in ACTIONS:
		var other: StringName = pair[0]
		if other == action:
			continue
		if primary_key(other) == code:
			_replace_primary(other, old)          # 互换
		else:
			_remove_key(other, code)              # 撞到对方的第二个键:拿掉
	_replace_primary(action, code)
	save()


## 全部回到 `project.godot` 的样子。
static func reset() -> void:
	for pair in ACTIONS:
		var a: StringName = pair[0]
		if _defaults.has(a):
			_replace_primary(a, int(_defaults[a]))
	save()


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # 和音量、全屏共用一个文件,先读再写
	if cfg.has_section("keys"):
		cfg.erase_section("keys")
	for pair in ACTIONS:
		var a: StringName = pair[0]
		if _defaults.get(a, 0) != primary_key(a):
			cfg.set_value("keys", String(a), primary_key(a))
	cfg.save(SETTINGS_PATH)


## 读回存过的按键(只存了改过的那几个)。
static func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK or not cfg.has_section("keys"):
		return
	for pair in ACTIONS:
		var a: StringName = pair[0]
		var code: int = int(cfg.get_value("keys", String(a), 0))
		if code != 0:
			_replace_primary(a, code)


## 换掉第一个键盘键,其余事件(第二个键盘键、手柄)原样、顺序不变。
static func _replace_primary(action: StringName, code: int) -> void:
	if not InputMap.has_action(action):
		return
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	var done: bool = false
	var out: Array[InputEvent] = []
	for e in events:
		if not done and e is InputEventKey:
			done = true
			if code != 0:
				var k := InputEventKey.new()
				k.physical_keycode = code as Key
				out.append(k)
			continue
		out.append(e)
	if not done and code != 0:
		var k2 := InputEventKey.new()
		k2.physical_keycode = code as Key
		out.push_front(k2)
	InputMap.action_erase_events(action)
	for e in out:
		InputMap.action_add_event(action, e)


## 把某个键从这个动作的第二个键盘键里拿掉(主键不动)。
static func _remove_key(action: StringName, code: int) -> void:
	if not InputMap.has_action(action):
		return
	var first: bool = true
	for e in InputMap.action_get_events(action):
		var k := e as InputEventKey
		if k == null:
			continue
		if first:
			first = false
			continue
		var c: int = int(k.physical_keycode) if k.physical_keycode != 0 else int(k.keycode)
		if c == code:
			InputMap.action_erase_event(action, e)
