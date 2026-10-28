class_name Dismantlable
extends Area2D
## A DESIGN-MARKED panel Ryn can take apart: hold `interact` nearby and the
## panel's collision geometry goes away, opening a route and changing what the
## guards can do.
##
## Implements `production/epics/the-cradle/story-005-dismantle-interaction.md`.
## Story 006 owns WHERE panels go; Story 007 reuses this interaction for
## 切断方舟节点, which is why nothing here knows about a level.
##
## ## Dismantling is NOT universal
##
## 叙事脚本.md 塔 1 is explicit — 「门禁我撬不开，但缝我钻得过」. 手巧 is one
## action against MARKED objects, not a skill that opens anything. So a panel is
## a node a designer placed on purpose; there is no "scan the level for things
## that look removable" path, and adding one would break the setting.
##
## ## What finishing a dismantle does
##
## Three things, together, every time:
##  1. **Geometry** — the panel's `StaticBody2D` stops colliding, so a new route
##     exists (a hole to drop through, or a passage to walk through).
##  2. **Guard navigation** — a FLOOR_HATCH under a guard removes the floor it
##     stands on and it falls (gravity, already in `Guard`); a `GuardReroute`
##     child instead rewrites the guard's patrol bounds. 坠落 **or** 改道, picked
##     per panel in the scene.
##  3. **Noise** — every node within `config.noise_radius` that answers
##     `report_disturbance()` is alerted. Work is loud; that is the cost.
##
## ## Rollback
##
## The panel joins `CheckpointManager.RESETTABLE_GROUP` and implements the
## duck-typed snapshot interface. Collision, visuals, held progress and the
## guard reroute all restore from one dictionary, so a reset can never leave a
## ghost passage behind (the hard-coupling point Story 003 flagged).
##
## Node origin is the TOP-LEFT corner, matching `GrayBlock`, `Ladder` and
## `ShadowZone`, so panels line up on the 16 px grid. No rotation, no scale.
##
## Usage (in a scene): instance `dismantlable.tscn`, set `position`, `size` and
## `kind`; add a `GuardReroute` child to change a patrol instead of dropping a
## guard.
## Usage (in code):
##     var panel := Dismantlable.new()
##     panel.config = load("res://assets/data/dismantle_default.tres")
##     panel.kind = Dismantlable.Kind.FENCE
##     panel.size = Vector2(8, 48)
##     panel.position = Vector2(1500, 272)
##     panel.dismantled.connect(_on_opened)
##     add_child(panel)

enum Kind {
	## A floor plate. Removing it opens a hole DOWNWARD: Ryn drops through and
	## anything standing on it falls.
	FLOOR_HATCH,
	## A fence or grate. Removing it opens a passage SIDEWAYS.
	FENCE,
	## 墙上的机关(2026-10-12 谜题房):链条锚、阀门、配电箱、控制面板、通风口盖板。**没有碰撞** ——
	## 拆它不开路,而是让别的东西动起来:`ShutterDoor` / `DropBridge` / `SteamValve` / `FuseBox` 听
	## `panel_dismantled` / `panel_restored`。会自己复原的(阀门、配电箱)由它们调 `rearm()`。
	PANEL,
}

## PANEL 画成什么。
enum Look {
	PLAIN,
	## 吊桥的链条锚:墙上一块铁板、一个环,链子从环里拉出去。
	CHAIN,
	## 蒸汽管上的阀门手轮。
	VALVE,
	## 配电箱:灰铁箱、闪电标。
	FUSE,
	## 控制面板:三个小开关、两盏指示灯。
	CONTROL,
	## 通风口的螺栓盖板:横栅 + 四颗螺栓,盖在管口上。
	VENT_COVER,
}

## Group every panel joins, so demos and a later level script can find them all.
const GROUP: StringName = &"dismantlable"
## The Input Map action that works a panel (`project.godot` [input]: E / pad X).
const INTERACT_ACTION: StringName = &"interact"

