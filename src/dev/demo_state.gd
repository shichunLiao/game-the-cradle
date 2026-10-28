class_name DemoState
extends Node
## DEV ONLY. Scripted demos for capturing screenshots and measuring movement
## from the command line. Does nothing unless a `--demo=` user arg is given.
##
## It presses the REAL input actions (Input.action_press), so the Input Map and
## Ryn's normal input path are exercised. Prints `[demo] ...` lines to stdout.
##
## Usage (user args go after `--`):
##     godot --path . --windowed --resolution 1280x720 -- --demo=crouch
##
## Demos: walk | jump | crouch | climb | guard-patrol | guard-blocked |
## guard-spotted | guard-suspicious | reset-fail | reset-fail-patrol | traverse |
## traverse-exit | route |
## shadow-safe | shadow-lit | shadow-crouch | shadow-crouch-stand |
## dismantle-prompt | dismantle-hatch | dismantle-abort | dismantle-fence |
## dismantle-reset. Each quits when its script finishes
## (a `--quit-after N` on the command line ends it earlier).
##
## The `guard-*` demos press no keys at all -- they only place Ryn and, for the
## stationary ones, pin the guard in place so a screenshot is deterministic.

@export var ryn: Ryn
@export var camera: FollowCamera
@export var guard: Guard
@export var detection_reset: DetectionReset
@export var checkpoints: CheckpointManager
@export var shadows: ShadowRegistry
@export var guard2: Guard
@export var hatch: Dismantlable
@export var fence: Dismantlable

const JUMP_HOLDS: Array[int] = [60, 60, 60, 1, 1, 1, 6, 6, 12, 12]

var _mode: String = ""
var _tick: int = 0
var _started: bool = false
var _wait_ticks: int = 0
var _phase: int = 0
var _counter: int = 0
var _jump_index: int = 0
var _hold_left: int = 0
var _takeoff_y: float = 0.0
var _min_y: float = 0.0
var _air_ticks: int = 0


## Traversal goal: the east end of the level, past every piece of geometry.
## Was 1160 (the guard's doorstep) until Stories 004 and 005 both built east of
## it and the bot silently covered none of it.
const TRAVERSE_GOAL_X: float = 1520.0
## Give up after this many physics ticks (~60 s at 60 Hz). Must leave room for
## the stuck rotation to reach its dismantle segment AND hold it out: the walk
## east alone costs ~1800 ticks, and a 1800 cap cut the run off at the exact
## moment the bot started trying to open the fence.
const TRAVERSE_TIMEOUT: int = 3600
## Ticks of no forward progress before the bot starts trying jump/crouch/climb.
const TRAVERSE_STUCK_GRACE: int = 12
## Ticks spent on each attempt before rotating to the next.
const TRAVERSE_ATTEMPT_TICKS: int = 24
## Ticks held on the dismantle attempt. Must exceed DismantleConfig.hold_duration
## (1.2 s = 72 ticks) or the bot can never open a panel that blocks the route.
const TRAVERSE_INTERACT_TICKS: int = 90
## One full rotation: jump, crouch, climb, dismantle.
const TRAVERSE_CYCLE: int = TRAVERSE_ATTEMPT_TICKS * 3 + TRAVERSE_INTERACT_TICKS

var _traverse_best_x: float = -1.0
var _traverse_stuck: int = 0
var _traverse_done: bool = false
var _traverse_blinded: bool = false

## VERTICAL REACHABILITY (`traverse-exit`).
##
## The original `traverse` walks right until TRAVERSE_GOAL_X. The towers are no
## longer flat, so "right" stopped being a route: a level whose way on is a
## ladder reads as UNREACHABLE no matter how open it is, and — worse — a level
## whose exit sits west of a dead end reads as REACHABLE because the bot never
## had to get anywhere in particular.
##
## This mode seeks the level's own `TowerExit` instead of a hardcoded x, so it
## needs no per-level constant and it targets the one place that actually ends
## the level. Progress is distance to that rect, not x, so climbing counts.
##
## 已知局限(和横向版一样,别当成判决):
##   - 它仍然是蛮力轮换,不做寻路。一条需要「先下后上再回头」的长路线可能超时。
##   - 超时 ⇒ UNREACHABLE 是**观察**:可能是路断了,也可能是机器人不够聪明。
##     判定关卡坏掉之前先看日志里 best 停在哪。
const EXIT_TIMEOUT: int = 9000
## 距离目标多近算到达。出口矩形本身约 48x56,给半个身位余量。
const EXIT_REACH_PX: float = 36.0
## 没有改善多少 tick 之后开始轮换。竖直路线比横向更容易短暂停滞(爬梯子时 x 不动),
## 所以比横向的 12 宽松。
const EXIT_STUCK_GRACE: int = 20
## 轮换里每个「朝目标」尝试占多少 tick。
const EXIT_ATTEMPT: int = 26
## 往回走的尝试要**短**。第一版和前进段一样长,机器人一路倒退回左墙再也没回来。
const EXIT_BACK: int = 14
## 一整轮尝试的长度。
const EXIT_CYCLE: int = EXIT_ATTEMPT * 3 + EXIT_BACK * 2 + TRAVERSE_INTERACT_TICKS
## 起跳后必须按住多少 tick。**这个值不能由 `_exit_stuck` 决定** —— 见 `_exit_jump_hold`。
const EXIT_JUMP_HOLD: int = 22
## 目标高出这么多才在非卡住状态下顺手去抓梯子。小于一层楼的高差不触发。
const CLIMB_HINT_PX: float = 60.0
## 连续多少整轮尝试都没进展之后,临时切成「只认 x」。
const FLAT_AFTER_ROTATIONS: int = 2
## 「只认 x」持续多少 tick(约 15 秒)。
const FLAT_TICKS: int = 900

