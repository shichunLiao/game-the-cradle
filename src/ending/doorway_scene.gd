class_name DoorwayScene
extends Node2D
## 结局 · 旧屋门口:门里透出暖光,两人坐在门口 —— 背着光,是两个深色的剪影。
##
## 叙事脚本.md 结局:「旧屋门口。……两人坐在门口。Vera 靠着 Ryn,或并排。」美术规格:暖色只给照片、吊坠、
## 旧屋、结局门口。这是全游戏最后、也是最多的一片暖色。人物用剪影(背光):Vera 的正式美术还没到,
## 而剪影本来就是这个美术方向的强项(规格:「剪影感强于细节堆砌」)。
##
## ## 精装修(2026-10-13,`docs/polish-research.md` §3.1–3.2)
##
## 和序章那间屋子对上(环境叙事:不说,让玩家自己认出来):
##   - 门里看得到屋里:炉子的火、晾衣绳、桌角;
##   - 两人一起盖着那床拼布被子,Vera 的头靠在 Ryn 肩上;
##   - 门槛上两只杯子(一只有缺口 —— 序章里那只一直没人用的,现在有人用了),冒着汽;
##   - 窗台上 Ryn 的铁皮小人;屋顶烟囱冒烟(炉子点着)。
## 背光的剪影用 1px 暖色轮廓光(TF2《Stylization with a Purpose》的 rim light)从门光里分出来。
## 门前地上的光按 3 级量化(像素画的硬边)。
##
## 节点原点是 **门的左下角**(门槛那一点)。画在实心块前面(z 2)。全是程序画的像素块。
##
## Usage (in a scene): 设 `position`、`door_size`。

const ACCENT_WARM: Color = Color("C4A574")
const INK: Color = Color("070B14")
const INK_SOFT: Color = Color("141820")
const WALL_DARK: Color = Color("0E1420")
const STEAM: Color = Color(0.78, 0.82, 0.86)

@export var door_size: Vector2 = Vector2(112.0, 160.0)
@export var frame_color: Color = Color("111A2B")
## 房子外墙相对门左下角的范围(和场景里的 `HouseWall` 对齐:墙 x 0..360、y 360..640,门在 x 150)。
@export var house_rect: Rect2 = Rect2(-150.0, -280.0, 360.0, 280.0)

var _time: float = 0.0


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w: float = door_size.x
	var h: float = door_size.y
	var flick: float = 0.94 + 0.06 * sin(_time * 1.7) * sin(_time * 0.6)
	_draw_facade(flick)
	# 门外一圈暖晕
	for i in 4:
		var g: float = 6.0 + i * 8.0
		draw_rect(Rect2(-g, -h - g, w + g * 2.0, h + g), Color(ACCENT_WARM, 0.045 * flick / (i + 1)))
	# 门前地上的光:3 级,越远越淡、越宽
	for i in 3:
		var d: float = 12.0 + i * 12.0
		var spill := PackedVector2Array([Vector2(0.0, 0.0), Vector2(w, 0.0),
				Vector2(w + d * 1.9, d), Vector2(-d * 1.4, d)])
		draw_colored_polygon(spill, Color(ACCENT_WARM, 0.07 * flick))
	# 门框和门洞
	draw_rect(Rect2(-6.0, -h - 6.0, w + 12.0, h + 6.0), frame_color)
	_draw_interior(w, h, flick)
	# 往里开着的门扇(左边一条深色的板)
	draw_rect(Rect2(0.0, -h, 10.0, h), Color("2A2118"))
	draw_rect(Rect2(10.0, -h, 1.0, h), Color(ACCENT_WARM, 0.35 * flick))
	# 门槛上的两只杯子、两个人
	_draw_mugs(Vector2(w * 0.86, 0.0), flick)
	_draw_pair(Vector2(w * 0.38, 0.0), Vector2(w * 0.56, 0.0), flick)


# ---------------------------------------------------------------- 房子