## Emitted on the tick a hold begins.
signal dismantle_started
## Emitted each time another step finishes. `index` is 1..`total`.
signal dismantle_step(index: int, total: int)
## Emitted when a hold is released before finishing. `lost` is the 0..1 progress
## thrown away.
signal dismantle_aborted(lost: float)
## Emitted once when the panel comes apart. `noticed` is how many guards heard it.
signal panel_dismantled(noticed: int)
## Emitted after a checkpoint rollback changed this panel's state.
signal panel_restored(dismantled: bool)

## Panel size in px. Grows right and down from the origin, like `GrayBlock`.
@export var size: Vector2 = Vector2(48.0, 16.0):
	set(value):
		size = value
		_sync_shapes()
		_sync_prompt_placement()
		queue_redraw()

## Which way the opened route runs, and how the panel is drawn. Layout, so it
## lives on the node rather than in the config.
@export var kind: Kind = Kind.FLOOR_HATCH:
	set(value):
		kind = value
		queue_redraw()

## Tuning. Required to draw or to work; an unset config leaves an inert solid
## panel (the rule is geometry, not paint).
@export var config: DismantleConfig:
	set(value):
		config = value
		_sync_tuning()
		queue_redraw()

## Optional per-panel override of `config.hold_duration`, seconds. 0 means "use
## the config". A heavier panel is scene layout, the same way `patrol_offset` is.
@export var hold_duration_override: float = 0.0:
	set(value):
		hold_duration_override = value
		_sync_tuning()

## Optional guard re-route applied when the panel opens. Usually a child node.
@export var reroute: GuardReroute
## PANEL 的样子。
@export var look: Look = Look.PLAIN:
	set(value):
		look = value
		queue_redraw()

## True once the panel has come apart. Change it through the interaction or
## `restore_state()`, not by assignment.
var is_dismantled: bool = false

var _progress: DismantleProgress = DismantleProgress.new()
var _area_shape: RectangleShape2D
var _area_collider: CollisionShape2D
var _solid: StaticBody2D
var _solid_shape: RectangleShape2D
var _solid_collider: CollisionShape2D
var _prompt: Label
var _players: Array[Node2D] = []
var _last_ratio: float = -1.0
var _last_near: bool = false


func _ready() -> void:
	# The panel senses Ryn and nothing senses the panel: `monitorable` off keeps
	# it out of the guards' vision broad phase, which only wants PLAYER.
	collision_layer = PhysicsLayers.DISMANTLABLE
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	monitorable = false

	_area_shape = RectangleShape2D.new()
	_area_collider = CollisionShape2D.new()
	_area_collider.shape = _area_shape
	add_child(_area_collider)

	# The solid half is a child body, not this Area2D: an Area2D cannot hold the
	# world collision Ryn and the guards stand on, and keeping them separate is
	# what lets the collision vanish while the prompt and the ghost outline stay.
	_solid = StaticBody2D.new()
	_solid.name = "Solid"
	_solid.collision_layer = PhysicsLayers.WORLD
	_solid.collision_mask = 0
	_solid_shape = RectangleShape2D.new()
	_solid_collider = CollisionShape2D.new()
	_solid_collider.shape = _solid_shape
	_solid.add_child(_solid_collider)
	add_child(_solid)

	if kind == Kind.PANEL:
		# 墙上的机关不挡路;画在人后面(挂在墙上,Ryn 站在它前面拆 —— 画在前面会盖住她的脸)
		_solid_collider.disabled = true
		_solid.collision_layer = 0
		z_index = -1

	_prompt = _build_prompt()
	add_child(_prompt)

	_sync_shapes()
	_sync_prompt_placement()
	_sync_tuning()
	_set_prompt_shown(false)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group(GROUP)
	add_to_group(CheckpointManager.RESETTABLE_GROUP)


func _physics_process(delta: float) -> void:
	if config == null:
		return
	var near: bool = is_player_in_reach()
	if is_dismantled:
		if _last_near or _prompt.visible:
			_set_prompt_shown(false)
			_last_near = false
		if kind == Kind.PANEL and look == Look.FUSE:
			queue_redraw()   # 拆开的配电箱里冒火花
		return

	var was_started: bool = _progress.is_started()
	var ratio_before: float = _progress.ratio()
	var step_before: int = _progress.step_index()
	var holding: bool = near and Input.is_action_pressed(INTERACT_ACTION)
	var finished: bool = _progress.advance(delta, holding)

	if not was_started and _progress.is_started():
		dismantle_started.emit()
	var step_after: int = _progress.step_index()
	if step_after > step_before:
		dismantle_step.emit(step_after, _progress.steps())
	if was_started and not _progress.is_started():
		# Released early: 叙事's 「拧三下，再撬」 is one unbroken motion.
		dismantle_aborted.emit(ratio_before)
	if finished:
		_finish()

	if near != _last_near:
		_set_prompt_shown(near)
		_last_near = near
	var ratio: float = _progress.ratio()
	if not is_equal_approx(ratio, _last_ratio):
		_last_ratio = ratio
		queue_redraw()


