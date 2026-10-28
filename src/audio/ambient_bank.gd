class_name AmbientBank
extends RefCounted
## 程序生成的环境声:每个地方一条无缝循环的底噪(bed),加几种偶尔响一下的点缀(accent)。
## 不依赖音频素材;和 `SfxBank` 一样,换真素材时只换这里返回的 `AudioStream`。
##
## 叙事脚本.md 的入塔描述就是这里的依据:
##  - 塔2「管道震动」→ 低频隆隆 + 慢慢起伏,偶尔一声管子敲击
##  - 塔3「灯管嗡鸣」→ 120Hz 嗡声带泛音,偶尔一下灯管跳闪的「咔」
##  - 塔4「探照灯扫过」+ 塔顶的风 → 风(一阵一阵)+ 远处探照灯马达,偶尔一声金属吱呀
##  - 下行「风从下方上来」→ 更低更重的风,偶尔滴水
##  - 坑底「大陆睡着,呼吸变慢」→ 很低的拍频嗡声,底下一口一口的呼吸
##  - 贫民窟屋顶(塔外)→ 一阵一阵的风 + 远处城市的低鸣,偶尔很远的一声金属碰撞
##
## ## 无缝循环
## 正弦、调幅都取「循环长度内整数个周期」的频率;噪声类多生成一段、把尾巴交叉淡入开头。
## 生成一次就缓存(静态字典),重进关卡不再算。
##
## Usage:
##     var loop: AudioStreamWAV = AmbientBank.bed(&"tower_2")
##     var knocks: Array[AudioStreamWAV] = AmbientBank.accents(&"tower_2")

## 每种地方:循环秒数、采样率、点缀间隔(秒,最短/最长)。低频为主的用 11025Hz,省一半计算。
const PROFILES: Dictionary = {
	&"prologue": {"seconds": 8.0, "rate": 11025, "accent_gap": Vector2(7.0, 14.0)},
	&"tower_1": {"seconds": 6.0, "rate": 22050, "accent_gap": Vector2(8.0, 16.0)},
	&"tower_2": {"seconds": 10.0, "rate": 11025, "accent_gap": Vector2(3.0, 8.0)},
	&"tower_3": {"seconds": 4.0, "rate": 22050, "accent_gap": Vector2(5.0, 11.0)},
	&"tower_4": {"seconds": 12.0, "rate": 11025, "accent_gap": Vector2(6.0, 12.0)},
	&"descent": {"seconds": 12.0, "rate": 11025, "accent_gap": Vector2(2.5, 6.0)},
	&"pit_bottom": {"seconds": 10.0, "rate": 11025, "accent_gap": Vector2(0.0, 0.0)},
	&"rooftops": {"seconds": 12.0, "rate": 11025, "accent_gap": Vector2(6.0, 13.0)},
}
const ACCENT_RATE: int = 22050

static var _beds: Dictionary = {}
static var _accents: Dictionary = {}


## 这个地方的循环底噪。未知名字返回 null。
static func bed(profile: StringName) -> AudioStreamWAV:
	if not PROFILES.has(profile):
		return null
	if not _beds.has(profile):
		_beds[profile] = _build_bed(profile)
	return _beds[profile]


## 这个地方的点缀音(几种变体)。没有点缀的地方返回空数组。
static func accents(profile: StringName) -> Array[AudioStreamWAV]:
	if not _accents.has(profile):
		_accents[profile] = _build_accents(profile)
	return _accents[profile]


## 点缀的间隔范围(秒)。x = 最短,y = 最长;(0, 0) = 没有点缀。
static func accent_gap(profile: StringName) -> Vector2:
	if not PROFILES.has(profile):
		return Vector2.ZERO
	return PROFILES[profile]["accent_gap"]


# ---------------------------------------------------------------- 底噪

