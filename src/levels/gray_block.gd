class_name GrayBlock
extends StaticBody2D
## 可站立的石砌结构。节点原点是 **左上角**,位置与尺寸对齐 16px 网格。
##
## ## 精细化,但不牺牲可读性
##
## 背景做成砖砌之后,前景还是纯色块就很突兀。这里给它同样的砌法 —— 但前景的
## 首要职责是让玩家 **一眼认出"这能站"**,所以细节是有节制的:
##   - 顶面高光(TOP_EDGE_COLOR)最亮且 **不被任何细节打断** —— 它是可站性的信号
##   - 砖缝只压暗一点点,不做深缝,免得远看像裂开的洞
##   - 斑驳点很少,且只在砖中部,不碰边缘
## 背景可以很花,因为它暗;前景一花就会和"可交互物"抢注意力。
##
## ## 画在角色前面
##
## `gray_block.tscn` 的根节点 `z_index = 1`:实心的墙、地板、天花板画在角色(z 0)前面。
## 2026-10-10 起碰撞体已经和画出来的人一样高(站 42 / 蹲 34,见 `docs/ryn-animation-research.md`),
## 但头顶的呆毛、跑步甩起的头发、跳起来撞到天花板那一下,仍会比碰撞体多出几 px ——
## 这几 px 应该被砖块挡住,而不是画到砖块上面。
## 用 GrayBlock 做的人物剪影(坑底/结局的 Vera 和吊坠)在各自场景里覆盖回 `z_index = 0`。
## 可拆物件(`dismantlable.tscn`)是 `z_index = 2`:它们常叠在实心块上(塔1 破盖板、坑底
## 要切断的节点),必须画在实心块之上,否则玩家看不见要互动的东西。
##
## ## 屋顶样式(2026-10-12,塔外的贫民窟屋顶)
##
## `style = ROOF`:顶上一条波纹铁皮(竖棱一亮一暗,偶尔一道很淡的锈痕),下面是楼的外墙,
## 稀稀拉拉几扇冷光窗。顶面高光照旧 —— 不管什么样式,「能站」的信号都一样。
##
## ## 塔内换装(2026-10-12)
##
## 每座塔一种材质:塔1 石砌(默认)、塔2 铆接钢板 `PLATE`、塔3 办公墙板 `PANEL`、塔4 浇筑混凝土 `BUNKER`;
## 外加 `CRATE`(箱子)和 `SHELF`(书架)给「本来就是箱子 / 书架」的那几块。底色都在 steel-blue 附近、
## 明度差不多,顶面高光和背光沿照旧 —— 换的是材质,不是「能不能站」。由 `tools/level_builder` 按
## 关卡描述里的 `BLOCK_STYLE` / `lv.style(...)` 写进场景。
##
## Usage (in a scene): instance gray_block.tscn, set `position` and `size`.
## Usage (in code):
##     var b := GrayBlock.new()
##     b.size = Vector2(64, 32)
##     b.position = Vector2(192, 288)
##     add_child(b)

const TOP_EDGE_COLOR: Color = Color("3D6B8A")
## 砌块尺寸。比背景砖大一号 —— 前景是承重结构,石料更大。
const BLOCK_W: float = 16.0
const BLOCK_H: float = 8.0
## 砖缝压暗量。刻意很浅。
const SEAM_DARKEN: float = 0.14
## 受光沿与背光沿。
const LIT_AMOUNT: float = 0.10
const SHADE_AMOUNT: float = 0.22

## Block size in pixels.
@export var size: Vector2 = Vector2(16, 16):
	set(value):
		size = value
		queue_redraw()
## Fill colour (palette: steel-blue for structure).
@export var fill_color: Color = Color("1A2A44")