var _exit_goal: Vector2 = Vector2.ZERO
var _exit_rect: Rect2 = Rect2()
## 历史最近距离,只用于报告。
var _exit_best: float = INF
## 卡住判定的参照距离。**和 `_exit_best` 分开**:见 `_exit_stuck` 的重置逻辑。
var _exit_ref: float = INF
var _exit_stuck: int = 0
## 跳跃按住倒计时,**独立于 `_exit_stuck`**。
##
## 为什么必须独立:Ryn 在空中只要向右挪过 1px,到目标的距离就改善,`_exit_stuck`
## 归零,控制流退回「朝目标走」的基本分支 —— 那个分支不按跳跃键。
## `jump_release_gravity_multiplier = 3.0` 于是把这一跳砍成约 13px。
## 实测后果:机器人在一个 32px 的台阶前卡了 9000 tick,而**脚本化的同一跳一次就过**。
## 看起来和「关卡断了」一模一样。
var _exit_jump_hold: int = 0
## 「只认 x」模式的截止 tick。
##
## 为什么需要:贪心地朝目标直线靠近,就走不了**先下后上**的路线。塔4 的路线正是
## 这样 —— 高台 → 落回地面 → 蹲过 NarrowCeiling → LadderEast → 东高台 → 塔顶。
## 目标在上方时机器人死活不肯往下,实测卡在 x≈730 的 HighPlatformMid 上 9000 tick。
## 卡够久就先把 y 忘掉往东走一段,到了东边再恢复找高度。
var _exit_flat_until: int = 0
var _exit_rotations: int = 0
var _dbg: bool = false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo="):
			_mode = arg.substr(7)
	if _mode.is_empty():
		set_physics_process(false)
		return
	var root: Window = get_tree().root
	print("[demo] mode=", _mode, " viewport=", get_viewport().get_visible_rect().size,
			" window=", root.size, " content_scale_mode=", root.content_scale_mode,
			" stretch=", root.content_scale_stretch, " aspect=", root.content_scale_aspect,
			" final_scale=", root.get_final_transform().get_scale())
	match _mode:
		"crouch":
			ryn.global_position = Vector2(700.0, 320.0)
		"climb":
			ryn.global_position = Vector2(420.0, 320.0)
		"guard-patrol":
			# Far enough left that the patrolling cone never reaches Ryn, and
			# the SightBlocker pillar covers the gap anyway.
			ryn.global_position = Vector2(1060.0, 320.0)
		"guard-blocked":
			# Behind the SightBlocker pillar: inside the cone, no line of sight.
			ryn.global_position = Vector2(1060.0, 320.0)
			_pin_guard(-1)
		"guard-spotted":
			# Between the pillar and the guard: nothing in the way.
			ryn.global_position = Vector2(1150.0, 320.0)
			_pin_guard(-1)
		"guard-suspicious":
			ryn.global_position = Vector2(1000.0, 320.0)
			_pin_guard(-1)
		"reset-fail", "reset-fail-patrol":
			# Full Story 003 loop, teleport-driven so the frame numbers are
			# deterministic (no focus-dependent key presses before the capture).
			# Start on CheckpointStart, walk the route to CheckpointMid, then
			# step out from behind the pillar into the guard's cone.
			# The -patrol variant leaves the guard PATROLLING, which is what
			# proves AC6's guard POSITION rollback (the pinned guard never moves,
			# so it can never demonstrate being moved back).
			ryn.global_position = Vector2(64.0, 320.0)
			if _mode == "reset-fail":
				_pin_guard(-1)
			_started = true
			if detection_reset != null:
				detection_reset.phase_changed.connect(_on_reset_phase)
				detection_reset.control_restored.connect(_on_control_restored)
			if checkpoints != null:
				checkpoints.checkpoint_activated.connect(_on_checkpoint_activated)
		"shadow-safe", "shadow-lit", "shadow-crouch", "shadow-crouch-stand":
			# Story 004. The guard is pinned facing RIGHT, into the open stretch
			# east of its spawn: no pillar, no ledge, so the line of sight is
			# clear by construction and a miss can only be the darkness rule.
			ryn.global_position = Vector2(_shadow_demo_x(), SHADOW_FLOOR_Y)
			_pin_guard(1)
		"dismantle-prompt", "dismantle-hatch", "dismantle-abort", "dismantle-reset":
			# Story 005. Ryn stands on the catwalk's west plate, in reach of the
			# FloorHatch. Both guards are pinned: the main one faces LEFT so it
			# cannot see her, and Guard2 stands ON the hatch facing away, so the
			# only thing that moves it is the floor leaving.
			ryn.global_position = Vector2(DM_CATWALK_X, DM_CATWALK_Y)
			_pin(guard, -1)
			_pin(guard2, 1)
		"dismantle-fence":
			# Ryn on the floor beside the FenceGrate. The main guard is pinned
			# facing left until the fence opens; its GuardReroute then widens the
			# patrol through the new passage and it walks there itself.
			ryn.global_position = Vector2(DM_FENCE_X, DM_FLOOR_Y)
			_pin(guard, -1)
			_pin(guard2, 1)
	if _mode.begins_with("dismantle"):
		# Every scripted interact press is re-issued each tick (a focus change
		# releases all actions, and a one-frame release would abort the hold).
		_started = true
		print("[demo] dismantle input_map has_interact=", InputMap.has_action(&"interact"),
				" events=", InputMap.action_get_events(&"interact"))
		if hatch != null:
			hatch.panel_dismantled.connect(_on_panel_dismantled.bind("hatch"))
			hatch.dismantle_step.connect(_on_dismantle_step.bind("hatch"))
			hatch.dismantle_aborted.connect(_on_dismantle_aborted.bind("hatch"))
			hatch.panel_restored.connect(_on_panel_restored.bind("hatch"))
		if fence != null:
			fence.panel_dismantled.connect(_on_panel_dismantled.bind("fence"))
			fence.panel_restored.connect(_on_panel_restored.bind("fence"))
	if _mode == "traverse":
		# No teleport, no pinning: Ryn starts where the SCENE puts her and walks.
		_started = true
		if guard != null:
			guard.player_spotted.connect(_on_traverse_spotted)
	if _mode == "route":
		_started = true
		var lr: Node = owner if owner != null else get_parent()
		var route_node: String = "DevRoute"
		for a3 in OS.get_cmdline_user_args():
			if a3.begins_with("--route-node="):
				route_node = a3.substr(13)
		_route = lr.get_node_or_null(NodePath(route_node))
		if _route == null or _route.points.size() < 2:
			printerr("[demo] route: 这个关卡没有 DevRoute(用 tools/level_builder 生成的关卡才有)")
			get_tree().quit(2)
			return
		print("[demo] route: %d 步,从 %s 到 %s" % [_route.points.size(), _route.points[0], _route.points[-1]])
		_dbg = OS.get_cmdline_user_args().has("--route-debug")
		for g in _collect_guards(lr):
			g.player_spotted.connect(_on_traverse_spotted)
		var rdr: DetectionReset = _find_reset(lr)
		if rdr != null:
			rdr.fail_started.connect(_on_traverse_failed)
		# `--pace`:全流程体检,边走边记存档点和「要看时机的关口」(`pace_probe.gd`)
		if OS.get_cmdline_user_args().has("--pace"):
			_pace = preload("res://src/dev/pace_probe.gd").new()
			add_child(_pace)
			_pace.call("setup", lr, ryn, _route)
	if _mode == "traverse-exit":
		_started = true
		# `--start=x,y`:**摆位,不是可达性主张**。只用于单独验证关卡的某一段 ——
		# 被跳过的那一段在证据里必须如实记为「本次未验证」,否则就又变成 Story
		# 002/003 那种「传送摆位掩盖了可达性问题」。不给这个参数时照常从场景出生点走。
		for a2 in OS.get_cmdline_user_args():
			if a2.begins_with("--start="):
				var parts: PackedStringArray = a2.substr(8).split(",")
				if parts.size() == 2:
					ryn.global_position = Vector2(float(parts[0]), float(parts[1]))
					print("[demo] traverse-exit STAGED start=", ryn.global_position,
							" —— 此点以西的地形本次未被走过")
		var level_root: Node = owner if owner != null else get_parent()
		var ex: TowerExit = _find_exit(level_root)
		if ex == null:
			printerr("[demo] traverse-exit: 这个关卡没有 TowerExit,无法确定目标")
			get_tree().quit(2)
			return
		# TowerExit 的原点是**左下角**(`Rect2(Vector2(0,-size.y), size)`)。
		# 当成左上角会把目标点放到出口上方一整个身位,机器人会永远差一点。
		_exit_rect = Rect2(ex.global_position + Vector2(0.0, -ex.size.y), ex.size)
		_exit_goal = _exit_rect.get_center()
		print("[demo] traverse-exit goal=", _exit_goal.snapped(Vector2(0.1, 0.1)),
				" rect=", _exit_rect, " ryn_start=", ryn.global_position.snapped(Vector2(0.1, 0.1)))
		# 所有守卫都要接,不只是 `guard` 导出的那一个 —— 致盲失效必须被看见。
		for g in _collect_guards(level_root):
			g.player_spotted.connect(_on_traverse_spotted)
		# **再接一道总闸。** 只接守卫是不够的:`SweepLight` 不是 `Guard`,它直接调
		# `DetectionReset.trigger()`。塔4 实测后果 —— 机器人被探照灯反复抓住,
		# 却报出一个安静的 UNREACHABLE,看起来和「路断了」一模一样,查了很久。
		# 接 `fail_started` 就与起因无关:任何失败都说明这次跑的不是纯地形。
		var dr: DetectionReset = _find_reset(level_root)
		if dr != null:
			dr.fail_started.connect(_on_traverse_failed)
	if _mode.begins_with("shadow"):
		# Every scripted press in a shadow demo is re-issued each tick, so a
		# focus change cannot cancel it and there is nothing to wait for.
		_started = true
		if guard != null:
			guard.player_spotted.connect(_on_player_spotted)
	if _mode.begins_with("guard"):
		# No scripted key presses, so there is nothing for focus loss to cancel.
		_started = true
		if guard != null:
			guard.player_spotted.connect(_on_player_spotted)