static func _build_bed(profile: StringName) -> AudioStreamWAV:
	var spec: Dictionary = PROFILES[profile]
	var rate: int = spec["rate"]
	var n: int = int(float(spec["seconds"]) * rate)
	var fade: int = rate / 2                              # 噪声交叉淡化半秒
	var x := PackedFloat32Array()
	x.resize(n)
	match profile:
		&"prologue":
			# 屋里的底噪:很闷的褐噪 + 远处电线的 50Hz
			var room := _loopify(_lowpass(_brown(n + fade, 11), 300.0, rate), n, fade)
			_add(x, _normalized(room, 0.5))
			_add_sine(x, 50.0, 0.06, rate)
			_add_sine(x, 100.0, 0.03, rate)
			# 炉火(2026-10-13 精装修):很低的火声 + 稀疏的噼啪 —— 「有来源的小声音」(Project Horseshoe 温馨报告)
			var fire := _loopify(_lowpass(_brown(n + fade, 31), 180.0, rate), n, fade)
			_add(x, _normalized(fire, 0.12))
			_add_crackles(x, rate, 33, 4.0, 0.20)
		&"tower_1":
			# 灯:100Hz 电流声和几道泛音 + 一点空气
			_add_sine(x, 100.0, 0.10, rate)
			_add_sine(x, 200.0, 0.05, rate)
			_add_sine(x, 300.0, 0.025, rate)
			var air := _loopify(_highpass(_lowpass(_white(n + fade, 12), 2200.0, rate), 200.0, rate), n, fade)
			_add(x, _normalized(air, 0.10))
		&"tower_2":
			# 管道震动:低频隆隆,每 10 秒 3 次起伏;43Hz 的管壁共振
			var rumble := _loopify(_lowpass(_brown(n + fade, 21), 120.0, rate), n, fade)
			rumble = _normalized(rumble, 0.85)
			for i in n:
				var t: float = float(i) / rate
				rumble[i] *= 0.65 + 0.35 * sin(TAU * 0.3 * t)
			_add(x, rumble)
			_add_sine(x, 43.0, 0.14, rate)
			_add_sine(x, 86.0, 0.05, rate)
		&"tower_3":
			# 灯管嗡鸣:120Hz 带泛音,软削波,再加一点高频嘶
			for k in range(1, 9):
				_add_sine(x, 120.0 * k, 0.16 / pow(float(k), 1.2), rate)
			for i in n:
				x[i] = tanh(x[i] * 1.8) * 0.55
			var hiss := _loopify(_highpass(_white(n + fade, 31), 3000.0, rate), n, fade)
			_add(x, _normalized(hiss, 0.03))
		&"tower_4":
			# 风:带通噪声,一阵一阵(12 秒一轮);远处探照灯马达
			var wind := _loopify(_highpass(_lowpass(_white(n + fade, 41), 900.0, rate), 150.0, rate), n, fade)
			wind = _normalized(wind, 0.7)
			for i in n:
				var t: float = float(i) / rate
				wind[i] *= _gust(t, 12.0)
			_add(x, wind)
			var motor := PackedFloat32Array()
			motor.resize(n)
			_add_sine(motor, 70.0, 0.06, rate)
			for i in n:
				motor[i] *= 0.6 + 0.4 * sin(TAU * 2.0 * float(i) / rate / 12.0)
			_add(x, motor)
		&"descent":
			# 从下面上来的风:更低、更重,一阵比一阵猛;38Hz 的坑底低鸣
			var deep := _loopify(_highpass(_lowpass(_white(n + fade, 51), 420.0, rate), 60.0, rate), n, fade)
			deep = _normalized(deep, 0.85)
			for i in n:
				var t: float = float(i) / rate
				deep[i] *= 0.35 + 0.65 * _gust(t, 12.0)
			_add(x, deep)
			_add_sine(x, 38.0, 0.10, rate)
		&"rooftops":
			# 塔外:风比塔顶轻一点,底下垫着整座城的低鸣(褐噪 + 一点 55Hz 的电)
			var wind2 := _loopify(_highpass(_lowpass(_white(n + fade, 71), 700.0, rate), 120.0, rate), n, fade)
			wind2 = _normalized(wind2, 0.55)
			for i in n:
				wind2[i] *= _gust(float(i) / rate, 12.0)
			_add(x, wind2)
			var city := _loopify(_lowpass(_brown(n + fade, 72), 180.0, rate), n, fade)
			_add(x, _normalized(city, 0.4))
			_add_sine(x, 55.0, 0.04, rate)
		&"pit_bottom":
			# 大陆在呼吸:41/43Hz 两个音拍出每秒 2 下的颤;底下一口一口的气(10 秒两口)
			_add_sine(x, 41.0, 0.12, rate)
			_add_sine(x, 43.0, 0.12, rate)
			_add_sine(x, 82.0, 0.04, rate)
			var breath := _loopify(_lowpass(_brown(n + fade, 61), 250.0, rate), n, fade)
			breath = _normalized(breath, 0.75)
			for i in n:
				var t: float = float(i) / rate
				var b: float = 0.5 - 0.5 * cos(TAU * 0.2 * t)
				breath[i] *= 0.15 + 0.85 * b * b
			_add(x, breath)
	return _make(_normalized(x, 0.8), rate, true)


