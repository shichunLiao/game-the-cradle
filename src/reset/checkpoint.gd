class_name Checkpoint
extends Area2D
## A respawn point that arms itself the first time Ryn walks through it.
##
## Implements `production/epics/the-cradle/story-003-detection-reset-loop.md`
## (AC: 关卡可放置多个检查点，重生取最近已激活的那个). Story 006 owns where they go.
##
## Node origin is the RESPAWN POINT, at FEET height, matching Ryn and Guard.
## The trigger box sits directly above it.
##
## Checkpoints do not know about the reset system: they add themselves to
## `CheckpointManager.CHECKPOINT_GROUP` and emit `checkpoint_touched`. The
## manager pulls the group and connects. So a level can place them freely and
## nothing needs wiring by hand.
##
## Usage (in a scene): instance `checkpoint.tscn`, set `position` to where Ryn's
## feet should land. Optionally widen `size`.

## Group every checkpoint joins so the manager can find it.
const GROUP: StringName = &"checkpoint"

## Emitted the first time Ryn enters this checkpoint. Re-entering a checkpoint
## that is already the active one does not re-emit.
signal checkpoint_touched(checkpoint: Checkpoint)

## Trigger box size in px. Grows up and out from the origin.
@export var size: Vector2 = Vector2(28, 44):
	set(value):
		size = value
		_sync_shape()
		queue_redraw()

## Marker colour (palette: cold-cyan). 2026-10-13 起不用了(画的是安全角落,见 `_draw`),留着让旧场景读得进来。
@export var marker_color: Color = Color("3D6B8A")

## True once Ryn has touched this checkpoint at least once.
var activated: bool = false

var _shape: RectangleShape2D
var _collider: CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	monitorable = false
	_shape = RectangleShape2D.new()
	_collider = CollisionShape2D.new()
	_collider.shape = _shape
	add_child(_collider)
	_sync_shape()
	add_to_group(GROUP)
	body_entered.connect(_on_body_entered)
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


## World position Ryn's feet are placed at on respawn.
##
## Usage: `ryn.global_position = checkpoint.respawn_position()`
func respawn_position() -> Vector2:
	return global_position


func _sync_shape() -> void:
	if _shape == null or _collider == null:
		return
	_shape.size = size
	_collider.position = Vector2(0.0, -size.y * 0.5)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Ryn
	if player == null:
		return
	if not activated:
		_since = 0.0          # 第一次碰到:掀毯子、罐子倒的动画
		set_process(true)
	activated = true
	checkpoint_touched.emit(self)
	queue_redraw()


## ## 画面:小小的安全角落(2026-10-13 细致化,`design/ideas-backlog.md` H2)
##
## 原来是一个冷青的门框线(开发用的标记)。现在是一个看得出「有人在这里躲过、喘过气」的角落:
## 压扁的纸箱、一条旧毯子、两个空罐子。Hollow Knight 的长椅那种「故事里本来就有的东西」,不是浮在
## 画面上的符号;Shovel Knight 的存档点那样有两种样子 —— 没碰过时毯子叠好、罐子立着;Ryn 走过之后
## 毯子被掀开一角、一个罐子倒了滚一下(配一声罐子叮当,`SfxBank.checkpoint`)。
##
## 只有 8px 高、贴着地 —— 不能让人以为能钻进去躲(能躲的只有柜子和通风管)。颜色是冷灰(塔里九成冷色)。
## 画在 Ryn 和守卫后面(z -1)、背景道具前面。

## 掀开 / 罐子滚动的动画时长,秒。
const SETTLE_TIME: float = 0.45
const CARD: Color = Color("3E4250")
const CARD_DARK: Color = Color("2A2E3A")
const BLANKET: Color = Color("34405A")
const BLANKET_FOLD: Color = Color("27304A")
const BLANKET_LIT: Color = Color("4A5874")
const TIN: Color = Color("5A6474")
const TIN_LIT: Color = Color("8A96A6")
const INK: Color = Color("0B1220")

var _since: float = -1.0


func _process(delta: float) -> void:
	if _since < 0.0:
		set_process(false)
		return
	_since += delta
	queue_redraw()
	if _since >= SETTLE_TIME:
		set_process(false)


func _draw() -> void:
	# 纸箱:压扁了铺在地上
	draw_rect(Rect2(-16.0, -2.0, 25.0, 2.0), CARD)
	draw_rect(Rect2(-16.0, -2.0, 25.0, 1.0), CARD.lightened(0.12))
	draw_rect(Rect2(-9.0, -2.0, 1.0, 2.0), CARD_DARK)          # 折痕
	var k: float = 1.0 if activated and _since < 0.0 else clampf(_since / SETTLE_TIME, 0.0, 1.0)
	if not activated:
		k = 0.0
	_draw_blanket(k)
	_draw_cans(k)


## 毯子:没碰过是叠好的一块;碰过之后被掀开一角、摊开一点。
func _draw_blanket(k: float) -> void:
	if k <= 0.0:
		draw_rect(Rect2(-14.0, -7.0, 12.0, 5.0), BLANKET)
		draw_rect(Rect2(-14.0, -7.0, 12.0, 1.0), BLANKET_LIT)
		draw_rect(Rect2(-14.0, -5.0, 12.0, 1.0), BLANKET_FOLD)   # 叠出来的两道褶
		draw_rect(Rect2(-14.0, -3.0, 12.0, 1.0), BLANKET_FOLD)
		return
	var spread: float = roundf(lerpf(0.0, 4.0, k))
	draw_rect(Rect2(-15.0, -5.0, 14.0 + spread, 3.0), BLANKET)      # 摊开的身子
	draw_rect(Rect2(-12.0, -7.0, 7.0, 2.0), BLANKET)                 # 堆起来的一团
	draw_rect(Rect2(-12.0, -7.0, 7.0, 1.0), BLANKET_LIT)
	draw_rect(Rect2(-15.0, -5.0, 3.0, 1.0), BLANKET_LIT)
	draw_rect(Rect2(-6.0, -4.0, 1.0, 2.0), BLANKET_FOLD)
	draw_rect(Rect2(-1.0 + spread, -3.0, 2.0, 1.0), BLANKET_FOLD)    # 被掀开的那一角


## 两个空罐子:没碰过都立着;碰过之后右边那个倒了、滚出去一点。
func _draw_cans(k: float) -> void:
	_can_standing(Vector2(3.0, 0.0))
	if k <= 0.0:
		_can_standing(Vector2(8.0, 0.0))
		return
	var x: float = roundf(lerpf(8.0, 12.0, k))
	draw_rect(Rect2(x - 1.0, -3.0, 5.0, 3.0), INK)
	draw_rect(Rect2(x, -3.0, 4.0, 3.0), TIN)
	draw_rect(Rect2(x, -3.0, 4.0, 1.0), TIN_LIT)
	draw_rect(Rect2(x + 3.0, -3.0, 1.0, 3.0), TIN.darkened(0.3))   # 罐口


func _can_standing(at: Vector2) -> void:
	draw_rect(Rect2(at.x - 1.0, at.y - 5.0, 5.0, 5.0), INK)
	draw_rect(Rect2(at.x, at.y - 5.0, 3.0, 5.0), TIN)
	draw_rect(Rect2(at.x, at.y - 5.0, 1.0, 5.0), TIN_LIT)
	draw_rect(Rect2(at.x, at.y - 5.0, 3.0, 1.0), TIN.darkened(0.25))
