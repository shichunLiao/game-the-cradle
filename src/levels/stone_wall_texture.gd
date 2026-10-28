class_name StoneWallTexture
extends RefCounted
## 程序生成中世纪石砌墙纹理。一次生成,之后每帧只画贴图。
##
## ## 精细度从哪来
##
## 第一版只是"纯色矩形排成砖",远看是砖、近看是色块。这一版每块砖本身有结构:
##   - 上沿受光、下沿与右沿背光 —— 单块砖就有体积
##   - 砖面随机斑驳点 —— 石头不是涂料
##   - 整体垂直明暗渐变 —— 墙根比墙腰暗,光从上方来
## 再加上城堡的建筑构件:腰线、箭窗(带透光)、壁龛、梁托、拱券。
##
## ## 风格依据
##
## `设定摘要.md`:「坑底是旧世界『方舟』」—— 塔是旧世界石造建筑,被改造成设施。
## 石砌是本体,管道灯管是后钉上去的(在 `tower_backdrop.gd` 里画)。
##
## 确定性:同一 `seed` 每次生成完全相同的墙。

const BRICK_H: int = 18
const BRICK_W_MIN: int = 26
const BRICK_W_MAX: int = 52
const MORTAR: int = 2


## 一面墙的全部参数。比一长串位置参数好读,也方便每层只改几项。
class Spec:
	var width: int = 1024
	var height: int = 500
	var seed_value: int = 1
	var stone: Color = Color("141C2B")
	var mortar: Color = Color("0A0F1A")
	var dark: Color = Color("05080D")
	## 透光色 —— 箭窗/裂缝透进来的光。为 0 透明则不画。
	var glow: Color = Color(0.34, 0.45, 0.58, 0.16)
	var breaches: int = 10
	var arches: int = 4
	var pilaster_spacing: int = 170
	## 细长箭窗数量。中世纪城堡的标志性开口。
	var slits: int = 5
	## 壁龛数量。
	var niches: int = 3
	## 腰线(横向装饰带)的行间隔,0 = 不画。
	var course_every: int = 6
	## 砖面斑驳点密度,每块砖的点数上限。
	var speckle: int = 3
	## 顶部额外压暗(0..1)。光从上方来时墙顶反而更暗 —— 拱顶阴影。
	var top_darken: float = 0.35
	## 墙根额外压暗。
	var bottom_darken: float = 0.22