## 一阵一阵的风,在 `period` 秒内循环(三个整数倍频率叠出来,不规则但无缝)。0.1..1。
static func _gust(t: float, period: float) -> float:
	var g: float = 0.5 + 0.28 * sin(TAU * t / period) + 0.16 * sin(TAU * 3.0 * t / period + 1.3) \
			+ 0.08 * sin(TAU * 7.0 * t / period + 2.1)
	return clampf(g, 0.1, 1.0)


# ---------------------------------------------------------------- 点缀

static func _build_accents(profile: StringName) -> Array[AudioStreamWAV]:
	var out: Array[AudioStreamWAV] = []
	match profile:
		&"prologue":
			out.append(_drip(1500.0))
		&"tower_1":
			out.append(_clank(330.0, 0.5, 5))
		&"tower_2":
			out.append(_clank(523.0, 0.7, 1))
			out.append(_clank(392.0, 0.9, 2))
			out.append(_clank(698.0, 0.5, 3))
		&"tower_3":
			out.append(_tick(1))
			out.append(_tick(2))
		&"tower_4":
			out.append(_creak(300.0, 220.0, 0.9))
			out.append(_creak(260.0, 200.0, 1.2))
		&"rooftops":
			out.append(_clank(260.0, 0.6, 7))
			out.append(_creak(240.0, 190.0, 1.0))
		&"descent":
			out.append(_drip(1400.0))
			out.append(_drip(1100.0))
			out.append(_drip(1700.0))
	return out


