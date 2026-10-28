class_name PauseMenu
extends CanvasLayer
## ESC 暂停:继续 / 重试本关 / 设定 / 回主菜单 / 退出游戏。
##
## 之前只能关窗口才能退出游戏 —— 那是"没做完"而不是"极简"。美术规格 §5 的极简
## 针对的是 **游玩中的 HUD**(无血条、无小地图),不是指不要暂停菜单。
##
## `process_mode = ALWAYS` + `get_tree().paused`:菜单在暂停时仍响应。
##
## ## 设定(2026-10-12)
##
## 三页:主页 → 设定 → 按键。
##   - 设定:总音量 / 音乐 / 音效 / 环境声(各五档,点一下往上一档、到顶回零;选中时 ← → 直接调)、
##     字幕大小(小 / 中 / 大)、全屏、声音波纹、按键设定…
##   - 按键:每个动作一行,点它 →「按下新的按键…」→ 按任意键换掉 **主键**(方向键那组和手柄不动);
##     撞到别的动作就互换(`KeyBindings`)。ESC 取消。最后一行「恢复默认」。
## 在设定 / 按键页按 ESC 是「返回上一页」,不是关菜单。
## 主菜单也能打开设定页(`open_settings_only()`):那时关掉就是关掉,不暂停游戏。
##
## 键盘和手柄都能用:上下选、确认键按,← → 调音量和字幕大小。

const MENU_LAYER: int = 120
const TEXT: Color = Color("C8D4E0")
const ACCENT: Color = Color("3D6B8A")
const DIM: Color = Color("4A5C78")

@export var font: TowerSubtitleConfig
## 重试本关时重载当前场景;为空则用 `get_tree().current_scene.scene_file_path`。
@export_file("*.tscn") var retry_scene: String = ""
## 只当设定页用(主菜单):ESC 不开暂停主页,也不暂停游戏。用 `open_settings_only()` 打开。
@export var settings_only: bool = false

## 菜单关上了(主菜单用来刷新按键提示)。
signal closed

enum Page { MAIN, SETTINGS, KEYS }

var _root: Control
var _pages: Dictionary = {}
var _page: Page = Page.MAIN
var _open: bool = false
## 只开设定页(主菜单用):不暂停、ESC 不开主页。
var _settings_only: bool = false
## 正在等新按键的动作;空 = 没在等。
var _capturing: StringName = &""
var _vol_buttons: Dictionary = {}       # 类别 → 按钮
var _sub_button: Button
var _fs_button: Button
var _rings_button: Button
var _key_buttons: Dictionary = {}       # 动作 → 按钮


func _ready() -> void:
	layer = MENU_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_only = settings_only
	_build()
	_set_open(false)


## 主菜单用:直接打开设定页(不暂停)。
func open_settings_only() -> void:
	_settings_only = true
	_open = true
	_root.visible = true
	_show(Page.SETTINGS)


## 菜单开着吗(验证脚本用)。
func is_open() -> bool:
	return _open


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var veil := ColorRect.new()
	veil.color = Color(Color("0B1220"), 0.86)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(veil)

	# ---- 主页
	var main := _new_page(Page.MAIN)
	_add_label(main, "暂停", 36, TEXT)
	_add_label(main, "", 16, Color("0B1220"))
	_add_button(main, "继续", _on_resume)
	_add_button(main, "重试本关", _on_retry)
	_add_button(main, "设定", func() -> void: _go(Page.SETTINGS))
	_add_button(main, "回主菜单", _on_menu)
	_add_button(main, "退出游戏", _on_quit)

	# ---- 设定
	var st := _new_page(Page.SETTINGS)
	_add_label(st, "设定", 32, TEXT)
	_add_label(st, "", 10, Color("0B1220"))
	for pair in [[&"master", "总音量"], [&"music", "音乐"], [&"sfx", "音效"], [&"ambient", "环境声"]]:
		var cat: StringName = pair[0]
		var b := _add_button(st, "", func() -> void: _step_volume(cat, 1, true))
		b.gui_input.connect(func(e: InputEvent) -> void: _lr(e, func(d: int) -> void: _step_volume(cat, d, false)))
		_vol_buttons[cat] = b
		b.set_meta(&"label", pair[1])
	_sub_button = _add_button(st, "", _on_subtitle)
	_sub_button.gui_input.connect(func(e: InputEvent) -> void: _lr(e, func(d: int) -> void: _step_subtitle(d)))
	_fs_button = _add_button(st, "", _on_fullscreen)
	_rings_button = _add_button(st, "", _on_rings)
	_add_button(st, "按键设定", func() -> void: _go(Page.KEYS))
	_add_button(st, "返回", _back)

	# ---- 按键
	var keys := _new_page(Page.KEYS)
	_add_label(keys, "按键设定", 32, TEXT)
	_add_label(keys, "点一下,再按新的按键(Esc 取消)。方向键和手柄不变。", 16, DIM)
	for pair in KeyBindings.ACTIONS:
		var action: StringName = pair[0]
		var b := _add_button(keys, "", func() -> void: _start_capture(action), 22)
		b.set_meta(&"label", pair[1])
		_key_buttons[action] = b
	_add_button(keys, "恢复默认", _on_reset_keys)
	_add_button(keys, "返回", _back)
	_refresh()


func _new_page(p: Page) -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override(&"separation", 2)
	_root.add_child(rows)
	_pages[p] = rows
	return rows


func _font() -> SystemFont:
	var f := SystemFont.new()
	if font != null:
		f.font_names = font.font_names
	return f


