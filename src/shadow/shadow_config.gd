class_name ShadowConfig
extends Resource
## Tuning for the Story 004 darkness rule: how a shadow zone is drawn, and how
## far inside its edge a sampled point must be to count as hidden.
##
## Implements the "暗区判定参数为外部配置，不硬编码" criterion of
## `production/epics/the-cradle/story-004-darkness-detection.md`. Every number
## and colour the darkness system uses lives here; the shipped values are in
## `assets/data/shadow_default.tres`.
##
## Palette note (`美术规格.md` §2 and §4): shadow zones are level geometry, so
## they stay COLD — ink-deep fill, cold-cyan boundary. `--accent-warm #C4A574`
## is reserved for 照片 / 吊坠 / 旧屋 / 结局 and must never appear here.
##
## Usage:
##     var cfg: ShadowConfig = load("res://assets/data/shadow_default.tres")
##     ShadowQuery.covers(point, rects, cfg.hide_margin)

## 2026-10-13 细致化(`canvas_shadow_zone.gdshader`):虚线框、四角括号不画了,下面 edge_* / dash_* / corner_* 保留
## 只为旧资源能读;现在用的是 fill_color、fill_alpha(中间的暗)、bottom_extra、soft_edge_px、floor_px、floor_alpha。
##
## Zone fill (palette: ink-deep). Alpha comes from `fill_alpha`.
@export var fill_color: Color = Color("0B1220")
## Fill opacity, 0..1. Below 1 the floor and ledges stay faintly readable
## through the dark, so the level still parses inside a zone.
@export_range(0.0, 1.0, 0.01) var fill_alpha: float = 0.82
## Boundary colour (palette: cold-cyan, the same accent GrayBlock lights its
## top edge with). Alpha comes from `edge_alpha`.
@export var edge_color: Color = Color("3D6B8A")
## Boundary opacity, 0..1.
@export_range(0.0, 1.0, 0.01) var edge_alpha: float = 0.7
## Boundary line thickness in px. 1 px reads correctly at 16 px tiles.
@export var edge_thickness: float = 1.0
## Dash length in px along the boundary. A DASHED outline (not a solid one) is
## what separates a shadow zone from a solid GrayBlock at a glance.
@export var dash_length: float = 3.0
## Gap between dashes in px.
@export var dash_gap: float = 5.0
## Length in px of the solid corner brackets. They anchor the four corners so
## the zone still reads as a bounded area where a dash falls in a gap.
@export var corner_length: float = 6.0
## How far INSIDE the drawn edge the sampled point must be to count as hidden,
## px.
##
## 0 makes the rule identical to the drawing, which is what keeps the boundary
## honest: what you see is exactly what hides you (AC4). A positive value
## shrinks the hiding area inside the visible one (harsher than it looks);
## a negative value grows it past the drawing (more forgiving, and no longer
## readable). Change it only with a reason.
@export var hide_margin: float = 0.0


## Fill colour with `fill_alpha` applied.
##
## Usage: `draw_rect(rect, config.fill())`
## 越靠地面多暗多少(叠在 fill_alpha 上)。
@export_range(0.0, 0.5, 0.01) var bottom_extra: float = 0.12
## 边缘抖点渐暗的宽度,px。
@export var soft_edge_px: float = 12.0
## 暗处脚下压在地板顶上的那一条有多厚,px。
@export var floor_px: float = 3.0
@export_range(0.0, 1.0, 0.01) var floor_alpha: float = 0.5


func fill() -> Color:
	var tint: Color = fill_color
	tint.a = fill_alpha
	return tint


## Boundary colour with `edge_alpha` applied.
##
## Usage: `draw_rect(dash_rect, config.edge())`
func edge() -> Color:
	var tint: Color = edge_color
	tint.a = edge_alpha
	return tint