func _physics_process(_delta: float) -> void:
	# Godot releases all pressed actions when the window gains or loses focus,
	# which would cancel a scripted press mid-demo. Wait for focus (bounded).
	if not _started:
		_wait_ticks += 1
		if (DisplayServer.window_is_focused() and _wait_ticks > 20) or _wait_ticks > 300:
			_started = true
		return
	_tick += 1
	match _mode:
		"walk":
			_demo_walk()
		"jump":
			_demo_jump()
		"crouch":
			_demo_crouch()
		"climb":
			_demo_climb()
		"guard-patrol", "guard-blocked", "guard-spotted":
			_demo_guard_watch()
		"guard-suspicious":
			_demo_guard_suspicious()
		"reset-fail":
			_demo_reset_fail()
		"reset-fail-patrol":
			_demo_reset_fail_patrol()
		"shadow-safe", "shadow-lit", "shadow-crouch-stand":
			_demo_shadow_watch()
		"shadow-crouch":
			# Re-pressed every tick on purpose: losing focus releases all actions,
			# and a demo that quietly stood up would "prove" the opposite thing.
			Input.action_press(&"move_down")
			_demo_shadow_watch()
		"dismantle-prompt":
			_demo_dismantle_prompt()
		"dismantle-hatch":
			_demo_dismantle_hatch()
		"dismantle-abort":
			_demo_dismantle_abort()
		"dismantle-fence":
			_demo_dismantle_fence()
		"dismantle-reset":
			_demo_dismantle_reset()
		"traverse":
			_demo_traverse()
		"traverse-exit":
			_demo_traverse_exit()
		"route":
			_demo_route()
		_:
			printerr("[demo] unknown demo: ", _mode)
			get_tree().quit(1)


func _demo_walk() -> void:
	if _tick == 10:
		Input.action_press(&"move_right")
	if _tick == 70:
		Input.action_release(&"move_right")
	if (_tick >= 8 and _tick <= 30 and _tick % 2 == 0) or (_tick >= 68 and _tick <= 100 and _tick % 2 == 0):
		print("[demo] walk tick=", _tick, " vx=", snappedf(ryn.velocity.x, 0.1), " x=", snappedf(ryn.global_position.x, 0.1))
	if _tick == 110:
		get_tree().quit()


func _demo_jump() -> void:
	match _phase:
		0:  # wait on the floor
			_counter += 1
			if _counter >= 30 and ryn.is_on_floor():
				if _jump_index >= JUMP_HOLDS.size():
					get_tree().quit()
					return
				_hold_left = JUMP_HOLDS[_jump_index]
				_takeoff_y = ryn.global_position.y
				_min_y = _takeoff_y
				_air_ticks = 0
				Input.action_press(&"jump")
				_phase = 1
		1:  # holding
			_min_y = minf(_min_y, ryn.global_position.y)
			_hold_left -= 1
			if _hold_left <= 0:
				Input.action_release(&"jump")
				_phase = 2
		2:  # airborne
			_air_ticks += 1
			_min_y = minf(_min_y, ryn.global_position.y)
			if _air_ticks > 3 and ryn.is_on_floor():
				print("[demo] jump#", _jump_index, " hold_ticks=", JUMP_HOLDS[_jump_index],
						" apex_px=", snappedf(_takeoff_y - _min_y, 0.01))
				_jump_index += 1
				_counter = 0
				_phase = 0


func _demo_crouch() -> void:
	if _tick == 5:
		Input.action_press(&"move_down")
		Input.action_press(&"move_right")
	if _phase == 0 and ryn.global_position.x > 760.0:
		# Deep under the slab: release everything. Ryn must stay crouched.
		Input.action_release(&"move_down")
		Input.action_release(&"move_right")
		_phase = 1
		_counter = 0
	elif _phase == 1:
		_counter += 1
		if _counter == 90:
			Input.action_press(&"move_left")
			_phase = 2
	elif _phase == 2 and ryn.global_position.x < 712.0:
		Input.action_release(&"move_left")
		_phase = 3
		_counter = 0
	elif _phase == 3:
		_counter += 1
		if _counter == 30:
			_log_crouch()
			get_tree().quit()
	if _tick % 15 == 0:
		_log_crouch()


func _log_crouch() -> void:
	print("[demo] crouch tick=", _tick, " phase=", _phase, " x=", snappedf(ryn.global_position.x, 0.1),
			" down_held=", Input.is_action_pressed(&"move_down"),
			" is_crouching=", ryn.is_crouching,
			" body_height=", ryn.get_body_height(), " can_stand=", ryn.can_stand())


func _demo_climb() -> void:
	if _tick == 5:
		Input.action_press(&"move_right")
	if _phase == 0 and ryn.global_position.x >= 450.0:
		Input.action_release(&"move_right")
		Input.action_press(&"move_up")
		_phase = 1
	elif _phase == 1 and ryn.state == Ryn.State.NORMAL and _tick > 20 and ryn.global_position.y < 321.0 \
			and not Input.is_action_pressed(&"move_right") and ryn.global_position.y <= 192.5:
		# Reached the top.
		Input.action_release(&"move_up")
		Input.action_press(&"move_right")
		_phase = 2
		_counter = 0
	elif _phase == 2:
		_counter += 1
		if _counter == 50:
			Input.action_release(&"move_right")
			print("[demo] climb DONE x=", snappedf(ryn.global_position.x, 0.1), " y=", snappedf(ryn.global_position.y, 0.1),
					" on_floor=", ryn.is_on_floor())
			get_tree().quit()
	if _tick % 10 == 0:
		print("[demo] climb tick=", _tick, " phase=", _phase, " state=", Ryn.State.keys()[ryn.state],
				" pos=", ryn.global_position.snapped(Vector2(0.1, 0.1)))


func _pin_guard(dir: int) -> void:
	_pin(guard, dir)


## Makes `target` a stationary watcher facing `dir`. MUST run before the guard's
## own `_ready` (DemoState is the scene's first child, so it does), because
## `Guard._ready` turns `patrol_offset` into its patrol bounds once.
func _pin(target: Guard, dir: int) -> void:
	if target == null:
		return
	target.patrol_offset = 0.0
	target.initial_facing = dir