func _add_label(page: VBoxContainer, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", _font())
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	page.add_child(l)
	return l


func _add_button(page: VBoxContainer, text: String, cb: Callable, size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_override(&"font", _font())
	b.add_theme_font_size_override(&"font_size", size)
	b.add_theme_color_override(&"font_color", TEXT)
	b.add_theme_color_override(&"font_hover_color", ACCENT)
	b.add_theme_color_override(&"font_focus_color", ACCENT)
	# 按钮撑满整行,默认的焦点框会是横贯全屏的两条线 —— 选中只靠字变青色
	b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	page.add_child(b)
	return b


## 选中的按钮上按 ← / →。
func _lr(e: InputEvent, step: Callable) -> void:
	if e.is_action_pressed(&"ui_left"):
		step.call(-1)
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed(&"ui_right"):
		step.call(1)
		get_viewport().set_input_as_handled()


func _bar(v: float) -> String:
	var n: int = int(round(v * 5.0))
	return "█".repeat(n) + "·".repeat(5 - n)


func _vol_of(cat: StringName) -> float:
	return Audio.master_volume() if cat == &"master" else Audio.volume(cat)


func _refresh() -> void:
	for cat in _vol_buttons:
		var b: Button = _vol_buttons[cat]
		b.text = "%s  %s" % [b.get_meta(&"label"), _bar(_vol_of(cat))]
	_sub_button.text = "字幕大小  " + Display.subtitle_name()
	_fs_button.text = "全屏  " + ("开" if Display.is_fullscreen() else "关") + "   (F11)"
	_rings_button.text = "声音波纹  " + ("开" if _noise_bus() != null and _noise_bus().rings_visible() else "关")
	for action in _key_buttons:
		var b: Button = _key_buttons[action]
		var shown: String = "按下新的按键…" if action == _capturing else KeyBindings.key_name(action)
		b.text = "%s    %s" % [b.get_meta(&"label"), shown]


func _show(p: Page) -> void:
	_page = p
	for k in _pages:
		(_pages[k] as Control).visible = k == p
	_refresh()
	for c in (_pages[p] as VBoxContainer).get_children():
		if c is Button:
			(c as Button).grab_focus()
			break


func _go(p: Page) -> void:
	Audio.play(&"ui_confirm", -8.0)
	_show(p)


func _back() -> void:
	Audio.play(&"ui_confirm", -8.0)
	if _page == Page.KEYS:
		_show(Page.SETTINGS)
	elif _settings_only:
		_set_open(false)
	else:
		_show(Page.MAIN)


func _input(event: InputEvent) -> void:
	# 等新按键:抢在别的输入之前(ESC 也在这里,取消而不是关菜单)
	if _capturing == &"" or not _open:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	get_viewport().set_input_as_handled()
	var action: StringName = _capturing
	_capturing = &""
	if k.keycode != KEY_ESCAPE and k.physical_keycode != KEY_ESCAPE:
		KeyBindings.set_key(action, int(k.physical_keycode) if k.physical_keycode != 0 else int(k.keycode))
		Audio.play(&"ui_confirm", -8.0)
	_refresh()
	if _key_buttons.has(action):
		(_key_buttons[action] as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	get_viewport().set_input_as_handled()
	if _open and _page != Page.MAIN and not (_settings_only and _page == Page.SETTINGS):
		_back()
	elif _settings_only:
		if _open:
			_set_open(false)
	else:
		_set_open(not _open)


func _set_open(value: bool) -> void:
	_open = value
	_root.visible = value
	_capturing = &""
	if not _settings_only:
		get_tree().paused = value
	if value:
		Audio.play(&"ui_confirm", -8.0)
		_show(Page.MAIN)
	else:
		closed.emit()


func _on_resume() -> void:
	Audio.play(&"ui_confirm", -8.0)
	_set_open(false)


func _on_retry() -> void:
	Audio.play(&"ui_confirm", -8.0)
	var path: String = retry_scene
	if path.is_empty() and get_tree().current_scene != null:
		path = get_tree().current_scene.scene_file_path
	get_tree().paused = false
	if not path.is_empty():
		get_tree().change_scene_to_file(path)


## 点一下:往上一档,到顶回到零(老的五档循环);← →:往一边调,到头停住。
func _step_volume(cat: StringName, dir: int, wrap: bool) -> void:
	var v: float = _vol_of(cat) + 0.2 * float(dir)
	if wrap and v > 1.01:
		v = 0.0
	v = clampf(v, 0.0, 1.0)
	if cat == &"master":
		Audio.set_master_volume(v)
	else:
		Audio.set_volume(cat, v)
	_refresh()
	Audio.play(&"ui_confirm", -8.0)


func _on_subtitle() -> void:
	Display.cycle_subtitle()
	_refresh()
	Audio.play(&"ui_confirm", -8.0)


func _step_subtitle(dir: int) -> void:
	Display.step_subtitle(dir)
	_refresh()
	Audio.play(&"ui_confirm", -8.0)


func _on_fullscreen() -> void:
	Display.toggle()
	_refresh()
	Audio.play(&"ui_confirm", -8.0)


## 声音波纹只是画面:关掉后守卫照样听得见,只是玩家看不到圈。
func _on_rings() -> void:
	var bus: Node = _noise_bus()
	if bus != null:
		bus.set_rings_visible(not bus.rings_visible())
	_refresh()
	Audio.play(&"ui_confirm", -8.0)


## 走 /root 路径:autoload 名在静态分析时会被当成类名。
func _noise_bus() -> Node:
	return get_node_or_null(^"/root/Noise")


func _start_capture(action: StringName) -> void:
	Audio.play(&"ui_confirm", -8.0)
	_capturing = action
	_refresh()


func _on_reset_keys() -> void:
	KeyBindings.reset()
	_refresh()
	Audio.play(&"ui_confirm", -8.0)


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")


func _on_quit() -> void:
	get_tree().paused = false
	Audio.quit_game()