## True while Ryn (anything on the PLAYER layer) is inside the panel's reach.
## This is exactly the area the 「E 拆」 prompt appears for, so the cue and the
## rule cannot drift apart.
##
## Usage: `if panel.is_player_in_reach(): ...`
func is_player_in_reach() -> bool:
	for body in _players:
		if body != null and is_instance_valid(body):
			return true
	return false


## Progress of the hold in flight, 0..1. 1 once dismantled.
func progress_ratio() -> float:
	return _progress.ratio()


## Steps finished so far, 0..`step_total()`.
func step_done() -> int:
	return _progress.step_index()


## Total steps in one dismantle (from the config).
func step_total() -> int:
	return _progress.steps()


## Seconds of continuous hold this panel takes, after the override.
func hold_duration() -> float:
	return _progress.duration()


## The panel in world space — exactly the rectangle `_draw` paints and the
## collision that disappears.
##
## Usage: `var r := panel.global_rect()`
func global_rect() -> Rect2:
	return Rect2(global_position, size)


## The reach area in world space, i.e. `global_rect()` grown by
## `config.reach_padding`.
func reach_rect() -> Rect2:
	var pad: float = 0.0 if config == null else maxf(config.reach_padding, 0.0)
	return Rect2(global_position - Vector2(pad, pad), size + Vector2(pad, pad) * 2.0)


## Takes the panel apart immediately, skipping the hold. For Story 007's scripted
## 切断 and for demos; normal play goes through the hold.
##
## Usage: `panel.force_dismantle()`
func force_dismantle() -> void:
	if is_dismantled:
		return
	_progress.set_ratio(1.0)
	_finish()


## 装回去(阀门自己关上、配电箱修好了):又能拆一次。不发 `panel_restored` —— 那个只给存档回滚用。
##
## Usage: `panel.rearm()`
func rearm() -> void:
	is_dismantled = false
	_progress.set_ratio(0.0)
	_apply_collision(false)
	_last_ratio = -1.0
	_last_near = false
	queue_redraw()


## Snapshots the panel for `CheckpointManager`. Keys: `dismantled` (bool),
## `ratio` (float 0..1, the hold in flight), `rerouted` (bool).
##
## Usage: `var s: Dictionary = panel.capture_state()`
func capture_state() -> Dictionary:
	return {
		&"dismantled": is_dismantled,
		&"ratio": _progress.ratio(),
		&"rerouted": reroute != null and reroute.is_applied(),
	}


## Restores collision, visuals, held progress and the guard re-route together.
## Restoring them apart is the bug Story 003 warned about: geometry back but the
## patrol still rewritten, or a ghost passage with the panel drawn over it.
##
## Usage: `panel.restore_state(s)`
func restore_state(state: Dictionary) -> void:
	var opened: bool = bool(state.get(&"dismantled", false))
	_progress.set_ratio(1.0 if opened else float(state.get(&"ratio", 0.0)))
	is_dismantled = opened
	_apply_collision(opened)
	if reroute != null:
		reroute.set_opened(bool(state.get(&"rerouted", opened)))
	_last_ratio = -1.0
	_last_near = false
	_set_prompt_shown(false)
	queue_redraw()
	panel_restored.emit(opened)


func _finish() -> void:
	is_dismantled = true
	_apply_collision(true)
	if reroute != null:
		reroute.apply()
	var noticed: int = _alert_nearby()
	_set_prompt_shown(false)
	_last_near = false
	_last_ratio = -1.0
	queue_redraw()
	panel_dismantled.emit(noticed)