enum Style {
	## 石砌(塔里)。
	MASONRY,
	## 贫民窟屋顶:波纹铁皮 + 楼的外墙。
	ROOF,
	## 输油管:圆柱的明暗、法兰环、锈痕(横的是管子,竖的是立管)。
	PIPE,
	## 钢架:上下翼板、中间 X 形斜撑、铆钉(栈桥、脚手架)。
	GIRDER,
	## 货箱:一格一只的铁皮箱,箱框 + X 形加强筋(塔1 跳跃教学的箱子、塔4 军械库的货箱)。
	CRATE,
	## 精炼塔:铆接钢板,板缝下偶尔一道锈。
	PLATE,
	## 登记塔:干净的办公墙板,顶下一条很淡的白边。
	PANEL,
	## 军事塔:浇筑混凝土,模板纹 + 对拉螺栓孔;一格厚的窄道底下一条警示斜纹。
	BUNKER,
	## 登记塔的书架:上下两块搁板,中间一排档案夹的书脊。
	SHELF,
}
@export var style: Style = Style.MASONRY

## 屋顶样式的颜色。外墙比石砌暗(夜里的楼),铁皮比外墙亮一点,锈只是一点点。
const ROOF_METAL: Color = Color("22324C")
const ROOF_WALL: Color = Color("111A2B")
const ROOF_RUST: Color = Color(0.545, 0.227, 0.184, 0.35)
const ROOF_WINDOW: Color = Color(0.239, 0.42, 0.541, 0.75)
## 铁皮那一条有多厚,px。
const ROOF_BAND: float = 6.0
## 管子 / 钢架的颜色(都是冷的,锈只是一点点)。
const PIPE_BODY: Color = Color("2A3446")
const GIRDER_STEEL: Color = Color("1E2A3C")
## 塔内四种样式的底色:都在 steel-blue(#1A2A44)附近,明度差不多 —— 换的是材质,不是「能不能站」。
const CRATE_STEEL: Color = Color("1E2B40")
const PLATE_STEEL: Color = Color("1B2639")
const PANEL_FILL: Color = Color("1D2B3F")
const BUNKER_FILL: Color = Color("172337")
const SHELF_WOOD: Color = Color("1F2C42")
## 板缝下的锈、办公墙板的白边、军事塔的警示斜纹:都很淡。
const PLATE_RUST: Color = Color(0.545, 0.227, 0.184, 0.3)
const PANEL_TRIM: Color = Color(0.784, 0.831, 0.878, 0.1)
const HAZARD_LIGHT: Color = Color(0.784, 0.831, 0.878, 0.16)


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = size * 0.5
	add_child(collider)


func _draw() -> void:
	if style == Style.ROOF:
		_draw_roof()
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 1.0)), TOP_EDGE_COLOR)
		return
	if style == Style.PIPE:
		_draw_pipe()
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 1.0)), TOP_EDGE_COLOR)
		return
	if style == Style.GIRDER:
		_draw_girder()
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 1.0)), TOP_EDGE_COLOR)
		return
	if style >= Style.CRATE:
		var base: Color = fill_color
		match style:
			Style.CRATE:
				base = CRATE_STEEL
				_draw_crates()
			Style.PLATE:
				base = PLATE_STEEL
				_draw_plates()
			Style.PANEL:
				base = PANEL_FILL
				_draw_panels()
			Style.BUNKER:
				base = BUNKER_FILL
				_draw_bunker()
			Style.SHELF:
				base = SHELF_WOOD
				_draw_shelf()
		if size.y > 3.0:
			draw_rect(Rect2(0.0, size.y - 1.0, size.x, 1.0), base.darkened(SHADE_AMOUNT))
		if size.x > 3.0:
			draw_rect(Rect2(size.x - 1.0, 0.0, 1.0, size.y), base.darkened(SHADE_AMOUNT * 0.7))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 1.0)), TOP_EDGE_COLOR)
		return
	draw_rect(Rect2(Vector2.ZERO, size), fill_color)
	_draw_masonry()
	# 底面与右侧背光沿 —— 给整块一点体积
	if size.y > 3.0:
		draw_rect(Rect2(0.0, size.y - 1.0, size.x, 1.0), fill_color.darkened(SHADE_AMOUNT))
	if size.x > 3.0:
		draw_rect(Rect2(size.x - 1.0, 0.0, 1.0, size.y), fill_color.darkened(SHADE_AMOUNT * 0.7))
	# 顶面高光最后画,确保不被任何砖缝打断 —— 这是"能站"的信号。
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 1.0)), TOP_EDGE_COLOR)


