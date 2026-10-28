class_name TowerDecor
extends Node2D
## 塔里的背景道具(2026-10-12,用户选「塔内换装」):每座塔一套,只是景。
##
##   塔1 出生地   铁婴儿床的骨架、瓦砾、倒下的椅子、门牌、熄了的壁灯和吊灯、撕破的帘子、墙裂
##   塔2 精炼     储罐、油桶、阀门、压力表、沿墙的管子、吊链、立管
##   塔3 登记     档案矮柜、带终端的办公桌、纸堆、排队栏杆、灯管、挂钟、叫号牌、告示
##   塔4 军事     沙袋、弹药箱、枪架、拒马、铁丝网、警示牌、喷字、信号盒、罩灯
##   坑口·下行    岩石、被蚀糊住的旧设备、坑壁上淌下来的蚀、断掉的吊缆、蚀凝成的冰柱(2026-10-12)
##   通用         电缆(两头挂在天花板上往下垂)
##
## ## 不碍事的规矩(潜行游戏,景不能骗人)
##
##   - 画在实心块、角色、暗区之下(z -50;背景墙 -100、窗 -60):暗区自然把它压暗,不会「暗处里有亮东西」。
##   - 明度比实心块低,顶上 **没有** 实心块那条亮边 —— 一眼看得出「这不能站」。
##   - 灯具:种类带「:on」的是亮的(灯泡 / 灯管画亮一点;光晕由 `TowerLamps` 叠上去),其余是熄的、坏的。
##     亮不亮由生成器按「光圈碰不碰暗区」决定(2026-10-13 精装修)。不画任何像柜子(百叶门)或通风管(栅格)的东西。
##   - 摆放由 `tools/level_builder/decor.py` 按格子算:避开梯子、柜子、通风管、存档点、出口、道具、
##     终端、盖板、栅栏、门禁、探照灯、窗;地上的只摆在站得直的地方,吊着的只挂在很高的天花板下。
##
## 一个节点画一片(生成器按高度切成几段,每段一个节点,画面外的整段被剔除)。
## 只在 `_ready` 后画一次,之后不重画。
##
## Usage (in a scene): 由 `tools/level_builder/build.py` 生成,`kinds[i]` 配 `rects[4i..4i+3]`(世界像素)。

## 每件道具的种类,和 `rects` 一一对应。
@export var kinds: PackedStringArray = PackedStringArray()
## 每件道具占的矩形,世界像素,4 个数一组 (x, y, w, h)。地上的 y + h = 地面;吊着的 y = 天花板底;
## 电缆的 (x, y) 和 (x + w, y) 是两个挂点,h 是垂下去多少。
@export var rects: PackedFloat32Array = PackedFloat32Array()

## 色板(美术规格.md):道具本体比实心块(#1A2A44)暗一档,比背景墙(#0C1220)亮一档。
const BODY: Color = Color("141F31")
const LIGHT: Color = Color("24344F")
const DARK: Color = Color("0A101B")
const CABLE: Color = Color("1E2A40")
## 点缀:都压得很低。
const WHITE_FAINT: Color = Color(0.784, 0.831, 0.878, 0.12)
const WHITE_DIM: Color = Color(0.784, 0.831, 0.878, 0.26)
const CYAN_DIM: Color = Color(0.239, 0.42, 0.541, 0.45)
const RUST_DIM: Color = Color(0.545, 0.227, 0.184, 0.32)
## 亮着的灯泡 / 灯管 / 警示灯罩(2026-10-13):灯具自己是整个画面里最亮的那一点,光从这里来。
const BULB_ON: Color = Color("D8E4EE")
const RUST_ON: Color = Color("C0503C")
## 蚀(下行关):和 `CorrosionZone` 同一套颜色,压暗一点。
const SLUDGE: Color = Color(0.165, 0.082, 0.22, 0.95)
const SHEEN_DIM: Color = Color(0.478, 0.345, 0.627, 0.45)


func _ready() -> void:
	z_index = -50
	queue_redraw()


## 道具数(验证脚本用)。
func count() -> int:
	return mini(kinds.size(), rects.size() / 4)


func _draw() -> void:
	for i in count():
		var r := Rect2(rects[i * 4], rects[i * 4 + 1], rects[i * 4 + 2], rects[i * 4 + 3])
		var rng := RandomNumberGenerator.new()
		rng.seed = int(r.position.x) * 73856093 ^ int(r.position.y) * 19349663
		var parts: PackedStringArray = kinds[i].split(":", true, 1)
		_paint(parts[0], r, rng, parts[1] if parts.size() > 1 else "")


