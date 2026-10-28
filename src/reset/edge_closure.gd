class_name EdgeClosure
extends Control
## Draws 美术规格.md §5's 「黑屏边缘收束」: a full-screen darkening plus four
## opaque bars sliding in from the screen edges, all driven by one 0..1 value.
##
## Procedurally drawn on purpose — 美术规格.md §6 lists UI 字幕 as
## 「可程序代替」, and a shader or sprite vignette would not scale cleanly with
## the integer-upscaled 640x360 viewport.
##
## Colours and travel distance come from the injected `DetectionResetConfig`;
## nothing here is tuned in code.
##
## Usage:
##     closure.configure(config)
##     closure.set_progress(0.5)   # half closed

var _color: Color = Color.BLACK
var _darken_alpha: float = 0.0
var _closure_fraction: float = 1.0
var _progress: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchors own the rect. The layout pass applies them AFTER _ready, so `size`
	# read here is still stale — that is not evidence that anchors do not work.
	# Assigning `size` here instead is both overridden and warned about:
	# "Nodes with non-equal opposite anchors will have their size overridden
	# after _ready()." Let the anchors do it, and redraw when the rect changes.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


## Injects the tuning resource. Safe to call before or after `_ready`.
##
## Usage: `closure.configure(load("res://assets/data/detection_reset.tres"))`
func configure(config: DetectionResetConfig) -> void:
	if config == null:
		return
	_color = config.edge_color
	_darken_alpha = config.darken_alpha
	_closure_fraction = config.closure_fraction
	queue_redraw()


## 0 = clear screen, 1 = edges fully closed at peak darkness.
##
## Usage: `closure.set_progress(sequence.close_progress())`
func set_progress(value: float) -> void:
	var next: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(next, _progress):
		return
	_progress = next
	queue_redraw()


## Current closure progress, 0..1.
func progress() -> float:
	return _progress


func _draw() -> void:
	if _progress <= 0.0:
		return
	var view: Vector2 = get_viewport_rect().size
	var wash := Color(_color.r, _color.g, _color.b, _darken_alpha * _progress)
	draw_rect(Rect2(Vector2.ZERO, view), wash)
	var solid := Color(_color.r, _color.g, _color.b, 1.0)
	var bar_w: float = view.x * 0.5 * _progress * _closure_fraction
	var bar_h: float = view.y * 0.5 * _progress * _closure_fraction
	if bar_w > 0.0:
		draw_rect(Rect2(0.0, 0.0, bar_w, view.y), solid)
		draw_rect(Rect2(view.x - bar_w, 0.0, bar_w, view.y), solid)
	if bar_h > 0.0:
		draw_rect(Rect2(0.0, 0.0, view.x, bar_h), solid)
		draw_rect(Rect2(0.0, view.y - bar_h, view.x, bar_h), solid)
