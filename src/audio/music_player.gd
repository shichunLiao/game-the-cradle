class_name MusicPlayer
extends Node
## 一段很淡的配乐,垫在环境声上面:主菜单、塔外几段、结局(2026-10-12)。
##
## 曲子是 `tools/audio/make_music.py` 离线合成的占位(`assets/audio/music/*.wav`,32 秒无缝循环):
##   menu    D 小调,慢慢铺底 + 姐姐动机(A–F–E–D)
##   outside 塔外:空旷的五度长音,偶尔很远的拨弦
##   ending  姐姐动机的大调版,落在 D 上
## 换正式作曲时同名文件替换即可。
##
## 塔里不放配乐 —— 潜行靠环境声和脚步声撑紧张感。
## 音量跟着 `Audio` 的主音量和静音走(每帧读);被发现时和环境声一起压低(`detection_reset`);
## 退出游戏时(`Audio.is_quitting()`)停掉。暂停时也继续(`PROCESS_MODE_ALWAYS`)。
##
## Usage (in a scene): 放在关卡根下,设 `track`。塔外的关由 `tools/level_builder` 按 `MUSIC = "outside"` 放。

const TRACKS: Dictionary = {
	&"menu": "res://assets/audio/music/menu.wav",
	&"outside": "res://assets/audio/music/outside.wav",
	&"ending": "res://assets/audio/music/ending.wav",
}

@export var track: StringName = &"outside"
## 音量(主音量 100% 时),dB。比环境声底噪(-17)再低一点 —— 是垫着的,不是主角。
@export var volume_db: float = -15.0
@export var fade_in: float = 4.0
## 被发现时压低多少,dB(同 `AmbientBed.duck_db`)。
@export var duck_db: float = -10.0
## 失败流程。没设时找同级的 `DetectionReset`;都没有就不压低。
@export var detection_reset: DetectionReset

var _player: AudioStreamPlayer
var _fade: float = 0.0
var _duck: float = 0.0
var _duck_target: float = 0.0
var _fading_out: float = -1.0
var _fade_out_time: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.volume_db = -80.0
	add_child(_player)
	var path: String = TRACKS.get(track, "")
	var stream := load(path) as AudioStreamWAV if not path.is_empty() else null
	if stream == null:
		push_warning("MusicPlayer: 没有这段曲子 %s" % track)
		return
	stream = stream.duplicate() as AudioStreamWAV   # 设循环点不要改到共享的资源
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * float(stream.mix_rate))
	_player.stream = stream
	_player.play()
	if detection_reset == null and get_parent() != null:
		detection_reset = get_parent().get_node_or_null(^"DetectionReset") as DetectionReset
	if detection_reset != null:
		detection_reset.phase_changed.connect(_on_fail_phase)


func _exit_tree() -> void:
	if _player != null:
		_player.stop()


## 在播吗(验证脚本用)。
func is_playing() -> bool:
	return _player != null and _player.playing


## 慢慢淡出到无声(结局黑场时用)。
func fade_out(seconds: float) -> void:
	_fade_out_time = maxf(seconds, 0.01)
	_fading_out = 0.0


func _on_fail_phase(phase: FailSequence.Phase) -> void:
	match phase:
		FailSequence.Phase.CLOSING, FailSequence.Phase.SUBTITLE, FailSequence.Phase.FADING:
			_duck_target = duck_db
		_:
			_duck_target = 0.0


func _process(delta: float) -> void:
	if _player == null or _player.stream == null:
		return
	if Audio.is_quitting():
		_player.stop()
		return
	_fade = minf(_fade + delta / maxf(fade_in, 0.01), 1.0)
	_duck = move_toward(_duck, _duck_target, delta * absf(duck_db) / 0.6)
	var out: float = 1.0
	if _fading_out >= 0.0:
		_fading_out += delta
		out = clampf(1.0 - _fading_out / _fade_out_time, 0.0, 1.0)
	var gain: float = Audio.master_volume() * Audio.volume(&"music") * _fade * out
	_player.volume_db = -80.0 if Audio.is_muted() or gain <= 0.0001 else volume_db + linear_to_db(gain) + _duck