## `kind` 可以带一个参数:「number_board:17」= 叫号牌上亮着 17(手摆的道具用,`lv.prop(...)`)。
func _paint(kind: String, r: Rect2, rng: RandomNumberGenerator, arg: String = "") -> void:
	match kind:
		"cable": _cable(r)
		"rubble": _rubble(r, rng)
		"crack": _crack(r, rng)
		"riser": _riser(r, rng)
		# 塔1
		"crib": _crib(r, rng)
		"chair": _chair(r, rng)
		"plaque": _plaque(r, rng)
		"sconce": _sconce(r, arg == "on")
		"hang_lamp": _hang_lamp(r, arg == "on")
		"curtain": _curtain(r, rng)
		# 塔2
		"tank": _tank(r, rng)
		"barrel": _barrel(r)
		"valve": _valve(r)
		"gauge": _gauge(r, rng)
		"pipe_run": _pipe_run(r)
		"chain": _chain(r)
		# 塔3
		"filing": _filing(r)
		"desk": _desk(r, rng)
		"papers": _papers(r, rng)
		"stanchion": _stanchion(r)
		"tube": _tube(r, arg == "on")
		"clock": _clock(r, rng)
		"number_board": _number_board(r, rng, arg)
		"notices": _notices(r, rng)
		# 塔4
		"sandbags": _sandbags(r, rng)
		"ammo": _ammo(r)
		"rack": _rack(r)
		"hedgehog": _hedgehog(r)
		"wire": _wire(r)
		"hazard": _hazard(r)
		"stencil": _stencil(r, rng)
		"signal": _signal(r)
		"cage_lamp": _cage_lamp(r, arg == "on")
		"warn_lamp": _warn_lamp(r, arg == "on")
		"work_lamp": _work_lamp(r, arg == "on")
		# 坑口·下行
		"rock": _rock(r, rng)
		"machine": _machine(r, rng)
		"drip": _drip(r, rng)
		"snapped_cable": _snapped_cable(r, rng)
		"stalactite": _stalactite(r)
		_:
			draw_rect(r, BODY)


# ------------------------------------------------------------------ 通用

## 一根电缆:两头挂点,中间按抛物线垂下 r.size.y。
func _cable(r: Rect2) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var t: float = float(i) / 16.0
		pts.append(Vector2(r.position.x + r.size.x * t, r.position.y + 4.0 * r.size.y * t * (1.0 - t)))
	draw_polyline(pts, CABLE, 1.0)
	draw_rect(Rect2(r.position.x - 1.0, r.position.y, 3.0, 2.0), LIGHT)
	draw_rect(Rect2(r.end.x - 1.0, r.position.y, 3.0, 2.0), LIGHT)


## 瓦砾堆:底下宽、上面窄的几层碎块。
func _rubble(r: Rect2, rng: RandomNumberGenerator) -> void:
	var floor_y: float = r.end.y
	var layers: int = maxi(1, int(r.size.y / 4.0))
	for l in layers:
		var inset: float = r.size.x * 0.18 * float(l)
		var x: float = r.position.x + inset
		var right: float = r.end.x - inset
		while x < right - 1.0:
			var w: float = minf(rng.randf_range(3.0, 7.0), right - x)
			var h: float = rng.randf_range(3.0, 5.0)
			var c: Color = BODY.lerp(LIGHT, rng.randf()) if rng.randf() < 0.7 else DARK
			draw_rect(Rect2(x, floor_y - 4.0 * float(l) - h, w, h), c)
			draw_rect(Rect2(x, floor_y - 4.0 * float(l) - h, w, 1.0), c.lightened(0.08))
			x += w + rng.randf_range(-1.0, 1.0)


