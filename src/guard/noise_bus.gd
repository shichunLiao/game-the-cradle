extends Node
## 噪音总线(autoload: `Noise`)。听觉系统的中枢。
##
## ## 这一项曾被明确排除
##
## 听觉系统原在 `里程碑排期.md` 的「明确砍掉(全程禁止加回)」清单内。作者于
## 2026-10-04 要求实装,并随后删除了整节清单 —— 所以项目现在没有那份硬性禁止列表,
## 范围以 `design/game-brief.md` 的 Out of scope 与 `美术规格.md` 的「不做」为准。
##
## ## 设计:噪音是位置 + 半径,不是音量曲线
##
## 守卫只问一件事:「这个声音离我多近」。不做衰减模型、不做遮挡 —— 墙不挡声。
## 理由是可读性:玩家必须能预测自己发出了多大动静,一个带遮挡的声学模型在
## 640x360 的灰盒里无法被看懂。
##
## 蹲行 **不发出噪音**,这是蹲姿除了压低轮廓之外的第二个价值。
##
## ## 看得见的噪音(2026-10-10)
##
## 每次噪音都由 `NoiseRings` 画成一圈扩散的环(Mark of the Ninja),环的半径就是
## 守卫能听到的距离。环挂在本节点下、画在世界坐标里,所以每一关都自动有。
##
## Usage:
##     Noise.emit_noise(global_position, 140.0)

## 任何守卫都可以连它。`radius` 是能听到的最大距离。
signal noise_made(position: Vector2, radius: float)

## 常用音量档,px。
const QUIET: float = 70.0      ## 普通走路
const NORMAL: float = 130.0    ## 落地
const LOUD: float = 220.0      ## 拆解、金属掉落


## autoload 先于全局类缓存加载,这里直接 preload,不依赖 `class_name NoiseRings` 已被扫描。
const NoiseRingsScript: Script = preload("res://src/ui/noise_rings.gd")

## 与全屏、音量共用的设置文件。
const SETTINGS_PATH: String = "user://settings.cfg"

## 画噪音环的节点。用 `set_rings_visible(false)` 关掉画面(规则不变,守卫照样听得见)。
var rings: Node2D


func _ready() -> void:
	rings = NoiseRingsScript.new()
	rings.name = "NoiseRings"
	add_child(rings)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		rings.enabled = bool(cfg.get_value("readability", "noise_rings", true))
	# 换场景时把还没淡完的环清掉,免得画到新关卡里
	get_tree().tree_changed.connect(_on_tree_changed)


## 噪音环是否显示。
func rings_visible() -> bool:
	return rings != null and rings.enabled


## 打开/关闭噪音环的画面,并记到设置文件。只影响画面,不影响守卫的听觉。
##
## Usage: `Noise.set_rings_visible(false)`
func set_rings_visible(value: bool) -> void:
	if rings == null:
		return
	rings.enabled = value
	if not value:
		rings.clear()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # 与全屏、音量共用一个文件,先读再写
	cfg.set_value("readability", "noise_rings", value)
	cfg.save(SETTINGS_PATH)


## 发出一次噪音。半径 <= 0 直接忽略(蹲行走的就是这条)。
func emit_noise(at: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	noise_made.emit(at, radius)
	if rings != null:
		rings.add_ring(at, radius)


var _scene: Node


func _on_tree_changed() -> void:
	if not is_inside_tree():
		return
	var current: Node = get_tree().current_scene
	if current != _scene:
		_scene = current
		if rings != null:
			rings.clear()
