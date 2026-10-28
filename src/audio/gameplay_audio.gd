class_name GameplayAudio
extends Node
## 把游戏事件接到音效上。适配器式 —— 被它监听的脚本一行不改。
##
## 它只 **读** 状态和 **接** 信号,不改任何游戏逻辑。脚步、落地、拆东西会往 `/root/Noise`
## 发噪音,守卫的听觉(`GuardPursuit`)据此去查看 —— 这是这里唯一影响玩法的出口。
##
## ## 脚步跟着画面走(2026-10-10)
##
## Ryn 的视觉节点在「脚踩实」的那一帧发 `foot_planted`,脚步声、扬尘、噪音都挂在它上面,
## 而不是另按走过的距离算 —— 声音和画面对不上,脚就「踩不实」。落地分轻重(`landed(hard)`),
## 起跳(`took_off`)和急停(`skid_started`)各有一小团贴地的尘(Celeste / Hollow Knight 的做法)。
## 视觉节点没有这些信号时(占位图),退回按距离响。
##
## Usage (in a scene): 指向 ryn / detection_reset / checkpoints,其余自动发现。

@export var ryn: Ryn
@export var detection_reset: DetectionReset
@export var checkpoints: CheckpointManager
@export var shake: CameraShake
## 落地扬尘与拆解碎屑。留空则不生成粒子。
@export var particles: ParticleBurst
## 每走多少 px 响一次脚步。
@export var footstep_distance: float = 22.0
@export_group("Noise — 听觉系统")
## 走路的可听半径,px。蹲行为 0(无声),这是蹲姿的第二个价值。
@export var walk_noise: float = 70.0
## 落地的可听半径。比走路大 —— 跳下来是会被听见的。重落地再乘 1.4。
@export var land_noise: float = 130.0
@export_group("Feel")
## 重落地时镜头抖动的幅度(相对 CameraShake 的满幅)。
@export_range(0.0, 1.0) var hard_land_shake: float = 0.35
## 被发现那一下的顿帧,秒(真实时间)。0.07 太短(约 4 帧)玩起来感觉不到 —— 2026-10-11 拉到 0.12,
## 和 Celeste / Mark of the Ninja 的 0.1~0.15 一档。
@export_range(0.0, 0.3) var spotted_hitstop: float = 0.12

var _walked: float = 0.0
var _left: bool = true
var _was_on_floor: bool = true
var _was_climbing: bool = false
var _guard_states: Dictionary = {}
## 视觉节点会发 foot_planted 等信号时为 true,脚步和落地都改由信号驱动。
var _frame_steps: bool = false


func _ready() -> void:
	await get_tree().process_frame
	var visual: Node = ryn.get_node_or_null(^"Visual") if ryn != null else null
	if visual != null and visual.has_signal(&"foot_planted"):
		visual.foot_planted.connect(_on_foot_planted)
		visual.landed.connect(_on_landed)
		visual.took_off.connect(_on_took_off)
		visual.skid_started.connect(_on_skid_started)
		_frame_steps = true
	if ryn != null and ryn.has_signal(&"air_jumped"):
		ryn.connect(&"air_jumped", _on_air_jumped)
	if detection_reset != null and detection_reset.has_signal(&"phase_changed"):
		detection_reset.phase_changed.connect(_on_phase)
	if checkpoints != null and checkpoints.has_signal(&"checkpoint_activated"):
		checkpoints.checkpoint_activated.connect(_on_checkpoint)
	for d in get_tree().get_nodes_in_group(&"dismantlable"):
		if d.has_signal(&"panel_dismantled"):
			d.panel_dismantled.connect(_on_dismantled)
		# 「拧三下,再撬」—— 每一步一声咔哒,音高递增,给手上一个进度感
		if d.has_signal(&"dismantle_step"):
			d.dismantle_step.connect(_on_dismantle_step)
		if d.has_signal(&"dismantle_aborted"):
			d.dismantle_aborted.connect(_on_dismantle_aborted)


func _physics_process(delta: float) -> void:
	if ryn == null:
		return
	# 脚步:有 foot_planted 就跟着画面的触地帧走;没有(占位图)才按走过的距离触发。
	var on_floor: bool = ryn.is_on_floor()
	if _frame_steps:
		pass        # 脚步由 foot_planted 驱动
	elif on_floor and ryn.state == Ryn.State.NORMAL and absf(ryn.velocity.x) > 6.0:
		_walked += absf(ryn.velocity.x) * delta
		var step: float = footstep_distance * (1.45 if ryn.is_crouching else (0.78 if ryn.is_sprinting else 1.0))
		if _walked >= step:
			_walked = 0.0
			_left = not _left
			# 听觉:蹲行无声 / 走路小声 / 跑步很响 —— 跑是要付代价的。
			if not ryn.is_crouching:
				var r: float = walk_noise
				if ryn.is_sprinting and ryn.config != null:
					r = ryn.config.sprint_noise_radius
				_noise(ryn.global_position, r)
			# 蹲行更轻 —— 视觉上在藏,听感也该跟上。
			Audio.play_footstep(_left) if not ryn.is_crouching else Audio.play(
					&"footstep_a" if _left else &"footstep_b", -14.0, randf_range(0.9, 1.0))
	else:
		_walked = 0.0

	# 起跳 / 落地
	if _was_on_floor and not on_floor and ryn.velocity.y < -40.0:
		Audio.play(&"jump", -9.0, randf_range(0.97, 1.05))
	if not _was_on_floor and on_floor and not _frame_steps:
		Audio.play(&"land", -8.0, randf_range(0.95, 1.05))
		_noise(ryn.global_position, land_noise)
		# 落地扬尘:冷色,贴地,很快消失
		if particles != null:
			particles.emit_at(ryn.global_position, 8, Color("2A3A52"), 36.0, 44.0, 0.38)
	_was_on_floor = on_floor

	# 守卫状态变化:起疑 / 发现
	for g in get_tree().get_nodes_in_group(&"guard_audio"):
		_poll_guard(g as Guard)