## 墙上的裂缝:一道折线往下,中间分一个叉。
func _crack(r: Rect2, rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array()
	var p := Vector2(r.position.x + r.size.x * rng.randf_range(0.3, 0.7), r.position.y)
	pts.append(p)
	var steps: int = 6
	var branch_at: int = rng.randi_range(2, 4)
	var branch := Vector2.ZERO
	for i in steps:
		p += Vector2(rng.randf_range(-r.size.x * 0.2, r.size.x * 0.2), r.size.y / float(steps))
		p.x = clampf(p.x, r.position.x, r.end.x)
		pts.append(p)
		if i == branch_at:
			branch = p
	draw_polyline(pts, DARK, 1.0)
	draw_line(branch, branch + Vector2(r.size.x * 0.3 * (1.0 if rng.randf() < 0.5 else -1.0), r.size.y * 0.15), DARK, 1.0)


## 立管:从地面通到天花板的一根竖管,每 48px 一个卡箍,偶尔一个阀门轮。
func _riser(r: Rect2, rng: RandomNumberGenerator) -> void:
	var w: float = r.size.x
	for i in int(w):
		var k: float = (float(i) + 0.5) / w
		var c: Color = DARK.lerp(LIGHT, sin(k * PI))
		draw_rect(Rect2(r.position.x + float(i), r.position.y, 1.0, r.size.y), c)
	var y: float = r.position.y + 20.0
	while y < r.end.y - 8.0:
		draw_rect(Rect2(r.position.x - 2.0, y, w + 4.0, 3.0), LIGHT)
		draw_rect(Rect2(r.position.x - 2.0, y + 3.0, w + 4.0, 1.0), DARK)
		y += 48.0
	if rng.randf() < 0.5:
		var vy: float = r.position.y + r.size.y * rng.randf_range(0.4, 0.7)
		var c := Vector2(r.position.x + w * 0.5, vy)
		draw_rect(Rect2(c.x - 1.0, vy, w * 0.5 + 6.0, 2.0), LIGHT)
		draw_arc(c + Vector2(w * 0.5 + 6.0, 1.0), 4.0, 0.0, TAU, 12, LIGHT, 1.0)


# ------------------------------------------------------------------ 塔1 出生地

## 铁婴儿床:两头立柱、上下横杆、一排栏杆、床板;有的栏杆掉了几根。
func _crib(r: Rect2, rng: RandomNumberGenerator) -> void:
	var x0: float = r.position.x
	var y0: float = r.position.y
	var w: float = r.size.x
	var h: float = r.size.y
	draw_rect(Rect2(x0, y0, 2.0, h), LIGHT)
	draw_rect(Rect2(x0 + w - 2.0, y0, 2.0, h), LIGHT)
	draw_rect(Rect2(x0, y0 + 1.0, w, 1.0), LIGHT)                       # 上横杆
	draw_rect(Rect2(x0, y0 + h - 7.0, w, 2.0), BODY)                    # 床板
	draw_rect(Rect2(x0 + 1.0, y0 + h - 5.0, w - 2.0, 1.0), DARK)        # 床板下的影子
	var x: float = x0 + 4.0
	while x < x0 + w - 3.0:
		if rng.randf() > 0.18:
			draw_rect(Rect2(x, y0 + 2.0, 1.0, h - 9.0), BODY.lerp(LIGHT, 0.5))
		x += 3.0
	draw_rect(Rect2(x0 + 1.0, y0 + h - 2.0, 2.0, 2.0), DARK)            # 脚
	draw_rect(Rect2(x0 + w - 3.0, y0 + h - 2.0, 2.0, 2.0), DARK)


## 椅子:有的立着,有的倒在地上。
func _chair(r: Rect2, rng: RandomNumberGenerator) -> void:
	var x0: float = r.position.x
	var fy: float = r.end.y
	if rng.randf() < 0.5:
		draw_rect(Rect2(x0, fy - 8.0, r.size.x, 2.0), LIGHT)              # 座
		draw_rect(Rect2(x0, fy - r.size.y, 2.0, r.size.y), BODY)          # 靠背 + 后腿
		draw_rect(Rect2(x0 + r.size.x - 2.0, fy - 6.0, 2.0, 6.0), BODY)   # 前腿
	else:
		draw_rect(Rect2(x0, fy - 2.0, r.size.x + 2.0, 2.0), BODY)         # 倒着:靠背贴地
		draw_rect(Rect2(x0 + 4.0, fy - 8.0, 2.0, 6.0), LIGHT)             # 座板竖着
		draw_rect(Rect2(x0 + 4.0, fy - 8.0, 8.0, 2.0), BODY)              # 腿朝外伸


## 门牌:一块小牌子,上面三道看不清的字。
func _plaque(r: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(r, BODY)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), LIGHT)
	draw_rect(Rect2(r.position + Vector2(0.0, r.size.y - 1.0), Vector2(r.size.x, 1.0)), DARK)
	var x: float = r.position.x + 2.0
	for i in 3:
		var w: float = rng.randf_range(2.0, 3.0)
		draw_rect(Rect2(x, r.position.y + r.size.y * 0.5 - 1.0, w, 2.0), WHITE_FAINT)
		x += w + 1.0


## 熄了的壁灯:墙上一个托架,灯罩里是暗的。
func _sconce(r: Rect2, on: bool = false) -> void:
	var cx: float = r.position.x + r.size.x * 0.5
	draw_rect(Rect2(cx - 1.0, r.position.y + 4.0, 2.0, r.size.y - 4.0), BODY)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5.0), LIGHT)
	draw_rect(Rect2(r.position.x + 1.0, r.position.y + 2.0, r.size.x - 2.0, 2.0), BULB_ON if on else DARK)


## 吊灯:一根线吊着一个灯罩;亮的灯罩口一条亮线。
func _hang_lamp(r: Rect2, on: bool = false) -> void:
	var cx: float = r.position.x + r.size.x * 0.5
	draw_rect(Rect2(cx, r.position.y, 1.0, r.size.y - 5.0), CABLE)
	var top: float = r.end.y - 5.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 2.0, top), Vector2(cx + 3.0, top),
		Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]), LIGHT)
	draw_rect(Rect2(cx - 1.0, r.end.y - 1.0, 3.0, 1.0), BULB_ON if on else DARK)


## 撕破的帘子:一根横杆,下面几道褶,下摆参差。
func _curtain(r: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(Rect2(r.position.x - 1.0, r.position.y, r.size.x + 2.0, 2.0), LIGHT)
	var x: float = r.position.x
	var i: int = 0
	while x < r.end.x:
		var w: float = minf(4.0, r.end.x - x)
		var h: float = r.size.y * rng.randf_range(0.45, 1.0)
		draw_rect(Rect2(x, r.position.y + 2.0, w, h), BODY if i % 2 == 0 else BODY.lerp(LIGHT, 0.4))
		x += w
		i += 1


# ------------------------------------------------------------------ 塔2 精炼

## 储罐:立着的圆柱,顶上圆顶,中间一道锈带,侧面一个小压力表。
func _tank(r: Rect2, rng: RandomNumberGenerator) -> void:
	var w: float = r.size.x
	var top: float = r.position.y + 4.0
	for i in int(w):
		var k: float = (float(i) + 0.5) / w
		var c: Color = DARK.lerp(LIGHT, sin(k * PI) * 0.9)
		var cap: float = 4.0 * (1.0 - sin(k * PI))                     # 圆顶:两边低、中间高
		draw_rect(Rect2(r.position.x + float(i), r.position.y + cap, 1.0, r.size.y - cap), c)
	var band_y: float = top + r.size.y * rng.randf_range(0.3, 0.45)
	draw_rect(Rect2(r.position.x, band_y, w, 3.0), RUST_DIM)
	draw_rect(Rect2(r.position.x, top + 6.0, w, 1.0), DARK)
	draw_rect(Rect2(r.position.x, r.end.y - 6.0, w, 1.0), DARK)
	var g := Vector2(r.position.x + w * 0.72, band_y + 10.0)
	draw_circle(g, 3.0, BODY)
	draw_arc(g, 3.0, 0.0, TAU, 10, LIGHT, 1.0)
	draw_line(g, g + Vector2(2.0, -1.0), RUST_DIM, 1.0)


## 油桶:小圆柱,两道箍。
func _barrel(r: Rect2) -> void:
	var w: float = r.size.x
	for i in int(w):
		var k: float = (float(i) + 0.5) / w
		draw_rect(Rect2(r.position.x + float(i), r.position.y, 1.0, r.size.y), DARK.lerp(LIGHT, sin(k * PI) * 0.8))
	draw_rect(Rect2(r.position.x, r.position.y, w, 2.0), BODY.lerp(LIGHT, 0.6))
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.33, w, 1.0), DARK)
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.66, w, 1.0), DARK)