## 外墙上的东西:一扇亮着暖光的窗(窗台上 Ryn 的铁皮小人)、几块补的铁皮、屋顶的烟囱和烟。
func _draw_facade(flick: float) -> void:
	var r := house_rect
	# 补的铁皮(竖条纹)
	for patch in [Rect2(r.position.x + 18.0, r.position.y + 40.0, 40.0, 56.0),
			Rect2(r.end.x - 70.0, r.position.y + 96.0, 46.0, 40.0)]:
		draw_rect(patch, WALL_DARK)
		var x: float = patch.position.x + 3.0
		while x < patch.end.x - 1.0:
			draw_rect(Rect2(x, patch.position.y, 1.0, patch.size.y), Color("172030"))
			x += 4.0
	# 窗:暖光、十字棂、窗台上铁皮小人的剪影
	var win := Rect2(-112.0, -132.0, 56.0, 44.0)
	draw_rect(win.grow(4.0), frame_color)
	draw_rect(win, Color(ACCENT_WARM, 0.75 * flick))
	draw_rect(Rect2(win.position.x + 4.0, win.position.y + 6.0, win.size.x - 8.0, win.size.y - 6.0),
			Color(ACCENT_WARM.darkened(0.15), 0.8 * flick))
	draw_rect(Rect2(win.get_center().x - 1.0, win.position.y, 2.0, win.size.y), frame_color)
	draw_rect(Rect2(win.position.x, win.get_center().y - 1.0, win.size.x, 2.0), frame_color)
	draw_rect(Rect2(win.position.x - 6.0, win.end.y, win.size.x + 12.0, 4.0), frame_color)   # 窗台
	draw_rect(Rect2(win.position.x + 8.0, win.end.y - 9.0, 5.0, 9.0), INK)                  # 铁皮小人
	draw_rect(Rect2(win.position.x + 9.0, win.end.y - 12.0, 3.0, 3.0), INK)
	for i in 3:                                                                              # 窗外一点光
		var g: float = 4.0 + i * 6.0
		draw_rect(win.grow(g), Color(ACCENT_WARM, 0.03 * flick / (i + 1)))
	# 烟囱 + 烟
	var chim := Rect2(r.end.x - 70.0, r.position.y - 30.0, 16.0, 30.0)
	draw_rect(chim, frame_color)
	draw_rect(Rect2(chim.position.x - 2.0, chim.position.y, chim.size.x + 4.0, 4.0), frame_color)
	for i in 6:
		var k: float = fposmod(_time / 4.0 + float(i) / 6.0, 1.0)
		var p := Vector2(chim.get_center().x + sin(_time * 0.7 + i) * 3.0 + k * 22.0, chim.position.y - k * 70.0)
		var s: float = 3.0 + k * 8.0
		draw_rect(Rect2(p.round(), Vector2(s, s * 0.6).round()), Color(STEAM, 0.10 * (1.0 - k)))


## 门洞里:屋里深一点的暖(纵深),晾衣绳、桌角、炉子和它的火。
func _draw_interior(w: float, h: float, flick: float) -> void:
	draw_rect(Rect2(0.0, -h, w, h), Color(ACCENT_WARM, flick))
	draw_rect(Rect2(8.0, -h + 12.0, w - 16.0, h - 12.0), Color(ACCENT_WARM.darkened(0.14), flick))
	draw_rect(Rect2(16.0, -h + 22.0, w - 32.0, h - 22.0), Color(ACCENT_WARM.darkened(0.22), flick))
	var back := Color(ACCENT_WARM.darkened(0.55), flick)
	# 晾衣绳和一件小衣服
	for x in range(12, int(w) - 12):
		var t: float = float(x - 12) / (w - 24.0)
		draw_rect(Rect2(float(x), -h + 30.0 + roundf(sin(t * PI) * 4.0), 1.0, 1.0), back)
	draw_rect(Rect2(w * 0.3, -h + 33.0, 9.0, 9.0), back)
	# 炉子(后面偏右):身子、烟囱、发亮的格栅
	var sx: float = w * 0.66
	draw_rect(Rect2(sx, -46.0, 22.0, 24.0), back)
	draw_rect(Rect2(sx + 15.0, -h + 12.0, 3.0, h - 58.0), back)
	var ember: float = 0.7 + 0.3 * sin(_time * 1.3)
	draw_rect(Rect2(sx + 5.0, -36.0, 12.0, 5.0), Color(ACCENT_WARM.lightened(0.35), ember))
	# 桌角(后面偏左)
	draw_rect(Rect2(14.0, -40.0, 30.0, 3.0), back)
	draw_rect(Rect2(16.0, -37.0, 3.0, 15.0), back)


# ---------------------------------------------------------------- 人