func _demo_guard_watch() -> void:
	if _tick % 20 == 0:
		_log_guard()


func _demo_guard_suspicious() -> void:
	if _tick == 5:
		guard.report_disturbance()
	if _tick % 20 == 0:
		_log_guard()


func _log_guard() -> void:
	if guard == null:
		return
	print("[demo] guard tick=", _tick, " state=", Guard.State.keys()[guard.state],
			" facing=", guard.facing,
			" guard_x=", snappedf(guard.global_position.x, 0.1),
			" ryn_x=", snappedf(ryn.global_position.x, 0.1),
			" half_angle_deg=", snappedf(rad_to_deg(guard.current_half_angle()), 0.1),
			" range=", snappedf(guard.current_range(), 0.1),
			" can_see_ryn=", guard.can_see(guard.sight_point(ryn)))


## Timeline in physics ticks. Phase changes are logged with the drawn-frame
## number so a `--write-movie` capture can be indexed exactly.
const RESET_TELEPORT_MID: int = 25
const RESET_TELEPORT_EXPOSED: int = 45
const RESET_PRESS_RIGHT: int = 250
const RESET_QUIT: int = 300


func _demo_reset_fail() -> void:
	match _tick:
		RESET_TELEPORT_MID:
			ryn.global_position = Vector2(1000.0, 320.0)
			_log_reset("teleport->CheckpointMid")
		RESET_TELEPORT_EXPOSED:
			ryn.global_position = Vector2(1150.0, 320.0)
			_log_reset("teleport->exposed")
		RESET_PRESS_RIGHT:
			# Proof that control really came back: real input, real Input Map.
			Input.action_press(&"move_right")
			_log_reset("press move_right")
		RESET_PRESS_RIGHT + 10:
			_log_reset("after press")
		RESET_QUIT:
			Input.action_release(&"move_right")
			_log_reset("done")
			get_tree().quit()
	if _tick % 10 == 0:
		_log_reset("tick")


## Story 003 AC6 proof: the guard is PATROLLING (not pinned), so its position
## at checkpoint-capture time differs from its position when Ryn is spotted.
## The log's `guard=` field before capture vs after FADING is the rollback.
func _demo_reset_fail_patrol() -> void:
	match _tick:
		40:
			ryn.global_position = Vector2(1000.0, 320.0)
			_log_reset("teleport->CheckpointMid (CAPTURE happens here)")
		120:
			ryn.global_position = Vector2(1150.0, 320.0)
			_log_reset("teleport->exposed, waiting for a patrolling guard to look left")
		700:
			_log_reset("done")
			get_tree().quit()
	if _tick % 10 == 0:
		_log_reset("tick")


## Reachability measures TERRAIN, not stealth. Without this the bot is spotted at
## the guard's doorstep, the fail sequence teleports it back to a checkpoint, and
## everything east of there is never walked — which is exactly how Stories 004
## and 005 both shipped geometry the bot had never touched.
##
## Reuses Story 004's `darkness_veto` injection point rather than editing or
## disabling the guards: "always hidden" is already a supported state.
func _blind_all_guards() -> void:
	var blind := func(_point: Vector2) -> bool: return true
	for g in _collect_guards(owner if owner != null else self):
		g.darkness_veto = blind
		# 「听」「追」不靠眼睛(撞上、顺着痕迹找到人,2026-10-13):把它们的发现也关掉,机器人测的是地形
		var senses := g.get_node_or_null(^"Senses")
		if senses != null:
			senses.process_mode = Node.PROCESS_MODE_DISABLED


func _collect_guards(node: Node) -> Array[Guard]:
	var found: Array[Guard] = []
	var g := node as Guard
	if g != null:
		found.append(g)
	for child in node.get_children():
		found.append_array(_collect_guards(child))
	return found


## REACHABILITY CHECK — the one demo that may not teleport.
##
## Every other demo sets `ryn.global_position` to stage a moment, which is fine
## for capturing a state but proves nothing about whether a player can GET
## there. That blind spot shipped a testbed whose SightBlocker was an 80 px wall
## in front of a 53 px jump: seven ACs, six screenshots and a full log all
## passed, and the level was impassable.
##
## This bot presses real actions only. It does not know the layout: when forward
## progress stalls it rotates through jump, crouch and climb until something
## works. Reaching the goal — or being spotted, which can only happen inside the
## guard's area — is the pass condition.
func _demo_traverse() -> void:
	if _traverse_done:
		return
	if not _traverse_blinded:
		# NOT in _ready: ShadowRegistry._ready() also assigns darkness_veto, and
		# DemoState is the earlier sibling, so blinding there is silently undone.
		# The first physics tick is after every _ready.
		_blind_all_guards()
		_traverse_blinded = true
	Input.action_press(&"move_right")
	var x: float = ryn.global_position.x
	if x > _traverse_best_x + 0.5:
		_traverse_best_x = x
		_traverse_stuck = 0
	else:
		_traverse_stuck += 1

	Input.action_release(&"move_down")
	Input.action_release(&"move_up")
	if _traverse_stuck <= TRAVERSE_STUCK_GRACE:
		Input.action_release(&"jump")
	else:
		var t: int = (_traverse_stuck - TRAVERSE_STUCK_GRACE) % TRAVERSE_CYCLE
		Input.action_release(&"interact")
		if t < TRAVERSE_ATTEMPT_TICKS:
			# Hold most of the segment, then release so the next rotation can
			# re-trigger just_pressed. Holding matters: Ryn's
			# jump_release_gravity_multiplier cuts a short hop hard — 6 ticks of
			# hold clears only ~31.7 px, 0.3 px short of the 32 px LedgeLow.
			# A near-full hold clears ~53 px.
			if t < TRAVERSE_ATTEMPT_TICKS - 4:
				Input.action_press(&"jump")
			else:
				Input.action_release(&"jump")
		elif t < TRAVERSE_ATTEMPT_TICKS * 2:
			Input.action_release(&"jump")
			Input.action_press(&"move_down")
		elif t < TRAVERSE_ATTEMPT_TICKS * 3:
			Input.action_release(&"jump")
			Input.action_press(&"move_up")
		else:
			# Dismantle. 「破路更安全」 is a route, so the reachability bot has to
			# be able to open one.
			Input.action_release(&"jump")
			Input.action_press(&"interact")

	if _tick % 30 == 0:
		print("[demo] traverse tick=", _tick, " x=", snappedf(x, 0.1),
				" best=", snappedf(_traverse_best_x, 0.1),
				" stuck=", _traverse_stuck,
				" on_floor=", ryn.is_on_floor(),
				" state=", Ryn.State.keys()[ryn.state],
				" crouch=", ryn.is_crouching)

	if x >= TRAVERSE_GOAL_X:
		_finish_traverse("REACHABLE — walked to x=%.1f" % x)
	elif _tick > TRAVERSE_TIMEOUT:
		_finish_traverse("UNREACHABLE — stalled at best x=%.1f after %d ticks" % [_traverse_best_x, _tick])