## 阀门:地上伸出一截管子,顶上一个手轮。
func _valve(r: Rect2) -> void:
	var cx: float = r.position.x + r.size.x * 0.5
	draw_rect(Rect2(cx - 2.0, r.position.y + 6.0, 4.0, r.size.y - 6.0), BODY)
	draw_rect(Rect2(cx - 2.0, r.position.y + 6.0, 1.0, r.size.y - 6.0), LIGHT)
	draw_rect(Rect2(cx - 3.0, r.end.y - 3.0, 6.0, 3.0), LIGHT)
	var c := Vector2(cx, r.position.y + 4.0)
	draw_arc(c, r.size.x * 0.5 - 1.0, 0.0, TAU, 14, LIGHT, 1.0)
	draw_line(c - Vector2(r.size.x * 0.5 - 1.0, 0.0), c + Vector2(r.size.x * 0.5 - 1.0, 0.0), LIGHT, 1.0)


## 压力表:墙上一截短管托着一个圆表,表针偏在红区。
func _gauge(r: Rect2, rng: RandomNumberGenerator) -> void:
	var cx: float = r.position.x + r.size.x * 0.5
	var rad: float = r.size.x * 0.5
	var c := Vector2(cx, r.position.y + rad)
	draw_rect(Rect2(cx - 1.0, c.y, 2.0, r.size.y - rad), BODY)
	draw_circle(c, rad, BODY)
	draw_circle(c, rad - 1.5, Color(DARK, 1.0).lerp(Color("C8D4E0"), 0.1))
	draw_arc(c, rad, 0.0, TAU, 16, LIGHT, 1.0)
	var a: float = rng.randf_range(-0.6, 0.4)
	draw_line(c, c + Vector2(cos(a), sin(a) - 0.4).normalized() * (rad - 2.0), RUST_DIM.lightened(0.2), 1.0)


## 沿墙的一段横管:法兰每 32px 一道,两头一个托架。
func _pipe_run(r: Rect2) -> void:
	var h: float = r.size.y
	for i in int(h):
		var k: float = (float(i) + 0.5) / h
		draw_rect(Rect2(r.position.x, r.position.y + float(i), r.size.x, 1.0), DARK.lerp(LIGHT, sin(k * PI) * 0.85))
	var x: float = r.position.x + 12.0
	while x < r.end.x - 6.0:
		draw_rect(Rect2(x, r.position.y - 1.0, 3.0, h + 2.0), LIGHT)
		draw_rect(Rect2(x + 3.0, r.position.y - 1.0, 1.0, h + 2.0), DARK)
		x += 32.0
	for bx in [r.position.x + 4.0, r.end.x - 6.0]:
		draw_rect(Rect2(bx, r.end.y, 2.0, 4.0), BODY)


## 吊链:一节一节往下,底下一个钩子。
func _chain(r: Rect2) -> void:
	var cx: float = r.position.x + r.size.x * 0.5
	var y: float = r.position.y
	var i: int = 0
	while y < r.end.y - 6.0:
		if i % 2 == 0:
			draw_rect(Rect2(cx - 1.0, y, 3.0, 3.0), LIGHT)
			draw_rect(Rect2(cx, y + 1.0, 1.0, 1.0), DARK)
		else:
			draw_rect(Rect2(cx, y, 1.0, 3.0), BODY)
		y += 3.0
		i += 1
	draw_arc(Vector2(cx - 1.0, r.end.y - 3.0), 3.0, -0.2, PI + 0.6, 8, LIGHT, 1.0)


# ------------------------------------------------------------------ 塔3 登记

## 档案矮柜:三层抽屉,每层一个把手和一张标签。比柜子(48 高、百叶门)矮一半,没有百叶。
func _filing(r: Rect2) -> void:
	draw_rect(r, BODY)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), LIGHT)
	var dh: float = (r.size.y - 2.0) / 3.0
	for i in 3:
		var y: float = r.position.y + 1.0 + dh * float(i)
		draw_rect(Rect2(r.position.x + 1.0, y + dh - 1.0, r.size.x - 2.0, 1.0), DARK)
		draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 2.0, y + 2.0, 4.0, 1.0), LIGHT)
		draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 1.0, y + 4.0, 3.0, 1.0), WHITE_FAINT)