func _apply_collision(opened: bool) -> void:
	if _solid_collider == null or _solid == null:
		return
	if kind == Kind.PANEL:
		return
	# Deferred: this runs inside a physics callback (and inside a guard's own
	# tick, since removing the floor is what drops it), where mutating a shape
	# flushes mid-step.
	_solid_collider.set_deferred(&"disabled", opened)
	_solid.set_deferred(&"collision_layer", 0 if opened else PhysicsLayers.WORLD)


## Alerts everything within `config.noise_radius` that answers
## `report_disturbance()`, measured from the panel's CENTRE to the node's own
## origin (a guard's origin is its feet). Returns how many were alerted.
##
## Duck-typed and discovered by walking the scene, not wired: guards do not join
## a group and `guard.gd` is read-only, and a panel that needed hand-wiring to
## every guard in earshot would silently go quiet the moment a level moved one.
## It runs once per dismantle, never per frame.
func _alert_nearby() -> int:
	if config == null or config.noise_radius <= 0.0:
		return 0
	var centre: Vector2 = global_position + size * 0.5
	var listeners: Array[Node2D] = []
	var root: Node = owner if owner != null else get_tree().current_scene
	if root == null:
		root = get_tree().root
	_collect_listeners(root, listeners)
	var noticed: int = 0
	for node in listeners:
		if centre.distance_to(node.global_position) > config.noise_radius:
			continue
		node.call(&"report_disturbance")
		noticed += 1
	return noticed


func _collect_listeners(node: Node, into: Array[Node2D]) -> void:
	var as_2d := node as Node2D
	if as_2d != null and as_2d.has_method(&"report_disturbance"):
		into.append(as_2d)
	for child in node.get_children():
		_collect_listeners(child, into)


func _sync_shapes() -> void:
	if _area_shape != null and _area_collider != null:
		var pad: float = 0.0 if config == null else maxf(config.reach_padding, 0.0)
		_area_shape.size = size + Vector2(pad, pad) * 2.0
		_area_collider.position = size * 0.5
	if _solid_shape != null and _solid_collider != null:
		_solid_shape.size = size
		_solid_collider.position = size * 0.5


func _sync_tuning() -> void:
	if config == null:
		return
	var duration: float = config.hold_duration
	if hold_duration_override > 0.0:
		duration = hold_duration_override
	var keep: float = _progress.ratio()
	_progress.configure(duration, config.steps)
	_progress.set_ratio(keep)
	_sync_shapes()


func _build_prompt() -> Label:
	var label := Label.new()
	label.name = "Prompt"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if config == null:
		return label
	label.text = config.prompt_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	# Default Control anchors are all 0 (equal opposite anchors), so assigning
	# `size` here is NOT the case ui-canvaslayer.md warns about — the layout pass
	# has nothing to override it with.
	label.size = Vector2(config.prompt_box_width, float(config.prompt_font_size) + 4.0)
	var font := SystemFont.new()
	font.font_names = config.prompt_font_names
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", config.prompt_font_size)
	label.add_theme_color_override(&"font_color", config.prompt_color)
	if config.prompt_outline_size > 0:
		label.add_theme_constant_override(&"outline_size", config.prompt_outline_size)
		label.add_theme_color_override(&"font_outline_color", config.prompt_outline_color)
	return label


func _sync_prompt_placement() -> void:
	if _prompt == null or config == null:
		return
	var box: Vector2 = _prompt.size
	_prompt.position = Vector2(size.x * 0.5 - box.x * 0.5,
			-config.prompt_gap - config.bar_gap - config.bar_size.y - box.y)


func _set_prompt_shown(shown: bool) -> void:
	if _prompt == null:
		return
	if shown and config != null:
		_prompt.text = KeyBindings.with_key(config.prompt_text)   # 改过按键,提示跟着变
	_prompt.visible = shown


func _on_body_entered(body: Node2D) -> void:
	if body == null or _players.has(body):
		return
	_players.append(body)


func _on_body_exited(body: Node2D) -> void:
	_players.erase(body)


