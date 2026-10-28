class_name TempShade
extends RefCounted
## 一块会开会关的暗区(2026-10-12 谜题房):蒸汽挡住视线、配电箱断电后整片变黑。
##
## 用一个普通的 `ShadowZone`,只是平时不在 `ShadowZone.GROUP` 里 —— `ShadowRegistry` 只认这个组,
## 所以「进组 + 让登记处重新收一遍」就是开,「出组 + 重新收」就是关。守卫的「暗处看不见」、Ryn 的隐身
## 样子、小地图(只画看得见的暗区)全都跟着走,不用另写一套规则。
##
## Usage:
##     var shade := TempShade.new(self, Rect2(640, 400, 256, 96), false)   # false = 不画暗色(蒸汽自己画)
##     shade.set_active(true)

const ZONE_SCENE: PackedScene = preload("res://src/shadow/shadow_zone.tscn")

var zone: ShadowZone
var _host: Node
var _active: bool = false


## `host` 是挂暗区的节点(一般是机关自己);`rect` 是世界坐标;`visible` = 开着时要不要画成暗区的样子。
func _init(host: Node, rect: Rect2, visible: bool) -> void:
	_host = host
	zone = ZONE_SCENE.instantiate() as ShadowZone
	zone.size = rect.size
	zone.top_level = true
	zone.global_position = rect.position
	zone.visible = false
	zone.set_meta(&"shade_visible", visible)
	host.add_child(zone)
	zone.global_position = rect.position
	zone.remove_from_group(ShadowZone.GROUP)   # 平时不算暗区
	_refresh()


## 现在算不算暗区。
func is_active() -> bool:
	return _active


func set_active(on: bool) -> void:
	if on == _active or zone == null:
		return
	_active = on
	if on:
		zone.add_to_group(ShadowZone.GROUP)
	else:
		zone.remove_from_group(ShadowZone.GROUP)
	zone.visible = on and bool(zone.get_meta(&"shade_visible", false))
	_refresh()


func _refresh() -> void:
	if _host == null or not _host.is_inside_tree():
		return
	var level: Node = _host.owner if _host.owner != null else _host.get_parent()
	if level == null:
		return
	var registry := level.get_node_or_null(^"ShadowRegistry") as ShadowRegistry
	if registry != null:
		registry.refresh()
