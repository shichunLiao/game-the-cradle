extends Node
## 显示设置(autoload: `Display`)。全屏切换 + 记忆;字幕大小;开游戏时读回改过的按键(`KeyBindings`)。
##
## 商业游戏的基本功能,之前完全没有 —— 只能以固定窗口跑。
##
## 整数缩放由 `project.godot` 的 `stretch/scale_mode=integer` 保证(见
## `docs/engine-reference/godot/modules/display-2d.md`),全屏下仍然成立:
## 640x360 在 1080p 上是 3 倍,在 1440p 上是 4 倍,两侧留黑边 —— 这正是
## `美术规格.md` §1「整数倍放大」要的,比拉伸填满更重要。

const SETTINGS_PATH: String = "user://settings.cfg"
## 字幕大小的三档(2026-10-12 设定选单):乘在 `TowerSubtitleConfig.font_size` 上。
const SUBTITLE_SCALES: Array[float] = [0.85, 1.0, 1.3]
const SUBTITLE_NAMES: Array[String] = ["小", "中", "大"]

var _fullscreen: bool = false
var _subtitle: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	KeyBindings.capture_defaults()
	KeyBindings.load_saved()
	_load()


## 字幕放大多少(`TowerSubtitle` 每次出字时读)。
func subtitle_scale() -> float:
	return SUBTITLE_SCALES[_subtitle]


## 字幕大小这一档的名字(小 / 中 / 大)。
func subtitle_name() -> String:
	return SUBTITLE_NAMES[_subtitle]


## 换到下一档(`dir` = 1 往大,-1 往小,到头不绕)。
func step_subtitle(dir: int) -> void:
	_subtitle = clampi(_subtitle + dir, 0, SUBTITLE_SCALES.size() - 1)
	_save()


## 一直往大换,到最大再回到最小(按钮点一下用)。
func cycle_subtitle() -> void:
	_subtitle = (_subtitle + 1) % SUBTITLE_SCALES.size()
	_save()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fullscreen"):
		toggle()
		get_viewport().set_input_as_handled()


func is_fullscreen() -> bool:
	return _fullscreen


func toggle() -> void:
	set_fullscreen(not _fullscreen)


func set_fullscreen(value: bool) -> void:
	_fullscreen = value
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # 与音量共用一个文件,先读再写,别覆盖掉对方
	cfg.set_value("display", "fullscreen", _fullscreen)
	cfg.set_value("readability", "subtitle_size", _subtitle)
	cfg.save(SETTINGS_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_subtitle = clampi(int(cfg.get_value("readability", "subtitle_size", 1)), 0, SUBTITLE_SCALES.size() - 1)
	set_fullscreen(bool(cfg.get_value("display", "fullscreen", false)))
