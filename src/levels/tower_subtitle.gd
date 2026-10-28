class_name TowerSubtitle
extends CanvasLayer
## One line of narration at the bottom of the screen, faded in and out.
##
## 叙事脚本.md gives each tower 「入塔一句 → 出塔一句」 and requires that it never
## blocks stealth for more than ~3 seconds, so this NEVER takes input away —
## unlike `FailOverlay`, which is part of the fail sequence. The two are separate
## on purpose: that one renders a fixed string, this one renders whatever the
## level hands it.
##
## Usage:
##     subtitle.show_line("「千万别往亮的地方走。」")

## Drawn above gameplay but below the fail overlay (which is 100).
const SUBTITLE_LAYER: int = 90

## 谁在说。Ryn 自己的话用配置里的颜色;广播(塔里的喇叭)换成冷青,玩家一眼分得出「这不是她」
## (2026-10-12 线索链)。
enum Tone { RYN, BROADCAST }
const BROADCAST_COLOR: Color = Color("8FB8C8")

@export var config: TowerSubtitleConfig

var _band: ColorRect
var _label: Label
var _elapsed: float = 0.0
var _showing: bool = false
var _hold: float = 0.0


func _ready() -> void:
	layer = SUBTITLE_LAYER
	_band = ColorRect.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 居中收窄,不横贯全屏 —— 满宽的底条读作"黑边"而不是"字幕底"
	_band.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	if config != null:
		_band.color = Color(config.band_color, config.band_alpha)
	_band.modulate.a = 0.0
	add_child(_band)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	if config != null:
		var face := SystemFont.new()
		face.font_names = config.font_names
		_label.add_theme_font_override(&"font", face)
		_label.add_theme_font_size_override(&"font_size", config.font_size)
		_label.add_theme_color_override(&"font_color", config.color)
		_label.add_theme_constant_override(&"outline_size", config.outline_size)
		_label.add_theme_color_override(&"font_outline_color", config.outline_color)
	_label.modulate.a = 0.0
	add_child(_label)
	set_process(false)


## Shows one line, fading in, holding, then fading out. Replaces any line in
## flight. An empty string is ignored. `tone` 换颜色(广播);`hold` > 0 时用它代替配置里的停留时间
## (广播那种长句要多停一会儿)。
func show_line(text: String, tone: Tone = Tone.RYN, hold: float = -1.0) -> void:
	if config == null or text.is_empty():
		return
	_label.text = text
	_label.add_theme_color_override(&"font_color", BROADCAST_COLOR if tone == Tone.BROADCAST else config.color)
	_hold = hold if hold > 0.0 else config.hold_time
	# 字幕大小(设定选单 小 / 中 / 大)。走 /root 路径:`-s` 检查脚本里 autoload 名不能当标识符用
	var display := get_node_or_null(^"/root/Display")
	var scale: float = float(display.call(&"subtitle_scale")) if display != null else 1.0
	var size: int = int(round(float(config.font_size) * scale))
	_label.add_theme_font_size_override(&"font_size", size)
	_label.offset_bottom = -config.bottom_margin
	var band_h: float = float(size) + config.band_padding * 2.0
	# 按文字实际宽度贴合,两端各留一点余量
	var fnt: Font = _label.get_theme_font(&"font")
	var tw: float = 0.0
	if fnt != null:
		tw = fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var band_w: float = minf(tw + config.band_padding * 6.0, get_viewport().get_visible_rect().size.x)
	_band.offset_left = -band_w * 0.5
	_band.offset_right = band_w * 0.5
	_band.offset_top = -(config.bottom_margin + band_h)
	_band.offset_bottom = -config.bottom_margin + config.band_padding
	_elapsed = 0.0
	_showing = true
	set_process(true)


func _process(delta: float) -> void:
	if not _showing or config == null:
		return
	_elapsed += delta
	var fade_in: float = maxf(config.fade_in_time, 0.0001)
	var hold_end: float = config.fade_in_time + _hold
	var fade_out: float = maxf(config.fade_out_time, 0.0001)
	if _elapsed < config.fade_in_time:
		_set_alpha(clampf(_elapsed / fade_in, 0.0, 1.0))
	elif _elapsed < hold_end:
		_set_alpha(1.0)
	elif _elapsed < hold_end + config.fade_out_time:
		_set_alpha(clampf(1.0 - (_elapsed - hold_end) / fade_out, 0.0, 1.0))
	else:
		_set_alpha(0.0)
		_showing = false
		set_process(false)


## 文字与底条一起淡入淡出 —— 分开淡会露出底条的硬边。
func _set_alpha(a: float) -> void:
	_label.modulate.a = a
	_band.modulate.a = a
