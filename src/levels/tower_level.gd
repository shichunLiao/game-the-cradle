class_name TowerLevel
extends Node2D
## Root script for a tower. Shows the entry line on arrival and hands the exit
## line to `TowerExit`.
##
## The two lines are `@export`ed rather than kept in a config resource because
## they are CONTENT, copied byte-for-byte from `叙事脚本.md` — a level's own text,
## not a tunable value.
##
## Usage (in a scene):
##     [node name="Tower1" type="Node2D"]
##     script = res://src/levels/tower_level.gd
##     entry_line = "「千万别往亮的地方走。」"

## Shown shortly after the level opens. From 叙事脚本.md, verbatim.
@export_multiline var entry_line: String = ""
## Shown when Ryn reaches the TowerExit. From 叙事脚本.md, verbatim.
@export_multiline var exit_line: String = ""
## Loaded after the exit line. Empty = last level, stay put.
@export_file("*.tscn") var next_scene: String = ""
@export var subtitle: TowerSubtitle
## 一进这关身上就有扣件吗。序章和塔1 是 false:塔1 四楼捡到第一颗扣件才学会丢(`RynThrow`)。
@export var throw_unlocked: bool = true


func _ready() -> void:
	if subtitle != null and not entry_line.is_empty():
		subtitle.show_line.call_deferred(entry_line)
		Audio.play.call_deferred(&"subtitle", -16.0)


## Called by `TowerExit`: shows the exit line, then loads `next_scene`.
func leave() -> void:
	if subtitle != null and not exit_line.is_empty():
		subtitle.show_line(exit_line)
	if next_scene.is_empty():
		return
	var delay: float = 2.2
	if subtitle != null and subtitle.config != null:
		delay = subtitle.config.exit_hold_before_load
	Progress.mark_cleared(scene_file_path)
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	# 走转场淡出,而不是硬切 —— 硬切读作"卡了一下"
	var trans := get_node_or_null(^"SceneTransition") as SceneTransition
	if trans != null:
		trans.go_to(next_scene)
	else:
		get_tree().change_scene_to_file(next_scene)
