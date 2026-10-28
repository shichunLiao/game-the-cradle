class_name EndingSequence
extends Node
## 坑底 终局: 认不出 → 照片静帧 → 唤醒 → 切断 → 大陆睡着 → 旧屋.
##
## Linear and written with `await`, because it IS linear — unlike the fail loop,
## which can start at any moment and needed a state machine. The player's only
## two inputs are raising the photo and cutting the node.
##
## 叙事脚本.md structure (终局 B/C/D):
##   B 核心·Vera  — Vera 认不出, 几乎下手. The VeraSweep from Story 006 is that.
##   C 照片       — 静帧. 吊坠微光. Vera 瞳孔聚焦.
##   D 切断       — 手巧演出, reusing Story 005's Dismantlable.
## Then 结局·旧屋门口, which is a separate scene.
##
## No combat anywhere: Vera is never fought, only survived and then reached.

signal ending_finished
## The node is cut and the Ark stops — the moment 大陆「睡着」. Emitted once, at
## the start of the sleep fade. The pit's `AmbientBed.fall_asleep` listens.
signal ark_stopped

@export var config: EndingConfig
@export var subtitle: TowerSubtitle
@export var ryn: Ryn
@export var sweep: VeraSweep
@export var photo: PhotoTrigger
@export var cut_node: Dismantlable
@export var pendant: CanvasItem
## 举起合影时的全屏静帧。与序章共用同一个节点类型。
@export var photo_display: PhotoDisplay
@export_file("*.tscn") var ending_scene: String = ""

var _overlay: ColorRect
var _started: bool = false
## 演出途中离开场景树(关游戏、换场景)。每个 await 之后都看一眼,是就直接收工。
var _dying: bool = false


func _ready() -> void:
	if pendant != null:
		pendant.visible = false
	if cut_node != null:
		# 叙事 order: the node can only be cut AFTER Vera is woken.
		cut_node.visible = false
		cut_node.process_mode = Node.PROCESS_MODE_DISABLED
	if photo != null:
		photo.photo_raised.connect(_on_photo_raised)
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_overlay)
	_begin.call_deferred()


## 离开场景树时,把还在等的计时器一个个「敲响」:等着它们的协程醒过来、看到 `_dying` 就返回。
## 不这样做,关游戏时停在半路的协程会以 GDScriptFunctionState 的形式泄漏到退出(2026-10-12)。
func _exit_tree() -> void:
	_dying = true
	for c in get_children():
		var t := c as Timer
		if t != null and not t.is_stopped():
			t.stop()
			t.timeout.emit()


## B. Vera does not recognise her.
func _begin() -> void:
	if _started or config == null:
		return
	_started = true
	_say(config.vera_hostile)
	await _wait(config.line_gap)
	if _dying:
		return
	_say(config.ryn_plead)
	await _wait(config.line_gap)
	if _dying:
		return
	# Only now is the photo offerable — the player must first survive her.
	if photo != null:
		photo.arm()


## C. 照片 — the frame stops and the pendant glows.
func _on_photo_raised() -> void:
	if config == null:
		return
	if sweep != null:
		sweep.process_mode = Node.PROCESS_MODE_DISABLED
		sweep.visible = false
	if ryn != null:
		ryn.input_enabled = false
		ryn.velocity = Vector2.ZERO
		_set_ryn_action(RynSpriteVisual.ACTION_PHOTO)
	# 静帧: dim everything, then the one warm point in the whole game.
	_overlay.color = Color(config.freeze_dim, config.freeze_dim_alpha)
	if pendant != null:
		pendant.visible = true
	await _wait(config.freeze_time)
	if _dying:
		return
	# 叙事脚本 终局 C:「Ryn 举起合影。**静帧。** 吊坠微光。Vera 瞳孔聚焦。」
	# 序章看过一次的那张照片,在这里第二次也是最后一次出现。
	if photo_display != null:
		photo_display.show_photo()
		await _wait_for(photo_display.closed)
		if _dying:
			return
	_say(config.vera_waking)
	await _wait(config.line_gap)
	if _dying:
		return
	_say(config.ryn_found)
	await _wait(config.line_gap)
	if _dying:
		return
	if not config.vera_knew.is_empty():
		_say(config.vera_knew)
		await _wait(config.line_gap)
		if _dying:
			return
	_overlay.color = Color(config.freeze_dim, 0.0)
	if ryn != null:
		_set_ryn_action(RynSpriteVisual.ACTION_NONE)
		ryn.input_enabled = true
	# D. 切断 — reuse Story 005's dismantle interaction, as the story requires.
	if cut_node != null:
		cut_node.visible = true
		cut_node.process_mode = Node.PROCESS_MODE_INHERIT
		cut_node.panel_dismantled.connect(_on_cut, CONNECT_ONE_SHOT)


## The Ark stops. 大陆「睡着」—— 呼吸变慢, 非死亡.
func _on_cut(_alerted: int) -> void:
	if config == null:
		return
	if ryn != null:
		ryn.input_enabled = false
		ryn.velocity = Vector2.ZERO
	_say(config.narration_rest)
	ark_stopped.emit()
	# Slow, even fade. Sleep, not a blackout: no shake, no sting, no flash.
	# 用补间做淡出、用 `_wait` 等它做完 —— 不在循环里等 process_frame(关游戏时那一帧永远不来)
	var dur: float = maxf(config.sleep_fade_time, 0.0001)
	_overlay.color = Color(config.freeze_dim, 0.0)
	create_tween().tween_property(_overlay, ^"color:a", 1.0, dur)
	await _wait(dur)
	if _dying:
		return
	await _wait(config.before_scene_change)
	if _dying:
		return
	ending_finished.emit()
	if is_inside_tree():
		Progress.mark_cleared(get_tree().current_scene.scene_file_path)
	if not ending_scene.is_empty() and is_inside_tree():
		get_tree().change_scene_to_file(ending_scene)


## 让 Ryn 摆出一个动作姿势(举照片)。视觉节点没有这个接口时什么都不做。
func _set_ryn_action(action: StringName) -> void:
	var visual: Node = ryn.get_node_or_null(^"Visual")
	if visual != null and visual.has_method(&"set_action"):
		visual.set_action(action)


func _say(line: String) -> void:
	if subtitle != null:
		subtitle.show_line(line)


## 等 `seconds` 秒。用挂在自己下面的 Timer,而不是 `SceneTree.create_timer`:演出途中关游戏时,
## 树上的计时器没响就被销毁,等着它的协程会以 ObjectDB 泄漏的形式留到退出;挂在自己下面的
## Timer 跟着本节点一起释放(2026-10-12)。
func _wait(seconds: float) -> void:
	var timer := _timer(maxf(seconds, 0.05))
	await timer.timeout
	timer.queue_free()


## 等另一个节点的信号(照片看完)。也走一个挂在自己下面的 Timer,离开场景树时能被「敲响」。
func _wait_for(sig: Signal) -> void:
	var timer := _timer(1.0e6)
	sig.connect(func() -> void:
		if is_instance_valid(timer) and not timer.is_stopped():
			timer.stop()
			timer.timeout.emit(), CONNECT_ONE_SHOT)
	await timer.timeout
	timer.queue_free()


func _timer(seconds: float) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = seconds
	add_child(timer)
	timer.start()
	return timer