func _draw() -> void:
	if config == null:
		return
	var w: float = maxf(size.x, 0.0)
	var h: float = maxf(size.y, 0.0)
	if w <= 0.0 or h <= 0.0:
		return
	var thick: float = maxf(config.edge_thickness, 1.0)

	if kind == Kind.PANEL and look != Look.PLAIN:
		_draw_look(w, h, is_dismantled)
		if is_dismantled:
			return
	elif is_dismantled:
		_draw_remnant(w, h, thick)
		return
	else:
		draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), config.body_color)
	match kind:
		Kind.FENCE:
			_draw_slats(w, h)
		Kind.FLOOR_HATCH:
			_draw_bolts(w, h)
	# 美术规格.md §5's 1px 亮边: the same outline all the time, brightened the
	# moment Ryn is in reach. One cue, two states, no extra art.
	var near: bool = _last_near
	var tint: Color = config.edge(near)
	draw_rect(Rect2(0.0, 0.0, w, thick), tint)
	draw_rect(Rect2(0.0, h - thick, w, thick), tint)
	draw_rect(Rect2(0.0, 0.0, thick, h), tint)
	draw_rect(Rect2(w - thick, 0.0, thick, h), tint)

	if _progress.is_started():
		_draw_progress(w)


## The faint outline of a panel that is gone, so an opened route still reads as
## something Ryn opened rather than a hole that was always there.
func _draw_remnant(w: float, h: float, thick: float) -> void:
	var tint: Color = config.remnant()
	draw_rect(Rect2(0.0, 0.0, w, thick), tint)
	draw_rect(Rect2(0.0, h - thick, w, thick), tint)
	draw_rect(Rect2(0.0, 0.0, thick, h), tint)
	draw_rect(Rect2(w - thick, 0.0, thick, h), tint)


func _draw_slats(w: float, h: float) -> void:
	var step: float = maxf(config.slat_width + config.slat_gap, 1.0)
	var bar: float = clampf(config.slat_width, 1.0, step)
	var tint: Color = config.edge_color
	if h >= w:
		var y: float = step
		while y < h - 1.0:
			draw_rect(Rect2(0.0, y, w, bar), tint)
			y += step
	else:
		var x: float = step
		while x < w - 1.0:
			draw_rect(Rect2(x, 0.0, bar, h), tint)
			x += step


func _draw_bolts(w: float, h: float) -> void:
	var r: float = maxf(config.bolt_radius, 0.5)
	var inset: float = r + 2.0
	var tint: Color = config.edge_color
	draw_circle(Vector2(inset, inset), r, tint)
	draw_circle(Vector2(w - inset, inset), r, tint)
	draw_circle(Vector2(inset, h - inset), r, tint)
	draw_circle(Vector2(w - inset, h - inset), r, tint)


func _draw_progress(w: float) -> void:
	var bar: Vector2 = config.bar_size
	if bar.x <= 0.0 or bar.y <= 0.0:
		return
	var origin := Vector2(w * 0.5 - bar.x * 0.5, -config.bar_gap - bar.y)
	draw_rect(Rect2(origin, bar), config.bar_back())
	var filled: float = bar.x * _progress.ratio()
	if filled > 0.0:
		draw_rect(Rect2(origin, Vector2(filled, bar.y)), config.bar_fill_color)
	# Step dividers: 「拧三下，再撬」 is four moves, so the bar is four notches.
	var total: int = _progress.steps()
	var i: int = 1
	while i < total:
		var x: float = origin.x + bar.x * float(i) / float(total)
		draw_rect(Rect2(x, origin.y, 1.0, bar.y), config.bar_step_color)
		i += 1


