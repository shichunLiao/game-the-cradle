class_name LevelSequence
extends RefCounted
## The 序章 → 屋顶 → 四塔(塔与塔之间各一段塔外)→ 下行 → 坑底 running order
## (设定摘要.md;下行关 2026-10-11、屋顶和三段塔外 2026-10-12 加)。
##
## A plain ordered list, not a save system — `design/game-brief.md` 的 Out of scope
## 里没有存档。进度只由 `Progress` 记一个整数。
##
## Usage:
##     LevelSequence.next_after("res://src/levels/tower_1_birthplace.tscn")

const ORDER: Array[String] = [
	"res://src/levels/prologue_slum.tscn",
	"res://src/levels/slum_rooftops.tscn",
	"res://src/levels/tower_1_birthplace.tscn",
	"res://src/levels/pipeline_bridge.tscn",
	"res://src/levels/tower_2_refinery.tscn",
	"res://src/levels/sky_bridge.tscn",
	"res://src/levels/tower_3_registry.tscn",
	"res://src/levels/scaffold_descent.tscn",
	"res://src/levels/tower_4_military.tscn",
	"res://src/levels/pit_descent.tscn",
	"res://src/levels/pit_bottom.tscn",
]

const TITLES: Array[String] = [
	"序章 · 贫民窟",
	"贫民窟 · 屋顶",
	"塔 1 · 出生地高塔",
	"塔外 · 输油管桥",
	"塔 2 · 能源精炼塔",
	"塔外 · 高空栈桥",
	"塔 3 · 人口登记塔",
	"塔外 · 外墙脚手架",
	"塔 4 · 军事防御塔",
	"坑口 · 下行",
	"中央 + 坑底",
]


## The scene after `path`, or "" when `path` is the last one or unknown.
static func next_after(path: String) -> String:
	var i: int = ORDER.find(path)
	if i < 0 or i + 1 >= ORDER.size():
		return ""
	return ORDER[i + 1]