## 让非守卫类危险物闭嘴。
##
## 守卫靠 `darkness_veto` 致盲,但探照灯不吃那一套(它**故意**照亮暗处),闸门灯同理
## —— 这两类自己持有 `ryn` 并直接调 `DetectionReset.trigger()`。
##
## **按能力匹配,不按类型枚举。** 先写成 `if child is SweepLight` 的版本只盖住了塔4
## 的探照灯,塔3 的 `GateLight` 当场漏网。凡是「同时持有 `ryn` 和 `detection_reset`」
## 的节点都是这一族,以后再加一种也自动覆盖。
##
## 漏网也不会变成静默失败:`fail_started` 那道总闸会把它报成 INCONCLUSIVE。
func _mute_hazards(node: Node = null) -> void:
	var root_node: Node = node if node != null else (owner if owner != null else get_parent())
	for child in root_node.get_children():
		if child == self:
			continue   # DemoState 自己也有这两个导出,置空会把机器人弄瘸
		if child.get(&"ryn") != null and child.get(&"detection_reset") != null:
			child.set(&"ryn", null)
		_mute_hazards(child)


func _find_reset(node: Node) -> DetectionReset:
	for child in node.get_children():
		if child is DetectionReset:
			return child
		var found: DetectionReset = _find_reset(child)
		if found != null:
			return found
	return null


func _on_traverse_failed(_player: Node2D, by: Node2D) -> void:
	_finish_traverse("INCONCLUSIVE — 被 %s 触发失败重置,这次跑的不是纯地形(最近 %.1f px)"
			% [str(by.name) if by != null else "未知", _exit_best])


func _find_exit(node: Node) -> TowerExit:
	for child in node.get_children():
		if child is TowerExit:
			return child
		var found: TowerExit = _find_exit(child)
		if found != null:
			return found
	return null


## VERTICAL REACHABILITY CHECK — seeks the level's own TowerExit.
##
## Same rule as the horizontal bot: **real input actions only, never a teleport.**
## It does not pathfind and it does not know the layout. It steers toward the
## exit; when that stops helping it rotates through everything Ryn can do,
## including walking AWAY — a ladder is often behind you, and a bot that only
## ever presses "toward the goal" cannot find one.
func _demo_traverse_exit() -> void:
	if _traverse_done:
		return
	if not _traverse_blinded:
		# 和横向版同样的理由:测地形,不测潜行。必须在第一个物理帧,不能在 _ready。
		_blind_all_guards()
		_mute_hazards()
		_traverse_blinded = true

	var pos: Vector2 = ryn.global_position
	if _exit_rect.has_point(pos) or pos.distance_to(_exit_goal) <= EXIT_REACH_PX:
		_finish_traverse("REACHABLE — reached the exit at %s" % str(pos.snapped(Vector2(0.1, 0.1))))
		return

	var flat: bool = _tick < _exit_flat_until
	# 卡住判定用的度量:平飞模式下只看 x,否则看直线距离。
	var dist: float = absf(_exit_goal.x - pos.x) if flat else pos.distance_to(_exit_goal)
	_exit_best = minf(_exit_best, pos.distance_to(_exit_goal))
	if dist < _exit_ref - 1.0:
		_exit_ref = dist
		_exit_stuck = 0
	else:
		_exit_stuck += 1
		if _exit_stuck > EXIT_STUCK_GRACE + EXIT_CYCLE:
			_exit_rotations += 1
			if _exit_rotations >= FLAT_AFTER_ROTATIONS and not flat:
				_exit_flat_until = _tick + FLAT_TICKS
				_exit_rotations = 0
				_exit_ref = INF   # 度量变了,参照必须重置
				print("[demo] traverse-exit 切到「只认 x」模式到 tick ", _exit_flat_until,
						" (在 ", pos.snapped(Vector2(0.1, 0.1)), " 卡住)")
			# 一整轮尝试都没有改善:以当前位置重设参照,让「朝目标走」这个基本行为
			# 恢复。不这么做的话 `_exit_stuck` 只增不减,机器人永远停在轮换模式里
			# ——六个尝试里只有两个朝前,净效果是原地抖动。第一版就是这样在左墙边
			# 蹭了 8000 tick,日志看起来像关卡断了,其实是机器人瘸了。
			_exit_stuck = 0
			_exit_ref = dist

	var toward: int = 1 if _exit_goal.x > pos.x else -1
	var want_up: bool = _exit_goal.y < pos.y - 8.0
	var want_down: bool = _exit_goal.y > pos.y + 8.0
	# 「顺手抓梯子」只在目标**显著**更高时才成立。用 8px 阈值的后果实测过:塔1 的
	# 出口 y=292 夹在地面 320 和天桥 272 之间,机器人在 LadderToUpper 上爬上去、
	# 发现目标在下方、再爬下来,无限往复,卡在 x=992 不动。
	var well_above: bool = (not flat) and _exit_goal.y < pos.y - CLIMB_HINT_PX

	_release_dirs()
	var want_interact: bool = false

	if ryn.state == Ryn.State.CLIMBING:
		_exit_jump_hold = 0
		# 在梯子上:垂直优先。同时按横向会把 Ryn 推离梯子,爬到一半掉下来。
		if want_up:
			Input.action_press(&"move_up")
		elif want_down:
			Input.action_press(&"move_down")
		else:
			_press_dir(toward)
	elif _exit_stuck <= EXIT_STUCK_GRACE:
		_press_dir(toward)
		# 目标明显在上方时顺手按住 up:走过梯子就会自动抓住,不必等卡住。
		if well_above:
			Input.action_press(&"move_up")
	else:
		# 顺序是调过的:**就地**的尝试排在前面,会让机器人离开当前位置的排在后面。
		# 反过来排(第一版)会让它在还没试完脚下的办法时就走掉。
		var t: int = (_exit_stuck - EXIT_STUCK_GRACE) % EXIT_CYCLE
		var b1: int = EXIT_ATTEMPT          # 1 跳(朝前)
		var b2: int = b1 + EXIT_ATTEMPT     # 2 蹲行(朝前)
		var b3: int = b2 + EXIT_ATTEMPT     # 3 原地向上(抓梯子)
		var b4: int = b3 + TRAVERSE_INTERACT_TICKS  # 4 拆
		var b5: int = b4 + EXIT_BACK        # 5 退一点
		if t < b1:
			_press_dir(toward)
			_start_jump()
		elif t < b2:
			_press_dir(toward)
			Input.action_press(&"move_down")
		elif t < b3:
			# 不按横向:同时按会把 Ryn 推离梯子。
			Input.action_press(&"move_up")
		elif t < b4:
			# 「破路更安全」也是竖直路线的一部分。interact 和 jump 同理:按住期间
			# 不能每帧松开,否则 `Dismantlable` 的长按会被判为中断。
			want_interact = true
		elif t < b5:
			# 梯子常常在身后。横向版没有这一步,竖直路线缺了它就走不通。
			_press_dir(-toward)
		else:
			_press_dir(-toward)
			_start_jump()

	# **必须在所有分支之后**:倒计时期间无条件按住跳跃,哪怕控制流已经回到基本分支。
	_apply_jump_hold()
	if want_interact:
		Input.action_press(&"interact")
	else:
		Input.action_release(&"interact")

	if _dbg and pos.x > 520.0 and pos.x < 600.0 and _tick < 1400:
		print("[dbg] t=", _tick, " x=", snappedf(pos.x, 0.1), " y=", snappedf(pos.y, 0.1),
				" vy=", snappedf(ryn.velocity.y, 0.1),
				" hold=", _exit_jump_hold,
				" jump_pressed=", Input.is_action_pressed(&"jump"),
				" stuck=", _exit_stuck, " floor=", ryn.is_on_floor())
	if _tick % 60 == 0:
		print("[demo] traverse-exit tick=", _tick,
				" pos=", pos.snapped(Vector2(0.1, 0.1)),
				" dist=", snappedf(dist, 0.1),
				" best=", snappedf(_exit_best, 0.1),
				" ref=", snappedf(_exit_ref, 0.1),
				" stuck=", _exit_stuck, " flat=", flat,
				" state=", Ryn.State.keys()[ryn.state],
				" on_floor=", ryn.is_on_floor())

	if _tick > EXIT_TIMEOUT:
		_finish_traverse("UNREACHABLE — closest approach %.1f px at tick %d (goal %s)"
				% [_exit_best, _tick, str(_exit_goal)])


