class_name DetectionResetConfig
extends Resource
## Tuning for the detection -> subtitle -> checkpoint reset loop.
##
## Implements `production/epics/the-cradle/story-003-detection-reset-loop.md`.
## Saved as a `.tres` under `assets/data/` so every timing, colour and the
## subtitle string are tuned without touching code (same pattern as
## `ryn_movement.tres` / `guard_default.tres`).
##
## Units: seconds, pixels, 0..1 alphas. The design resolution is 640x360.
##
## Colours come from `美术规格.md` §2. Level feedback stays COLD:
## `--ink-deep #0B1220` for the closing edges, `--tower-white #C8D4E0` for the
## subtitle. `--accent-warm #C4A574` is reserved for 照片/吊坠/旧屋/结局 and must
## never appear in this sequence.
##
## There is deliberately NO failure cost here — no health, no lives, no death
## counter. Failure costs time only, so this resource has no penalty knobs.
##
## Usage:
##     var cfg: DetectionResetConfig = load("res://assets/data/detection_reset.tres")
##     detection_reset.config = cfg

@export_group("Subtitle")
## The fixed line shown on a sighting. Verbatim from `叙事脚本.md`
## 「系统台词（固定）」— do not re-word, translate or re-punctuate.
@export var spotted_line: String = "被发现了，看来这样行不通。"
## 第一次被「听」的守卫(`Guard.Sense.HEARING`)抓到时换成这句,整个游戏只出一次(2026-10-17 用户:
## 「第一次被靠听的守卫抓到,死亡应该要显示『原来他是靠听觉行动的』」)。空字符串 = 不换。
@export var first_hearing_caught_line: String = "原来他是靠听觉行动的。"
## Font families tried in order; the first one the OS provides is used. Needs a
## CJK-capable family — Godot's built-in font has no Han glyphs.
@export var subtitle_font_names: PackedStringArray = PackedStringArray([
	"PingFang SC", "Hiragino Sans GB", "Heiti SC", "Noto Sans CJK SC",
	"Microsoft YaHei", "sans-serif",
])
## Subtitle size in design pixels (the viewport is 640x360 before upscale).
@export var subtitle_font_size: int = 14
## Subtitle colour (palette: tower-white).
@export var subtitle_color: Color = Color("C8D4E0")
## Outline thickness in px, 0 for none. Helps the line read over bright scenery.
@export var subtitle_outline_size: int = 0
## Outline colour (palette: ink-deep).
@export var subtitle_outline_color: Color = Color("0B1220")
## Gap between the subtitle baseline block and the bottom of the screen, px.
@export var subtitle_bottom_margin: float = 54.0

@export_group("Edge Closure")
## Colour the screen edges close in with (palette: ink-deep).
@export var edge_color: Color = Color("0B1220")
## Peak alpha of the full-screen darkening under the closing edges.
@export var darken_alpha: float = 0.9
## How far the edges travel at full progress. 1.0 = fully closed (黑屏).
@export var closure_fraction: float = 1.0

@export_group("Timings")
## Edges closing in and the screen darkening, s.
@export var close_in_time: float = 0.45
## Subtitle fade-in inside the hold, s. Clamped to `subtitle_hold_time`.
@export var subtitle_fade_in_time: float = 0.2
## How long the closed, darkened screen holds the subtitle, s.
@export var subtitle_hold_time: float = 1.1
## Fade in at the respawn point, s. The reset happens as this phase starts.
@export var fade_in_time: float = 0.6
## After control returns, how long new sightings are ignored, s. Stops an
## instant re-trigger when the checkpoint sits inside a guard's cone.
@export var respawn_grace_time: float = 0.8
