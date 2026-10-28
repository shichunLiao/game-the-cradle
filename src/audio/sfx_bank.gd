class_name SfxBank
extends RefCounted
## 程序生成的占位音效。不依赖任何音频素材文件。
##
## 排期 W8:「音效:脚步、发现、拆件、字幕 blip」。这是灰盒阶段的占位实现 ——
## 方波与噪声合成,W7/W8 换成真素材时只需替换 `AudioStream`,调用方不用改。
##
## ## 这不是「听觉系统」
##
## 这里只生成 **玩家听到的反馈音**。守卫的听觉是另一套东西(`src/guard/noise_bus.gd`),
## 两者没有耦合:这个库发不出任何会被守卫察觉的东西。
##
## Usage:
##     var s: AudioStreamWAV = SfxBank.footstep()

const RATE: int = 22050


static func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	stream.data = bytes
	return stream


## 指数衰减包络。
static func _env(i: int, n: int, power: float = 3.0) -> float:
	var t: float = float(i) / float(maxi(n, 1))
	return pow(1.0 - t, power)


## 方波。`sweep` < 1 时音高下滑, > 1 时上滑。
static func _tone(freq: float, ms: int, sweep: float = 1.0, power: float = 3.0, duty: float = 0.5) -> PackedFloat32Array:
	var n: int = int(RATE * ms / 1000.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / float(maxi(n, 1))
		var f: float = freq * lerpf(1.0, sweep, t)
		phase += f / float(RATE)
		phase = fmod(phase, 1.0)
		out[i] = (1.0 if phase < duty else -1.0) * _env(i, n, power)
	return out


## 白噪声。
static func _noise(ms: int, power: float = 3.0, seed_value: int = 1) -> PackedFloat32Array:
	var n: int = int(RATE * ms / 1000.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = rng.randf_range(-1.0, 1.0) * _env(i, n, power)
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array, gain_a: float = 1.0, gain_b: float = 1.0) -> PackedFloat32Array:
	var n: int = maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var va: float = a[i] * gain_a if i < a.size() else 0.0
		var vb: float = b[i] * gain_b if i < b.size() else 0.0
		out[i] = clampf(va + vb, -1.0, 1.0)
	return out


## 脚步:极短的低频噪声扑。
static func footstep(variant: int = 1) -> AudioStreamWAV:
	return _make(_mix(_noise(55, 5.0, variant), _tone(90.0, 55, 0.7, 5.0), 0.35, 0.3))

## 起跳:短促上滑。
static func jump() -> AudioStreamWAV:
	return _make(_tone(240.0, 110, 1.9, 2.5, 0.35))

## 落地:闷响。
static func land() -> AudioStreamWAV:
	return _make(_mix(_noise(70, 6.0, 7), _tone(120.0, 70, 0.55, 4.0), 0.3, 0.45))

## 被发现:下滑警报 + 噪声刺。整场最刺耳的一个音。
static func spotted() -> AudioStreamWAV:
	return _make(_mix(_tone(520.0, 420, 0.42, 1.2, 0.5), _noise(150, 2.5, 3), 0.55, 0.22))

## 守卫起疑:一声短促上扬的问句音。
static func suspicious() -> AudioStreamWAV:
	return _make(_tone(300.0, 130, 1.45, 2.2, 0.4))

## 拆解的每一步:咔哒。「拧三下,再撬」。
static func dismantle_step(step: int = 0) -> AudioStreamWAV:
	return _make(_mix(_noise(34, 8.0, 11 + step), _tone(160.0 + 40.0 * step, 34, 1.1, 6.0), 0.4, 0.3))

## 拆解完成:掉落感的低音。
static func dismantle_done() -> AudioStreamWAV:
	return _make(_mix(_noise(220, 3.0, 23), _tone(150.0, 220, 0.45, 2.0), 0.35, 0.4))

## 字幕逐句的 blip。
static func subtitle_blip() -> AudioStreamWAV:
	return _make(_tone(660.0, 42, 1.0, 5.0, 0.25))

## 重生:柔和上升,不刺激 —— 失败不该被惩罚得难听。
static func respawn() -> AudioStreamWAV:
	return _make(_tone(180.0, 340, 1.8, 2.0, 0.5))

## 检查点激活(2026-10-13 细致化,backlog H2):存档点是「小小的安全角落」—— 走过时碰到空罐子,
## 罐子滚了一下(三声高低不一的「叮当」),毯子窸窣一声。原来是一声 440Hz 的「哔」,像菜单音。
static func checkpoint() -> AudioStreamWAV:
	var out := _noise(300, 1.2, 53)
	for i in out.size():
		out[i] *= 0.10
	for hit in [[0, 1320.0, 0.30], [80, 1630.0, 0.22], [170, 1180.0, 0.16]]:
		var ring := _mix(_tone(hit[1], 110, 0.97, 4.0, 0.25), _tone(hit[1] * 1.5, 70, 1.0, 5.0, 0.2), 1.0, 0.5)
		var at: int = int(RATE * float(hit[0]) / 1000.0)
		for i in ring.size():
			if at + i < out.size():
				out[at + i] = clampf(out[at + i] + ring[i] * hit[2], -1.0, 1.0)
	return _make(out)


## 进了暗处(守卫看不见了)那一下(2026-10-13 细致化,backlog H1):很轻的一口气 —— 低沉的气声 + 一点低频。
## Thief 的光宝石也有声音:画面之外再给一条「藏住了」的线索。
static func shade_in() -> AudioStreamWAV:
	var breath := _noise(220, 1.4, 77)
	var swell := PackedFloat32Array()
	swell.resize(breath.size())
	for i in breath.size():
		var t: float = float(i) / float(breath.size())
		swell[i] = breath[i] * sin(t * PI)          # 先起后落,不是一下子冲出来
	return _make(_mix(swell, _tone(150.0, 220, 0.8, 2.0, 0.5), 0.16, 0.05))

## 菜单确认。
static func ui_confirm() -> AudioStreamWAV:
	return _make(_tone(520.0, 90, 1.3, 4.0, 0.3))


## 丢扣件出手:很轻的一声风。出手本身不该吵 —— 吵的是落地。
static func bolt_throw() -> AudioStreamWAV:
	return _make(_mix(_noise(90, 1.5, 31), _tone(700.0, 90, 0.5, 3.0, 0.15), 0.18, 0.08))


## 扣件落地:金属「叮」。这一声就是守卫听到的那一声。
static func bolt_clink() -> AudioStreamWAV:
	var ring := _mix(_tone(1760.0, 160, 0.97, 3.5, 0.3), _tone(2640.0, 100, 1.0, 4.0, 0.2), 0.35, 0.22)
	return _make(_mix(ring, _noise(16, 6.0, 41), 1.0, 0.3))


## 扣件撞墙:短促的「嗒」,不传给守卫。
static func bolt_tick() -> AudioStreamWAV:
	return _make(_tone(1200.0, 30, 1.0, 6.0, 0.3))


## 广播前的提示音:「叮——咚」两声,混一点旧喇叭的沙沙声(塔2 的调配广播,2026-10-12)。
static func pa_chime() -> AudioStreamWAV:
	var ding := _mix(_tone(880.0, 320, 1.0, 2.2, 0.5), _tone(1760.0, 200, 1.0, 4.0, 0.5), 0.5, 0.12)
	var dong := _mix(_tone(660.0, 520, 1.0, 1.8, 0.5), _tone(1320.0, 260, 1.0, 4.0, 0.5), 0.5, 0.1)
	var out := PackedFloat32Array()
	out.append_array(ding)
	out.append_array(dong)
	return _make(_mix(out, _noise(out.size() * 1000 / RATE, 0.6, 53), 1.0, 0.05))


## 谜题房(2026-10-12):蒸汽喷出的嘶声 —— 一段慢慢收的噪声。
static func steam_hiss() -> AudioStreamWAV:
	return _make(_mix(_noise(1100, 1.2, 61), _noise(300, 4.0, 62), 0.35, 0.25))


## 断电:往下滑的嗡声。
static func power_down() -> AudioStreamWAV:
	return _make(_mix(_tone(240.0, 600, 0.35, 1.6, 0.5), _noise(120, 5.0, 63), 0.4, 0.3))


## 来电:往上爬的嗡声。
static func power_up() -> AudioStreamWAV:
	return _make(_tone(150.0, 450, 2.2, 1.2, 0.5))


## 铁卷门卷上去:哗啦啦的铁片声。
static func shutter_roll() -> AudioStreamWAV:
	var rattle := PackedFloat32Array()
	for i in 9:
		rattle.append_array(_mix(_noise(70, 3.0, 70 + i), _tone(90.0 + i * 6.0, 70, 1.0, 3.0, 0.3), 0.5, 0.3))
	return _make(rattle)


## 吊桥砸下来:很重的一声。
static func bridge_crash() -> AudioStreamWAV:
	return _make(_mix(_noise(420, 4.0, 81), _tone(70.0, 420, 0.5, 2.0, 0.5), 0.6, 0.6))