## 墙上机关的样子(PANEL)。`open` = 拆开之后。都用美术规格的冷色,只有配电箱的火花和阀门的小牌子带一点锈红。
func _draw_look(w: float, h: float, open: bool) -> void:
	var body: Color = config.body_color
	var edge: Color = config.edge_color
	var dark := Color("0B1220")
	var rust := Color(0.545, 0.227, 0.184, 0.9)
	var white := Color(0.784, 0.831, 0.878, 0.8)
	match look:
		Look.CHAIN:
			draw_rect(Rect2(1.0, 2.0, w - 2.0, h - 4.0), body)                       # 铁板
			for p in [Vector2(3.0, 4.0), Vector2(w - 4.0, 4.0), Vector2(3.0, h - 5.0), Vector2(w - 4.0, h - 5.0)]:
				draw_rect(Rect2(p, Vector2(1.0, 1.0)), edge)
			var c := Vector2(w * 0.5, h * 0.5)
			if open:
				draw_arc(c, 3.0, 0.6, TAU - 0.6, 10, edge, 1.0)                      # 断开的环
				draw_line(c + Vector2(3.0, 2.0), c + Vector2(5.0, 6.0), edge, 1.0)   # 垂下来的一截
			else:
				draw_arc(c, 3.0, 0.0, TAU, 12, edge.lightened(0.2), 1.5)
		Look.VALVE:
			draw_rect(Rect2(w * 0.5 - 2.0, 0.0, 4.0, h), body)                        # 管子
			draw_rect(Rect2(w * 0.5 - 2.0, 0.0, 1.0, h), edge)
			var c := Vector2(w * 0.5, h * 0.5)
			if open:
				draw_rect(Rect2(c.x - 3.0, c.y - 1.0, 6.0, 2.0), dark)               # 手轮拧掉了,露出阀口
			else:
				draw_arc(c, w * 0.5 - 1.5, 0.0, TAU, 16, edge.lightened(0.15), 1.5)
				draw_line(c - Vector2(w * 0.5 - 2.0, 0.0), c + Vector2(w * 0.5 - 2.0, 0.0), edge, 1.0)
				draw_line(c - Vector2(0.0, w * 0.5 - 2.0), c + Vector2(0.0, w * 0.5 - 2.0), edge, 1.0)
				draw_rect(Rect2(c.x + 3.0, c.y + 3.0, 3.0, 4.0), rust)                # 小牌子
		Look.FUSE:
			draw_rect(Rect2(0.0, 0.0, w, h), body)
			if open:
				draw_rect(Rect2(2.0, 2.0, w - 4.0, h - 4.0), dark)                   # 门拆了,里面是黑的
				var t: float = float(Time.get_ticks_msec()) / 1000.0
				if fmod(t * 7.0, 1.0) < 0.35:
					draw_rect(Rect2(w * 0.5 + sin(t * 31.0) * 3.0, h * 0.5 + cos(t * 23.0) * 2.0, 1.0, 1.0), white)
			else:
				draw_rect(Rect2(w * 0.5, 2.0, 1.0, h - 4.0), dark)                   # 门缝
				draw_colored_polygon(PackedVector2Array([Vector2(w * 0.3, 3.0), Vector2(w * 0.55, 3.0),
						Vector2(w * 0.42, h * 0.5), Vector2(w * 0.6, h * 0.5), Vector2(w * 0.3, h - 3.0),
						Vector2(w * 0.38, h * 0.55), Vector2(w * 0.22, h * 0.55)]), Color(white, 0.5))  # 闪电标
		Look.CONTROL:
			draw_rect(Rect2(0.0, 0.0, w, h), body)
			if open:
				draw_rect(Rect2(2.0, 2.0, w - 4.0, h - 4.0), dark)
				for i in 3:
					draw_line(Vector2(3.0 + i * 3.0, 3.0), Vector2(4.0 + i * 3.0, h - 3.0), Color(edge, 0.8), 1.0)  # 扯出来的线
			else:
				for i in 3:
					draw_rect(Rect2(3.0 + i * 4.0, h * 0.55, 2.0, 4.0), edge)              # 开关
				draw_rect(Rect2(3.0, 3.0, 2.0, 2.0), Color(0.42, 0.88, 0.66, 0.9))         # 指示灯
				draw_rect(Rect2(7.0, 3.0, 2.0, 2.0), rust)
		Look.VENT_COVER:
			if open:
				return
			draw_rect(Rect2(0.0, 0.0, w, h), body)
			var y: float = 3.0
			while y < h - 2.0:
				draw_rect(Rect2(2.0, y, w - 4.0, 1.0), edge)                          # 横栅
				y += 3.0
			for p in [Vector2(1.0, 1.0), Vector2(w - 2.0, 1.0), Vector2(1.0, h - 2.0), Vector2(w - 2.0, h - 2.0)]:
				draw_rect(Rect2(p, Vector2(1.0, 1.0)), white)                         # 螺栓