## 交错砌块。用确定性伪随机(按本块的世界位置取种子),所以同一块砖每帧一致,
## 相邻两块又不会出现同样的图案。
func _draw_masonry() -> void:
	if size.x < BLOCK_W * 0.75 or size.y < BLOCK_H * 1.5:
		return   # 太小的块画砖缝只会糊成一团
	var seam := fill_color.darkened(SEAM_DARKEN)
	var lit := fill_color.lightened(LIT_AMOUNT)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x) * 73856093 ^ int(position.y) * 19349663
	var row: int = 0
	var y: float = BLOCK_H
	while y < size.y - 1.0:
		# 横缝
		draw_rect(Rect2(0.0, y, size.x, 1.0), seam)
		# 缝下沿的受光线 —— 砌块的厚度
		if y + 1.0 < size.y - 1.0:
			draw_rect(Rect2(0.0, y + 1.0, size.x, 1.0), lit)
		# 竖缝,逐行交错
		var x: float = BLOCK_W * (0.5 if row % 2 == 1 else 1.0)
		while x < size.x - 1.0:
			draw_rect(Rect2(x, y, 1.0, minf(BLOCK_H, size.y - y)), seam)
			x += BLOCK_W
		# 斑驳:每行一两点,只落在砖中部
		for i in rng.randi_range(0, 2):
			var sx: float = rng.randf_range(2.0, maxf(size.x - 3.0, 2.0))
			var sy: float = y + rng.randf_range(2.0, maxf(BLOCK_H - 2.0, 2.0))
			if sy < size.y - 2.0:
				draw_rect(Rect2(sx, sy, 1.0, 1.0), fill_color.darkened(0.1))
		y += BLOCK_H
		row += 1
	# 第一行的竖缝(顶面高光之下)
	var x0: float = BLOCK_W
	while x0 < size.x - 1.0:
		draw_rect(Rect2(x0, 1.0, 1.0, minf(BLOCK_H - 1.0, size.y - 1.0)), seam)
		x0 += BLOCK_W


## 屋顶:上面一条波纹铁皮,下面楼的外墙和几扇窗。按世界位置取种子,每帧一致。
func _draw_roof() -> void:
	var band: float = minf(ROOF_BAND, size.y)
	draw_rect(Rect2(Vector2.ZERO, size), ROOF_WALL)
	draw_rect(Rect2(0.0, 0.0, size.x, band), ROOF_METAL)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x) * 73856093 ^ int(position.y) * 19349663
	# 波纹:每 4px 一道棱,亮一线、暗一线
	var x: float = 1.0
	while x < size.x - 1.0:
		draw_rect(Rect2(x, 1.0, 1.0, band - 1.0), ROOF_METAL.lightened(0.12))
		draw_rect(Rect2(x + 2.0, 1.0, 1.0, band - 1.0), ROOF_METAL.darkened(0.25))
		x += 4.0
	# 铁皮下沿的阴影 —— 檐口
	if size.y > band + 1.0:
		draw_rect(Rect2(0.0, band, size.x, 1.0), ROOF_WALL.darkened(0.45))
	# 锈痕:很少,顺着波纹往下淌一小段
	for i in int(size.x / 48.0):
		if rng.randf() < 0.5:
			var rx: float = floorf(rng.randf_range(2.0, maxf(size.x - 3.0, 2.0)) / 4.0) * 4.0 + 1.0
			draw_rect(Rect2(rx, 2.0, 1.0, rng.randf_range(2.0, band)), ROOF_RUST)
	# 外墙上的窗:3x4,大多黑着
	var wy: float = band + 8.0
	while wy < size.y - 8.0:
		var wx: float = 6.0
		while wx < size.x - 8.0:
			var roll: float = rng.randf()
			if roll < 0.06:
				draw_rect(Rect2(wx, wy, 3.0, 4.0), ROOF_WINDOW)
			elif roll < 0.3:
				draw_rect(Rect2(wx, wy, 3.0, 4.0), ROOF_WALL.darkened(0.35))
			wx += 12.0
		wy += 14.0
	# 右侧背光沿
	if size.x > 3.0:
		draw_rect(Rect2(size.x - 1.0, band, 1.0, size.y - band), ROOF_WALL.darkened(0.3))


