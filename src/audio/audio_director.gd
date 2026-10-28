extends Node
## 全局音频播放器(autoload: `Audio`)。持有音效库、音量设置与播放池。
##
## 关卡只管喊 `Audio.play(&"spotted")`,不关心音源怎么来的 —— W7/W8 换真素材时
## 只改这里的 `_bank`,所有调用点不动。
##
## 音量写进 `user://settings.cfg`,与存档分开。

const BUS_MASTER: int = 0
const POOL_SIZE: int = 10
const SETTINGS_PATH: String = "user://settings.cfg"
## 退出前等多久(真实时间),让音频线程放掉已停的播放。按帧等不可靠:无头模式下几帧不到 1 毫秒。
const QUIT_SETTLE_TIME: float = 0.12

var _bank: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _master_volume: float = 0.8
## 分开调的三类音量(2026-10-12 设定选单):乘在总音量上。音乐 = `MusicPlayer`,环境声 = `AmbientBed`,
## 音效 = 这里 `play()` 出去的一切(脚步、拆东西、字幕提示音……)。
var _volumes: Dictionary = {&"music": 1.0, &"sfx": 1.0, &"ambient": 1.0}
var _muted: bool = false
var _quitting: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 关窗(含 Cmd+Q)先走 `quit_game()`:停声音、等几帧再退,见那里的说明
	get_tree().set_auto_accept_quit(false)
	_bank = {
		&"footstep_a": SfxBank.footstep(1),
		&"footstep_b": SfxBank.footstep(2),
		&"jump": SfxBank.jump(),
		&"land": SfxBank.land(),
		&"spotted": SfxBank.spotted(),
		&"suspicious": SfxBank.suspicious(),
		&"dismantle_0": SfxBank.dismantle_step(0),
		&"dismantle_1": SfxBank.dismantle_step(1),
		&"dismantle_2": SfxBank.dismantle_step(2),
		&"dismantle_3": SfxBank.dismantle_step(3),
		&"dismantle_done": SfxBank.dismantle_done(),
		&"subtitle": SfxBank.subtitle_blip(),
		&"respawn": SfxBank.respawn(),
		&"checkpoint": SfxBank.checkpoint(),
		&"shade_in": SfxBank.shade_in(),
		&"ui_confirm": SfxBank.ui_confirm(),
		&"bolt_throw": SfxBank.bolt_throw(),
		&"bolt_clink": SfxBank.bolt_clink(),
		&"bolt_tick": SfxBank.bolt_tick(),
		&"pa_chime": SfxBank.pa_chime(),
		&"steam_hiss": SfxBank.steam_hiss(),
		&"power_down": SfxBank.power_down(),
		&"power_up": SfxBank.power_up(),
		&"shutter_roll": SfxBank.shutter_roll(),
		&"bridge_crash": SfxBank.bridge_crash(),
	}
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool.append(p)
	load_settings()


## 退出游戏。所有调用 `quit()` 的地方都走这里(关窗、暂停菜单的「退出」)。
##
## 先停掉场景里每一个还在响的声音,等一小会儿让音频线程放手,再真正退出。直接 `quit()` 时
## 还在循环的环境声,它的播放状态被音频线程攥着,退出时报 ObjectDB 泄漏(2026-10-12 查到)。
func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	for p in _pool:
		p.stop()
	_stop_players(get_tree().root)
	await get_tree().create_timer(QUIT_SETTLE_TIME, true, false, true).timeout
	get_tree().quit()


## 正在退出(`quit_game()` 停完声音、等那几帧的时候)。这时谁都不该再出声。
func is_quitting() -> bool:
	return _quitting


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func _stop_players(node: Node) -> void:
	for c in node.get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).stop()
		elif c is AudioStreamPlayer2D:
			(c as AudioStreamPlayer2D).stop()
		_stop_players(c)


## 播一个音。未知名字静默忽略 —— 缺一个音效不该让游戏炸。
##
## Usage: `Audio.play(&"spotted")`
func play(id: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if _muted or _quitting or not _bank.has(id):
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _bank[id]
	p.pitch_scale = pitch
	p.volume_db = volume_db + linear_to_db(maxf(_master_volume * volume(&"sfx"), 0.0001))
	p.play()


## 脚步左右交替,并带轻微音高抖动,避免机械感。
func play_footstep(left: bool) -> void:
	play(&"footstep_a" if left else &"footstep_b", -6.0, randf_range(0.94, 1.06))


func master_volume() -> float:
	return _master_volume


func set_master_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	save_settings()


## 某一类的音量(0..1):&"music" / &"sfx" / &"ambient"。
func volume(category: StringName) -> float:
	return float(_volumes.get(category, 1.0))


func set_volume(category: StringName, value: float) -> void:
	_volumes[category] = clampf(value, 0.0, 1.0)
	save_settings()


func is_muted() -> bool:
	return _muted


func set_muted(value: bool) -> void:
	_muted = value
	save_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # 和全屏、按键、字幕大小共用一个文件,先读再写,别覆盖掉别的
	cfg.set_value("audio", "master", _master_volume)
	cfg.set_value("audio", "muted", _muted)
	for k in _volumes:
		cfg.set_value("audio", String(k), _volumes[k])
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_master_volume = float(cfg.get_value("audio", "master", 0.8))
	_muted = bool(cfg.get_value("audio", "muted", false))
	for k in _volumes.keys():
		_volumes[k] = clampf(float(cfg.get_value("audio", String(k), 1.0)), 0.0, 1.0)