## ROUTE (`--demo=route`):沿关卡生成器搜出来的路线走,用真实物理验证每一步。
##
## `tools/level_builder` 按 Ryn 的能力(跳 3 格、跨 4 格、蹲着钻 40px、爬梯、通风管、拆东西)
## 在格子上搜出一条从出生点到出口的路,写进场景里的 `DevRoute`。这里一步一步照着走:
## 每一步有目标落脚点和动作,到了就走下一步;一步超过 `ROUTE_STEP_TIMEOUT` 还没到就判失败,
## 并打印是哪一步、在哪里卡住 —— 失败说明「格子上的模型」和「真实物理」对不上,要么关卡
## 要改,要么模型的数要改。守卫和危险物照样关掉:测的是地形。
const ROUTE_STEP_TIMEOUT: int = 600
## 到达判定:水平、竖直容差(px)。
const ROUTE_REACH_X: float = 5.0
const ROUTE_REACH_Y: float = 6.0
var _route: DevRoute
var _route_i: int = 1
var _route_step_ticks: int = 0
var _route_jumped: bool = false
var _route_tapped: bool = false
var _route_wait: int = 0
## 这一步里踩过的最粘的蚀(时限按它放宽;走出蚀也不收回)。
var _route_min_drag: float = 1.0
## `--pace` 时的记录器(`pace_probe.gd`),否则 null。
var _pace: Node = null


func _demo_route() -> void:
	if _traverse_done:
		return
	if not _traverse_blinded:
		_blind_all_guards()
		_mute_hazards()
		_traverse_blinded = true
	if _route_i >= _route.points.size():
		_finish_traverse("REACHABLE — followed all %d route steps to the exit at %s"
				% [_route.points.size(), str(ryn.global_position.snapped(Vector2(0.1, 0.1)))])
		return
	var target: Vector2 = _route.points[_route_i]
	var action: String = _route.actions[_route_i]
	var pos: Vector2 = ryn.global_position
	_route_step_ticks += 1
	# 谜题房的机关面板(2026-10-12):站在原地长按 E,拆完再等机关动完(吊桥倒下、铁卷门卷上去)
	if action == "panel":
		_release_dirs()
		var panel := _panel_near(target)
		if panel == null:
			_finish_traverse("UNREACHABLE — route step %d: no panel near %s" % [_route_i, str(target)])
			return
		if not panel.is_dismantled:
			Input.action_press(&"interact")
			_route_wait = 0
		else:
			Input.action_release(&"interact")
			_route_wait += 1
			if _route_wait >= 90:
				_route_i += 1
				_route_step_ticks = 0
				_route_wait = 0
		if _route_step_ticks > ROUTE_STEP_TIMEOUT:
			_finish_traverse("UNREACHABLE — route step %d (panel) at %s timed out" % [_route_i, str(target)])
		return
	var arrived: bool = absf(pos.x - target.x) <= ROUTE_REACH_X and absf(pos.y - target.y) <= ROUTE_REACH_Y \
			and ryn.state == Ryn.State.NORMAL and ryn.is_on_floor()
	if arrived:
		_route_i += 1
		_route_step_ticks = 0
		_route_min_drag = 1.0
		_route_jumped = false
		_route_tapped = false
		if _route_i % 10 == 0:
			print("[demo] route step %d/%d at %s" % [_route_i, _route.points.size(), str(pos.snapped(Vector2(0.1, 0.1)))])
		return
	# 时限按这一步的水平距离放宽:合并后的一步可能是整条走廊(走 1.75px/tick,蹲行 0.73px/tick)
	var per_tick: float = 0.6 if action == "crawl" else 1.5
	# 踩在蚀里走得慢(下行关的蚀池只有 1/4 速度):时限跟着放宽
	_route_min_drag = minf(_route_min_drag, ryn.ground_drag)
	per_tick *= clampf(_route_min_drag, 0.2, 1.0)
	var prev_x: float = _route.points[_route_i - 1].x
	# 爬梯是竖着走的:按这一步的高度和设定的爬速放宽(2026-10-15 爬速 56 → 40,长梯子超过固定的 10 秒)
	var climb_ticks: int = 0
	if action.begins_with("climb"):
		climb_ticks = int(absf(target.y - _route.points[_route_i - 1].y) / (ryn.config.climb_speed / 60.0 * 0.8))
	if _route_step_ticks > ROUTE_STEP_TIMEOUT + climb_ticks + int(absf(target.x - prev_x) / per_tick):
		_finish_traverse("UNREACHABLE — route step %d (%s) to %s timed out at %s state=%s"
				% [_route_i, action, str(target), str(pos.snapped(Vector2(0.1, 0.1))),
				Ryn.State.keys()[ryn.state]])
		return
	_release_dirs()
	Input.action_release(&"sprint")
	var dir: int = 1 if target.x > pos.x else -1
	var near_x: bool = absf(pos.x - target.x) <= ROUTE_REACH_X
	var want_interact: bool = false
	# 落地了但站得比目标高(冲过头踩在下一块的边角上):往目标挪,从边上走下去
	if ryn.is_on_floor() and ryn.state == Ryn.State.NORMAL and pos.y < target.y - ROUTE_REACH_Y \
			and action in ["jump", "gap", "drop", "walk", "crawl"] and absf(pos.x - target.x) > 1.0 \
			and absf(pos.x - target.x) <= 12.0:
		_press_dir(dir)
		_apply_jump_hold()
		return
	match action:
		"walk":
			if not near_x:
				_press_dir(dir)
		"crawl":
			Input.action_press(&"move_down")
			if not near_x:
				_press_dir(dir)
		"jump", "gap":
			if action == "gap":
				Input.action_press(&"sprint")
			if not near_x:
				_press_dir(dir)
			if ryn.is_on_floor() and absf(pos.y - target.y) > ROUTE_REACH_Y or (action == "gap" and ryn.is_on_floor() and not near_x):
				if not _route_jumped or _exit_jump_hold <= 0:
					_start_jump()
					_route_jumped = true
		"drop":
			if not near_x:
				_press_dir(dir)
		"climb_up":
			if ryn.state == Ryn.State.CLIMBING:
				Input.action_press(&"move_up")
			elif absf(pos.x - target.x) > 4.0 and pos.y > target.y + ROUTE_REACH_Y:
				_press_dir(dir)
			else:
				Input.action_press(&"move_up")
		"climb_down":
			if ryn.state == Ryn.State.CLIMBING:
				Input.action_press(&"move_down")
			elif absf(pos.x - target.x) > 4.0 and pos.y < target.y - ROUTE_REACH_Y:
				_press_dir(dir)
			else:
				Input.action_press(&"move_down")
		"vent":
			# 站在管口按一下 E;之后等人从另一头出来
			if ryn.state == Ryn.State.NORMAL and not _route_tapped:
				want_interact = _route_step_ticks % 6 < 3
				if _route_step_ticks > 6:
					_route_tapped = true
		"dismantle_hatch", "dismantle_fence":
			if ryn.is_on_floor() and absf(pos.y - target.y) > ROUTE_REACH_Y or (action == "dismantle_fence" and not near_x):
				want_interact = true
				if action == "dismantle_fence":
					_press_dir(dir)
	_apply_jump_hold()
	if want_interact:
		Input.action_press(&"interact")
	else:
		Input.action_release(&"interact")
	if _tick % 120 == 0 or (_dbg and _tick < 400):
		print("[demo] route tick=%d step=%d/%d %s → %s pos=%s state=%s floor=%s" % [_tick, _route_i,
				_route.points.size(), action, str(target), str(pos.snapped(Vector2(0.1, 0.1))),
				Ryn.State.keys()[ryn.state], ryn.is_on_floor()])


