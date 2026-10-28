class_name VeraSweep
extends Area2D
## 坑底 only: Vera's one lethal attack, which can be DODGED and never countered.
##
## 叙事脚本.md 终局 B: Vera 认不出 Ryn, 几乎下手 — 「躲开一次致死攻击；失败则重开」,
## and it recommends reusing the standard fail line rather than a bespoke one, so
## a hit calls `DetectionReset.trigger()` and lets the usual sequence run.
##
## ## Wiring
##
## Unlike a guard, this is not a `Guard` and cannot use `GuardResetAdapter`, so
## it is not picked up by `DetectionReset`'s automatic spotter discovery. Point
## `detection_reset` at the level's `DetectionReset` node or the sweep is inert:
## it will draw, telegraph and emit, and Ryn will walk through it unharmed.
##
## There is no combat anywhere in this game: this has no health, no damage and no
## way to fight back. It is a timing window, like a guard's cone.
##
## The ending performance (照片 → 切断 → 结局字卡) is Story 007. This is the room's
## hazard, not the cutscene.

signal ryn_caught(ryn: Node2D)

## The fail loop a hit feeds. Required — see Wiring above.
@export var detection_reset: DetectionReset
## Seconds between sweeps.
@export var period: float = 3.2
## Seconds the sweep is lethal.
@export var active_time: float = 0.7
## Seconds of warning before it goes lethal, so it is dodgeable on sight.
@export var telegraph_time: float = 0.8
@export var size: Vector2 = Vector2(96.0, 64.0):
	set(value):
		size = value
		_apply_shape()
		queue_redraw()
@export var idle_color: Color = Color("4A3F6B")
@export var telegraph_color: Color = Color("8B3A2F")
@export var active_color: Color = Color("C4453A")

var _shape: RectangleShape2D
var _collider: CollisionShape2D
var _elapsed: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	_collider = CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	_collider.shape = _shape
	add_child(_collider)
	_apply_shape()


func _apply_shape() -> void:
	if _shape == null or _collider == null:
		return
	_shape.size = size
	_collider.position = Vector2(size.x * 0.5, -size.y * 0.5)


## Phase 0 = idle, 1 = telegraphing, 2 = lethal.
func phase() -> int:
	var t: float = fmod(_elapsed, maxf(period, 0.0001))
	var warn_at: float = maxf(period - active_time - telegraph_time, 0.0)
	if t >= warn_at + telegraph_time:
		return 2
	if t >= warn_at:
		return 1
	return 0


func _physics_process(delta: float) -> void:
	# While the fail sequence owns the screen, the room is frozen: the cycle does
	# not advance and a Ryn already caught is not hit a second time every frame.
	if detection_reset != null and detection_reset.is_failing():
		return
	var before: int = phase()
	_elapsed += delta
	var now: int = phase()
	if now != before:
		queue_redraw()
	if now != 2:
		return
	for body in get_overlapping_bodies():
		if body is Ryn and (body as Ryn).is_detectable():
			ryn_caught.emit(body)
			if detection_reset != null:
				detection_reset.trigger(body, self)
			return


func _draw() -> void:
	var rect := Rect2(Vector2(0.0, -size.y), size)
	var colors: Array[Color] = [idle_color, telegraph_color, active_color]
	var c: Color = colors[phase()]
	c.a = 0.30 if phase() == 0 else (0.45 if phase() == 1 else 0.65)
	draw_rect(rect, c, true)
	draw_rect(rect, c.lightened(0.3), false, 1.0)