## 办公桌:桌面、桌腿、一侧抽屉;桌上一台终端,屏幕上几行很暗的字。
func _desk(r: Rect2, rng: RandomNumberGenerator) -> void:
	var top: float = r.end.y - 12.0
	draw_rect(Rect2(r.position.x, top, r.size.x, 2.0), LIGHT)
	draw_rect(Rect2(r.position.x + 1.0, top + 2.0, 2.0, 10.0), BODY)
	draw_rect(Rect2(r.end.x - 10.0, top + 2.0, 9.0, 10.0), BODY)
	draw_rect(Rect2(r.end.x - 8.0, top + 5.0, 5.0, 1.0), LIGHT)
	var mx: float = r.position.x + 4.0 + rng.randf_range(0.0, maxf(r.size.x - 22.0, 0.0))
	draw_rect(Rect2(mx + 4.0, top - 2.0, 3.0, 2.0), BODY)                # 底座
	draw_rect(Rect2(mx, r.position.y, 11.0, top - 2.0 - r.position.y), BODY)
	draw_rect(Rect2(mx + 1.0, r.position.y + 1.0, 9.0, top - 4.0 - r.position.y), DARK)
	var ly: float = r.position.y + 2.0
	while ly < top - 4.0:
		draw_rect(Rect2(mx + 2.0, ly, rng.randf_range(2.0, 7.0), 1.0), Color(CYAN_DIM, 0.3))
		ly += 2.0


## 纸堆:几摞淡白的纸。
func _papers(r: Rect2, rng: RandomNumberGenerator) -> void:
	var y: float = r.end.y - 1.0
	while y > r.position.y:
		var off: float = rng.randf_range(-1.0, 1.0)
		draw_rect(Rect2(r.position.x + off, y, r.size.x, 1.0), WHITE_FAINT if int(y) % 2 == 0 else Color(WHITE_FAINT, 0.07))
		y -= 1.0


## 排队栏杆:两根立柱,中间一根绳子垂下来。
func _stanchion(r: Rect2) -> void:
	for x in [r.position.x, r.end.x - 2.0]:
		draw_rect(Rect2(x, r.position.y, 2.0, r.size.y), LIGHT)
		draw_rect(Rect2(x - 2.0, r.end.y - 2.0, 6.0, 2.0), BODY)
		draw_rect(Rect2(x - 1.0, r.position.y, 4.0, 2.0), LIGHT)
	var pts := PackedVector2Array()
	for i in 13:
		var t: float = float(i) / 12.0
		pts.append(Vector2(r.position.x + 2.0 + (r.size.x - 4.0) * t, r.position.y + 2.0 + 6.0 * t * (1.0 - t) * 4.0 * 0.5))
	draw_polyline(pts, BODY.lerp(LIGHT, 0.6), 1.0)


## 灯管:两根吊杆吊着灯罩,里面一线很淡的白;偶尔一根是坏的(更暗)。底下一抹几乎看不见的光晕。
func _tube(r: Rect2, on: bool = false) -> void:
	draw_rect(Rect2(r.position.x + 3.0, r.position.y, 1.0, r.size.y - 3.0), CABLE)
	draw_rect(Rect2(r.end.x - 4.0, r.position.y, 1.0, r.size.y - 3.0), CABLE)
	draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 2.0), BODY)
	draw_rect(Rect2(r.position.x + 1.0, r.end.y - 1.0, r.size.x - 2.0, 1.0),
		BULB_ON if on else Color(WHITE_DIM, 0.1))


## 挂钟:圆盘,两根指针。
func _clock(r: Rect2, rng: RandomNumberGenerator) -> void:
	var rad: float = r.size.x * 0.5
	var c := r.position + Vector2(rad, rad)
	draw_circle(c, rad, BODY)
	draw_circle(c, rad - 1.5, DARK)
	draw_arc(c, rad, 0.0, TAU, 16, LIGHT, 1.0)
	var a: float = rng.randf() * TAU
	draw_line(c, c + Vector2(cos(a), sin(a)) * (rad - 2.5), WHITE_DIM, 1.0)
	draw_line(c, c + Vector2(cos(a * 7.0), sin(a * 7.0)) * (rad - 3.5), WHITE_DIM, 1.0)


## 七段数码管:哪几段亮(上、中、下、左上、右上、左下、右下)。
const SEGMENTS: Dictionary = {
	"0": [1, 0, 1, 1, 1, 1, 1], "1": [0, 0, 0, 0, 1, 0, 1], "2": [1, 1, 1, 0, 1, 1, 0], "3": [1, 1, 1, 0, 1, 0, 1],
	"4": [0, 1, 0, 1, 1, 0, 1], "5": [1, 1, 1, 1, 0, 0, 1], "6": [1, 1, 1, 1, 0, 1, 1], "7": [1, 0, 0, 0, 1, 0, 1],
	"8": [1, 1, 1, 1, 1, 1, 1], "9": [1, 1, 1, 1, 1, 0, 1],
}