## 管子:横的(宽 ≥ 高)画成卧着的圆柱,竖的画成立管。每 48px 一道法兰环,偶尔一道锈痕。
func _draw_pipe() -> void:
	var horizontal: bool = size.x >= size.y
	var span: float = size.y if horizontal else size.x
	var steps: int = maxi(int(span), 1)
	for i in steps:
		# 圆柱的明暗:受光的一边亮、中间正常、背光一边暗
		var k: float = (float(i) + 0.5) / float(steps)
		var shade: float = sin(k * PI)
		var c: Color = PIPE_BODY.darkened(0.35).lerp(PIPE_BODY.lightened(0.18), shade)
		if k < 0.25:
			c = c.lightened(0.08)
		if horizontal:
			draw_rect(Rect2(0.0, float(i), size.x, 1.0), c)
		else:
			draw_rect(Rect2(float(i), 0.0, 1.0, size.y), c)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x) * 73856093 ^ int(position.y) * 19349663
	var along: float = size.x if horizontal else size.y
	var a: float = 24.0
	while a < along - 8.0:
		# 法兰:比管子粗一点的一圈,中间一排螺栓
		if horizontal:
			draw_rect(Rect2(a, 0.0, 4.0, size.y), PIPE_BODY.lightened(0.1))
			draw_rect(Rect2(a + 4.0, 0.0, 1.0, size.y), PIPE_BODY.darkened(0.4))
			var by: float = 2.0
			while by < size.y - 2.0:
				draw_rect(Rect2(a + 1.0, by, 1.0, 1.0), PIPE_BODY.lightened(0.35))
				by += 4.0
		else:
			draw_rect(Rect2(0.0, a, size.x, 4.0), PIPE_BODY.lightened(0.1))
			draw_rect(Rect2(0.0, a + 4.0, size.x, 1.0), PIPE_BODY.darkened(0.4))
		a += 48.0
	# 锈:顺着管子底部淌下的几道
	for i in int(along / 40.0):
		if rng.randf() < 0.45:
			var at: float = rng.randf_range(4.0, maxf(along - 6.0, 4.0))
			if horizontal:
				draw_rect(Rect2(at, size.y * 0.55, 1.0, size.y * 0.45), ROOF_RUST)
			else:
				draw_rect(Rect2(size.x * 0.55, at, size.x * 0.45, 1.0), ROOF_RUST)


## 钢架:上翼板(亮)、下翼板、中间每 16px 一根竖杆,两根之间 X 形斜撑,翼板上一排铆钉。
func _draw_girder() -> void:
	var steel := GIRDER_STEEL
	if size.y < 6.0:
		draw_rect(Rect2(Vector2.ZERO, size), steel.lightened(0.12))
		return
	# 中间是空的(透出后面的景),只画骨架
	draw_rect(Rect2(0.0, 0.0, size.x, 3.0), steel.lightened(0.15))
	draw_rect(Rect2(0.0, size.y - 3.0, size.x, 3.0), steel)
	var x: float = 0.0
	while x <= size.x - 1.0:
		draw_rect(Rect2(x, 0.0, 2.0, size.y), steel.lightened(0.05))
		var nx: float = minf(x + 16.0, size.x - 2.0)
		if nx > x + 4.0:
			draw_line(Vector2(x + 1.0, 3.0), Vector2(nx + 1.0, size.y - 3.0), steel.lightened(0.02), 1.0)
			draw_line(Vector2(nx + 1.0, 3.0), Vector2(x + 1.0, size.y - 3.0), steel.lightened(0.02), 1.0)
		x += 16.0
	draw_rect(Rect2(size.x - 2.0, 0.0, 2.0, size.y), steel.lightened(0.05))
	# 铆钉
	var r: float = 3.0
	while r < size.x - 2.0:
		draw_rect(Rect2(r, 1.0, 1.0, 1.0), steel.lightened(0.45))
		draw_rect(Rect2(r, size.y - 2.0, 1.0, 1.0), steel.lightened(0.3))
		r += 6.0


## 按本块的世界位置取种子:同一块每帧一样,相邻两块又不一样。
func _seeded() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x) * 73856093 ^ int(position.y) * 19349663
	return rng