## 两个人坐在门槛上,一起盖着那床拼布被子;Vera 的头靠在 Ryn 肩上。`ryn` / `vera` = 各自臀部着地那一点。
##
## 轮廓光:先把整个剪影往左、上、右各挪 1px 用暖色画一遍,再在原位用墨色盖上 —— 朝着门光的边留下一圈 1px 暖边。
## 第一版用方块拼,头是方的、被子是一整块长方形,远看像一张沙发(2026-10-13 截图)。
func _draw_pair(ryn: Vector2, vera: Vector2, flick: float) -> void:
	var rim := Color(ACCENT_WARM.lightened(0.15), 0.9 * flick)
	for o in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0)]:
		_pair_shapes(ryn + o, vera + o, rim)
	_pair_shapes(ryn, vera, INK)
	# 被子上的拼布格:比剪影稍亮一点,背光里隐约看得见
	for k in 6:
		var px: float = ryn.x - 8.0 + k * 7.0
		draw_rect(Rect2(px, ryn.y - 13.0 + (k % 2) * 4.0, 5.0, 3.0), INK_SOFT)
	# 吊坠:被子在 Vera 胸口那里没合拢,露出一点暖光(和坑底那颗一样)
	var glow: float = 0.75 + 0.25 * sin(_time * 1.3)
	var pend := Vector2(vera.x + 1.0, vera.y - 17.0)
	draw_rect(Rect2(pend, Vector2(2.0, 2.0)), Color(ACCENT_WARM.lightened(0.2), glow))
	draw_rect(Rect2(pend - Vector2(2.0, 2.0), Vector2(6.0, 6.0)), Color(ACCENT_WARM, 0.16 * glow))


## 两个人的剪影形状,全用 `c` 画。
func _pair_shapes(ryn: Vector2, vera: Vector2, c: Color) -> void:
	# Ryn:小一点;碎发翘起来,刘海遮眼
	draw_circle(ryn + Vector2(0.0, -25.0), 5.5, c)
	draw_rect(Rect2(ryn.x - 6.0, ryn.y - 29.0, 4.0, 3.0), c)
	draw_rect(Rect2(ryn.x - 4.0, ryn.y - 32.0, 2.0, 3.0), c)
	draw_rect(Rect2(ryn.x + 1.0, ryn.y - 33.0, 2.0, 3.0), c)
	draw_rect(Rect2(ryn.x + 4.0, ryn.y - 31.0, 2.0, 2.0), c)
	draw_rect(Rect2(ryn.x - 2.0, ryn.y - 20.0, 4.0, 3.0), c)                       # 脖子
	# Vera:头歪过来靠在 Ryn 右肩上 —— 头贴着 Ryn 的头侧,比坐直时低;脖子斜过去;低马尾往右下垂
	var head := ryn + Vector2(11.0, -23.0)
	draw_circle(head, 6.0, c)
	draw_colored_polygon(PackedVector2Array([vera + Vector2(-3.0, -19.0), vera + Vector2(3.0, -19.0),
			head + Vector2(3.0, 4.0), head + Vector2(-2.0, 5.0)]), c)
	draw_rect(Rect2(head.x + 4.0, head.y + 2.0, 3.0, 8.0), c)
	draw_rect(Rect2(head.x + 5.0, head.y + 9.0, 3.0, 3.0), c)
	# 被子:一个弧形的包,两个人的肩在里面拱起来
	var quilt := PackedVector2Array([
		ryn + Vector2(-11.0, -1.0), ryn + Vector2(-10.0, -12.0), ryn + Vector2(-7.0, -18.0),
		ryn + Vector2(-2.0, -20.0), ryn + Vector2(4.0, -19.0), vera + Vector2(-6.0, -20.0),
		vera + Vector2(1.0, -22.0), vera + Vector2(7.0, -20.0), vera + Vector2(10.0, -14.0),
		vera + Vector2(11.0, -1.0)])
	draw_colored_polygon(quilt, c)
	# 脚:从被子底下伸出来,搁在门槛外的台阶上
	for fx in [ryn.x - 6.0, ryn.x + 1.0, vera.x - 4.0, vera.x + 3.0]:
		draw_rect(Rect2(fx, ryn.y - 2.0, 5.0, 2.0), c)


## 门槛上两只杯子,一只有缺口;冒着汽。`at` = 第一只的底。
func _draw_mugs(at: Vector2, flick: float) -> void:
	var rim := Color(ACCENT_WARM.lightened(0.15), 0.85 * flick)
	for i in 2:
		var x: float = at.x + i * 8.0
		draw_rect(Rect2(x, at.y - 7.0, 6.0, 7.0), INK)
		draw_rect(Rect2(x + 6.0, at.y - 5.0, 2.0, 3.0), INK)                          # 把手
		draw_rect(Rect2(x, at.y - 8.0, 6.0, 1.0), rim)
	draw_rect(Rect2(at.x + 12.0, at.y - 8.0, 2.0, 1.0), INK)                          # 缺口:轮廓光在这断开
	for j in 4:
		var k: float = fposmod(_time / 2.2 + float(j) / 4.0, 1.0)
		var p := Vector2(at.x + 2.0 + sin(_time * 1.5 + j) * 1.5, at.y - 10.0 - k * 14.0)
		draw_rect(Rect2(p.round(), Vector2(1.0 + floorf(k * 2.0), 1.0)), Color(STEAM, 0.35 * (1.0 - k)))
