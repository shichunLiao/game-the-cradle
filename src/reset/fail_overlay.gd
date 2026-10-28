class_name FailOverlay
extends CanvasLayer
## The screen-space half of the fail sequence: the closing edges and the one
## fixed subtitle. Builds its own children so a level only has to drop in a
## CanvasLayer with this script and a config.
##
## Implements 美术规格.md §5 「被发现：黑屏边缘收束 → 字幕 → 淡入重生点」.
## It has NO gameplay knowledge: `DetectionReset` drives it with two numbers.
## It also holds no reference to gameplay nodes, satisfying the standard that
## gameplay code must not reach into UI (the arrow only points this way).
##
## The subtitle needs a CJK-capable face — Godot's built-in font has no Han
## glyphs and the line would render as tofu. `DetectionResetConfig
## .subtitle_font_names` is tried in order via `SystemFont`.
##
## Usage (in a scene):
##     [node name="FailOverlay" type="CanvasLayer" parent="."]
##     script = res://src/reset/fail_overlay.gd
##     config = res://assets/data/detection_reset.tres

## Drawn above everything gameplay.
const OVERLAY_LAYER: int = 100

## Tuning. Required.
@export var config: DetectionResetConfig

var _closure: EdgeClosure
var _subtitle: Label


func _ready() -> void:
	assert(config != null, "FailOverlay.config must be set")
	layer = OVERLAY_LAYER
	_closure = EdgeClosure.new()
	_closure.name = "EdgeClosure"
	add_child(_closure)
	_closure.configure(config)
	_subtitle = _build_subtitle()
	add_child(_subtitle)
	set_progress(0.0)
	set_subtitle_alpha(0.0)


## 0 = clear screen, 1 = fully closed and darkened.
##
## Usage: `overlay.set_progress(sequence.close_progress())`
func set_progress(value: float) -> void:
	if _closure != null:
		_closure.set_progress(value)


## 0 = subtitle hidden, 1 = fully opaque.
##
## Usage: `overlay.set_subtitle_alpha(sequence.subtitle_alpha())`
func set_subtitle_alpha(value: float) -> void:
	if _subtitle == null:
		return
	var alpha: float = clampf(value, 0.0, 1.0)
	_subtitle.visible = alpha > 0.0
	_subtitle.modulate = Color(1.0, 1.0, 1.0, alpha)


## Replaces the displayed line. Levels should not need this — the line comes
## from the config — but a cutscene or a test can override it.
##
## Usage: `overlay.set_line(config.spotted_line)`
func set_line(text: String) -> void:
	if _subtitle != null:
		_subtitle.text = text


## The line currently displayed. Lets a test assert the exact string.
func line() -> String:
	return "" if _subtitle == null else _subtitle.text


func _build_subtitle() -> Label:
	var label := Label.new()
	label.name = "Subtitle"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_bottom = -config.subtitle_bottom_margin
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Verbatim from `叙事脚本.md`「系统台词（固定）」via the config default.
	label.text = config.spotted_line
	var font := SystemFont.new()
	font.font_names = config.subtitle_font_names
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", config.subtitle_font_size)
	label.add_theme_color_override(&"font_color", config.subtitle_color)
	if config.subtitle_outline_size > 0:
		label.add_theme_constant_override(&"outline_size", config.subtitle_outline_size)
		label.add_theme_color_override(&"font_outline_color", config.subtitle_outline_color)
	return label
