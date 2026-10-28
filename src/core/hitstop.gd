extends Node
## 顿帧(autoload: `Hitstop`)。关键瞬间把时间几乎停住几帧,再放开。
##
## 这是动作游戏给"冲击力"的标准手法,成本极低。之前被发现时是直接滑入边缘收束,
## 温吞;停两三帧再开始收束,那一下才有分量。
##
## 用 `Engine.time_scale` 而不是 `get_tree().paused`:暂停菜单占用了 paused,
## 而且顿帧要的是"几乎停"而不是"完全停" —— 完全停会让音效也卡住。
##
## 自己 `PROCESS_MODE_ALWAYS` 并用真实时间计时,否则时间被自己减慢后永远恢复不了。
##
## Usage: `Hitstop.hit(0.06)`

## 顿帧期间的时间流速。不设 0 —— 音效与渲染仍要推进。
const FROZEN_SCALE: float = 0.04

var _left_ms: int = 0
var _last_ms: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


## 停 `seconds` 的真实时间。重复调用取较长的那个,不累加。
func hit(seconds: float) -> void:
	var ms: int = int(maxf(seconds, 0.0) * 1000.0)
	if ms <= 0:
		return
	_left_ms = maxi(_left_ms, ms)
	_last_ms = Time.get_ticks_msec()
	Engine.time_scale = FROZEN_SCALE
	set_process(true)


func _process(_delta: float) -> void:
	# 用真实时钟计时:delta 已经被 time_scale 压扁了,拿它计时会停很久。
	var now: int = Time.get_ticks_msec()
	_left_ms -= now - _last_ms
	_last_ms = now
	if _left_ms <= 0:
		_left_ms = 0
		Engine.time_scale = 1.0
		set_process(false)