## 叫号牌:黑底上三个很暗的数字(只是几段横竖)。`digits` 不为空时显示这个号码(塔3:停在 17,
## 线索链 2026-10-12),亮一点。
func _number_board(r: Rect2, rng: RandomNumberGenerator, digits: String = "") -> void:
	draw_rect(r, BODY)
	draw_rect(Rect2(r.position + Vector2(1.0, 1.0), r.size - Vector2(2.0, 2.0)), DARK)
	if not digits.is_empty():
		var n: int = digits.length()
		var cw: float = (r.size.x - 4.0) / float(n)
		for d in n:
			var seg: Array = SEGMENTS.get(digits[d], [])
			var o := Vector2(r.position.x + 2.0 + cw * float(d) + 1.0, r.position.y + 2.0)
			var w: float = cw - 3.0
			var h: float = r.size.y - 4.0
			var col := Color(0.42, 0.88, 0.66, 0.75)
			var rects: Array[Rect2] = [Rect2(o, Vector2(w, 1.0)), Rect2(o + Vector2(0.0, floorf(h * 0.5)), Vector2(w, 1.0)),
				Rect2(o + Vector2(0.0, h - 1.0), Vector2(w, 1.0)), Rect2(o, Vector2(1.0, ceilf(h * 0.5))),
				Rect2(o + Vector2(w - 1.0, 0.0), Vector2(1.0, ceilf(h * 0.5))),
				Rect2(o + Vector2(0.0, floorf(h * 0.5)), Vector2(1.0, ceilf(h * 0.5))),
				Rect2(o + Vector2(w - 1.0, floorf(h * 0.5)), Vector2(1.0, ceilf(h * 0.5)))]
			for k in seg.size():
				if seg[k] == 1:
					draw_rect(rects[k], col)
		draw_rect(Rect2(r.position - Vector2(2.0, 2.0), r.size + Vector2(4.0, 4.0)), Color(0.42, 0.88, 0.66, 0.05))
		return
	var dw: float = (r.size.x - 4.0) / 3.0
	for d in 3:
		var o := Vector2(r.position.x + 2.0 + dw * float(d) + 1.0, r.position.y + 2.0)
		var w: float = dw - 3.0
		var h: float = r.size.y - 4.0
		var segs: int = rng.randi()
		var col := Color(WHITE_DIM, 0.3)
		if segs & 1: draw_rect(Rect2(o, Vector2(w, 1.0)), col)
		if segs & 2: draw_rect(Rect2(o + Vector2(0.0, h * 0.5), Vector2(w, 1.0)), col)
		if segs & 4: draw_rect(Rect2(o + Vector2(0.0, h - 1.0), Vector2(w, 1.0)), col)
		if segs & 8: draw_rect(Rect2(o, Vector2(1.0, h * 0.5)), col)
		if segs & 16: draw_rect(Rect2(o + Vector2(w - 1.0, 0.0), Vector2(1.0, h * 0.5)), col)
		if segs & 32: draw_rect(Rect2(o + Vector2(0.0, h * 0.5), Vector2(1.0, h * 0.5)), col)
		draw_rect(Rect2(o + Vector2(w - 1.0, h * 0.5), Vector2(1.0, h * 0.5)), col)


## 告示:几张淡白的纸贴在墙上,略微错开,上面几行看不清的字。
func _notices(r: Rect2, rng: RandomNumberGenerator) -> void:
	var n: int = rng.randi_range(2, 3)
	for i in n:
		var w: float = rng.randf_range(7.0, 10.0)
		var h: float = rng.randf_range(9.0, r.size.y)
		var x: float = r.position.x + (r.size.x - w) * float(i) / maxf(float(n - 1), 1.0)
		var y: float = r.position.y + rng.randf_range(0.0, r.size.y - h)
		draw_rect(Rect2(x, y, w, h), Color(WHITE_FAINT, rng.randf_range(0.06, 0.12)))
		var ly: float = y + 2.0
		while ly < y + h - 2.0:
			draw_rect(Rect2(x + 1.0, ly, rng.randf_range(2.0, w - 2.0), 1.0), Color(DARK, 0.6))
			ly += 2.0


# ------------------------------------------------------------------ 塔4 军事

## 沙袋:一层层错开的袋子,上面一层少一个。
func _sandbags(r: Rect2, rng: RandomNumberGenerator) -> void:
	var bw: float = 8.0
	var bh: float = 5.0
	var rows: int = maxi(1, int(r.size.y / bh))
	for row in rows:
		var y: float = r.end.y - bh * float(row + 1)
		var x: float = r.position.x + (bw * 0.5 if row % 2 == 1 else 0.0) + bw * 0.5 * float(row / 2)
		var right: float = r.end.x - bw * 0.5 * float(row / 2)
		while x + bw <= right + 0.5:
			var c: Color = BODY.lerp(LIGHT, rng.randf_range(0.2, 0.8))
			draw_rect(Rect2(x + 1.0, y, bw - 2.0, bh), c)
			draw_rect(Rect2(x, y + 1.0, bw, bh - 2.0), c)
			draw_rect(Rect2(x + 1.0, y, bw - 2.0, 1.0), c.lightened(0.1))
			draw_rect(Rect2(x + bw * 0.5, y + 1.0, 1.0, 1.0), DARK)            # 扎口
			x += bw


## 弹药箱:箱盖一道缝、一个搭扣、一块淡白的喷字。
func _ammo(r: Rect2) -> void:
	draw_rect(r, BODY.lerp(LIGHT, 0.3))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), LIGHT)
	draw_rect(Rect2(r.position + Vector2(0.0, 3.0), Vector2(r.size.x, 1.0)), DARK)
	draw_rect(Rect2(r.position + Vector2(r.size.x * 0.5 - 1.0, 2.0), Vector2(2.0, 3.0)), LIGHT)
	draw_rect(Rect2(r.position + Vector2(2.0, 5.0), Vector2(r.size.x * 0.4, 2.0)), WHITE_FAINT)


