class_name GuardSpriteVisual
extends GuardPlaceholderVisual
## 守卫的像素造型(2026-10-13 精装修,`docs/polish-research.md` §3.4):取代方块剪影。
##
## 三种造型对应三种发现方式(`Guard.sense`):SIGHT → C 军帽制服兵、HEARING → A 面罩头盔兵、
## TRACKING → B 防毒面具兵。素材 `assets/art/guard_sprites.png` 由 `assets/art/src/build_guard_sheet.py` 生成,
## 以后可以整张交给画师重画(格子、行列不变)。
##
## 接口和 `GuardPlaceholderVisual` 一样(继承它):`Guard` 每帧 `update_pose` / `set_alert`,
## `GuardBehaviour` 每帧 `set_walk`;头顶的「?」「!」也沿用它的画法。这里只换 `_draw`。
##
## ## 表的布局(必须与构建脚本一致)
## 每格 40x60,脚底中心在格内 (20, 59),朝右画。造型 k 占第 3k..3k+2 行:
##   行 0  待机呼吸 0-3、起疑 4-5、发现 6-7
##   行 1  走 0-7
##   行 2  转身(脸朝镜头)0-1、开柜门 2-3、蹲下低头看扣件 4-5、伸手捡 6、站起来拿着看 7
##
## ## 选哪一格
##   发现 → 发现两帧交替(跟着锥子的红闪);查看扣件(`_inspect`)→ 蹲着两帧慢慢换(头一点一点)/ 捡 / 拿着看;
##   起疑 → 在走(搜查、顺着痕迹追)用走路帧,站着用起疑两帧;
##   巡逻 → 刚转身用转身帧,在走用走路帧(按走过的距离),站着用呼吸帧。发现时红闪也闪在身上。

const SHEET: Texture2D = preload("res://assets/art/guard_sprites.png")
const CELL := Vector2(40.0, 60.0)
const FOOT := Vector2(20.0, 59.0)
## 头顶(脚底往上多少 px):头顶记号画在这上面。
const HEAD_TOP_Y: float = 47.0
const FLASH_TINT: Color = Color(1.55, 0.62, 0.52)

var _look: int = 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var g := get_parent() as Guard
	if g != null:
		_look = int(g.sense)


func _draw() -> void:
	var cell: Vector2i = _pick()
	var src := Rect2(Vector2(cell) * CELL, CELL)
	var flashing: bool = _state == Guard.State.SPOTTED and _fill.r > _fill.b
	var tint: Color = FLASH_TINT if flashing else Color.WHITE
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(_facing), 1.0))
	draw_texture_rect_region(SHEET, Rect2(-FOOT, CELL), src, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _state == Guard.State.SUSPICIOUS or _state == Guard.State.SPOTTED:
		var alert: bool = _state == Guard.State.SPOTTED
		_draw_mark(GLYPH_BANG if alert else GLYPH_QUESTION,
				MARK_SPOTTED if alert else MARK_SUSPICIOUS, Vector2(0.0, -HEAD_TOP_Y))


## (列, 行)。
func _pick() -> Vector2i:
	var base: int = _look * 3
	var walking: bool = _still_for < STAND_AFTER
	if _state == Guard.State.SPOTTED:
		return Vector2i(6 + (int(_state_time / 0.18) % 2), base)
	match _inspect:
		1:
			return Vector2i(4 + (int(_clock / 0.7) % 2), base + 2)
		2:
			return Vector2i(6, base + 2)
		3:
			return Vector2i(7, base + 2)
	if walking:
		return Vector2i(int(fposmod(_walk_phase, 1.0) * 8.0) % 8, base + 1)
	if _state == Guard.State.SUSPICIOUS:
		return Vector2i(4 + (int(_state_time / 0.5) % 2), base)
	if _turn_left > 0.0:
		return Vector2i(0, base + 2)
	return Vector2i(int(fposmod(_clock, BREATH_PERIOD) / BREATH_PERIOD * 4.0) % 4, base)
