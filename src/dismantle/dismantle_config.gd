class_name DismantleConfig
extends Resource
## Every number and colour the dismantling interaction uses.
##
## Implements 「拆解耗时／步骤为外部配置，不硬编码」 of
## `production/epics/the-cradle/story-005-dismantle-interaction.md`. The shipped
## values live in `assets/data/dismantle_default.tres`; a designer retunes the
## feel of 手巧 there without opening a `.gd` file.
##
## Palette note (`美术规格.md` §2): a dismantlable panel is LEVEL geometry, so
## every colour here is cold — steel-blue body, cold-cyan edge and fill,
## tower-white text. `--accent-warm #C4A574` is reserved for
## 照片 / 吊坠 / 旧屋 / 结局 and must never appear in a level.
##
## Usage:
##     var cfg: DismantleConfig = load("res://assets/data/dismantle_default.tres")
##     progress.configure(cfg.hold_duration, cfg.steps)

@export_group("Action")
## Seconds of CONTINUOUS hold on `interact` that a dismantle takes. Releasing
## early keeps nothing (see `DismantleProgress`).
@export var hold_duration: float = 1.2
## How many steps the hold is reported and drawn in. 4 = 叙事脚本.md 塔 2's
## 「拧三下，再撬」 — three twists and a pry.
@export var steps: int = 4
## How far OUTSIDE the panel's own rectangle Ryn still counts as near enough to
## read the prompt and work, px. This is the whole reach of 手巧.
@export var reach_padding: float = 16.0
## Radius in px within which finishing a dismantle alerts a guard
## (`Guard.report_disturbance`). 0 makes the work silent.
@export var noise_radius: float = 160.0

@export_group("Prompt")
## The near-object prompt text (`美术规格.md` §5: 短提示「E 拆」).
@export var prompt_text: String = "E 拆"
## Font families tried in order. Godot's built-in face has no Han glyphs, so a
## CJK family is required or 「拆」 renders as tofu.
@export var prompt_font_names: PackedStringArray = PackedStringArray([
	"PingFang SC", "Hiragino Sans GB", "Heiti SC", "Noto Sans CJK SC",
	"Microsoft YaHei", "sans-serif",
])
## Prompt size in px. The design resolution is 640x360, so this is small.
@export var prompt_font_size: int = 9
## Prompt colour (palette: tower-white — cold, and legible on ink-deep).
@export var prompt_color: Color = Color("C8D4E0")
## Outline thickness behind the prompt, px. 0 disables it.
@export var prompt_outline_size: int = 1
## Prompt outline colour (palette: ink-deep).
@export var prompt_outline_color: Color = Color("0B1220")
## Width of the invisible box the prompt is centred in, px.
@export var prompt_box_width: float = 56.0
## Gap between the top of the panel and the bottom of the prompt, px.
@export var prompt_gap: float = 3.0

@export_group("Panel")
## Panel body fill (palette: steel-blue, the same as GrayBlock structure).
@export var body_color: Color = Color("1A2A44")
## Panel edge and highlight (palette: cold-cyan).
@export var edge_color: Color = Color("3D6B8A")
## Edge thickness, px. 1 px is 美术规格.md §5's 「1px 亮边」.
@export var edge_thickness: float = 1.0
## Edge opacity while Ryn is out of reach, 0..1 — the panel still reads as a
## seam in the wall, it just is not highlighted.
@export_range(0.0, 1.0, 0.01) var idle_edge_alpha: float = 0.45
## Edge opacity while Ryn is in reach. This jump IS the 1px 亮边 cue.
@export_range(0.0, 1.0, 0.01) var near_edge_alpha: float = 1.0
## Width of a grate slat, px (FENCE panels are drawn as slats, not a plate).
@export var slat_width: float = 1.0
## Gap between grate slats, px.
@export var slat_gap: float = 3.0
## Radius of the two corner bolts drawn on a FLOOR_HATCH plate, px — the
## 「扣件」 Ryn's mother taught her to undo.
@export var bolt_radius: float = 1.0
## Opacity of the faint outline left where a dismantled panel used to be, 0..1.
## Above 0 the opened route still reads as something that was opened.
@export_range(0.0, 1.0, 0.01) var remnant_alpha: float = 0.16

@export_group("Progress")
## Progress bar size in px.
@export var bar_size: Vector2 = Vector2(30.0, 3.0)
## Gap between the top of the panel and the bottom of the bar, px.
@export var bar_gap: float = 2.0
## Bar backing colour (palette: ink-deep).
@export var bar_back_color: Color = Color("0B1220")
## Bar fill colour (palette: cold-cyan).
@export var bar_fill_color: Color = Color("3D6B8A")
## Colour of the step dividers drawn across the bar (palette: tower-white).
@export var bar_step_color: Color = Color("C8D4E0")
## Bar backing opacity, 0..1.
@export_range(0.0, 1.0, 0.01) var bar_back_alpha: float = 0.85


## `edge_color` at the opacity for the current proximity.
##
## Usage: `draw_rect(r, config.edge(is_near))`
func edge(near: bool) -> Color:
	var tint: Color = edge_color
	tint.a = near_edge_alpha if near else idle_edge_alpha
	return tint


## `edge_color` at `remnant_alpha` — the ghost of a removed panel.
func remnant() -> Color:
	var tint: Color = edge_color
	tint.a = remnant_alpha
	return tint


## `bar_back_color` at `bar_back_alpha`.
func bar_back() -> Color:
	var tint: Color = bar_back_color
	tint.a = bar_back_alpha
	return tint