## 枪架:一个框,里面几支枪的剪影竖着靠。
func _rack(r: Rect2) -> void:
	draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 3.0), BODY)
	draw_rect(Rect2(r.position.x, r.position.y + 4.0, r.size.x, 2.0), BODY)
	draw_rect(Rect2(r.position.x, r.position.y + 4.0, 2.0, r.size.y - 4.0), BODY)
	draw_rect(Rect2(r.end.x - 2.0, r.position.y + 4.0, 2.0, r.size.y - 4.0), BODY)
	var x: float = r.position.x + 4.0
	while x < r.end.x - 4.0:
		draw_rect(Rect2(x, r.position.y, 1.0, r.size.y - 8.0), LIGHT)       # 枪管
		draw_rect(Rect2(x, r.end.y - 9.0, 3.0, 6.0), LIGHT)                  # 枪托
		x += 4.0


## 拒马:两根交叉的粗梁 + 一根横梁。
func _hedgehog(r: Rect2) -> void:
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), LIGHT, 2.0)
	draw_line(Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.end.y), BODY, 2.0)
	draw_rect(Rect2(r.position.x + 2.0, r.position.y + r.size.y * 0.5 - 1.0, r.size.x - 4.0, 2.0), BODY.lerp(LIGHT, 0.5))


## 铁丝网:一串圈,圈上几根刺。
func _wire(r: Rect2) -> void:
	var rad: float = r.size.y * 0.5
	var x: float = r.position.x + rad
	var col: Color = BODY.lerp(LIGHT, 0.8)
	while x < r.end.x - rad + 0.5:
		var c := Vector2(x, r.position.y + rad)
		draw_arc(c, rad - 0.5, 0.0, TAU, 12, col, 1.0)
		draw_line(c + Vector2(0.0, -rad), c + Vector2(1.0, -rad - 2.0), col, 1.0)
		draw_line(c + Vector2(rad, 0.0), c + Vector2(rad + 2.0, 1.0), col, 1.0)
		x += rad * 1.2


## 警示牌:一块斜纹板(只用冷白和墨色,不用黄 —— 美术规格:关卡 90% 冷色)。
func _hazard(r: Rect2) -> void:
	draw_rect(r, DARK)
	var y: float = r.position.y
	while y < r.end.y - 4.0:
		draw_colored_polygon(PackedVector2Array([
			Vector2(r.position.x + 1.0, y + 4.0), Vector2(r.position.x + 1.0, y + 7.0),
			Vector2(r.end.x - 1.0, y + 3.0), Vector2(r.end.x - 1.0, y)]), Color(WHITE_DIM, 0.22))
		y += 6.0
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), LIGHT)


## 墙上的喷字:一个 V 形箭头 + 两位编号(只是方块),淡白。
func _stencil(r: Rect2, rng: RandomNumberGenerator) -> void:
	var col := Color(WHITE_FAINT, 0.1)
	var cy: float = r.position.y + r.size.y * 0.5
	var x0: float = r.position.x
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0, r.position.y), Vector2(x0 + 3.0, r.position.y), Vector2(x0 + 7.0, cy),
		Vector2(x0 + 3.0, r.end.y), Vector2(x0, r.end.y), Vector2(x0 + 4.0, cy)]), col)
	var x: float = x0 + 10.0
	for d in 2:
		if x + 4.0 > r.end.x:
			break
		draw_rect(Rect2(x, r.position.y + 1.0, 4.0, 1.0), col)
		draw_rect(Rect2(x + (3.0 if rng.randf() < 0.5 else 0.0), r.position.y + 1.0, 1.0, r.size.y - 2.0), col)
		draw_rect(Rect2(x, r.end.y - 2.0, 4.0, 1.0), col)
		x += 6.0


## 信号盒:墙上一个小铁盒,两个小指示灯(一青一锈,都很暗)。
func _signal(r: Rect2) -> void:
	draw_rect(r, BODY)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), LIGHT)
	draw_rect(Rect2(r.position + Vector2(2.0, 3.0), Vector2(1.0, 1.0)), CYAN_DIM)
	draw_rect(Rect2(r.position + Vector2(5.0, 3.0), Vector2(1.0, 1.0)), RUST_DIM)
	draw_rect(Rect2(r.position + Vector2(2.0, 6.0), Vector2(r.size.x - 4.0, 1.0)), DARK)
	draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 1.0, r.end.y, 1.0, 6.0), CABLE)


## 罩灯:一根线吊着一个铁丝罩;熄的灯泡是暗的。
func _cage_lamp(r: Rect2, on: bool = false) -> void:
	var cx: float = r.position.x + r.size.x * 0.5
	draw_rect(Rect2(cx, r.position.y, 1.0, r.size.y - 8.0), CABLE)
	var top: float = r.end.y - 8.0
	draw_rect(Rect2(r.position.x, top, r.size.x, 2.0), LIGHT)
	draw_circle(Vector2(cx + 0.5, top + 5.0), 2.0, BULB_ON if on else DARK)
	draw_rect(Rect2(r.position.x, top + 2.0, 1.0, 6.0), BODY)
	draw_rect(Rect2(r.end.x - 1.0, top + 2.0, 1.0, 6.0), BODY)
	draw_rect(Rect2(cx, top + 2.0, 1.0, 6.0), BODY)
	draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), BODY)


