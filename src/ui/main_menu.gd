class_name MainMenu
extends Control
## 序章 + level select (AC9: 序章→四塔 可连续串关).
##
## Deliberately minimal: `design/game-brief.md` 的 Out of scope 里没有存档系统,
## 所以这里只记「解锁到第几关」,不是存档。每一关仍可单独打开测试。
##
## The prologue text is 叙事脚本.md 序章, verbatim.
##
## ## 背景:塔外的夜景(2026-10-12)
## 打开游戏第一眼就该知道这是什么样的世界。背景是 `SkylineBackdrop`(和屋顶关、塔里的窗同一片景),
## 镜头慢慢横移、来回飘;菜单文字放在上层的 `CanvasLayer`(不跟镜头缩放),后面一条中间深、两边淡的
## 暗带保证字读得清楚。很轻的屋顶风声(`AmbientBed`)和一段很淡的配乐(`MusicPlayer` 的 menu)。

## 叙事脚本.md 序章 · Ryn（自语）
const PROLOGUE: String = "「差不多准备好了，是时候出发了」"
## 叙事脚本.md 序章 · 目标提示（UI 一行）
const OBJECTIVE: String = "潜入高塔。别被看见。"

@export var config: TowerSubtitleConfig
## 背景镜头横移的速度,世界 px/秒;来回飘的范围。
@export var drift_speed: float = 9.0
@export var drift_range: Vector2 = Vector2(700.0, 3300.0)

var _rows: VBoxContainer
var _cam: Camera2D
var _hint: Label
var _settings: PauseMenu
var _drift_dir: float = 1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_backdrop()

	var ui := CanvasLayer.new()
	ui.layer = 1
	add_child(ui)
	var band := Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_anchors_preset(Control.PRESET_FULL_RECT)
	band.draw.connect(_draw_band.bind(band))
	ui.add_child(band)

	_rows = VBoxContainer.new()
	_rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_rows.add_theme_constant_override(&"separation", 0)
	ui.add_child(_rows)

	_add_label("The Cradle", 40, Color("C8D4E0"))
	_add_label(OBJECTIVE, 24, Color("3D6B8A"))
	_add_label("", 20, Color("0B1220"))
	for i in LevelSequence.ORDER.size():
		# 未解锁的关只显示为暗色标题 —— 有推进感,但不做存档系统
		# 塔与塔之间的塔外段落(含屋顶)小一号、淡一点:读起来是「塔之间的路」,菜单也放得下 11 关
		var between: bool = _is_between(LevelSequence.ORDER[i])
		if Progress.is_unlocked(i):
			_add_button(LevelSequence.TITLES[i], LevelSequence.ORDER[i], between)
		else:
			_add_label("· " + LevelSequence.TITLES[i] + " ·", 16 if between else 24, Color("1F2B3E"))
	_add_label("", 10, Color("0B1220"))
	# 设定(2026-10-12):音量分开调、字幕大小、按键 —— 和暂停菜单同一页
	_settings = PauseMenu.new()
	_settings.font = config
	_settings.settings_only = true
	add_child(_settings)
	_settings.closed.connect(_refresh_hint)
	var b := Button.new()
	b.text = "设定"
	b.flat = true
	b.add_theme_font_override(&"font", _font())
	b.add_theme_font_size_override(&"font_size", 20)
	b.add_theme_color_override(&"font_color", Color("7F93AB"))
	b.add_theme_color_override(&"font_hover_color", Color("3D6B8A"))
	b.pressed.connect(func() -> void:
		Audio.play(&"ui_confirm", -8.0)
		_settings.open_settings_only())
	_rows.add_child(b)
	_add_label("", 10, Color("0B1220"))
	_add_label("", 18, Color("4A5C78"))
	_hint = _rows.get_child(_rows.get_child_count() - 1) as Label
	_refresh_hint()


## 底下那行操作提示:按现在的按键写(改过按键会跟着变)。
func _refresh_hint() -> void:
	if _hint == null:
		return
	var k := func(a: StringName) -> String: return KeyBindings.key_name(a)
	_hint.text = "ESC 暂停 · %s/%s 走 · %s 跑 · %s 跳(空中再按:二段跳)· %s 蹲 · %s 爬 · 按住 %s 拆 · 按住 %s 丢扣件" % [
		k.call(&"move_left"), k.call(&"move_right"), k.call(&"sprint"), k.call(&"jump"),
		k.call(&"move_down"), k.call(&"move_up"), k.call(&"interact"), k.call(&"throw")]


## 夜景 + 慢慢横移的镜头 + 很轻的风声。
func _build_backdrop() -> void:
	var world := Node2D.new()
	add_child(world)
	var sky := SkylineBackdrop.new()
	sky.level_rect = Rect2(0.0, 0.0, 4000.0, 1200.0)
	sky.horizon = 0.74
	sky.focus_tower = -1
	sky.pan = 0.08
	world.add_child(sky)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(2.0, 2.0)
	_cam.position = Vector2(drift_range.x, 1000.0)
	world.add_child(_cam)
	_cam.make_current()
	var amb := AmbientBed.new()
	amb.profile = AmbientBed.Profile.ROOFTOPS
	amb.bed_db = -24.0
	amb.accent_db = -28.0
	add_child(amb)
	var music := MusicPlayer.new()
	music.track = &"menu"
	music.volume_db = -13.0
	add_child(music)


func _process(delta: float) -> void:
	if _cam == null:
		return
	_cam.position.x += drift_speed * _drift_dir * delta
	if _cam.position.x > drift_range.y:
		_drift_dir = -1.0
	elif _cam.position.x < drift_range.x:
		_drift_dir = 1.0


## 菜单后面一条竖的暗带:中间深、两边淡(20 条竖条叠出来)。
func _draw_band(band: Control) -> void:
	var size: Vector2 = band.get_viewport_rect().size
	var w: float = 620.0
	var strips: int = 20
	for i in strips:
		var k: float = (float(i) + 0.5) / float(strips) * 2.0 - 1.0
		var a: float = 0.62 * (1.0 - k * k)
		band.draw_rect(Rect2(size.x * 0.5 - w * 0.5 + w * float(i) / strips, 0.0, w / strips + 1.0, size.y),
				Color(0.043, 0.071, 0.125, a))


func _font() -> SystemFont:
	var face := SystemFont.new()
	if config != null:
		face.font_names = config.font_names
	return face


func _add_label(text: String, size: int, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", _font())
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	_rows.add_child(l)


## 塔外段落(塔与塔之间、序章之后的屋顶)。
func _is_between(scene_path: String) -> bool:
	for key in ["slum_rooftops", "pipeline_bridge", "sky_bridge", "scaffold_descent"]:
		if scene_path.contains(key):
			return true
	return false


func _add_button(text: String, scene_path: String, small: bool = false) -> void:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_override(&"font", _font())
	b.add_theme_font_size_override(&"font_size", 17 if small else 26)
	b.add_theme_color_override(&"font_color", Color("7F93AB") if small else Color("C8D4E0"))
	b.add_theme_color_override(&"font_hover_color", Color("3D6B8A"))
	b.pressed.connect(func() -> void:
		Audio.play(&"ui_confirm", -8.0)
		get_tree().change_scene_to_file(scene_path))
	_rows.add_child(b)