## 货箱:整块分成一只只箱子(宽约 24、高 16),每只一圈箱框 + X 形加强筋,偶尔一块模糊的喷字。
func _draw_crates() -> void:
	var rng := _seeded()
	var cols: int = maxi(1, roundi(size.x / 24.0))
	var rows: int = maxi(1, roundi(size.y / 16.0))
	var cw: float = size.x / float(cols)
	var ch: float = size.y / float(rows)
	for r in rows:
		for c in cols:
			var o := Vector2(floorf(c * cw), floorf(r * ch))
			var s := Vector2(floorf((c + 1) * cw) - o.x, floorf((r + 1) * ch) - o.y)
			var body: Color = CRATE_STEEL.lerp(Color.BLACK, rng.randf_range(0.0, 0.12))
			draw_rect(Rect2(o, s), body)
			var brace: Color = body.darkened(0.25)
			draw_line(o + Vector2(2.0, 2.0), o + s - Vector2(2.0, 2.0), brace, 1.0)
			draw_line(o + Vector2(s.x - 2.0, 2.0), o + Vector2(2.0, s.y - 2.0), brace, 1.0)
			draw_rect(Rect2(o, Vector2(s.x, 1.0)), body.lightened(0.14))            # 箱框
			draw_rect(Rect2(o, Vector2(1.0, s.y)), body.lightened(0.1))
			draw_rect(Rect2(o + Vector2(s.x - 1.0, 0.0), Vector2(1.0, s.y)), body.darkened(0.35))
			draw_rect(Rect2(o + Vector2(0.0, s.y - 1.0), Vector2(s.x, 1.0)), body.darkened(0.35))
			if s.x >= 14.0 and s.y >= 12.0 and rng.randf() < 0.35:
				draw_rect(Rect2(o + Vector2(floorf(s.x * 0.5) - 3.0, floorf(s.y * 0.5) - 1.0), Vector2(6.0, 2.0)),
					PANEL_TRIM)


## 精炼塔的铆接钢板:32×16 一块,逐行错开半块;板缝压暗,四角铆钉,板缝下偶尔淌一道锈。
func _draw_plates() -> void:
	var rng := _seeded()
	draw_rect(Rect2(Vector2.ZERO, size), PLATE_STEEL)
	var seam: Color = PLATE_STEEL.darkened(0.32)
	var rivet: Color = PLATE_STEEL.lightened(0.3)
	var row: int = 0
	var y: float = 0.0
	while y < size.y:
		var ph: float = minf(16.0, size.y - y)
		var x: float = -16.0 if row % 2 == 1 else 0.0
		while x < size.x:
			var x0: float = maxf(x, 0.0)
			var x1: float = minf(x + 32.0, size.x)
			draw_rect(Rect2(x0, y, x1 - x0, ph), PLATE_STEEL.lerp(Color.BLACK, rng.randf_range(0.0, 0.1)))
			if x1 < size.x:
				draw_rect(Rect2(x1 - 1.0, y, 1.0, ph), seam)
			if ph >= 8.0 and x1 - x0 >= 10.0:
				for rx in [x0 + 2.0, x1 - 4.0]:
					draw_rect(Rect2(rx, y + 2.0, 1.0, 1.0), rivet)
					draw_rect(Rect2(rx, y + ph - 3.0, 1.0, 1.0), rivet)
			x += 32.0
		if y + ph < size.y:
			draw_rect(Rect2(0.0, y + ph - 1.0, size.x, 1.0), seam)
		y += 16.0
		row += 1
	for i in int(size.x / 40.0) + 1:
		if rng.randf() < 0.4 and size.y > 18.0:
			var rx: float = floorf(rng.randf_range(2.0, maxf(size.x - 3.0, 2.0)))
			var ry: float = floorf(rng.randf_range(0.0, maxf(size.y - 18.0, 0.0)) / 16.0) * 16.0 + 16.0
			draw_rect(Rect2(rx, ry, 1.0, minf(rng.randf_range(3.0, 9.0), size.y - ry - 1.0)), PLATE_RUST)