## 警示灯(塔2 管道、塔4 墙上):小方座 + 圆罩;亮的罩是锈红(应急 / 警报,美术规格里锈红的用途)。
func _warn_lamp(r: Rect2, on: bool = false) -> void:
	draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 3.0), BODY)
	draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 1.0), LIGHT)
	var c := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.45)
	draw_circle(c, r.size.x * 0.5 - 0.5, LIGHT)
	draw_circle(c, r.size.x * 0.5 - 1.5, RUST_ON if on else DARK)
	draw_rect(Rect2(c.x - 3.0, c.y - 0.5, 6.0, 1.0), BODY)      # 罩上的铁箍


## 工作灯(塔2、下行):吊在梁下的搪瓷反光罩,亮的罩口一道冷光。
func _work_lamp(r: Rect2, on: bool = false) -> void:
	var cx: float = r.position.x + r.size.x * 0.5
	draw_rect(Rect2(cx, r.position.y, 1.0, r.size.y - 5.0), CABLE)
	var top: float = r.end.y - 5.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 1.0, top), Vector2(cx + 2.0, top),
		Vector2(r.end.x, r.end.y - 1.0), Vector2(r.position.x, r.end.y - 1.0)]), LIGHT)
	draw_rect(Rect2(r.position.x + 1.0, r.end.y - 1.0, r.size.x - 2.0, 1.0), BULB_ON if on else DARK)


# ------------------------------------------------------------------ 坑口·下行

## 岩石:不规则的一块(多边形),底下一圈蚀的紫。
func _rock(r: Rect2, rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array()
	var n: int = 7
	var c := Vector2(r.get_center().x, r.end.y)
	for i in n:
		var a: float = PI + PI * float(i) / float(n - 1)          # 上半圆
		var rx: float = r.size.x * 0.5 * rng.randf_range(0.75, 1.0)
		var ry: float = r.size.y * rng.randf_range(0.7, 1.0)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, BODY)
	draw_polyline(pts, LIGHT, 1.0)
	draw_rect(Rect2(r.position.x + 2.0, r.end.y - 2.0, r.size.x - 4.0, 2.0), SLUDGE)
	draw_rect(Rect2(r.position.x + r.size.x * 0.3, r.end.y - 3.0, 3.0, 1.0), SHEEN_DIM)


## 被蚀糊住的旧设备:一个铁箱,几道面板缝、一个表,上面淌着一道道紫黑的蚀。
func _machine(r: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(r, BODY)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), LIGHT)
	draw_rect(Rect2(r.position.x + 2.0, r.position.y + 4.0, r.size.x - 4.0, 1.0), DARK)
	draw_rect(Rect2(r.position.x + r.size.x * 0.5, r.position.y + 5.0, 1.0, r.size.y - 7.0), DARK)
	draw_arc(r.position + Vector2(5.0, 9.0), 2.5, 0.0, TAU, 10, LIGHT, 1.0)
	var x: float = r.position.x + 1.0
	while x < r.end.x - 1.0:
		if rng.randf() < 0.45:
			var h: float = rng.randf_range(3.0, r.size.y - 2.0)
			draw_rect(Rect2(x, r.position.y, 2.0, h), SLUDGE)
			draw_rect(Rect2(x, r.position.y + h, 2.0, 1.0), SHEEN_DIM)
		x += rng.randf_range(3.0, 6.0)
	draw_rect(Rect2(r.position.x - 2.0, r.end.y - 2.0, r.size.x + 4.0, 2.0), SLUDGE)


## 坑壁上淌下来的一道蚀。
func _drip(r: Rect2, rng: RandomNumberGenerator) -> void:
	var w: float = r.size.x
	draw_rect(Rect2(r.position.x, r.position.y, w, r.size.y * 0.6), Color(SLUDGE, 0.55))
	draw_rect(Rect2(r.position.x + 1.0, r.position.y, w - 2.0, r.size.y * rng.randf_range(0.8, 1.0)), Color(SLUDGE, 0.7))
	draw_rect(Rect2(r.position.x + w * 0.5, r.end.y - 2.0, 1.0, 2.0), SHEEN_DIM)


## 断掉的吊缆:从上面垂下来一截,末端炸开成几股。
func _snapped_cable(r: Rect2, rng: RandomNumberGenerator) -> void:
	var cx: float = r.position.x + r.size.x * 0.5
	var end := Vector2(cx + rng.randf_range(-2.0, 2.0), r.end.y - 4.0)
	draw_line(Vector2(cx, r.position.y), end, CABLE.lightened(0.1), 2.0)
	draw_rect(Rect2(cx - 2.0, r.position.y, 4.0, 2.0), LIGHT)                   # 吊环
	for k in 3:
		var a: float = PI * 0.5 + (float(k) - 1.0) * 0.5
		draw_line(end, end + Vector2(cos(a), sin(a)) * 4.0, CABLE.lightened(0.2), 1.0)


## 蚀凝成的冰柱:一根往下尖的紫黑,尖上挂一滴。
func _stalactite(r: Rect2) -> void:
	draw_colored_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
			Vector2(r.get_center().x, r.end.y - 2.0)]), SLUDGE)
	draw_rect(Rect2(r.get_center().x, r.end.y - 1.0, 1.0, 1.0), SHEEN_DIM)