## 金属敲击:几个不成谐波的正弦一起衰减,开头一下噪声。
static func _clank(base: float, seconds: float, seed_value: int) -> AudioStreamWAV:
	var n: int = int(seconds * ACCENT_RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	var partials: Array[float] = [1.0, 2.27, 3.65, 5.1]
	var gains: Array[float] = [0.5, 0.3, 0.18, 0.1]
	for p in partials.size():
		var f: float = base * partials[p]
		for i in n:
			var t: float = float(i) / ACCENT_RATE
			x[i] += sin(TAU * f * t) * gains[p] * exp(-t * (5.0 + p * 3.0))
	var click := _white(int(0.012 * ACCENT_RATE), seed_value)
	for i in click.size():
		x[i] += click[i] * 0.4 * (1.0 - float(i) / click.size())
	return _make(_normalized(x, 0.7), ACCENT_RATE, false)


## 灯管跳闪:很短的一串噼啪。
static func _tick(seed_value: int) -> AudioStreamWAV:
	var n: int = int(0.09 * ACCENT_RATE)
	var noise := _highpass(_white(n, seed_value), 1500.0, ACCENT_RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t: float = float(i) / n
		# 两下:0 和 0.45 处各一个尖
		var e: float = exp(-t * 40.0) + 0.6 * exp(-maxf(t - 0.45, 0.0) * 50.0) * float(t >= 0.45)
		x[i] = noise[i] * e
	return _make(_normalized(x, 0.6), ACCENT_RATE, false)


## 金属吱呀:音高慢慢往下滑的三角波,头尾淡入淡出。
static func _creak(f0: float, f1: float, seconds: float) -> AudioStreamWAV:
	var n: int = int(seconds * ACCENT_RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / n
		phase = fmod(phase + lerpf(f0, f1, t) * (1.0 + 0.03 * sin(t * 40.0)) / ACCENT_RATE, 1.0)
		var tri: float = 4.0 * absf(phase - 0.5) - 1.0
		x[i] = tri * sin(PI * t) * 0.5
	return _make(_normalized(_lowpass(x, 1200.0, ACCENT_RATE), 0.5), ACCENT_RATE, false)


## 滴水:往下滑的短音,后面跟两次回声。
static func _drip(freq: float) -> AudioStreamWAV:
	var n: int = int(0.7 * ACCENT_RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	var one: int = int(0.07 * ACCENT_RATE)
	var echoes: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(0.18, 0.35), Vector2(0.36, 0.12)]
	for e in echoes:
		var start: int = int(e.x * ACCENT_RATE)
		var phase: float = 0.0
		for i in one:
			if start + i >= n:
				break
			var t: float = float(i) / one
			phase += freq * lerpf(1.0, 0.62, t) / ACCENT_RATE
			x[start + i] += sin(TAU * phase) * exp(-t * 5.0) * e.y
	return _make(_normalized(x, 0.5), ACCENT_RATE, false)


# ---------------------------------------------------------------- 工具

static func _make(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


static func _white(n: int, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = rng.randf_range(-1.0, 1.0)
	return out


## 褐噪声(白噪声积分,带一点泄漏免得漂走)。
static func _brown(n: int, seed_value: int) -> PackedFloat32Array:
	var w := _white(n, seed_value)
	var y: float = 0.0
	for i in n:
		y = y * 0.997 + w[i] * 0.05
		w[i] = y
	return w


## 一阶低通。
static func _lowpass(x: PackedFloat32Array, cutoff: float, rate: int) -> PackedFloat32Array:
	var a: float = exp(-TAU * cutoff / rate)
	var out := PackedFloat32Array()
	out.resize(x.size())
	var y: float = 0.0
	for i in x.size():
		y = (1.0 - a) * x[i] + a * y
		out[i] = y
	return out


## 一阶高通(原信号减去低通)。
static func _highpass(x: PackedFloat32Array, cutoff: float, rate: int) -> PackedFloat32Array:
	var lo := _lowpass(x, cutoff, rate)
	for i in x.size():
		lo[i] = x[i] - lo[i]
	return lo


## 长 n + fade 的信号收成长 n 的无缝循环:尾巴 fade 个采样交叉淡入开头。
static func _loopify(x: PackedFloat32Array, n: int, fade: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = x[i]
	for i in fade:
		var w: float = float(i) / fade
		out[i] = x[i] * w + x[n + i] * (1.0 - w)
	return out


static func _normalized(x: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m: float = 0.0001
	for v in x:
		m = maxf(m, absf(v))
	var k: float = peak / m
	for i in x.size():
		x[i] *= k
	return x


static func _add(into: PackedFloat32Array, x: PackedFloat32Array) -> void:
	for i in mini(into.size(), x.size()):
		into[i] += x[i]


## 柴火的噼啪:每秒约 `per_second` 下,每下 2–12 毫秒的白噪声短促衰减,偶尔一声大一点的「啪」。
## 不跨过循环的接缝(最后 30 毫秒不放)。
static func _add_crackles(into: PackedFloat32Array, rate: int, seed_value: int, per_second: float, amp: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n: int = into.size()
	var count: int = int(per_second * float(n) / rate)
	for c in count:
		var big: bool = rng.randf() < 0.12
		var length: int = int(rate * (rng.randf_range(0.012, 0.022) if big else rng.randf_range(0.002, 0.012)))
		var at: int = rng.randi_range(0, maxi(n - length - int(rate * 0.03), 0))
		var a: float = amp * (1.0 if big else rng.randf_range(0.25, 0.7))
		for i in length:
			var env: float = exp(-6.0 * float(i) / float(length))
			into[at + i] += rng.randf_range(-1.0, 1.0) * a * env


## 加一个正弦(频率要在循环长度里走整数圈,才无缝)。
static func _add_sine(into: PackedFloat32Array, freq: float, amp: float, rate: int) -> void:
	for i in into.size():
		into[i] += sin(TAU * freq * float(i) / rate) * amp