## 登记塔的办公墙板:48×16 一格,左上受光、右下背光;顶下第 3 行一条很淡的白边;偶尔一张小标签。
func _draw_panels() -> void:
	var rng := _seeded()
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_FILL)
	var lit: Color = PANEL_FILL.lightened(0.08)
	var dark: Color = PANEL_FILL.darkened(0.3)
	var y: float = 0.0
	while y < size.y:
		var ph: float = minf(16.0, size.y - y)
		var x: float = 0.0
		while x < size.x:
			var pw: float = minf(48.0, size.x - x)
			if y > 0.0:
				draw_rect(Rect2(x, y, pw, 1.0), lit)
			if x > 0.0:
				draw_rect(Rect2(x, y, 1.0, ph), lit)
			draw_rect(Rect2(x + pw - 1.0, y, 1.0, ph), dark)
			draw_rect(Rect2(x, y + ph - 1.0, pw, 1.0), dark)
			if pw >= 24.0 and ph >= 12.0 and rng.randf() < 0.18:
				draw_rect(Rect2(x + 6.0, y + 6.0, 5.0, 2.0), PANEL_TRIM)
			x += 48.0
		y += 16.0
	if size.y > 6.0:
		draw_rect(Rect2(0.0, 3.0, size.x, 1.0), PANEL_TRIM)


## 军事塔的浇筑混凝土:每 8px 一道模板纹,24×16 一个对拉螺栓孔;一格厚的窄道底下 4px 警示斜纹。
func _draw_bunker() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BUNKER_FILL)
	var line: Color = BUNKER_FILL.darkened(0.12)
	var hole: Color = BUNKER_FILL.darkened(0.45)
	var y: float = 8.0
	while y < size.y - 1.0:
		draw_rect(Rect2(0.0, y, size.x, 1.0), line)
		y += 8.0
	var hy: float = 6.0
	var stripes: bool = size.y <= 16.0 and size.x >= 32.0
	var stripe_top: float = size.y - 5.0
	while hy < size.y - 3.0:
		if stripes and hy + 2.0 > stripe_top:
			break
		var hx: float = 12.0 if int(hy / 16.0) % 2 == 0 else 24.0
		while hx < size.x - 4.0:
			draw_rect(Rect2(hx, hy, 2.0, 2.0), hole)
			draw_rect(Rect2(hx, hy + 2.0, 2.0, 1.0), BUNKER_FILL.lightened(0.08))
			hx += 24.0
		hy += 16.0
	if stripes:
		draw_rect(Rect2(0.0, stripe_top, size.x, 4.0), BUNKER_FILL.darkened(0.3))
		var sx: float = 0.0
		while sx + 8.0 <= size.x:
			draw_colored_polygon(PackedVector2Array([
				Vector2(sx, stripe_top + 4.0), Vector2(sx + 4.0, stripe_top + 4.0),
				Vector2(sx + 8.0, stripe_top), Vector2(sx + 4.0, stripe_top)]), HAZARD_LIGHT)
			sx += 8.0


## 书架:每 16px 一层,上搁板 3px、下搁板 2px,中间一排档案夹书脊(高低、宽窄、灰度都不一),偶尔一个空档。
func _draw_shelf() -> void:
	var rng := _seeded()
	draw_rect(Rect2(Vector2.ZERO, size), Color("0D1420"))
	var spines: Array[Color] = [Color("2A3850"), Color("223047"), Color("34425A"), Color("1A2638"), Color("2E3B52")]
	var y: float = 0.0
	while y < size.y:
		var ph: float = minf(16.0, size.y - y)
		var floor_y: float = y + ph - 2.0
		var x: float = 1.0
		while x < size.x - 2.0:
			if rng.randf() < 0.08:
				x += rng.randf_range(3.0, 7.0)                       # 空档
				continue
			var w: float = float(rng.randi_range(2, 4))
			var h: float = minf(rng.randf_range(7.0, 11.0), floor_y - y - 3.0)
			var c: Color = spines[rng.randi() % spines.size()]
			draw_rect(Rect2(x, floor_y - h, minf(w, size.x - 2.0 - x), h), c)
			if w >= 3.0 and rng.randf() < 0.3:
				draw_rect(Rect2(x + 1.0, floor_y - h * 0.6, 1.0, 2.0), PANEL_TRIM)
			x += w + 1.0
		draw_rect(Rect2(0.0, y, size.x, 3.0), SHELF_WOOD.lightened(0.08))      # 上搁板
		draw_rect(Rect2(0.0, floor_y, size.x, 2.0), SHELF_WOOD.darkened(0.1))  # 下搁板
		y += 16.0
