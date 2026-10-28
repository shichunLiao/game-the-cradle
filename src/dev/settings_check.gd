extends SceneTree
## DEV ONLY:设定选单检查 + 截图(2026-10-12)—— 分开调的音量、字幕大小、按键重新设定、提示跟着按键变。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/settings_check.gd
##
## 会改 `user://settings.cfg`:开始前把整个文件备份,结束时原样写回(不动玩家自己的设定)。
## 截图存到 production/qa/evidence/settings/。

const SETTINGS := "user://settings.cfg"
const OUT := "res://production/qa/evidence/settings"

var fails := 0
var _backup: String = ""
var _had_file: bool = false


func _check(ok: bool, what: String) -> void:
	print("[settings] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _wait(sec: float) -> void:
	for _i in int(sec * 60.0):
		await process_frame


func _snap(name: String) -> void:
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _button(menu: Node, prefix: String) -> Button:
	var stack: Array[Node] = [menu]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var b := n as Button
		if b != null and b.is_visible_in_tree() and b.text.begins_with(prefix):
			return b
		stack.append_array(n.get_children())
	return null


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("[settings] TIMEOUT")
		_restore()
		quit(2))
	# 先等两帧:autoload(`Display`)的 _ready 要先跑完、记下默认按键,不然记到的是这里改过的
	await process_frame
	await process_frame
	_had_file = FileAccess.file_exists(SETTINGS)
	if _had_file:
		_backup = FileAccess.get_file_as_string(SETTINGS)
	var audio: Node = root.get_node("Audio")
	var display: Node = root.get_node("Display")

	# ---- 音量分开
	audio.call("set_volume", &"music", 0.4)
	audio.call("set_volume", &"sfx", 0.6)
	_check(is_equal_approx(float(audio.call("volume", &"music")), 0.4) and is_equal_approx(float(audio.call("volume", &"sfx")), 0.6),
			"音乐 / 音效分开调")
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	_check(is_equal_approx(float(cfg.get_value("audio", "music", -1.0)), 0.4), "音乐音量存进设定文件")
	display.call("set_fullscreen", false)
	audio.call("set_volume", &"ambient", 0.8)
	cfg = ConfigFile.new()
	cfg.load(SETTINGS)
	_check(cfg.has_section_key("display", "fullscreen"), "改音量不会洗掉全屏设定(以前会)")

	# ---- 按键
	var jump0: int = KeyBindings.primary_key(&"jump")
	var right0: int = KeyBindings.primary_key(&"move_right")
	KeyBindings.set_key(&"jump", KEY_K)
	_check(KeyBindings.primary_key(&"jump") == KEY_K and KeyBindings.key_name(&"jump") == "K", "跳 换成 K")
	_key(KEY_K, true)
	await process_frame
	_check(Input.is_action_pressed(&"jump"), "按 K 就是跳")
	_key(KEY_K, false)
	await process_frame
	KeyBindings.set_key(&"jump", right0)
	_check(KeyBindings.primary_key(&"jump") == right0 and KeyBindings.primary_key(&"move_right") == KEY_K,
			"换成「向右」在用的键:两个互换")
	KeyBindings.set_key(&"interact", KEY_R)
	_check(KeyBindings.with_key("E 拆") == "R 拆", "提示跟着换:%s" % KeyBindings.with_key("E 拆"))
	KeyBindings.reset()
	_check(KeyBindings.primary_key(&"jump") == jump0 and KeyBindings.primary_key(&"move_right") == right0,
			"恢复默认")

	# ---- 暂停菜单:设定页、按键页、在菜单里换键
	var level: Node = (load("res://src/levels/tower_2_refinery.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await _wait(1.0)
	var menu: Node = level.get_node("PauseMenu")   # 不写类型:PauseMenu 里用了 Audio,-s 模式下不能当类型
	menu.call("_set_open", true)
	await _wait(0.3)
	_check(bool(menu.call("is_open")) and paused, "ESC 打开暂停菜单(游戏暂停)")
	_button(menu, "设定").pressed.emit()
	await _wait(0.3)
	var vol := _button(menu, "音乐")
	_check(vol != null and vol.text.contains("██"), "设定页:音乐一行(%s)" % (vol.text if vol else "无"))
	_snap("01-settings-page")
	_button(menu, "字幕大小").pressed.emit()
	await _wait(0.1)
	_check(String(display.call("subtitle_name")) == "大", "字幕大小换到「大」")
	var sub := level.get_node("TowerSubtitle") as TowerSubtitle
	sub.show_line("「字幕大小:大」")
	await _wait(0.1)
	var lbl := sub.get("_label") as Label
	_check(lbl.get_theme_font_size(&"font_size") > 30, "字幕字号放大了(%d)" % lbl.get_theme_font_size(&"font_size"))
	_button(menu, "按键设定").pressed.emit()
	await _wait(0.3)
	_snap("02-keys-page")
	_button(menu, "跳").pressed.emit()
	await _wait(0.1)
	_check(_button(menu, "跳").text.contains("按下新的按键"), "点「跳」:等新按键")
	_snap("03-keys-capturing")
	_key(KEY_J, true)
	await process_frame
	_key(KEY_J, false)
	await _wait(0.1)
	_check(KeyBindings.primary_key(&"jump") == KEY_J and _button(menu, "跳").text.ends_with("J"), "在菜单里把跳换成 J")
	_button(menu, "恢复默认").pressed.emit()
	await _wait(0.1)
	_check(KeyBindings.primary_key(&"jump") == jump0, "菜单里恢复默认")
	display.call("cycle_subtitle")                      # 大 → 小
	display.call("cycle_subtitle")                      # 小 → 中
	menu.call("_set_open", false)
	paused = false
	level.queue_free()
	await _wait(0.2)

	# ---- 主菜单的设定入口
	var main: Node = (load("res://src/ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(1.0)
	var entry := _button(main, "设定")
	_check(entry != null, "主菜单有「设定」")
	entry.pressed.emit()
	await _wait(0.3)
	_snap("04-main-menu-settings")
	var mm: Node = main.get("_settings")
	_check(bool(mm.call("is_open")) and not paused, "主菜单打开设定页(不暂停)")
	main.queue_free()
	await _wait(0.2)
	_restore()
	print("[settings] done, %d fail(s)" % fails)
	quit(1 if fails > 0 else 0)


## 把玩家原来的设定文件写回去,按键也回到默认(再读一次原来的设定)。
func _restore() -> void:
	KeyBindings.reset()
	if _had_file:
		var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
		f.store_string(_backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	KeyBindings.load_saved()
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null:
		audio.call("load_settings")
