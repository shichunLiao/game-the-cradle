class_name SceneTransition
extends CanvasLayer
## 关卡间的淡入淡出。之前是硬切,一瞬间换场,读作"卡了一下"而不是"换场了"。
##
## 自己淡入(场景刚打开)。切场时调 `go_to()`,它淡出后再换。

const TRANS_LAYER: int = 110

@export var fade_in_time: float = 0.6
@export var fade_out_time: float = 0.5
@export var color: Color = Color("0B1220")

var _veil: ColorRect


func _ready() -> void:
	layer = TRANS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = color
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	_fade(1.0, 0.0, fade_in_time)


## 淡出后切场。
##
## Usage: `transition.go_to("res://src/levels/tower_2_refinery.tscn")`
func go_to(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	await _fade(0.0, 1.0, fade_out_time)
	if is_inside_tree():
		get_tree().change_scene_to_file(scene_path)


func _fade(from: float, to: float, dur: float) -> void:
	var t: float = 0.0
	var d: float = maxf(dur, 0.0001)
	_veil.color.a = from
	while t < d:
		t += get_process_delta_time()
		_veil.color.a = lerpf(from, to, clampf(t / d, 0.0, 1.0))
		await get_tree().process_frame
	_veil.color.a = to