static func build_spec(spec: Spec) -> ImageTexture:
	var w: int = maxi(spec.width, 8)
	var h: int = maxi(spec.height, 8)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = spec.seed_value
	img.fill(spec.mortar)

	# --- 砖:每块有受光沿、背光沿与斑驳 ---
	var y: int = 0
	var row: int = 0
	while y < h:
		var x: int = -rng.randi_range(0, BRICK_W_MAX) if row % 2 == 1 else 0
		var is_course: bool = spec.course_every > 0 and row % spec.course_every == 0
		while x < w:
			var bw: int = rng.randi_range(BRICK_W_MIN, BRICK_W_MAX)
			if is_course:
				bw = rng.randi_range(28, 40)   # 腰线用长条石
			var shade: float = rng.randf_range(-0.03, 0.03)
			var base := Color(
				clampf(spec.stone.r + shade, 0.0, 1.0),
				clampf(spec.stone.g + shade, 0.0, 1.0),
				clampf(spec.stone.b + shade, 0.0, 1.0), 1.0)
			if is_course:
				base = base.lightened(0.035)
			var rx: int = maxi(x, 0)
			var rw: int = mini(bw - (rx - x) - MORTAR, w - rx)
			var rh: int = mini(BRICK_H - MORTAR, h - y)
			if rw > 1 and rh > 1:
				img.fill_rect(Rect2i(rx, y, rw, rh), base)
				# 受光沿:上 1px
				img.fill_rect(Rect2i(rx, y, rw, 1), base.lightened(0.05))
				# 背光沿:下 1px 与右 1px —— 单块砖的体积感全靠这两条
				img.fill_rect(Rect2i(rx, y + rh - 1, rw, 1), base.darkened(0.16))
				img.fill_rect(Rect2i(rx + rw - 1, y, 1, rh), base.darkened(0.12))
				# 斑驳:石头不是涂料
				for sp in rng.randi_range(0, spec.speckle):
					var px2: int = rx + rng.randi_range(1, maxi(rw - 2, 1))
					var py2: int = y + rng.randi_range(1, maxi(rh - 2, 1))
					if px2 < w and py2 < h:
						var d: float = rng.randf_range(-0.09, 0.05)
						img.fill_rect(Rect2i(px2, py2, rng.randi_range(1, 2), 1),
								base.lightened(d) if d > 0.0 else base.darkened(-d))
			x += bw
		y += BRICK_H
		row += 1

	# --- 壁柱:带柱头与基座 ---
	var px: int = spec.pilaster_spacing / 2
	while px < w:
		var pw: int = 22
		var col := spec.stone.lightened(0.03)
		img.fill_rect(Rect2i(px, 0, mini(pw, w - px), h), col)
		var ly: int = 0
		while ly < h:
			img.fill_rect(Rect2i(px, ly, mini(pw, w - px), MORTAR), spec.mortar)
			img.fill_rect(Rect2i(px, ly + 1, mini(pw, w - px), 1), col.lightened(0.04))
			ly += BRICK_H * 2
		img.fill_rect(Rect2i(px, 0, 1, h), spec.mortar)
		if px + pw - 1 < w:
			img.fill_rect(Rect2i(px + pw - 1, 0, 1, h), col.darkened(0.2))
		# 柱头:向两侧外探的梁托
		var cap_y: int = int(h * 0.26)
		var cw: int = pw + 10
		var cx0: int = clampi(px - 5, 0, w - 1)
		img.fill_rect(Rect2i(cx0, cap_y, mini(cw, w - cx0), 6), col.lightened(0.05))
		img.fill_rect(Rect2i(cx0, cap_y + 5, mini(cw, w - cx0), 1), col.darkened(0.22))
		px += spec.pilaster_spacing

	# --- 箭窗:细长开口,边缘斜切,透一点光 ---
	for i in spec.slits:
		var sw2: int = rng.randi_range(4, 7)
		var sh2: int = rng.randi_range(34, 62)
		var sx2: int = rng.randi_range(0, maxi(w - sw2 - 2, 1))
		var sy2: int = rng.randi_range(0, maxi(int(h * 0.55) - sh2, 1))
		img.fill_rect(Rect2i(sx2, sy2, sw2, sh2), spec.dark)
		# 斜切的窗侧 —— 城堡箭窗内宽外窄
		for k in 3:
			var iy: int = sy2 + sh2 + k
			if iy < h:
				img.fill_rect(Rect2i(maxi(sx2 - k, 0), iy, sw2 + k * 2, 1), spec.stone.darkened(0.18))
		if spec.glow.a > 0.0:
			img.fill_rect(Rect2i(sx2, sy2, sw2, 2), spec.glow)

	# --- 壁龛:带拱顶的凹进 ---
	for i in spec.niches:
		var nw: int = rng.randi_range(22, 34)
		var nh: int = rng.randi_range(30, 46)
		var nx: int = rng.randi_range(0, maxi(w - nw, 1))
		var ny: int = rng.randi_range(int(h * 0.3), maxi(int(h * 0.75) - nh, int(h * 0.3) + 1))
		_arch(img, nx, ny, nw, nh, spec.stone.darkened(0.35), spec.stone.darkened(0.1))

	# --- 拱券门洞 ---
	for i in spec.arches:
		var aw: int = rng.randi_range(44, 78)
		var ah: int = rng.randi_range(70, 120)
		var ax: int = rng.randi_range(0, maxi(w - aw, 1))
		var ay: int = rng.randi_range(0, maxi(h - ah - 20, 1))
		_arch(img, ax, ay, aw, ah, spec.dark, spec.stone.darkened(0.22))

	# --- 破损 ---
	for i in spec.breaches:
		var bw2: int = rng.randi_range(14, 52)
		var bh2: int = rng.randi_range(10, 40)
		var bx: int = rng.randi_range(0, maxi(w - bw2, 1))
		var by: int = rng.randi_range(0, maxi(h - bh2, 1))
		for yy in bh2:
			var jit: int = rng.randi_range(-3, 3)
			var rx2: int = clampi(bx + jit, 0, w - 1)
			var rw2: int = clampi(bw2 + jit, 1, w - rx2)
			img.fill_rect(Rect2i(rx2, by + yy, rw2, 1), spec.dark)
		for k in rng.randi_range(3, 8):
			var sx3: int = clampi(bx + rng.randi_range(0, bw2), 0, w - 2)
			var sy3: int = clampi(by + bh2 + rng.randi_range(0, 5), 0, h - 2)
			img.fill_rect(Rect2i(sx3, sy3, 2, 2), spec.stone.darkened(0.1))

	_apply_gradient(img, spec.top_darken, spec.bottom_darken)
	return ImageTexture.create_from_image(img)


## 顶与底压暗。拱顶阴影 + 墙根积灰,把中段留给玩家读。
static func _apply_gradient(img: Image, top: float, bottom: float) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var band: int = int(h * 0.34)
	for yy in band:
		var f: float = 1.0 - float(yy) / float(maxi(band, 1))
		var a_top: float = top * f
		var a_bot: float = bottom * f
		if a_top > 0.004:
			_shade_row(img, yy, w, a_top)
		var by: int = h - 1 - yy
		if a_bot > 0.004 and by > band:
			_shade_row(img, by, w, a_bot)


static func _shade_row(img: Image, y: int, w: int, amount: float) -> void:
	for x in w:
		img.set_pixel(x, y, img.get_pixel(x, y).darkened(amount))


static func _arch(img: Image, x: int, y: int, aw: int, ah: int, inner: Color, voussoir: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var r: float = float(aw) * 0.5
	var cx: float = float(x) + r
	var cy: float = float(y) + r
	for yy in range(y, mini(int(cy), h)):
		var dy: float = cy - float(yy)
		if dy > r:
			continue
		var half: int = int(sqrt(maxf(r * r - dy * dy, 0.0)))
		var sx: int = clampi(int(cx) - half, 0, w - 1)
		var sw: int = clampi(half * 2, 1, w - sx)
		img.fill_rect(Rect2i(sx, yy, sw, 1), inner)
		if sx > 0:
			img.fill_rect(Rect2i(sx - 1, yy, 1, 1), voussoir)
		if sx + sw < w:
			img.fill_rect(Rect2i(sx + sw, yy, 1, 1), voussoir)
	var by: int = int(cy)
	var bh: int = mini(y + ah, h) - by
	if bh > 0:
		var bx: int = clampi(x, 0, w - 1)
		var bw: int = clampi(aw, 1, w - bx)
		img.fill_rect(Rect2i(bx, by, bw, bh), inner)
		img.fill_rect(Rect2i(bx, by, 1, bh), voussoir)
		if bx + bw - 1 < w:
			img.fill_rect(Rect2i(bx + bw - 1, by, 1, bh), voussoir)
