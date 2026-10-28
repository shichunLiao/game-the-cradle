class_name GuardFallLine
extends Node
## 拆掉地板盖板、让守卫掉下去之后,Ryn 低声说一句。只说一次。
##
## 叙事脚本.md 塔 2 关键事件:「拆地板 → 守卫跌落(或改道)。Ryn 可低声:『对不起。——不,不同情。』」
## 只在**真的有守卫掉下去**时说 —— 拆了一块没人站的盖板不说。
##
## 不需要手连:开场时找同一关里所有 `FLOOR_HATCH` 盖板,听它们的 `panel_dismantled`;
## 拆完后过 `check_delay` 秒,看有没有守卫比拆之前低了 `fall_px` 以上。
##
## Usage (in a scene): 放在关卡根节点下,设 `text`,`subtitle` 指向关卡的 `TowerSubtitle`。
## 关卡由 `tools/level_builder` 生成时用 `lv.fall_line(...)` 放。

## 这一句。
@export_multiline var text: String = ""
@export var subtitle: TowerSubtitle
## 拆完多久后检查,秒(守卫掉一层楼约 0.5 秒)。
@export var check_delay: float = 0.9
## 守卫比拆之前低了多少 px 才算「掉下去了」。
@export var fall_px: float = 24.0

var _done: bool = false


func _ready() -> void:
	_connect_panels.call_deferred()


## 说过了吗。
func is_done() -> bool:
	return _done


func _connect_panels() -> void:
	for n in get_tree().get_nodes_in_group(Dismantlable.GROUP):
		var panel := n as Dismantlable
		if panel == null or panel.kind != Dismantlable.Kind.FLOOR_HATCH:
			continue
		if not _in_this_level(panel):
			continue
		panel.panel_dismantled.connect(_on_panel_dismantled.bind(panel))


func _in_this_level(panel: Node) -> bool:
	var root: Node = get_parent()
	return root != null and root.is_ancestor_of(panel)


func _on_panel_dismantled(_noticed: int, _panel: Dismantlable) -> void:
	if _done or text.is_empty():
		return
	var before: Dictionary = {}
	for g in _guards():
		before[g] = g.global_position.y
	await get_tree().create_timer(check_delay).timeout
	if _done or not is_inside_tree():
		return
	for g in before:
		if is_instance_valid(g) and (g as Node2D).global_position.y - float(before[g]) >= fall_px:
			_done = true
			StoryTrigger.say(subtitle, text)
			return


func _guards() -> Array[Node2D]:
	var out: Array[Node2D] = []
	var root: Node = get_parent()
	if root == null:
		return out
	for c in root.get_children():
		if c is Guard:
			out.append(c as Node2D)
	return out