## 二段跳:比起跳轻、高一点的一声,脚下散开一小团冷色的气流。不出噪音(和起跳一样,落地才出声)。
func _on_air_jumped() -> void:
	Audio.play(&"jump", -13.0, randf_range(1.18, 1.26))
	if particles != null:
		particles.emit_at(ryn.global_position, 6, Color("3A4E6E"), 30.0, -20.0, 0.3)


## 脚踩实的那一帧:声音、噪音、(跑步时)脚后跟扬起一点灰。
func _on_foot_planted(kind: StringName) -> void:
	if ryn == null:
		return
	_left = not _left
	match kind:
		&"sneak":
			# 蹲行:几乎听不见,也不发噪音 —— 这是蹲姿的第二个价值
			Audio.play(&"footstep_a" if _left else &"footstep_b", -16.0, randf_range(0.88, 0.96))
		&"run":
			Audio.play_footstep(_left)
			if ryn.config != null:
				_noise(ryn.global_position, ryn.config.sprint_noise_radius)
			if particles != null:
				particles.emit_dust(ryn.global_position - Vector2(float(ryn.facing) * 3.0, 0.0),
						3, -ryn.facing, 0.8)
		_:
			Audio.play_footstep(_left)
			_noise(ryn.global_position, walk_noise)


## 落地:轻落地一小团灰往两边铺;重落地(从高处掉下来)灰更多、铺更远,镜头抖一下。
func _on_landed(hard: bool) -> void:
	if ryn == null:
		return
	Audio.play(&"land", -4.0 if hard else -8.0, randf_range(0.82, 0.9) if hard else randf_range(0.95, 1.05))
	_noise(ryn.global_position, land_noise * (1.4 if hard else 1.0))
	if particles != null:
		particles.emit_dust(ryn.global_position, 12 if hard else 6, 0, 1.6 if hard else 1.0)
	if hard and shake != null:
		shake.shake(hard_land_shake)


## 起跳:脚下蹬起一点灰。
func _on_took_off() -> void:
	if particles != null and ryn != null:
		particles.emit_dust(ryn.global_position, 4, 0, 0.7)


## 急停:鞋底往前搓出一串灰。
func _on_skid_started() -> void:
	if ryn == null:
		return
	Audio.play(&"footstep_a", -9.0, 0.78)
	if particles != null:
		var dir: int = 1 if ryn.velocity.x > 0.0 else -1
		particles.emit_dust(ryn.global_position + Vector2(float(dir) * 4.0, 0.0), 5, dir, 1.0)


func _poll_guard(g: Guard) -> void:
	if g == null:
		return
	var id: int = g.get_instance_id()
	var prev: int = int(_guard_states.get(id, Guard.State.PATROL))
	if g.state != prev:
		if g.state == Guard.State.SUSPICIOUS and prev == Guard.State.PATROL:
			Audio.play(&"suspicious", -7.0)
		_guard_states[id] = g.state


func _on_phase(phase: int) -> void:
	# CLOSING = 刚被发现那一帧
	if phase == FailSequence.Phase.CLOSING:
		Audio.play(&"spotted", -3.0)
		# 顿帧在震动之前 —— 先停住,再抖,收束才有分量
		var hs := get_node_or_null(^"/root/Hitstop")
		if hs != null:
			hs.hit(spotted_hitstop)
		if shake != null:
			shake.shake()
	elif phase == FailSequence.Phase.GRACE:
		Audio.play(&"respawn", -10.0)


func _on_checkpoint(_cp: Node) -> void:
	Audio.play(&"checkpoint", -12.0)


## 发一次噪音。走 /root 路径:autoload 名在静态分析时会被当成类名。
func _noise(at: Vector2, radius: float) -> void:
	var bus := get_node_or_null(^"/root/Noise")
	if bus != null:
		bus.emit_noise(at, radius)


func _on_dismantled(_alerted: int) -> void:
	Audio.play(&"dismantle_done", -6.0)
	# 拆完的碎屑:比落地多、飞得散
	if particles != null and ryn != null:
		particles.emit_at(ryn.global_position - Vector2(0.0, 8.0), 14, Color("1A2A44"), 70.0, 95.0, 0.62)
	# 拆完最响 —— 叙事塔2「拆地板 → 守卫跌落」本就该惊动人
	if ryn != null:
		_noise(ryn.global_position, 220.0)


func _on_dismantle_step(index: int, _total: int) -> void:
	Audio.play(StringName("dismantle_%d" % mini(index, 3)), -7.0)
	# 每一下咔哒掉几粒 —— 手上有进度感
	if particles != null and ryn != null:
		particles.emit_at(ryn.global_position - Vector2(0.0, 6.0), 4, Color("24354F"), 26.0, 40.0, 0.3)
	# 每一下咔哒都传得出去 —— 拆东西本来就该有风险
	if ryn != null:
		_noise(ryn.global_position, 150.0)


func _on_dismantle_aborted(_lost: float) -> void:
	# 松手的挫败感:一声下滑的短音,区别于完成
	Audio.play(&"dismantle_0", -12.0, 0.7)
