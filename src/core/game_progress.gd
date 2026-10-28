extends Node
## 全局进度(autoload: `Progress`)。只记「打到哪一关」,不是存档系统。
##
## `design/game-brief.md` 的 Out of scope 里没有存档系统 —— 所以这里刻意做到最薄:
## 一个场景路径。没有中途存档、没有多档位、没有物品状态。
##
## 它要解决的是选关界面全开、毫无推进感的问题,仅此而已。
##
## 2026-10-12:原来存的是「解锁到第几关」的整数。关卡顺序中间插了关(屋顶、三段塔外),
## 整数就错位了 —— 原本解锁的最后几关变成锁着。现在存「解锁到哪个场景」,插关不影响。
## 旧存档的整数按插关之前那一版的顺序(`LEGACY_ORDER`)换算成场景。

const SAVE_PATH: String = "user://progress.cfg"

## 存整数那一版的最后一个关卡顺序(2026-10-12 加三段塔外之前)。只用来换算旧存档。
const LEGACY_ORDER: Array[String] = [
	"res://src/levels/prologue_slum.tscn",
	"res://src/levels/slum_rooftops.tscn",
	"res://src/levels/tower_1_birthplace.tscn",
	"res://src/levels/tower_2_refinery.tscn",
	"res://src/levels/tower_3_registry.tscn",
	"res://src/levels/tower_4_military.tscn",
	"res://src/levels/pit_descent.tscn",
	"res://src/levels/pit_bottom.tscn",
]

## 已经解锁到的那一关(场景路径)。空 = 只有第一关。
var unlocked_scene: String = ""


func _ready() -> void:
	load_progress()


## 解锁到 `LevelSequence.ORDER` 的第几个(索引)。
func unlocked_index() -> int:
	return maxi(LevelSequence.ORDER.find(unlocked_scene), 0)


## 通关某一关后调用。只增不减。
func mark_cleared(scene_path: String) -> void:
	var i: int = LevelSequence.ORDER.find(scene_path)
	if i < 0:
		return
	var next: int = mini(i + 1, LevelSequence.ORDER.size() - 1)
	if next > unlocked_index():
		unlocked_scene = LevelSequence.ORDER[next]
		save_progress()


func is_unlocked(index: int) -> bool:
	return index <= unlocked_index()


## 清空进度(设置里的「重新开始」)。
func reset() -> void:
	unlocked_scene = ""
	save_progress()


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked_scene", unlocked_scene)
	cfg.save(SAVE_PATH)


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if cfg.has_section_key("progress", "unlocked_scene"):
		unlocked_scene = str(cfg.get_value("progress", "unlocked_scene", ""))
		return
	# 旧存档:整数,按 LEGACY_ORDER 换算
	if cfg.has_section_key("progress", "unlocked"):
		var n: int = int(cfg.get_value("progress", "unlocked", 0))
		unlocked_scene = LEGACY_ORDER[clampi(n, 0, LEGACY_ORDER.size() - 1)]
		save_progress()
