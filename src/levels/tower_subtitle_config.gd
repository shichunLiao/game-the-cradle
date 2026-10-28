class_name TowerSubtitleConfig
extends Resource
## Tuning for the tower entry/exit subtitles.
##
## The LINES themselves are not here — they are content, authored per level in
## the .tscn, copied byte-for-byte from `叙事脚本.md`. This resource holds only
## how they look and how long they stay.

## CJK-capable faces, tried in order. Godot's built-in font has no Han glyphs
## and the line would render as tofu.
@export var font_names: PackedStringArray = PackedStringArray([
	"PingFang SC", "Hiragino Sans GB", "Heiti SC",
	"Noto Sans CJK SC", "Microsoft YaHei", "sans-serif",
])
@export var font_size: int = 14
@export var color: Color = Color("C8D4E0")
@export var outline_size: int = 0
@export var outline_color: Color = Color("0B1220")
## Distance from the bottom of the screen, px.
@export var bottom_margin: float = 54.0
@export_group("Backdrop band")
## 字幕底条。描边不足以保证可读:塔3 的办公桌正是 tower-white #C8D4E0,
## 与字幕同色,纯描边在那上面仍然勉强。一条半透明暗条能在任何底色上兜住。
@export var band_color: Color = Color("0B1220")
@export var band_alpha: float = 0.72
## 底条在文字上下各留的余量,px。
@export var band_padding: float = 6.0

@export_group("Timings")
@export var fade_in_time: float = 0.35
@export var hold_time: float = 2.4
@export var fade_out_time: float = 0.5
## 叙事脚本.md: 「不打断潜行超过 3 秒」. Entry lines show without taking control;
## this is only how long the exit line holds before the next scene loads.
@export var exit_hold_before_load: float = 2.2
