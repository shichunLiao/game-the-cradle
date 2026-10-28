class_name RynStealthVisual
extends Node
## 把 Ryn 的 **真实隐蔽状态** 接到她的视觉上(美术规格.md §3 的 `hide-in-shadow`)。
##
## ## 为什么不是"蹲下就变暗"
##
## 蹲在亮处照样会被发现。如果一蹲下就给出"藏好了"的视觉,玩家会据此做判断,
## 然后在自以为安全的地方被抓 —— 视觉说一套、机制做一套,这在潜行游戏里是致命的。
## 所以这里分两档,各自对应真实状态:
##
##   | 状态 | concealment | 含义 |
##   |---|---|---|
##   | 站立 | 0.0 | 完全暴露 |
##   | 蹲下,亮处 | `crouch_only` (默认 0.35) | "在尽量藏",但守卫仍看得见 |
##   | 蹲下,暗处 | 1.0 | 真的藏住了 |
##   | 站立,暗处 | `shadow_only` (默认 0.55) | 暗处也能藏,只是轮廓更大 |
##
## 采样点与守卫判定 **用同一个点**(躯干中点),否则视觉与机制会在边界上打架。
##
## 适配器式接法,与 `RynResetAdapter` / `ShadowRegistry` 一致。
##
## ## 顺带接两个「动作」
##
## 同样是关卡里的状态要反映到 Ryn 身上,所以也放在这里(移动姿态由 `Ryn` 自己传):
##   - **拆东西**:身边有拆到一半的可拆物件(`Dismantlable`)→ 蹲下拧、撬;
##   - **被发现**:本关的 `DetectionReset` 刚开始失败流程(画面收拢那一段)→ 一惊、僵住。
##
## Usage (in a scene):
##     [node name="RynStealthVisual" type="Node" parent="." node_paths=...]
##     ryn = NodePath("../Ryn")
##     shadows = NodePath("../ShadowRegistry")

@export var ryn: Ryn
@export var shadows: ShadowRegistry
## 本关的失败流程。为空时在 Ryn 的兄弟节点里找。
@export var detection_reset: DetectionReset
## 蹲下但未进暗处时的隐蔽度。刻意低于 1.0 —— 它表示"在藏",不是"藏住了"。
@export_range(0.0, 1.0) var crouch_only: float = 0.35
## 站在暗处(未蹲)时的隐蔽度。
@export_range(0.0, 1.0) var shadow_only: float = 0.55

var _visual: Node2D
var _owned_action: StringName = RynSpriteVisual.ACTION_NONE
## 进暗处的那一声(2026-10-13):上一帧是不是在暗处、这个状态持续多久了(边缘来回晃不要连响)。
var _was_hidden: bool = false
var _state_for: float = 0.0
var _cued: bool = true
## 进暗处之后稳住多久才响,秒。
const CUE_SETTLE: float = 0.12


func _ready() -> void:
	if ryn != null:
		_visual = ryn.get_node_or_null(^"Visual") as Node2D
		if detection_reset == null and ryn.get_parent() != null:
			for child in ryn.get_parent().get_children():
				if child is DetectionReset:
					detection_reset = child
					break


func _physics_process(delta: float) -> void:
	if _visual == null or ryn == null:
		return
	var crouched: bool = ryn.is_crouching
	var hidden: bool = false
	if shadows != null:
		# 与 Guard.sight_point() 同一个采样点:躯干中点。
		var p := ryn.global_position - Vector2(0.0, ryn.get_body_height() * 0.5)
		hidden = shadows.covers(p)
	var level: float = 0.0
	if crouched and hidden:
		level = 1.0
	elif hidden:
		level = shadow_only
	elif crouched:
		level = crouch_only
	_visual.set_concealment(level)
	_shade_cue(hidden, delta)
	# 只管自己设的动作:别处设的(结局举照片)不要被这里的「无」清掉
	var want: StringName = _current_action()
	if want != _owned_action:
		if want != RynSpriteVisual.ACTION_NONE or _visual.current_action() == _owned_action:
			_visual.set_action(want)
		_owned_action = want


## 被发现 > 拆东西 > 无。被发现只在画面收拢、字幕那两段;回到存档点时已经恢复原样。
func _current_action() -> StringName:
	if detection_reset != null and detection_reset.is_failing():
		var phase: FailSequence.Phase = detection_reset.phase()
		if phase == FailSequence.Phase.CLOSING or phase == FailSequence.Phase.SUBTITLE:
			return RynSpriteVisual.ACTION_CAUGHT
	for node in get_tree().get_nodes_in_group(Dismantlable.GROUP):
		var panel := node as Dismantlable
		if panel != null and not panel.is_dismantled and panel.is_player_in_reach() \
				and panel.progress_ratio() > 0.0:
			return RynSpriteVisual.ACTION_WORK
	return RynSpriteVisual.ACTION_NONE


## 进了暗处(守卫看不见了)稳住 `CUE_SETTLE` 秒,轻轻一声(`shade_in`);出来不响。
## 和画面同一个判定(躯干中点在不在暗区),站着、蹲着都算 —— 守卫的规则就是这样。
## `Audio` 用节点路径找:这个脚本会被 `-s` 检查脚本连带编译,那时 autoload 名不能直接用。
func _shade_cue(hidden: bool, delta: float) -> void:
	if hidden != _was_hidden:
		_was_hidden = hidden
		_state_for = 0.0
		_cued = not hidden
		return
	_state_for += delta
	if hidden and not _cued and _state_for >= CUE_SETTLE and ryn.input_enabled:
		_cued = true
		var audio := get_node_or_null(^"/root/Audio")
		if audio != null:
			audio.call(&"play", &"shade_in", -18.0)