## 离 `at`(Ryn 站的地面那一点)最近的机关面板(48px 内)。
func _panel_near(at: Vector2) -> Dismantlable:
	var best: Dismantlable = null
	var best_d: float = 48.0
	for n in get_tree().get_nodes_in_group(Dismantlable.GROUP):
		var p := n as Dismantlable
		if p == null or p.kind != Dismantlable.Kind.PANEL:
			continue
		var d: float = (p.global_position + p.size * 0.5).distance_to(at + Vector2(0.0, -20.0))
		if d < best_d:
			best_d = d
			best = p
	return best


## 只在站在地面上且上一跳已经按完时起跳,避免空中反复重置倒计时。
func _start_jump() -> void:
	if _exit_jump_hold <= 0 and ryn.is_on_floor():
		_exit_jump_hold = EXIT_JUMP_HOLD


func _press_dir(dir: int) -> void:
	if dir >= 0:
		Input.action_press(&"move_right")
	else:
		Input.action_press(&"move_left")


## 只松开方向键。**跳跃和 interact 不在这里松** —— 见 `_apply_jump_hold`。
func _release_dirs() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	Input.action_release(&"move_down")


## 按住期间**绝不插入 release**。
##
## `Ryn._poll_input` 用 `Input.is_action_just_pressed(&"jump")` 触发起跳。第一版
## 每帧先 release 再 press,实测结果是 `is_action_pressed` 为真(所以 `jump_held`
## 成立)但起跳**一次都没触发**:日志里 `jump_pressed=true hold=21..0` 而 `vy=0.0`、
## y 一动不动,整整 30 帧。横向版 `_demo_traverse` 从来不这么做 —— 它在按住期间
## 连续按住,所以它能跳。
func _apply_jump_hold() -> void:
	if _exit_jump_hold > 0:
		_exit_jump_hold -= 1
		Input.action_press(&"jump")
	else:
		Input.action_release(&"jump")


func _release_all_moves() -> void:
	_release_dirs()
	_exit_jump_hold = 0
	Input.action_release(&"jump")
	Input.action_release(&"interact")


func _on_traverse_spotted(_player: Node2D, _by: Guard) -> void:
	# Guards are blinded for this demo, so a sighting means the blinding did not
	# take. Reporting it as a pass is how a broken check looks identical to a
	# working one — the run is INCONCLUSIVE, not REACHABLE.
	_finish_traverse("INCONCLUSIVE — guard blinding failed; spotted at x=%.1f, so terrain east of here was never walked" % _traverse_best_x)


func _finish_traverse(verdict: String) -> void:
	if _traverse_done:
		return
	_traverse_done = true
	_release_all_moves()
	print("[demo] TRAVERSE RESULT: ", verdict)
	if _pace != null:
		_pace.call("report", verdict)
	get_tree().quit(0 if verdict.begins_with("REACHABLE") else 1)


func _log_reset(label: String) -> void:
	print("[demo] reset ", label, " tick=", _tick, " frame=", Engine.get_frames_drawn(),
			" phase=", FailSequence.Phase.keys()[detection_reset.phase()],
			" ryn=", ryn.global_position.snapped(Vector2(0.1, 0.1)),
			" ryn_vx=", snappedf(ryn.velocity.x, 0.1),
			" input_enabled=", ryn.input_enabled,
			" guard=", guard.global_position.snapped(Vector2(0.1, 0.1)),
			" guard_state=", Guard.State.keys()[guard.state],
			" respawn=", checkpoints.respawn_position().snapped(Vector2(0.1, 0.1)),
			" snapshot=", checkpoints.snapshot_size())


func _on_reset_phase(phase: FailSequence.Phase) -> void:
	_log_reset("PHASE->" + FailSequence.Phase.keys()[phase])


func _on_control_restored() -> void:
	_log_reset("CONTROL RESTORED")


func _on_checkpoint_activated(checkpoint: Checkpoint) -> void:
	print("[demo] reset CHECKPOINT ", checkpoint.name, " at ", checkpoint.respawn_position(),
			" tick=", _tick, " frame=", Engine.get_frames_drawn())


func _on_player_spotted(player: Node2D, by_guard: Guard) -> void:
	print("[demo] SIGNAL player_spotted player=", player.name, " guard=", by_guard.name,
			" tick=", _tick)


## STORY 004 DARKNESS DEMOS — all four place Ryn in the open stretch east of the
## guard's spawn, where nothing occludes the view, and pin the guard facing her.
## The only variable left is darkness, which is the point.
##
##   shadow-safe         inside ShadowZoneDeep  -> in cone, clear LOS, NOT seen
##   shadow-lit          in the gap between zones -> in cone, clear LOS, SEEN
##   shadow-crouch       crouched in ShadowZoneLow -> hidden (low zone covers the
##                       crouched sight point)
##   shadow-crouch-stand standing in the SAME low zone -> SEEN, because standing
##                       lifts the sight point above the zone's top edge

## Floor surface in the testbed.
const SHADOW_FLOOR_Y: float = 320.0
## Centre of ShadowZoneDeep (x 1210..1290).
const SHADOW_SAFE_X: float = 1250.0
## The lit gap between the two zones (x 1290..1320).
const SHADOW_LIT_X: float = 1305.0
## Centre of ShadowZoneLow (x 1320..1390), the 19 px-tall crouch-only zone (covers the
## crouched sight point 17 px up, not the standing one 21 px up).
const SHADOW_CROUCH_X: float = 1355.0


func _shadow_demo_x() -> float:
	match _mode:
		"shadow-safe":
			return SHADOW_SAFE_X
		"shadow-lit":
			return SHADOW_LIT_X
		_:
			return SHADOW_CROUCH_X


func _demo_shadow_watch() -> void:
	if _tick % 20 == 0:
		_log_shadow()


func _log_shadow() -> void:
	if guard == null or ryn == null:
		return
	var sight: Vector2 = guard.sight_point(ryn)
	var in_cone: bool = GuardVision.is_in_cone(guard.eye_position(), sight,
			Vector2(float(guard.facing), 0.0), guard.current_half_angle(),
			guard.current_range())
	var in_shadow: bool = false
	var zones: int = -1
	if shadows != null:
		in_shadow = shadows.covers(sight)
		zones = shadows.zone_count()
	print("[demo] shadow tick=", _tick, " frame=", Engine.get_frames_drawn(),
			" ryn=", ryn.global_position.snapped(Vector2(0.1, 0.1)),
			" crouch=", ryn.is_crouching,
			" body_height=", ryn.get_body_height(),
			" sight_point=", sight.snapped(Vector2(0.1, 0.1)),
			" zones=", zones,
			" in_shadow=", in_shadow,
			" in_cone=", in_cone,
			" can_see=", guard.can_see(sight),
			" guard_state=", Guard.State.keys()[guard.state])


