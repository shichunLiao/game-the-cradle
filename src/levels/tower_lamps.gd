class_name TowerLamps
extends Node2D
## 塔里亮着的灯的光晕(2026-10-13 精装修,`docs/polish-research.md` §3.3)。灯具本身由 `TowerDecor` 画
## (亮的种类带「:on」);这里每盏灯放一个 `LampGlow`。
##
## 亮不亮、接在哪个配电箱,都由 `tools/level_builder/decor.py` 的 `lamps()` 算好:光圈碰到暗区的灯是坏的,
## 不会出现在这里 —— 「画面上的光 = 玩法上的光」。接在配电箱上的灯,配电箱断电(`FuseBox.is_off()`)时一起灭。
##
## 只用冷光(用户 2026-10-13 定;美术规格 §2):`cyan` 冷青、`white` 惨白,`rust` 只给警示 / 应急灯。
##
## Usage (in a scene): 由 `tools/level_builder/build.py` 生成,数组一一对应。

const COLORS: Dictionary = {
	"cyan": Color("7FA6C2"),
	"white": Color("C8D4E0"),
	"rust": Color("B04A3A"),
}
## 中心亮度。第一版 0.13–0.20 在暗砖墙上几乎看不见(2026-10-13 截图),调到看得出一圈光、又不抢守卫视野锥的程度。
const ENERGY: Dictionary = {"cyan": 0.30, "white": 0.30, "rust": 0.36}
## 衰减比旧屋的烛光平缓:灯管、灯泡的光散得开。
const FALLOFF: float = 1.5
const FLICKERS: Dictionary = {
	"steady": LampGlow.Flicker.STEADY,
	"fluorescent": LampGlow.Flicker.FLUORESCENT,
	"emergency": LampGlow.Flicker.EMERGENCY,
	"candle": LampGlow.Flicker.CANDLE,
	"ember": LampGlow.Flicker.EMBER,
}

## 每盏灯的光心,世界像素。
@export var points: PackedVector2Array = PackedVector2Array()
@export var radii: PackedFloat32Array = PackedFloat32Array()
## `COLORS` 的键。
@export var colors: PackedStringArray = PackedStringArray()
## `FLICKERS` 的键。
@export var flickers: PackedStringArray = PackedStringArray()
@export var squashes: PackedFloat32Array = PackedFloat32Array()
## 接在哪个配电箱(关卡根下的节点名);空 = 不接。
@export var fuses: PackedStringArray = PackedStringArray()

var _glows: Array[LampGlow] = []
var _fuse_nodes: Dictionary = {}      # 名字 → FuseBox
var _was_off: Dictionary = {}


func _ready() -> void:
	var level: Node = owner if owner != null else get_parent()
	for i in points.size():
		var g := LampGlow.new()
		var key: String = colors[i] if i < colors.size() else "cyan"
		g.color = COLORS.get(key, COLORS["cyan"])
		g.energy = ENERGY.get(key, 0.13)
		g.radius = radii[i] if i < radii.size() else 40.0
		g.squash = squashes[i] if i < squashes.size() else 1.0
		g.steps = 6
		g.falloff = FALLOFF
		g.flicker = FLICKERS.get(flickers[i] if i < flickers.size() else "steady", LampGlow.Flicker.STEADY)
		g.position = points[i] - global_position
		# 画在背景墙和道具之上(-100 / -50)、实心块和角色之下(1 / 0)
		g.z_as_relative = false
		g.z_index = -40
		add_child(g)
		_glows.append(g)
		var fname: String = fuses[i] if i < fuses.size() else ""
		if not fname.is_empty() and level != null and not _fuse_nodes.has(fname):
			var f := level.get_node_or_null(NodePath(fname))
			if f != null:
				_fuse_nodes[fname] = f
	set_process(not _fuse_nodes.is_empty())


## 灯数(检查脚本用)。
func count() -> int:
	return _glows.size()


## 第 `i` 盏灯现在亮着吗(检查脚本用)。
func is_lit(i: int) -> bool:
	return i < _glows.size() and _glows[i].powered


func _process(_delta: float) -> void:
	for fname in _fuse_nodes:
		var off: bool = bool(_fuse_nodes[fname].call(&"is_off"))
		if _was_off.get(fname, false) == off:
			continue
		_was_off[fname] = off
		for i in _glows.size():
			if i < fuses.size() and fuses[i] == fname:
				_glows[i].set_powered(not off)
