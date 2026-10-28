class_name AmbientBed
extends Node
## 一关的环境声:一条循环的底噪,加上隔一阵响一下的点缀(管子敲击、灯管跳闪、金属吱呀、滴水)。
##
## 声音由 `AmbientBank` 程序生成(第一次在后台线程算,算好后淡入;之后有缓存)。
## 音量跟着 `Audio` 的主音量和静音走 —— 每帧读一次,暂停菜单里拖音量条立刻听得到变化,
## 所以它在暂停时也继续跑(`PROCESS_MODE_ALWAYS`)。
## 环境声是给玩家听的,守卫听不见(与 `noise_bus.gd` 无关)。
##
## ## 跟着剧情走
##  - **被发现**:失败流程(`DetectionReset.phase_changed`)合拢到淡回之间,整体压低 `duck_db`,
##    回到可操作后慢慢放回来 —— 那一拍安静,让「被看见了」更重。
##  - **睡着**:`fall_asleep()` 把音高慢慢压到 `sleep_pitch`(坑底的呼吸变慢、低鸣变低)、音量降
##    `sleep_db`,点缀停掉。叙事脚本.md:「方舟停。大陆睡着 —— 呼吸变慢,非死亡。」所以不静音。
##    坑底场景里 `EndingSequence.ark_stopped` 连到这里。
##
## Usage (in a scene): 放在关卡根节点下,设 `profile`。
## 塔和下行关由 `tools/level_builder` 生成时按关卡描述的 `AMBIENT` 放。

enum Profile { PROLOGUE, TOWER_1, TOWER_2, TOWER_3, TOWER_4, DESCENT, PIT_BOTTOM, ROOFTOPS }

const PROFILE_KEYS: Array[StringName] = [
	&"prologue", &"tower_1", &"tower_2", &"tower_3", &"tower_4", &"descent", &"pit_bottom", &"rooftops",
]

## 哪个地方的声音。
@export var profile: Profile = Profile.TOWER_1
## 底噪音量(主音量 100% 时),dB。环境声要「听得出、不抢戏」:比脚步(-6)低得多。
@export var bed_db: float = -17.0
## 点缀音量,dB。
@export var accent_db: float = -20.0
## 开场淡入,秒。
@export var fade_in: float = 2.5
## 点缀音高随机范围(±)。
@export var accent_pitch_jitter: float = 0.12
## 被发现时整体压低多少,dB。
@export var duck_db: float = -10.0
## 压下去 / 放回来用多久,秒。
@export var duck_in_time: float = 0.25
@export var duck_out_time: float = 1.4
## 「睡着」:音高压到多少、音量降多少 dB、用多久(和结局的淡出 `sleep_fade_time` 对齐)。
@export var sleep_pitch: float = 0.55
@export var sleep_db: float = -8.0
@export var sleep_time: float = 4.5
## 失败流程。没设时找同级的 `DetectionReset`;都没有就不压低(序章、结局)。
@export var detection_reset: DetectionReset

var _bed: AudioStreamPlayer
var _accent: AudioStreamPlayer
var _task: int = -1
var _gen_bed: AudioStreamWAV
var _gen_accents: Array[AudioStreamWAV] = []
var _fade: float = 0.0
var _accent_left: float = 0.0
var _rng := RandomNumberGenerator.new()
var _started: bool = false
var _duck: float = 0.0
var _duck_target: float = 0.0
var _sleeping: bool = false
var _sleep: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1000 + int(profile)
	_bed = AudioStreamPlayer.new()
	_bed.volume_db = -80.0
	add_child(_bed)
	_accent = AudioStreamPlayer.new()
	add_child(_accent)
	_task = WorkerThreadPool.add_task(_generate, false, "ambient " + str(key()))
	if detection_reset == null and get_parent() != null:
		detection_reset = get_parent().get_node_or_null(^"DetectionReset") as DetectionReset
	if detection_reset != null:
		detection_reset.phase_changed.connect(_on_fail_phase)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	# 关游戏时底噪还在循环:不先停掉,播放状态会被音频线程攥着,退出时报 ObjectDB 泄漏
	if _bed != null:
		_bed.stop()
	if _accent != null:
		_accent.stop()


## 这关用的声音名(`AmbientBank.PROFILES` 的键)。
func key() -> StringName:
	return PROFILE_KEYS[int(profile)]


## 底噪开始播了吗(验证脚本用)。
func is_playing() -> bool:
	return _started and _bed.playing


## 现在压低了多少 dB(≤ 0,验证脚本用)。
func duck_amount() -> float:
	return _duck


## 大陆睡着:呼吸变慢、变低、变轻,但不停。只能进,不能退。
func fall_asleep() -> void:
	_sleeping = true


func _on_fail_phase(phase: FailSequence.Phase) -> void:
	match phase:
		FailSequence.Phase.CLOSING, FailSequence.Phase.SUBTITLE, FailSequence.Phase.FADING:
			_duck_target = duck_db
		_:
			_duck_target = 0.0


## 后台线程:生成(或从缓存取)声音。
func _generate() -> void:
	_gen_bed = AmbientBank.bed(key())
	_gen_accents = AmbientBank.accents(key())


func _process(delta: float) -> void:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_start()
	if not _started:
		return
	if Audio.is_quitting():
		return   # 退出前停掉的声音不能再被点缀音拉起来(那几帧里滴水声会再响一次 → 泄漏)
	_fade = minf(_fade + delta / maxf(fade_in, 0.01), 1.0)
	var duck_time: float = duck_in_time if _duck_target < _duck else duck_out_time
	_duck = move_toward(_duck, _duck_target, delta * absf(duck_db) / maxf(duck_time, 0.01))
	var sleep_k: float = 0.0
	if _sleeping:
		_sleep = minf(_sleep + delta / maxf(sleep_time, 0.01), 1.0)
		sleep_k = smoothstep(0.0, 1.0, _sleep)
		_bed.pitch_scale = lerpf(1.0, sleep_pitch, sleep_k)
	var gain_db: float = linear_to_db(maxf(Audio.master_volume() * Audio.volume(&"ambient") * _fade, 0.0001)) \
			+ _duck + sleep_db * sleep_k
	var muted: bool = Audio.is_muted()
	_bed.volume_db = -80.0 if muted else bed_db + gain_db
	if not _sleeping:
		_tick_accents(delta, gain_db, muted)


func _start() -> void:
	_started = true
	if _gen_bed != null:
		_bed.stream = _gen_bed
		_bed.play()
	_accent_left = _next_gap()


func _tick_accents(delta: float, gain_db: float, muted: bool) -> void:
	if _gen_accents.is_empty():
		return
	_accent_left -= delta
	if _accent_left > 0.0:
		return
	_accent_left = _next_gap()
	if muted:
		return
	_accent.stream = _gen_accents[_rng.randi_range(0, _gen_accents.size() - 1)]
	_accent.pitch_scale = 1.0 + _rng.randf_range(-accent_pitch_jitter, accent_pitch_jitter)
	_accent.volume_db = accent_db + gain_db + _rng.randf_range(-3.0, 0.0)
	_accent.play()


func _next_gap() -> float:
	var gap: Vector2 = AmbientBank.accent_gap(key())
	if gap.y <= 0.0:
		return INF
	return _rng.randf_range(gap.x, gap.y)