## STORY 005 DISMANTLE DEMOS — 手巧拆物件 and what it does to the guards.
##
##   dismantle-prompt  Ryn in reach of the FloorHatch, pressing nothing:
##                     the 1px 亮边 brightens and 「E 拆」 appears (AC1).
##   dismantle-hatch   holds `interact` through all four steps: the segmented
##                     progress bar fills (AC2), the plate's collision goes
##                     (AC3), and Guard2 — standing on it — falls (AC4).
##   dismantle-abort   releases at ~55%: progress returns to 0, nothing opens.
##   dismantle-fence   opens the FenceGrate: a sideways passage (AC3/AC5) and
##                     the main guard's patrol widens through it (AC4 改道).
##   dismantle-reset   dismantles the hatch, then rolls the checkpoint back:
##                     the plate is solid again and Guard2 is back on it (AC6).
##
## Every one of them presses the REAL `interact` action through the Input Map,
## so a project.godot that did not take would fail here rather than look fine.

## Ryn's spot on the catwalk's west plate, in reach of the FloorHatch.
const DM_CATWALK_X: float = 1440.0
## Catwalk walking surface.
const DM_CATWALK_Y: float = 256.0
## Ryn's spot on the floor beside the FenceGrate.
const DM_FENCE_X: float = 1492.0
## Behind the fence, inside ShadowZoneNook, where the re-routed guard cannot
## see her walk in.
const DM_NOOK_X: float = 1522.0
## Testbed floor surface.
const DM_FLOOR_Y: float = 320.0
## Tick the scripted hold begins on (after the window has settled and focus
## events have stopped releasing actions).
const DM_PRESS_TICK: int = 60
## Tick `dismantle-reset` rolls the checkpoint back on.
const DM_RESTORE_TICK: int = 220


func _demo_dismantle_prompt() -> void:
	if _tick % 20 == 0:
		_log_dismantle("prompt")
	if _tick == 140:
		_log_dismantle("done")
		get_tree().quit()


func _demo_dismantle_hatch() -> void:
	_hold_interact(hatch, _tick >= DM_PRESS_TICK)
	if _tick % 10 == 0:
		_log_dismantle("hatch")
	if _tick == 300:
		_log_dismantle("done")
		get_tree().quit()


func _demo_dismantle_abort() -> void:
	# 30..70 is ~0.67 s of a 1.2 s hold: past two of the four steps.
	_hold_interact(hatch, _tick >= 30 and _tick < 70)
	if _tick == 69:
		_log_dismantle("ABOUT TO RELEASE")
	if _tick == 71:
		_log_dismantle("JUST RELEASED")
	if _tick % 10 == 0:
		_log_dismantle("abort")
	if _tick == 140:
		_log_dismantle("done")
		get_tree().quit()


func _demo_dismantle_fence() -> void:
	_hold_interact(fence, _tick >= DM_PRESS_TICK)
	if _tick % 20 == 0:
		_log_dismantle("fence")
	if _tick == 400:
		_log_dismantle("done")
		get_tree().quit()


func _demo_dismantle_reset() -> void:
	# The hold stops before the rollback: re-pressing afterwards would simply
	# dismantle the restored panel again and prove nothing.
	_hold_interact(hatch, _tick >= DM_PRESS_TICK and _tick < DM_RESTORE_TICK)
	if _tick == DM_RESTORE_TICK:
		_log_dismantle("BEFORE RESTORE")
		# Ryn is repositioned by RynResetAdapter as part of the same snapshot,
		# so the demo does NOT touch her position here.
		checkpoints.restore()
	if _tick == DM_RESTORE_TICK + 2:
		_log_dismantle("AFTER RESTORE")
	if _tick % 10 == 0:
		_log_dismantle("reset")
	if _tick == 340:
		_log_dismantle("done")
		get_tree().quit()


## Presses or releases `interact` every tick. Re-pressing is deliberate: Godot
## releases all actions on a focus change, and a single released frame would
## throw the whole hold away (which is the rule, not a bug).
func _hold_interact(panel: Dismantlable, want: bool) -> void:
	if want and panel != null and not panel.is_dismantled:
		Input.action_press(&"interact")
	else:
		Input.action_release(&"interact")


func _log_dismantle(label: String) -> void:
	var patrol: Vector2 = Vector2.ZERO
	var rerouted: bool = false
	if fence != null and fence.reroute != null:
		patrol = fence.reroute.bounds()
		rerouted = fence.reroute.is_applied()
	print("[demo] dismantle ", label, " tick=", _tick, " frame=", Engine.get_frames_drawn(),
			" ryn=", ryn.global_position.snapped(Vector2(0.1, 0.1)),
			" interact_held=", Input.is_action_pressed(&"interact"),
			" hatch_near=", hatch.is_player_in_reach(),
			" hatch_ratio=", snappedf(hatch.progress_ratio(), 0.01),
			" hatch_step=", str(hatch.step_done(), "/", hatch.step_total()),
			" hatch_open=", hatch.is_dismantled,
			" fence_near=", fence.is_player_in_reach(),
			" fence_ratio=", snappedf(fence.progress_ratio(), 0.01),
			" fence_open=", fence.is_dismantled,
			" guard_x=", snappedf(guard.global_position.x, 0.1),
			" guard_state=", Guard.State.keys()[guard.state],
			" patrol_bounds=", patrol, " rerouted=", rerouted,
			" guard2=", guard2.global_position.snapped(Vector2(0.1, 0.1)),
			" guard2_state=", Guard.State.keys()[guard2.state],
			" snapshot=", checkpoints.snapshot_size())


func _on_panel_dismantled(noticed: int, which: String) -> void:
	print("[demo] dismantle SIGNAL ", which, " dismantled, guards_alerted=", noticed,
			" tick=", _tick, " frame=", Engine.get_frames_drawn())
	if which == "fence":
		# Staging, logged so it is not mistaken for proof: the guard is placed
		# at 1430 — INSIDE its old 1180..1440 route, so this move was always
		# legal — and then walks PAST 1440 to the new bound, which is the thing
		# the fence actually changed. Without it the capture needs ~650 ticks.
		guard.global_position.x = 1430.0
		guard.facing = 1
		# Ryn steps through the new passage into the dark nook so the re-routed
		# guard can walk in without the demo collapsing into a fail sequence.
		ryn.global_position = Vector2(DM_NOOK_X, DM_FLOOR_Y)
		_log_dismantle("STAGED guard_x=1430 (old max 1440) + Ryn into the nook")


func _on_dismantle_step(index: int, total: int, which: String) -> void:
	print("[demo] dismantle STEP ", which, " ", index, "/", total,
			" tick=", _tick, " frame=", Engine.get_frames_drawn())


func _on_dismantle_aborted(lost: float, which: String) -> void:
	print("[demo] dismantle ABORTED ", which, " lost=", lost, " ratio_now=",
			snappedf(hatch.progress_ratio(), 0.01), " tick=", _tick)


func _on_panel_restored(dismantled: bool, which: String) -> void:
	print("[demo] dismantle RESTORED ", which, " dismantled=", dismantled,
			" tick=", _tick, " frame=", Engine.get_frames_drawn())
